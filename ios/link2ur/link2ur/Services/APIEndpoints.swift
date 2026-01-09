import Foundation

/// API 端点统一管理
/// 所有 API 端点路径都在这里定义，便于维护和修改
enum APIEndpoints {
    // MARK: - Authentication (认证)
    enum Auth {
        static let login = "/api/secure-auth/login"
        static let loginWithCode = "/api/secure-auth/login-with-code"
        static let loginWithPhoneCode = "/api/secure-auth/login-with-phone-code"
        static let sendVerificationCode = "/api/secure-auth/send-verification-code"
        static let sendPhoneVerificationCode = "/api/secure-auth/send-phone-verification-code"
        static let refresh = "/api/secure-auth/refresh"
        static let logout = "/api/secure-auth/logout"
        static let captchaSiteKey = "/api/secure-auth/captcha-site-key"
    }
    
    // MARK: - Users (用户)
    enum Users {
        static let register = "/api/users/register"
        static let profileMe = "/api/users/profile/me"
        static func profile(_ userId: String) -> String {
            "/api/users/profile/\(userId)"
        }
        static let updateAvatar = "/api/users/profile/avatar"
        static let sendEmailUpdateCode = "/api/users/profile/send-email-update-code"
        static let sendPhoneUpdateCode = "/api/users/profile/send-phone-update-code"
        static let myTasks = "/api/users/my-tasks"
        static let notifications = "/api/users/notifications"
        static let unreadNotifications = "/api/users/notifications/unread"
        static let unreadNotificationCount = "/api/users/notifications/unread/count"
        static func markNotificationRead(_ id: Int) -> String {
            "/api/users/notifications/\(id)/read"
        }
        static let markAllNotificationsRead = "/api/users/notifications/read-all"
        static let deviceToken = "/api/users/device-token"
        static let contacts = "/api/users/contacts"
        static func markChatRead(_ contactId: String) -> String {
            "/api/users/messages/mark-chat-read/\(contactId)"
        }
        static let messagesUnread = "/api/users/messages/unread"
        static let messagesUnreadCount = "/api/users/messages/unread/count"
        static func messageHistory(_ userId: String) -> String {
            "/api/users/messages/history/\(userId)"
        }
        static let messagesSend = "/api/users/messages/send"
        static func markMessageRead(_ messageId: Int) -> String {
            "/api/messages/\(messageId)/read"
        }
        static let customerServiceAssign = "/api/users/user/customer-service/assign"
        static let customerServiceChats = "/api/users/user/customer-service/chats"
        static func customerServiceMessages(_ chatId: String) -> String {
            "/api/users/user/customer-service/chats/\(chatId)/messages"
        }
        static func customerServiceEndChat(_ chatId: String) -> String {
            "/api/users/user/customer-service/chats/\(chatId)/end"
        }
        static func customerServiceRate(_ chatId: String) -> String {
            "/api/users/user/customer-service/chats/\(chatId)/rate"
        }
        static let customerServiceQueueStatus = "/api/users/user/customer-service/queue-status"
        static func taskComplete(_ taskId: Int) -> String {
            "/api/users/tasks/\(taskId)/complete"
        }
        static let myServiceApplications = "/api/users/me/service-applications"
    }
    
    // MARK: - Tasks (任务)
    enum Tasks {
        static let list = "/api/tasks"
        static func detail(_ id: Int) -> String {
            "/api/tasks/\(id)"
        }
        static func apply(_ id: Int) -> String {
            "/api/tasks/\(id)/apply"
        }
        static func applyString(_ id: String) -> String {
            "/api/tasks/\(id)/apply"
        }
        static func confirmCompletion(_ id: Int) -> String {
            "/api/tasks/\(id)/confirm_completion"
        }
        static func cancel(_ id: Int) -> String {
            "/api/tasks/\(id)/cancel"
        }
        static func delete(_ id: Int) -> String {
            "/api/tasks/\(id)/delete"
        }
        static func reject(_ id: Int) -> String {
            "/api/tasks/\(id)/reject"
        }
        static func review(_ id: Int) -> String {
            "/api/tasks/\(id)/review"
        }
        static func reviews(_ id: Int) -> String {
            "/api/tasks/\(id)/reviews"
        }
        static func participants(_ id: String) -> String {
            "/api/tasks/\(id)/participants"
        }
        static func participantComplete(_ id: String) -> String {
            "/api/tasks/\(id)/participants/me/complete"
        }
        static func participantExitRequest(_ id: String) -> String {
            "/api/tasks/\(id)/participants/me/exit-request"
        }
        static func applications(_ id: Int) -> String {
            "/api/tasks/\(id)/applications"
        }
        static func acceptApplication(_ taskId: Int, _ applicationId: Int) -> String {
            "/api/tasks/\(taskId)/applications/\(applicationId)/accept"
        }
        static func rejectApplication(_ taskId: Int, _ applicationId: Int) -> String {
            "/api/tasks/\(taskId)/applications/\(applicationId)/reject"
        }
        static func withdrawApplication(_ taskId: Int, _ applicationId: Int) -> String {
            "/api/tasks/\(taskId)/applications/\(applicationId)/withdraw"
        }
        static func negotiateApplication(_ taskId: Int, _ applicationId: Int) -> String {
            "/api/tasks/\(taskId)/applications/\(applicationId)/negotiate"
        }
        static func respondNegotiation(_ taskId: Int, _ applicationId: Int) -> String {
            "/api/tasks/\(taskId)/applications/\(applicationId)/respond-negotiation"
        }
        static func sendApplicationMessage(_ taskId: Int, _ applicationId: Int) -> String {
            "/api/tasks/\(taskId)/applications/\(applicationId)/send-message"
        }
        static func replyApplicationMessage(_ taskId: Int, _ applicationId: Int) -> String {
            "/api/tasks/\(taskId)/applications/\(applicationId)/reply-message"
        }
    }
    
    // MARK: - Task Messages (任务消息)
    enum TaskMessages {
        static let list = "/api/messages/tasks"
        static func taskMessages(_ taskId: Int) -> String {
            "/api/messages/task/\(taskId)"
        }
        static func send(_ taskId: Int) -> String {
            "/api/messages/task/\(taskId)/send"
        }
        static func read(_ taskId: Int) -> String {
            "/api/messages/task/\(taskId)/read"
        }
    }
    
    // MARK: - Notifications (通知)
    enum Notifications {
        static func negotiationTokens(_ notificationId: Int) -> String {
            "/api/notifications/\(notificationId)/negotiation-tokens"
        }
    }
    
    // MARK: - Points & Coupons (积分和优惠券)
    enum Points {
        static let account = "/api/coupon-points/points/account"
        static let transactions = "/api/coupon-points/points/transactions"
    }
    
    enum Coupons {
        static let available = "/api/coupons/available"
        static let my = "/api/coupons/my"
        static let claim = "/api/coupons/claim"
    }
    
    // MARK: - Payment (支付)
    enum Payment {
        static func createTaskPayment(_ taskId: Int) -> String {
            "/api/coupon-points/tasks/\(taskId)/payment"
        }
        static let paymentHistory = "/api/coupon-points/payment-history"
    }
    
    // MARK: - Check-in (签到)
    enum CheckIn {
        static let checkIn = "/api/checkin"
        static let status = "/api/checkin/status"
        static let rewards = "/api/checkin/rewards"
    }
    
    // MARK: - Invitation Codes (邀请码)
    enum InvitationCodes {
        static let validate = "/api/invitation-codes/validate"
    }
    
    // MARK: - Student Verification (学生认证)
    enum StudentVerification {
        static let status = "/api/student-verification/status"
        static let submit = "/api/student-verification/submit"
        static let renew = "/api/student-verification/renew"
        static let changeEmail = "/api/student-verification/change-email"
        static let universities = "/api/student-verification/universities"
    }
    
    // MARK: - Forum (论坛)
    enum Forum {
        static let categories = "/api/forum/forums/visible"
        static let posts = "/api/forum/posts"
        static func postDetail(_ id: Int) -> String {
            "/api/forum/posts/\(id)"
        }
        static func replies(_ postId: Int) -> String {
            "/api/forum/posts/\(postId)/replies"
        }
        static let likes = "/api/forum/likes"
        static let favorites = "/api/forum/favorites"
        static func incrementView(_ postId: Int) -> String {
            "/api/forum/posts/\(postId)/view"
        }
        static let myPosts = "/api/forum/my/posts"
        static let myReplies = "/api/forum/my/replies"
        static let notifications = "/api/forum/notifications"
        static func markNotificationRead(_ id: Int) -> String {
            "/api/forum/notifications/\(id)/read"
        }
        static let markAllNotificationsRead = "/api/forum/notifications/read-all"
    }
    
    // MARK: - Flea Market (跳蚤市场)
    enum FleaMarket {
        static let items = "/api/flea-market/items"
        static func itemDetail(_ id: String) -> String {
            "/api/flea-market/items/\(id)"
        }
        static func directPurchase(_ id: String) -> String {
            "/api/flea-market/items/\(id)/direct-purchase"
        }
        static func refresh(_ id: String) -> String {
            "/api/flea-market/items/\(id)/refresh"
        }
        static func favorite(_ id: String) -> String {
            "/api/flea-market/items/\(id)/favorite"
        }
        static func purchaseRequest(_ id: String) -> String {
            "/api/flea-market/items/\(id)/purchase-request"
        }
        static func report(_ id: String) -> String {
            "/api/flea-market/items/\(id)/report"
        }
        static let myPurchases = "/api/flea-market/my-purchases"
        static let favorites = "/api/flea-market/favorites/items"
    }
    
    // MARK: - Task Experts (任务达人)
    enum TaskExperts {
        static let list = "/api/task-experts"
        static func detail(_ id: String) -> String {
            "/api/task-experts/\(id)"
        }
        static func services(_ expertId: String) -> String {
            "/api/task-experts/\(expertId)/services"
        }
        static func applyForService(_ serviceId: Int) -> String {
            "/api/task-experts/services/\(serviceId)/apply"
        }
        static let apply = "/api/task-experts/apply"
    }
    
    // MARK: - Activities (活动)
    enum Activities {
        static let list = "/api/activities"
        static func detail(_ id: Int) -> String {
            "/api/activities/\(id)"
        }
        static func apply(_ id: Int) -> String {
            "/api/activities/\(id)/apply"
        }
        static func favorite(_ id: Int) -> String {
            "/api/activities/\(id)/favorite"
        }
        static func favoriteStatus(_ id: Int) -> String {
            "/api/activities/\(id)/favorite/status"
        }
    }
    
    // MARK: - Leaderboard (排行榜)
    enum Leaderboard {
        static let list = "/api/custom-leaderboards"
        static func items(_ leaderboardId: Int) -> String {
            "/api/custom-leaderboards/\(leaderboardId)/items"
        }
        static let vote = "/api/custom-leaderboards/vote"
        static func report(_ leaderboardId: Int) -> String {
            "/api/custom-leaderboards/\(leaderboardId)/report"
        }
        static func reportItem(_ itemId: Int) -> String {
            "/api/custom-leaderboards/items/\(itemId)/report"
        }
    }
    
    // MARK: - Common (通用)
    enum Common {
        static let uploadImage = "/api/upload/image"
        static let banners = "/api/banners"
    }
    
    // MARK: - Reports (举报)
    enum Reports {
        static let forumPost = "/api/posts/reports"
    }
    
    // MARK: - User Preferences (用户偏好)
    enum UserPreferences {
        static let get = "/api/user-preferences"
        static let update = "/api/user-preferences"
    }
    
    // MARK: - Public Endpoints (不需要认证的端点)
    static let publicEndpoints: Set<String> = [
        Auth.login,
        Auth.loginWithCode,
        Auth.loginWithPhoneCode,
        Auth.sendVerificationCode,
        Auth.sendPhoneVerificationCode,
        Users.register,
        Forum.posts,
        Forum.categories,
        Activities.list,
        Common.banners
    ]
}

