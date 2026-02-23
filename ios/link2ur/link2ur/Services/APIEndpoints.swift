import Foundation

/// API 端点统一管理
/// 所有 API 端点路径都在这里定义，便于维护和修改
enum APIEndpoints {
    // MARK: - Authentication (认证)
    // 后端: secure_auth_routes.py (prefix: /api/secure-auth)
    enum Auth {
        static let login = "/api/secure-auth/login"
        static let loginWithCode = "/api/secure-auth/login-with-code"
        static let loginWithPhoneCode = "/api/secure-auth/login-with-phone-code"
        static let sendVerificationCode = "/api/secure-auth/send-verification-code"
        static let sendPhoneVerificationCode = "/api/secure-auth/send-phone-verification-code"
        static let refresh = "/api/secure-auth/refresh"
        static let logout = "/api/secure-auth/logout"
        static let captchaSiteKey = "/api/secure-auth/captcha-site-key"
        static let logoutAll = "/api/secure-auth/logout-all"
        static let logoutOthers = "/api/secure-auth/logout-others"
        static let sessions = "/api/secure-auth/sessions"
        static func revokeSession(_ sessionId: String) -> String {
            "/api/secure-auth/sessions/\(sessionId)"
        }
    }
    
    // MARK: - Users (用户)
    // 后端: routers.py (prefix: /api/users)
    enum Users {
        static let register = "/api/users/register"
        static let profileMe = "/api/users/profile/me"
        static let updateProfile = "/api/users/profile"
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
        static func notificationsWithRecentRead(limit: Int = 10) -> String {
            "/api/users/notifications/with-recent-read?recent_read_limit=\(limit)"
        }
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
        static let customerServiceAvailability = "/api/users/user/customer-service/availability"
        static func taskComplete(_ taskId: Int) -> String {
            "/api/tasks/\(taskId)/complete"
        }
        static let myServiceApplications = "/api/users/me/service-applications"
        static let deleteAccount = "/api/users/account"
        static let activateVIP = "/api/users/vip/activate"
        static let vipStatus = "/api/users/vip/status"
        static let vipHistory = "/api/users/vip/history"
        static func taskStatistics(_ userId: String) -> String {
            "/api/users/\(userId)/task-statistics"
        }
        static func sharedTasks(_ userId: String) -> String {
            "/api/users/shared-tasks/\(userId)"
        }
        static func receivedReviews(_ userId: String) -> String {
            "/api/users/\(userId)/received-reviews"
        }
    }
    
    // MARK: - Tasks (任务)
    // 后端: routers.py + async_routers.py + multi_participant_routes.py (prefix: /api)
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
        static func accept(_ id: Int) -> String {
            "/api/tasks/\(id)/accept"
        }
        static func approve(_ id: Int) -> String {
            "/api/tasks/\(id)/approve"
        }
        static func interaction(_ id: Int) -> String {
            "/api/tasks/\(id)/interaction"
        }
        static func matchScore(_ id: Int) -> String {
            "/api/tasks/\(id)/match-score"
        }
        static func confirmCompletion(_ id: Int) -> String {
            "/api/tasks/\(id)/confirm_completion"
        }
        static func cancel(_ id: Int) -> String {
            "/api/tasks/\(id)/cancel"
        }
        static func taskComplete(_ id: Int) -> String {
            "/api/tasks/\(id)/complete"
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
        static func history(_ id: Int) -> String {
            "/api/tasks/\(id)/history"
        }
        static func dispute(_ id: Int) -> String {
            "/api/tasks/\(id)/dispute"
        }
        static func updateReward(_ taskId: Int) -> String {
            "/api/tasks/\(taskId)/reward"
        }
        static func updateVisibility(_ taskId: Int) -> String {
            "/api/tasks/\(taskId)/visibility"
        }
        // --- 退款/争议 ---
        static func refundRequest(_ id: Int) -> String {
            "/api/tasks/\(id)/refund-request"
        }
        static func refundStatus(_ id: Int) -> String {
            "/api/tasks/\(id)/refund-status"
        }
        static func refundHistory(_ id: Int) -> String {
            "/api/tasks/\(id)/refund-history"
        }
        static func cancelRefundRequest(_ taskId: Int, _ refundId: Int) -> String {
            "/api/tasks/\(taskId)/refund-request/\(refundId)/cancel"
        }
        static func submitRefundRebuttal(_ taskId: Int, _ refundId: Int) -> String {
            "/api/tasks/\(taskId)/refund-request/\(refundId)/rebuttal"
        }
        static func disputeTimeline(_ taskId: Int) -> String {
            "/api/tasks/\(taskId)/dispute-timeline"
        }
        // --- 多参与者 ---
        static func participants(_ id: String) -> String {
            "/api/tasks/\(id)/participants"
        }
        static func participantComplete(_ id: String) -> String {
            "/api/tasks/\(id)/participants/me/complete"
        }
        static func participantExitRequest(_ id: String) -> String {
            "/api/tasks/\(id)/participants/me/exit-request"
        }
        // --- 申请管理 ---
        static let myApplications = "/api/my-applications"
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
        static let unreadCount = "/api/messages/tasks/unread/count"
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
        static let redeemCoupon = "/api/coupon-points/points/redeem/coupon"
    }
    
    enum Coupons {
        static let available = "/api/coupon-points/coupons/available"
        static let my = "/api/coupon-points/coupons/my"
        static let claim = "/api/coupon-points/coupons/claim"
    }
    
    // MARK: - Payment (支付)
    enum Payment {
        static func createTaskPayment(_ taskId: Int) -> String {
            "/api/coupon-points/tasks/\(taskId)/payment"
        }
        /// 查询任务支付状态（只读，用于检查支付是否已完成）
        static func getTaskPaymentStatus(_ taskId: Int) -> String {
            "/api/coupon-points/tasks/\(taskId)/payment-status"
        }
        static let paymentHistory = "/api/coupon-points/payment-history"
        
        /// 创建微信支付 Checkout Session（iOS 专用，因为 PaymentSheet 不支持微信支付）
        static func createWeChatCheckout(_ taskId: Int) -> String {
            "/api/coupon-points/tasks/\(taskId)/wechat-checkout"
        }
    }
    
    // MARK: - Check-in (签到)
    enum CheckIn {
        static let checkIn = "/api/coupon-points/checkin"
        static let status = "/api/coupon-points/checkin/status"
        static let rewards = "/api/coupon-points/checkin/rewards"
    }
    
    // MARK: - Invitation Codes (邀请码)
    enum InvitationCodes {
        static let validate = "/api/coupon-points/invitation-codes/validate"
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
    // 后端: forum_routes.py (prefix: /api/forum)
    enum Forum {
        static let visibleForums = "/api/forum/forums/visible"
        static let categories = "/api/forum/forums/visible" // 别名，保持向后兼容
        static let allCategories = "/api/forum/categories"
        static func categoryById(_ id: Int) -> String {
            "/api/forum/categories/\(id)"
        }
        static let categoryRequest = "/api/forum/categories/request"
        static let posts = "/api/forum/posts"
        static func postDetail(_ id: Int) -> String {
            "/api/forum/posts/\(id)"
        }
        static func replies(_ postId: Int) -> String {
            "/api/forum/posts/\(postId)/replies"
        }
        static func replyById(_ replyId: Int) -> String {
            "/api/forum/replies/\(replyId)"
        }
        static let likes = "/api/forum/likes"
        static let favorites = "/api/forum/favorites"
        static func postLikes(_ postId: Int) -> String {
            "/api/forum/posts/\(postId)/likes"
        }
        static func replyLikes(_ replyId: Int) -> String {
            "/api/forum/replies/\(replyId)/likes"
        }
        static let myPosts = "/api/forum/my/posts"
        static let myReplies = "/api/forum/my/replies"
        static let myFavorites = "/api/forum/my/favorites"
        static let myLikes = "/api/forum/my/likes"
        static let notifications = "/api/forum/notifications"
        static func markNotificationRead(_ id: Int) -> String {
            "/api/forum/notifications/\(id)/read"
        }
        static let markAllNotificationsRead = "/api/forum/notifications/read-all"
        static let notificationsUnreadCount = "/api/forum/notifications/unread-count"
        static let search = "/api/forum/search"
        static let hotPosts = "/api/forum/hot-posts"
        static let myCategoryRequests = "/api/forum/categories/requests/my"
        static func categoryFavorite(_ categoryId: Int) -> String {
            "/api/forum/categories/\(categoryId)/favorite"
        }
        static func categoryFavoriteStatus(_ categoryId: Int) -> String {
            "/api/forum/categories/\(categoryId)/favorite/status"
        }
        static let categoryFavoritesBatch = "/api/forum/categories/favorites/batch"
        static let myCategoryFavorites = "/api/forum/my/category-favorites"
    }
    
    // MARK: - Flea Market (跳蚤市场)
    // 后端: flea_market_routes.py (prefix: /api/flea-market)
    enum FleaMarket {
        static let items = "/api/flea-market/items"
        static let categories = "/api/flea-market/categories"
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
        static func purchaseRequests(_ id: String) -> String {
            "/api/flea-market/items/\(id)/purchase-requests"
        }
        static func acceptPurchase(_ id: String) -> String {
            "/api/flea-market/items/\(id)/accept-purchase"
        }
        static func rejectPurchase(_ id: String) -> String {
            "/api/flea-market/items/\(id)/reject-purchase"
        }
        static func counterOffer(_ id: String) -> String {
            "/api/flea-market/items/\(id)/counter-offer"
        }
        static func respondCounterOffer(_ id: String) -> String {
            "/api/flea-market/items/\(id)/respond-counter-offer"
        }
        static let myPurchases = "/api/flea-market/my-purchases"
        static let myRelatedItems = "/api/flea-market/my-related-items"
        static let myPurchaseRequests = "/api/flea-market/my/purchase-requests"
        static let favorites = "/api/flea-market/favorites/items"
        static let uploadImage = "/api/flea-market/upload-image"
        static let agreeNotice = "/api/flea-market/agree-notice"
        static func approvePurchaseRequest(_ requestId: String) -> String {
            "/api/flea-market/purchase-requests/\(requestId)/approve"
        }
    }
    
    // MARK: - Task Experts (任务达人)
    // 后端: task_expert_routes.py (prefix: /api/task-experts)
    enum TaskExperts {
        static let list = "/api/task-experts"
        static func detail(_ id: String) -> String {
            "/api/task-experts/\(id)"
        }
        static func services(_ expertId: String) -> String {
            "/api/task-experts/\(expertId)/services"
        }
        static func reviews(_ expertId: String) -> String {
            "/api/task-experts/\(expertId)/reviews"
        }
        static func serviceDetail(_ serviceId: Int) -> String {
            "/api/task-experts/services/\(serviceId)"
        }
        static func applyForService(_ serviceId: Int) -> String {
            "/api/task-experts/services/\(serviceId)/apply"
        }
        static func serviceReviews(_ serviceId: Int) -> String {
            "/api/task-experts/services/\(serviceId)/reviews"
        }
        static func serviceTimeSlots(_ serviceId: Int) -> String {
            "/api/task-experts/services/\(serviceId)/time-slots"
        }
        static let apply = "/api/task-experts/apply"
        static let myApplication = "/api/task-experts/my-application"
        static let myProfile = "/api/task-experts/me"
        static let myServices = "/api/task-experts/me/services"
        static let myApplications = "/api/task-experts/me/applications"
        static func myServiceTimeSlots(_ serviceId: Int) -> String {
            "/api/task-experts/me/services/\(serviceId)/time-slots"
        }
        static let profileUpdateRequest = "/api/task-experts/me/profile-update-request"
        // --- 达人审核申请操作 ---
        static func approveApplication(_ applicationId: Int) -> String {
            "/api/task-experts/applications/\(applicationId)/approve"
        }
        static func rejectApplication(_ applicationId: Int) -> String {
            "/api/task-experts/applications/\(applicationId)/reject"
        }
        static func counterOfferApplication(_ applicationId: Int) -> String {
            "/api/task-experts/applications/\(applicationId)/counter-offer"
        }
    }
    
    // MARK: - User Service Applications (用户服务申请)
    enum UserServiceApplications {
        static let list = "/api/users/me/service-applications"
        static func respondCounterOffer(_ applicationId: Int) -> String {
            "/api/users/me/service-applications/\(applicationId)/respond-counter-offer"
        }
        static func cancel(_ applicationId: Int) -> String {
            "/api/users/me/service-applications/\(applicationId)/cancel"
        }
    }
    
    // MARK: - Activities (活动)
    // 后端: multi_participant_routes.py (prefix: /api)
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
        static let myActivities = "/api/my/activities"
        // 官方活动 (official_activity_routes.py, prefix: /api/official-activities)
        static func officialApply(_ id: Int) -> String {
            "/api/official-activities/\(id)/apply"
        }
        static func officialResult(_ id: Int) -> String {
            "/api/official-activities/\(id)/result"
        }
    }
    
    // MARK: - Leaderboard (排行榜)
    // 后端: custom_leaderboard_routes.py (prefix: /api/custom-leaderboards)
    enum Leaderboard {
        static let list = "/api/custom-leaderboards"
        static func detail(_ id: Int) -> String {
            "/api/custom-leaderboards/\(id)"
        }
        static func items(_ leaderboardId: Int) -> String {
            "/api/custom-leaderboards/\(leaderboardId)/items"
        }
        static let createItem = "/api/custom-leaderboards/items"
        static func itemDetail(_ itemId: Int) -> String {
            "/api/custom-leaderboards/items/\(itemId)"
        }
        static func vote(_ itemId: Int) -> String {
            "/api/custom-leaderboards/items/\(itemId)/vote"
        }
        static func itemVotes(_ itemId: Int) -> String {
            "/api/custom-leaderboards/items/\(itemId)/votes"
        }
        static func voteLike(_ voteId: Int) -> String {
            "/api/custom-leaderboards/votes/\(voteId)/like"
        }
        static let apply = "/api/custom-leaderboards/apply"
        static func review(_ id: Int) -> String {
            "/api/custom-leaderboards/\(id)/review"
        }
        static func report(_ leaderboardId: Int) -> String {
            "/api/custom-leaderboards/\(leaderboardId)/report"
        }
        static func reportItem(_ itemId: Int) -> String {
            "/api/custom-leaderboards/items/\(itemId)/report"
        }
        static func favorite(_ leaderboardId: Int) -> String {
            "/api/custom-leaderboards/\(leaderboardId)/favorite"
        }
        static func favoriteStatus(_ leaderboardId: Int) -> String {
            "/api/custom-leaderboards/\(leaderboardId)/favorite/status"
        }
        static let favoritesBatch = "/api/custom-leaderboards/favorites/batch"
        static let myFavorites = "/api/custom-leaderboards/my/favorites"
    }
    
    // MARK: - Discovery (发现 Feed)
    enum Discovery {
        static let feed = "/api/discovery/feed"
    }
    
    // MARK: - Stripe Connect (收款账户)
    // 后端: stripe_connect_routes.py (prefix: /api/stripe/connect)
    enum StripeConnect {
        static let createAccount = "/api/stripe/connect/account/create"
        static let createEmbedded = "/api/stripe/connect/account/create-embedded"
        static let accountStatus = "/api/stripe/connect/account/status"
        static let accountDetails = "/api/stripe/connect/account/details"
        static let accountBalance = "/api/stripe/connect/account/balance"
        static let externalAccounts = "/api/stripe/connect/account/external-accounts"
        static let payout = "/api/stripe/connect/account/payout"
        static let transactions = "/api/stripe/connect/account/transactions"
        static let onboardingSession = "/api/stripe/connect/account/onboarding-session"
        static let accountSession = "/api/stripe/connect/account_session"
    }
    
    // MARK: - Translation (翻译)
    // 后端: routers.py → /translate/*
    enum Translation {
        static let translate = "/api/translate"
        static let batch = "/api/translate/batch"
        static func task(_ taskId: Int) -> String {
            "/api/translate/task/\(taskId)"
        }
        static let tasksBatch = "/api/translate/tasks/batch"
    }
    
    // MARK: - Common (通用)
    enum Common {
        static let uploadImage = "/api/upload/image"
        static let uploadPublicImage = "/api/v2/upload/image"
        static let uploadFile = "/api/upload/file"
        static let refreshImageUrl = "/api/refresh-image-url"
        static func privateImage(_ imageId: String) -> String {
            "/api/private-image/\(imageId)"
        }
        static let privateFile = "/api/private-file"
        static let banners = "/api/banners"
        static let health = "/api/health"
        static let systemSettingsPublic = "/api/system-settings/public"
        static let jobPositions = "/api/job-positions"
        static func faq(lang: String) -> String {
            "/api/faq?lang=\(lang)"
        }
        static func legal(type: String, lang: String) -> String {
            "/api/legal/\(type)?lang=\(lang)"
        }
    }
    
    // MARK: - Reports (举报)
    enum Reports {
        static let forumPost = "/api/forum/reports"
    }
    
    // MARK: - User Preferences (用户偏好)
    enum UserPreferences {
        static let get = "/api/user-preferences"
        static let update = "/api/user-preferences"
    }
    
    // MARK: - Recommendations (推荐)
    enum Recommendations {
        static let list = "/api/recommendations"
        static func feedback(_ taskId: Int) -> String {
            "/api/recommendations/\(taskId)/feedback"
        }
    }
    
    // MARK: - AI Agent
    // 后端: ai_agent_routes.py (prefix: /api/ai)
    enum AI {
        static let conversations = "/api/ai/conversations"
        static func conversationDetail(_ id: String) -> String {
            "/api/ai/conversations/\(id)"
        }
        static func sendMessage(_ conversationId: String) -> String {
            "/api/ai/conversations/\(conversationId)/messages"
        }
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
        Discovery.feed,
        Common.banners,
        Common.health,
        "/api/faq",
        "/api/legal/privacy",
        "/api/legal/terms",
        "/api/legal/cookie"
    ]
}

