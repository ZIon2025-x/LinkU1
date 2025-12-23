import Foundation
import Combine
import UIKit

public class AppState: ObservableObject {
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: User?
    @Published public var shouldResetHomeView: Bool = false { // 用于触发首页重置
        didSet {
            print("🔍 [AppState] shouldResetHomeView 变化: \(oldValue) -> \(shouldResetHomeView), 时间: \(Date())")
            if shouldResetHomeView {
                print("🔍 [AppState] ⚠️ 触发首页重置！这可能导致详情页返回")
            }
        }
    }
    @Published public var unreadNotificationCount: Int = 0 // 未读通知数量
    @Published public var unreadMessageCount: Int = 0 // 未读消息数量（任务聊天）
    @Published public var hideTabBar: Bool = false // 控制是否隐藏底部 TabBar
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
    
    public init() {
        setupNotifications()
        // 延迟检查登录状态，避免阻塞初始化
        DispatchQueue.main.async { [weak self] in
            self?.checkLoginStatus()
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
                
                // 登录成功后，请求位置权限并获取位置
                self?.requestLocationAfterLogin()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                // 登出时断开WebSocket连接
                WebSocketService.shared.disconnect()
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
        
        // 监听应用进入前台事件（合并处理，避免重复调用）
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification))
            .debounce(for: .milliseconds(500), scheduler: DispatchQueue.main) // 防抖，避免两个通知同时触发
            .sink { [weak self] _ in
                // 应用进入前台或变为活跃时，刷新未读数量
                if self?.isAuthenticated == true {
                    self?.loadUnreadNotificationCount()
                    self?.loadUnreadMessageCount()
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
                if case .failure(let error) = result {
                    print("⚠️ 加载未读通知数量失败: \(error.localizedDescription)")
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
        
        apiService.getUnreadMessageCount()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingMessageCount = false
                if case .failure(let error) = result {
                    print("⚠️ 加载未读消息数量失败: \(error.localizedDescription)")
                }
            }, receiveValue: { [weak self] response in
                // 后端返回格式：{"unread_count": 5} 或 {"total": 5} 或 {"tasks": 5}
                if let count = response["unread_count"] {
                    self?.unreadMessageCount = count
                } else if let total = response["total"] {
                    self?.unreadMessageCount = total
                } else if let tasks = response["tasks"] {
                    // 如果 tasks 是数字，直接使用
                    self?.unreadMessageCount = tasks
                } else {
                    // 如果没有找到任何字段，设置为0
                    self?.unreadMessageCount = 0
                }
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
        isCheckingLoginStatus = true
        let startTime = Date()
        let minimumDisplayTime: TimeInterval = 3.0 // 至少显示3秒
        
        // 在加载界面显示期间，提前预加载首页数据
        preloadHomeData()
        
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty {
            // 验证Token有效性并加载用户信息
            apiService.request(User.self, "/api/users/profile/me", method: "GET")
                .sink(receiveCompletion: { [weak self] result in
                    let elapsed = Date().timeIntervalSince(startTime)
                    let remainingTime = max(0, minimumDisplayTime - elapsed)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                        self?.isCheckingLoginStatus = false
                        if case .failure = result {
                            // Token无效，清除并登出
                            self?.logout()
                        }
                    }
                }, receiveValue: { [weak self] user in
                    let elapsed = Date().timeIntervalSince(startTime)
                    let remainingTime = max(0, minimumDisplayTime - elapsed)
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + remainingTime) {
                        self?.currentUser = user
                        self?.isAuthenticated = true
                        self?.isCheckingLoginStatus = false
                        
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
                self.userSkippedLogin = skippedLogin
            }
        }
    }
    
    /// 预加载首页数据，在加载界面显示期间提前加载
    private func preloadHomeData() {
        // 预加载推荐任务（首页最重要的数据）
        apiService.getTasks(page: 1, pageSize: 20, type: nil, location: nil, keyword: nil, sortBy: nil, userLatitude: nil, userLongitude: nil)
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    Logger.warning("预加载推荐任务失败: \(error.localizedDescription)", category: .api)
                } else {
                    Logger.success("预加载推荐任务成功", category: .api)
                }
            }, receiveValue: { response in
                // 将数据保存到缓存，这样首页加载时可以直接使用
                let openTasks = response.tasks.filter { $0.status == .open }
                CacheManager.shared.saveTasks(openTasks, category: nil, city: nil)
                Logger.success("已预加载并缓存 \(openTasks.count) 个任务", category: .cache)
            })
            .store(in: &cancellables)
        
        // 预加载热门活动（延迟一点，避免同时发起太多请求）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.apiService.request([Activity].self, "/api/activities?status=active&limit=10", method: "GET")
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        Logger.warning("预加载热门活动失败: \(error.localizedDescription)", category: .api)
                    } else {
                        Logger.success("预加载热门活动成功", category: .api)
                    }
                }, receiveValue: { activities in
                    Logger.success("已预加载 \(activities.count) 个活动", category: .cache)
                })
                .store(in: &self.cancellables)
        }
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
    
    public func logout() {
        // 停止定期刷新
        stopPeriodicRefresh()
        
        // 断开WebSocket连接
        WebSocketService.shared.disconnect()
        
        _ = KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
        _ = KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
        isAuthenticated = false
        currentUser = nil
        unreadNotificationCount = 0
        unreadMessageCount = 0
    }
}

