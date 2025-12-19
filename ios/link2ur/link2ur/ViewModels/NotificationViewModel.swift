import Foundation
import Combine

class NotificationViewModel: ObservableObject {
    @Published var notifications: [SystemNotification] = []
    @Published var forumNotifications: [ForumNotification] = []
    @Published var unifiedNotifications: [UnifiedNotification] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    func loadNotifications() {
        isLoading = true
        errorMessage = nil
        
        // 并行加载普通通知和论坛通知
        let systemNotifications = apiService.request(NotificationListResponse.self, "/api/users/notifications", method: "GET")
            .map { $0.notifications }
            .catch { _ in Just([SystemNotification]()).eraseToAnyPublisher() }
        
        let forumNotifications = apiService.getForumNotifications(page: 1, pageSize: 50)
            .map { $0.notifications }
            .catch { _ in Just([ForumNotification]()).eraseToAnyPublisher() }
        
        Publishers.Zip(systemNotifications, forumNotifications)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载通知")
                    if let apiError = error as? APIError {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }, receiveValue: { [weak self] (systemNotifs, forumNotifs) in
                self?.notifications = systemNotifs
                self?.forumNotifications = forumNotifs
                self?.updateUnifiedNotifications()
            })
            .store(in: &cancellables)
    }
    
    private func updateUnifiedNotifications() {
        var unified: [UnifiedNotification] = []
        
        // 添加系统通知
        unified.append(contentsOf: notifications.map { UnifiedNotification(from: $0) })
        
        // 添加论坛通知
        unified.append(contentsOf: forumNotifications.map { UnifiedNotification(from: $0) })
        
        // 按创建时间排序（最新的在前）
        unified.sort { $0.createdAt > $1.createdAt }
        
        unifiedNotifications = unified
    }
    
    func markAsRead(notificationId: Int) {
        print("🔔 [NotificationViewModel] markAsRead 被调用，notificationId: \(notificationId)")
        
        // 立即更新本地状态（乐观更新）
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            print("🔔 [NotificationViewModel] 找到通知，索引: \(index)，当前 isRead: \(notifications[index].isRead ?? -1)")
            notifications[index] = notifications[index].markingAsRead()
            print("🔔 [NotificationViewModel] 已更新本地状态，新 isRead: \(notifications[index].isRead ?? -1)")
        } else {
            print("⚠️ [NotificationViewModel] 未找到通知，ID: \(notificationId)")
        }
        
        // 发送API请求 - 使用专门的 markNotificationRead 方法
        print("🔔 [NotificationViewModel] 发送API请求: POST /api/users/notifications/\(notificationId)/read")
        
        apiService.markNotificationRead(notificationId: notificationId)
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    print("❌ [NotificationViewModel] 标记已读失败: \(error.localizedDescription)")
                    print("❌ [NotificationViewModel] 错误详情: \(error)")
                    // 如果API调用失败，回滚乐观更新，重新加载以确保状态同步
                    self?.loadNotifications()
                } else {
                    print("✅ [NotificationViewModel] 标记已读成功")
                }
            }, receiveValue: { [weak self] updatedNotification in
                print("✅ [NotificationViewModel] API调用成功，返回的通知 isRead: \(updatedNotification.isRead ?? -1)")
                // 更新本地状态为服务器返回的状态（确保同步）
                if let index = self?.notifications.firstIndex(where: { $0.id == notificationId }) {
                    self?.notifications[index] = updatedNotification
                    print("✅ [NotificationViewModel] 已同步服务器状态")
                }
            })
            .store(in: &cancellables)
    }
    
    func markForumNotificationAsRead(notificationId: Int) {
        apiService.markForumNotificationRead(notificationId: notificationId)
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] _ in
                // 更新本地状态
                if self?.forumNotifications.contains(where: { $0.id == notificationId }) == true {
                    self?.loadForumNotificationsOnly()
                }
            })
            .store(in: &cancellables)
    }
    
    // 只加载互动相关通知（论坛和排行榜，用于互动信息页面）
    func loadForumNotificationsOnly() {
        isLoading = true
        errorMessage = nil
        
        print("🔍 [NotificationViewModel] 开始加载互动通知（论坛+排行榜）")
        
        // 并行加载论坛通知和普通通知（筛选出排行榜相关的）
        let forumNotifications = apiService.getForumNotifications(page: 1, pageSize: 50)
            .map { $0.notifications }
            .catch { error -> Just<[ForumNotification]> in
                print("⚠️ [NotificationViewModel] 加载论坛通知失败: \(error.localizedDescription)")
                return Just([ForumNotification]())
            }
        
        // 加载普通通知，筛选出排行榜相关的
        let systemNotifications = apiService.request(NotificationListResponse.self, "/api/users/notifications", method: "GET")
            .map { response -> [SystemNotification] in
                // 只保留排行榜相关的通知
                return response.notifications.filter { notification in
                    guard let type = notification.type else { return false }
                    return type.hasPrefix("leaderboard_")
                }
            }
            .catch { error -> Just<[SystemNotification]> in
                print("⚠️ [NotificationViewModel] 加载系统通知失败: \(error.localizedDescription)")
                return Just([SystemNotification]())
            }
        
        Publishers.Zip(forumNotifications, systemNotifications)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    print("❌ [NotificationViewModel] 加载互动通知失败: \(error.localizedDescription)")
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] (forumNotifs, systemNotifs) in
                print("✅ [NotificationViewModel] 论坛通知: \(forumNotifs.count) 条")
                print("✅ [NotificationViewModel] 排行榜通知: \(systemNotifs.count) 条")
                self?.forumNotifications = forumNotifs
                self?.notifications = systemNotifs
                self?.updateUnifiedNotificationsForInteraction()
                print("✅ [NotificationViewModel] 统一通知总数: \(self?.unifiedNotifications.count ?? 0)")
            })
            .store(in: &cancellables)
    }
    
    // 更新统一通知列表（仅用于互动信息，包含论坛通知和排行榜通知）
    private func updateUnifiedNotificationsForInteraction() {
        var unified: [UnifiedNotification] = []
        
        // 添加论坛通知
        unified.append(contentsOf: forumNotifications.map { UnifiedNotification(from: $0) })
        
        // 添加排行榜相关的系统通知
        unified.append(contentsOf: notifications.map { UnifiedNotification(from: $0) })
        
        // 按创建时间排序（最新的在前）
        unified.sort { $0.createdAt > $1.createdAt }
        
        unifiedNotifications = unified
    }
}

