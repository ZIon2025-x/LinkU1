import Foundation
import Combine
import UIKit

public class AppState: ObservableObject {
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: User?
    @Published public var shouldResetHomeView: Bool = false // 用于触发首页重置
    @Published public var unreadNotificationCount: Int = 0 // 未读通知数量
    @Published public var unreadMessageCount: Int = 0 // 未读消息数量（任务聊天）
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private let refreshInterval: TimeInterval = 30 // 每30秒刷新一次
    
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
                
                // 加载未读通知数量
                self?.loadUnreadNotificationCount()
                self?.loadUnreadMessageCount()
                
                // 开始定期刷新未读数量
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
        
        // 监听应用进入前台事件
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                // 应用进入前台时，立即刷新未读数量
                if self?.isAuthenticated == true {
                    self?.loadUnreadNotificationCount()
                    self?.loadUnreadMessageCount()
                }
            }
            .store(in: &cancellables)
        
        // 监听应用变为活跃状态
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                // 应用变为活跃时，立即刷新未读数量
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
        
        apiService.getUnreadNotificationCount()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
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
        
        apiService.getUnreadMessageCount()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { result in
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
        
        // 立即加载一次
        loadUnreadNotificationCount()
        loadUnreadMessageCount()
        
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
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty {
            // 验证Token有效性并加载用户信息
            apiService.request(User.self, "/api/users/profile/me", method: "GET")
                .sink(receiveCompletion: { [weak self] result in
                    if case .failure = result {
                        // Token无效，清除并登出
                        self?.logout()
                    }
                }, receiveValue: { [weak self] user in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    
                    // 建立WebSocket连接
                    if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                        WebSocketService.shared.connect(token: token, userId: user.id)
                    }
                    
                    // 加载未读通知数量
                    self?.loadUnreadNotificationCount()
                    self?.loadUnreadMessageCount()
                    
                    // 开始定期刷新未读数量
                    self?.startPeriodicRefresh()
                    
                    // 检查登录状态后，请求位置权限并获取位置
                    self?.requestLocationAfterLogin()
                })
                .store(in: &cancellables)
        } else {
            isAuthenticated = false
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
        
        KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
        KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
        isAuthenticated = false
        currentUser = nil
        unreadNotificationCount = 0
        unreadMessageCount = 0
    }
}

