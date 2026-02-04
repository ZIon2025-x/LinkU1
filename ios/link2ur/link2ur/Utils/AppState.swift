import Foundation
import Combine
import UIKit

public class AppState: ObservableObject {
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: User?
    @Published public var shouldResetHomeView: Bool = false // 用于触发首页重置
    @Published public var unreadNotificationCount: Int = 0 // 未读通知数量
    @Published public var unreadMessageCount: Int = 0 // 未读消息数量（任务聊天）
    @Published public var isCheckingLoginStatus: Bool = true // 是否正在检查登录状态
    @Published public var userSkippedLogin: Bool = false // 用户是否选择跳过登录
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 60 // 每60秒刷新一次（减少请求频率）
    private var isLoadingNotificationCount = false // 防止重复请求
    private var isLoadingMessageCount = false // 防止重复请求
    private var lastNotificationRefreshTime: Date? // 记录上次刷新时间
    private var lastMessageRefreshTime: Date? // 记录上次刷新时间
    private let minRefreshInterval: TimeInterval = 10 // 最小刷新间隔（秒）- 增加到10秒，减少请求频率
    private var isPreloadingHomeData = false // 防止重复预加载首页数据
    private var preloadTaskCompleted = false // 预加载任务请求完成标志
    private var preloadActivityCompleted = false // 预加载活动请求完成标志
    private var isCheckingLogin = false // 防止重复检查登录状态
    
    public init() {
        setupNotifications()
        // 直接检查登录状态：Keychain 读取很快，网络请求异步；尽早设 isAuthenticated 避免用户点需登录功能时误弹登录框
        checkLoginStatus()
        
        // 初始化时清除 Badge（如果未登录）
        // 登录后会自动更新 Badge
        if !isAuthenticated {
            BadgeManager.shared.clearBadge()
        }
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .userDidLogin)
            .compactMap { $0.object as? User }
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = true
                
                // 登录成功后，建立WebSocket连接
                if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                    WebSocketService.shared.connect(token: token, userId: user.id)
                }
                
                // 开始定期刷新未读数量（会立即加载一次）
                self?.startPeriodicRefresh()
                
                // 登录成功后，更新设备令牌（确保令牌是最新的）
                if let deviceToken = UserDefaults.standard.string(forKey: "device_token") {
                    APIService.shared.registerDeviceToken(deviceToken) { success in
                        if success {
                            Logger.debug("设备令牌已更新（登录成功后）", category: .api)
                        }
                    }
                }
                
                // 登录成功后，请求位置权限并获取位置
                self?.requestLocationAfterLogin()
                
                // 登录成功后，智能预加载推荐任务
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self?.preloadRecommendedTasksIfNeeded()
                }
                
                // 登录成功后，同步引导教程保存的偏好设置到服务器
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    self?.syncOnboardingPreferencesToServer()
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                // 登出时调用 logout()，它会处理 WebSocket 断开和清除
                self?.logout()
            }
            .store(in: &cancellables)
        
        // 监听 WebSocket 通知事件
        WebSocketService.shared.notificationSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // 收到通知事件，刷新未读数量
                self?.loadUnreadNotificationCount()
            }
            .store(in: &cancellables)
        
        // 监听 WebSocket 消息事件
        WebSocketService.shared.messageSubject
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // 收到新消息，刷新未读消息数量
                self?.loadUnreadMessageCount()
            }
            .store(in: &cancellables)
        
        // 未读数量变化时更新应用图标 Badge（替代原 didSet）
        $unreadNotificationCount.merge(with: $unreadMessageCount)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateAppIconBadge()
            }
            .store(in: &cancellables)

        // 监听任务状态更新，清理已完成/取消任务的图片缓存
        NotificationCenter.default.publisher(for: .taskUpdated)
            .compactMap { $0.object as? Task }
            .sink { task in
                // 如果任务状态变为已完成或取消，清理相关图片缓存
                if task.status == .completed || task.status == .cancelled {
                    ImageCache.shared.clearTaskImages(task: task)
                }
            }
            .store(in: &cancellables)
        
        // 监听应用进入前台事件（合并处理，避免重复调用）
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main) // 防抖，避免两个通知同时触发
            .sink { [weak self] _ in
                // 应用进入前台或变为活跃时，刷新未读数量
                if self?.isAuthenticated == true {
                    self?.loadUnreadNotificationCount()
                    self?.loadUnreadMessageCount()
                    
                    // 更新设备令牌（确保令牌始终是最新的）
                    if let deviceToken = UserDefaults.standard.string(forKey: "device_token") {
                        APIService.shared.registerDeviceToken(deviceToken) { success in
                            if success {
                                Logger.debug("设备令牌已更新（应用恢复前台）", category: .api)
                            }
                        }
                    }
                } else {
                    // 未登录时清除 Badge
                    BadgeManager.shared.clearBadge()
                }
            }
            .store(in: &cancellables)
    }
    
    /// 加载未读通知数量
    public func loadUnreadNotificationCount() {
        guard isAuthenticated else {
            unreadNotificationCount = 0
            return
        }
        
        // 防止重复请求
        guard !isLoadingNotificationCount else {
            return
        }
        
        // 检查最小刷新间隔
        if let lastRefresh = lastNotificationRefreshTime,
           Date().timeIntervalSince(lastRefresh) < minRefreshInterval {
            return
        }
        
        isLoadingNotificationCount = true
        lastNotificationRefreshTime = Date()
        
        apiService.getUnreadNotificationCount()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingNotificationCount = false
                if case .failure = result {
                }
            }, receiveValue: { [weak self] response in
                // 后端返回格式：{"unread_count": 5}（参考 frontend api.ts）
                if let count = response["unread_count"] {
                    self?.unreadNotificationCount = count
                } else {
                    // 如果没有 unread_count 字段，尝试分别统计
                    let taskCount = response["task"] ?? 0
                    let forumCount = response["forum"] ?? 0
                    self?.unreadNotificationCount = taskCount + forumCount
                }
                // Badge 会在 unreadNotificationCount 的 didSet 中自动更新
            })
            .store(in: &cancellables)
    }
    
    /// 加载未读消息数量（任务聊天）
    public func loadUnreadMessageCount() {
        guard isAuthenticated else {
            unreadMessageCount = 0
            return
        }
        
        // 防止重复请求
        guard !isLoadingMessageCount else {
            return
        }
        
        // 检查最小刷新间隔
        if let lastRefresh = lastMessageRefreshTime,
           Date().timeIntervalSince(lastRefresh) < minRefreshInterval {
            return
        }
        
        isLoadingMessageCount = true
        lastMessageRefreshTime = Date()
        
        // 使用任务聊天消息的未读数量 API
        apiService.getTaskChatUnreadCount()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingMessageCount = false
                if case .failure = result {
                    // 失败时不清零，保持上次的值
                }
            }, receiveValue: { [weak self] response in
                // 后端返回格式：{"unread_count": 5}
                if let count = response["unread_count"] {
                    self?.unreadMessageCount = count
                } else {
                    // 如果没有找到 unread_count 字段，设置为0
                    self?.unreadMessageCount = 0
                }
                // Badge 会在 unreadMessageCount 的 didSet 中自动更新
            })
            .store(in: &cancellables)
    }
    
    /// 开始定期刷新未读数量
    private func startPeriodicRefresh() {
        // 停止现有的定时器
        stopPeriodicRefresh()
        
        guard isAuthenticated else { return }
        
        // 延迟加载未读数量，避免启动时阻塞主线程
        // 先延迟500ms加载通知数量，再延迟800ms加载消息数量，避免同时发起请求
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.loadUnreadNotificationCount()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            self?.loadUnreadMessageCount()
        }
        
        // 创建定时器，定期刷新
        refreshTimer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            guard let self = self, self.isAuthenticated else {
                self?.stopPeriodicRefresh()
                return
            }
            self.loadUnreadNotificationCount()
            self.loadUnreadMessageCount()
        }
    }
    
    /// 停止定期刷新
    private func stopPeriodicRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
    
    public func checkLoginStatus() {
        // 防止重复调用
        guard !isCheckingLogin else {
            Logger.debug("登录状态检查已在进行中，跳过重复调用", category: .auth)
            return
        }
        
        isCheckingLogin = true
        isCheckingLoginStatus = true
        let startTime = Date()
        let minimumDisplayTime: TimeInterval = 3.0 // 至少显示3秒
        
        // 在加载界面显示期间，提前预加载首页数据
        preloadHomeData()
        
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty {
            // 有 token 即先视为已登录，避免 /me 返回前或用户跳过加载时点击需登录功能误弹登录框；/me 失败且刷新失败时会在 receiveCompletion 或 APIService 中置为 false
            isAuthenticated = true
            // 验证 Token 有效性并加载用户信息
            apiService.request(User.self, "/api/users/profile/me", method: "GET")
                .sink(receiveCompletion: { [weak self] result in
                    let elapsed = Date().timeIntervalSince(startTime)
                    let remainingTime = max(0, minimumDisplayTime - elapsed)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                        self?.isCheckingLoginStatus = false
                        self?.isCheckingLogin = false
                        if case .failure(let error) = result {
                            // ⚠️ 修复：区分网络错误和认证错误
                            // 只有真正的认证失败（401且刷新失败）才应该登出
                            // 网络错误、超时等不应该导致登出，保持登录状态
                            if case APIError.unauthorized = error {
                                // 401 未授权：可能是 token 过期，尝试刷新
                                Logger.warning("登录状态检查：401 未授权，可能是 token 过期", category: .auth)
                                // 注意：APIService 会自动尝试刷新 token
                                // 如果刷新失败，APIService 会处理登出逻辑
                                // 这里不立即登出，等待刷新结果
                                // 但先设置为已登录，让用户可以使用 app（如果 token 有效，后续请求会成功）
                                self?.isAuthenticated = true
                            } else if case APIError.httpError(401) = error {
                                // HTTP 401 错误：认证失败
                                Logger.warning("登录状态检查：HTTP 401 错误，认证失败", category: .auth)
                                // 不立即登出，等待 token 刷新机制处理
                                // 但先设置为已登录，让用户可以使用 app（如果 token 有效，后续请求会成功）
                                self?.isAuthenticated = true
                            } else {
                                // 网络错误、超时等：不登出，保持登录状态
                                Logger.warning("登录状态检查失败（网络错误），保持登录状态: \(error.localizedDescription)", category: .auth)
                                // ⚠️ 关键修复：如果 Keychain 中有 token，即使验证失败（网络错误），也先设置为已登录
                                // 这样用户可以使用 app，后续请求会自动重试，如果 token 有效会成功
                                // 如果 token 真的无效，APIService 的刷新机制会处理登出
                                self?.isAuthenticated = true
                                
                                // 尝试建立 WebSocket 连接（如果 token 有效）
                                if KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) != nil {
                                    // 注意：这里无法获取 userId，所以暂时不连接 WebSocket
                                    // 等后续请求成功后，会自动连接
                                }
                            }
                        }
                    }
                }, receiveValue: { [weak self] user in
                    let elapsed = Date().timeIntervalSince(startTime)
                    let remainingTime = max(0, minimumDisplayTime - elapsed)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                        self?.currentUser = user
                        self?.isAuthenticated = true
                        self?.isCheckingLoginStatus = false
                        self?.isCheckingLogin = false
                        
                        // 建立WebSocket连接
                        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                            WebSocketService.shared.connect(token: token, userId: user.id)
                        }
                        
                        // 开始定期刷新未读数量（会立即加载一次）
                        self?.startPeriodicRefresh()
                        
                        // 检查登录状态后，请求位置权限并获取位置
                        self?.requestLocationAfterLogin()
                    }
                })
                .store(in: &cancellables)
        } else {
            // 没有 token，检查用户是否之前选择跳过登录
            let skippedLogin = UserDefaults.standard.bool(forKey: "user_skipped_login")
            // 确保加载界面至少显示3秒，提供更好的用户体验
            DispatchQueue.main.asyncAfter(deadline: .now() + minimumDisplayTime) {
                self.isAuthenticated = false
                self.isCheckingLoginStatus = false
                self.isCheckingLogin = false
                self.userSkippedLogin = skippedLogin
            }
        }
    }
    
    /// 预加载首页数据，在加载界面显示期间提前加载
    private func preloadHomeData() {
        // 防止重复预加载
        guard !isPreloadingHomeData else {
            Logger.debug("首页数据正在预加载中，跳过重复调用", category: .cache)
            return
        }
        
        isPreloadingHomeData = true
        
        // 重置完成标志
        preloadTaskCompleted = false
        preloadActivityCompleted = false
        
        // 预加载推荐任务（首页最重要的数据，增强：包含GPS位置）
        var userLat: Double? = nil
        var userLon: Double? = nil
        if let userLocation = LocationService.shared.currentLocation {
            userLat = userLocation.latitude
            userLon = userLocation.longitude
        }
        apiService.getTaskRecommendations(limit: 20, algorithm: "hybrid", taskType: nil, location: nil, keyword: nil, latitude: userLat, longitude: userLon)
            .sink(receiveCompletion: { [weak self] result in
                guard let self = self else { return }
                if case .failure(let error) = result {
                    Logger.warning("预加载推荐任务失败: \(error.localizedDescription)，回退到普通任务", category: .api)
                    // 如果推荐任务加载失败，回退到普通任务
                    self.preloadNormalTasks()
                } else {
                    Logger.success("预加载推荐任务成功", category: .api)
                }
                self.preloadTaskCompleted = true
                // 如果两个请求都完成了，重置标志
                if self.preloadTaskCompleted && self.preloadActivityCompleted {
                    self.isPreloadingHomeData = false
                }
            }, receiveValue: { [weak self] response in
                // 将推荐任务转换为 Task 对象并保存到专用缓存
                let recommendedTasks = response.recommendations.map { $0.toTask() }
                let openRecommendedTasks = recommendedTasks.filter { $0.status == .open }
                CacheManager.shared.saveTasks(openRecommendedTasks, category: nil, city: nil, isRecommended: true)
                Logger.success("已预加载并缓存 \(openRecommendedTasks.count) 个推荐任务", category: .cache)
                // 确保 self 存在时才更新状态
                guard self != nil else { return }
            })
            .store(in: &cancellables)
        
        // 同时预加载普通任务（作为后备和补充）
        preloadNormalTasks()
        
        // 预加载 Banner（延迟一点，避免同时发起太多请求）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.apiService.getBanners()
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        Logger.warning("预加载 Banner 失败: \(error.localizedDescription)", category: .api)
                    } else {
                        Logger.success("预加载 Banner 成功", category: .api)
                    }
                }, receiveValue: { [weak self] response in
                    guard self != nil else { return }
                    // 将 Banner 数据保存到缓存
                    CacheManager.shared.saveBanners(response.banners)
                    Logger.success("已预加载并缓存 \(response.banners.count) 个 Banner", category: .cache)
                })
                .store(in: &self.cancellables)
        }
        
        // 预加载热门活动（延迟一点，避免同时发起太多请求）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.apiService.request([Activity].self, "/api/activities?status=active&limit=10", method: "GET")
                .sink(receiveCompletion: { [weak self] result in
                    guard let self = self else { return }
                    self.preloadActivityCompleted = true
                    if case .failure(let error) = result {
                        Logger.warning("预加载热门活动失败: \(error.localizedDescription)", category: .api)
                    } else {
                        Logger.success("预加载热门活动成功", category: .api)
                    }
                    // 如果两个请求都完成了，重置标志
                    if self.preloadTaskCompleted && self.preloadActivityCompleted {
                        self.isPreloadingHomeData = false
                    }
                }, receiveValue: { [weak self] activities in
                    guard self != nil else { return }
                    Logger.success("已预加载 \(activities.count) 个活动", category: .cache)
                })
                .store(in: &self.cancellables)
        }
    }
    
    /// 预加载普通任务（作为推荐任务的后备）
    private func preloadNormalTasks() {
        apiService.getTasks(page: 1, pageSize: 20, type: nil, location: nil, keyword: nil, sortBy: nil, userLatitude: nil, userLongitude: nil)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.warning("预加载普通任务失败: \(error.localizedDescription)", category: .api)
                } else {
                    Logger.success("预加载普通任务成功", category: .api)
                }
            }, receiveValue: { response in
                // 将普通任务保存到缓存
                let openTasks = response.tasks.filter { $0.status == .open }
                CacheManager.shared.saveTasks(openTasks, category: nil, city: nil, isRecommended: false)
                Logger.success("已预加载并缓存 \(openTasks.count) 个普通任务", category: .cache)
            })
            .store(in: &cancellables)
    }
    
    /// 智能预加载推荐任务（登录后延迟加载，避免影响登录流程，增强：包含GPS位置）
    private func preloadRecommendedTasksIfNeeded() {
        guard isAuthenticated, !isPreloadingHomeData else { return }
        
        // 增强：获取GPS位置（如果用户允许位置权限）
        var userLat: Double? = nil
        var userLon: Double? = nil
        if let userLocation = LocationService.shared.currentLocation {
            userLat = userLocation.latitude
            userLon = userLocation.longitude
        }
        apiService.getTaskRecommendations(limit: 20, algorithm: "hybrid", taskType: nil, location: nil, keyword: nil, latitude: userLat, longitude: userLon)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.warning("智能预加载推荐任务失败: \(error.localizedDescription)", category: .api)
                } else {
                    Logger.success("智能预加载推荐任务成功", category: .api)
                }
            }, receiveValue: { response in
                // 将推荐任务转换为 Task 对象并保存到专用缓存
                let recommendedTasks = response.recommendations.map { $0.toTask() }
                let openRecommendedTasks = recommendedTasks.filter { $0.status == .open }
                CacheManager.shared.saveTasks(openRecommendedTasks, category: nil, city: nil, isRecommended: true)
                Logger.success("已智能预加载并缓存 \(openRecommendedTasks.count) 个推荐任务", category: .cache)
            })
            .store(in: &cancellables)
    }
    
    /// 登录后请求位置权限并获取位置
    private func requestLocationAfterLogin() {
        guard isAuthenticated else { return }
        
        // 请求位置权限
        LocationService.shared.requestAuthorization()
        
        // 监听位置更新（GPS坐标）
        LocationService.shared.$currentLocation
            .compactMap { $0 }
            .sink { _ in
                // 位置已更新，可以用于排序等功能
            }
            .store(in: &cancellables)
        
        // 监听城市名称更新
        LocationService.shared.$currentCityName
            .compactMap { $0 }
            .sink { _ in
                // 城市名称已确定，可以用于筛选任务
            }
            .store(in: &cancellables)
    }
    
    /// 同步引导教程保存的偏好设置到服务器
    private func syncOnboardingPreferencesToServer() {
        // 检查是否有引导教程保存的偏好设置
        guard let preferredCity = UserDefaults.standard.string(forKey: "preferred_city"),
              !preferredCity.isEmpty else {
            return
        }
        
        guard let preferredTaskTypes = UserDefaults.standard.array(forKey: "preferred_task_types") as? [String],
              !preferredTaskTypes.isEmpty else {
            return
        }
        
        // 检查是否已经同步过（避免重复同步）
        if UserDefaults.standard.bool(forKey: "onboarding_preferences_synced") {
            return
        }
        
        // 将本地化的显示名称转换为后端值
        let taskTypeMapping: [String: String] = [
            LocalizationKey.taskCategoryErrandRunning.localized: "Errand Running",
            LocalizationKey.taskCategorySkillService.localized: "Skill Service",
            LocalizationKey.taskCategoryHousekeeping.localized: "Housekeeping",
            LocalizationKey.taskCategoryTransportation.localized: "Transportation",
            LocalizationKey.taskCategorySocialHelp.localized: "Social Help",
            LocalizationKey.taskCategoryCampusLife.localized: "Campus Life",
            LocalizationKey.taskCategorySecondhandRental.localized: "Second-hand & Rental",
            LocalizationKey.taskCategoryPetCare.localized: "Pet Care",
            LocalizationKey.taskCategoryLifeConvenience.localized: "Life Convenience",
            LocalizationKey.taskCategoryOther.localized: "Other"
        ]
        
        // 转换任务类型
        let backendTaskTypes = preferredTaskTypes.compactMap { taskTypeMapping[$0] }
        
        // 创建用户偏好对象
        let preferences = UserPreferences(
            taskTypes: backendTaskTypes,
            locations: [preferredCity],
            taskLevels: [],
            keywords: [],
            minDeadlineDays: 1
        )
        
        // 同步到服务器
        apiService.updateUserPreferences(preferences: preferences)
            .sink(
                receiveCompletion: { result in
                    if case .failure(let error) = result {
                        Logger.warning("同步引导偏好设置失败: \(error.localizedDescription)", category: .api)
                    }
                },
                receiveValue: { _ in
                    // 标记已同步，避免重复同步
                    UserDefaults.standard.set(true, forKey: "onboarding_preferences_synced")
                    Logger.success("引导偏好设置已同步到服务器", category: .api)
                }
            )
            .store(in: &cancellables)
    }
    
    public func logout() {
        // 停止定期刷新
        stopPeriodicRefresh()
        
        // 断开WebSocket连接并清除用户信息
        WebSocketService.shared.disconnectAndClear()
        
        // 登出时注销设备token（防止其他用户登录后收到当前用户的推送）
        // 注意：必须在清除认证信息之前发起 API 请求
        let deviceToken = UserDefaults.standard.string(forKey: "device_token")
        
        // 先清除本地认证信息和状态（让 UI 立即响应）
        _ = KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
        _ = KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
        isAuthenticated = false
        currentUser = nil
        unreadNotificationCount = 0
        unreadMessageCount = 0
        
        // 登出时清除应用图标 Badge
        BadgeManager.shared.clearBadge()
        
        // 异步注销设备令牌（不阻塞 UI）
        // 即使认证已清除，服务端可能仍然能处理这个请求（通过设备令牌本身识别）
        // 即使失败也没关系，服务端会在下次推送失败时自动清理无效的令牌
        if let token = deviceToken {
            DispatchQueue.global(qos: .utility).async {
                APIService.shared.unregisterDeviceToken(token) { success in
                    if success {
                        Logger.debug("设备令牌已注销（登出时）", category: .api)
                    } else {
                        Logger.debug("设备令牌注销请求已发送（登出时），结果无关紧要", category: .api)
                    }
                }
            }
        }
    }
    
    /// 更新应用图标 Badge
    /// 根据未读通知和消息的总数更新应用图标上的 Badge
    private func updateAppIconBadge() {
        let totalUnread = unreadNotificationCount + unreadMessageCount
        BadgeManager.shared.updateBadge(count: totalUnread)
    }
}

