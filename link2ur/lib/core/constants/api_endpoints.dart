/// API端点常量
/// 与iOS项目 APIEndpoints.swift 和后端路由完全对齐
/// 标记 [RESERVED] 的端点已在后端定义但Flutter客户端尚未使用
class ApiEndpoints {
  ApiEndpoints._();

  // ==================== 认证相关 ====================
  // 后端: secure_auth_routes.py (prefix: /api/secure-auth)
  static const String login = '/api/secure-auth/login';
  static const String loginWithCode = '/api/secure-auth/login-with-code';
  static const String loginWithPhoneCode =
      '/api/secure-auth/login-with-phone-code';
  static const String register = '/api/users/register';
  static const String logout = '/api/secure-auth/logout';
  static const String refreshToken = '/api/secure-auth/refresh';
  static const String sendVerificationCode =
      '/api/secure-auth/send-verification-code';
  static const String sendPhoneCode =
      '/api/secure-auth/send-phone-verification-code';
  static const String captchaSiteKey = '/api/secure-auth/captcha-site-key';

  // 后端: routers.py (prefix: /api)
  static const String forgotPassword = '/api/forgot_password';
  static String resetPassword(String token) => '/api/reset_password/$token';

  // ==================== 用户相关 ====================
  // 后端: routers.py → GET /profile/me, PATCH /profile, PATCH /profile/avatar 等
  static const String userProfile = '/api/users/profile/me';
  static const String updateProfile = '/api/users/profile'; // PATCH，无 /me
  static const String uploadAvatar = '/api/users/profile/avatar';
  static String userById(String id) => '/api/users/profile/$id';
  static const String sendEmailUpdateCode =
      '/api/users/profile/send-email-update-code';
  static const String sendPhoneUpdateCode =
      '/api/users/profile/send-phone-update-code';
  static const String deleteAccount = '/api/users/account';
  static const String deviceToken = '/api/users/device-token';
  static const String userPreferences = '/api/user-preferences';
  static String userTaskStatistics(String userId) =>
      '/api/users/$userId/task-statistics';
  static String sharedTasks(String userId) =>
      '/api/users/shared-tasks/$userId';
  static String userReceivedReviews(String userId) =>
      '/api/users/$userId/received-reviews';

  // ==================== 任务相关 ====================
  // 后端: routers.py (prefix: /api) + multi_participant_routes.py (prefix: /api)
  static const String tasks = '/api/tasks';
  static String taskById(int id) => '/api/tasks/$id';
  static String applyTask(int id) => '/api/tasks/$id/apply';
  static String acceptTask(int id) => '/api/tasks/$id/accept';
  static String approveTask(int id) => '/api/tasks/$id/approve';
  static String taskInteraction(int id) => '/api/tasks/$id/interaction';
  static String taskMatchScore(int id) => '/api/tasks/$id/match-score';
  static String completeTask(int id) => '/api/tasks/$id/complete';
  static String confirmCompletion(int id) => '/api/tasks/$id/confirm_completion';
  static String cancelTask(int id) => '/api/tasks/$id/cancel';
  static String deleteTask(int id) => '/api/tasks/$id/delete';
  static String rejectTask(int id) => '/api/tasks/$id/reject';
  static String reviewTask(int id) => '/api/tasks/$id/review';
  static String taskReviews(int id) => '/api/tasks/$id/reviews';
  static String taskHistory(int id) => '/api/tasks/$id/history';
  static String disputeTask(int id) => '/api/tasks/$id/dispute';
  static const String myTasks = '/api/users/my-tasks';

  // --- 退款/争议 ---
  static String refundRequest(int taskId) =>
      '/api/tasks/$taskId/refund-request';
  static String refundStatus(int taskId) =>
      '/api/tasks/$taskId/refund-status';
  static String refundHistory(int taskId) =>
      '/api/tasks/$taskId/refund-history';
  static String cancelRefundRequest(int taskId, int refundId) =>
      '/api/tasks/$taskId/refund-request/$refundId/cancel';
  static String submitRefundRebuttal(int taskId, int refundId) =>
      '/api/tasks/$taskId/refund-request/$refundId/rebuttal';
  static String disputeTimeline(int taskId) =>
      '/api/tasks/$taskId/dispute-timeline';

  // --- 多参与者 ---
  static String taskParticipants(String taskId) =>
      '/api/tasks/$taskId/participants';
  static String participantComplete(String taskId) =>
      '/api/tasks/$taskId/participants/me/complete';
  static String participantExitRequest(String taskId) =>
      '/api/tasks/$taskId/participants/me/exit-request';

  // --- 申请管理 ---
  // 后端: task_chat_routes.py (prefix: /api)
  static const String myApplications = '/api/my-applications';
  static String taskApplications(int taskId) =>
      '/api/tasks/$taskId/applications';
  static String acceptApplication(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/accept';
  static String rejectApplication(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/reject';
  static String withdrawApplication(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/withdraw';
  static String negotiateApplication(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/negotiate';
  static String respondNegotiation(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/respond-negotiation';
  static String sendApplicationMessage(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/send-message';
  static String replyApplicationMessage(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/reply-message';

  // ==================== 跳蚤市场 ====================
  // 后端: flea_market_routes.py (prefix: /api/flea-market)
  static const String fleaMarketItems = '/api/flea-market/items';
  static const String fleaMarketCategories = '/api/flea-market/categories';
  static String fleaMarketItemById(String id) => '/api/flea-market/items/$id';
  static String fleaMarketDirectPurchase(String id) =>
      '/api/flea-market/items/$id/direct-purchase';
  static String fleaMarketPurchaseRequest(String id) =>
      '/api/flea-market/items/$id/purchase-request';
  static String fleaMarketItemRefresh(String id) =>
      '/api/flea-market/items/$id/refresh';
  static String fleaMarketItemFavorite(String id) =>
      '/api/flea-market/items/$id/favorite';
  static String fleaMarketItemReport(String id) =>
      '/api/flea-market/items/$id/report';
  static const String fleaMarketMyPurchases = '/api/flea-market/my-purchases';
  static const String fleaMarketMyRelatedItems = '/api/flea-market/my-related-items';
  static const String fleaMarketFavorites = '/api/flea-market/favorites/items';
  static const String fleaMarketUploadImage = '/api/flea-market/upload-image';
  static String fleaMarketItemPurchaseRequests(String id) =>
      '/api/flea-market/items/$id/purchase-requests';
  static String fleaMarketAcceptPurchase(String id) =>
      '/api/flea-market/items/$id/accept-purchase';
  static String fleaMarketRejectPurchase(String id) =>
      '/api/flea-market/items/$id/reject-purchase';
  static String fleaMarketCounterOffer(String id) =>
      '/api/flea-market/items/$id/counter-offer';
  static String fleaMarketRespondCounterOffer(String id) =>
      '/api/flea-market/items/$id/respond-counter-offer';
  static const String fleaMarketAgreeNotice = '/api/flea-market/agree-notice';
  // --- 我的商品/购买/销售 ---
  // 我的在售商品 & 已售商品: 复用 fleaMarketItems + seller_id + status 参数（对齐iOS）
  static const String fleaMarketMyPurchaseRequests =
      '/api/flea-market/my/purchase-requests';
  static String fleaMarketApprovePurchaseRequest(String requestId) =>
      '/api/flea-market/purchase-requests/$requestId/approve';

  // ==================== 任务达人 ====================
  // 后端: task_expert_routes.py (prefix: /api/task-experts)
  static const String taskExperts = '/api/task-experts';
  static String taskExpertById(String id) => '/api/task-experts/$id';
  static String taskExpertServices(String expertId) =>
      '/api/task-experts/$expertId/services';
  static String applyForService(int serviceId) =>
      '/api/task-experts/services/$serviceId/apply';
  static String taskExpertServiceDetail(int serviceId) =>
      '/api/task-experts/services/$serviceId';
  static String taskExpertServiceReviews(int serviceId) =>
      '/api/task-experts/services/$serviceId/reviews';
  static String taskExpertReviews(String expertId) => // [RESERVED]
      '/api/task-experts/$expertId/reviews';
  static const String applyToBeExpert = '/api/task-experts/apply';
  static const String myExpertApplication = '/api/task-experts/my-application';
  static const String myExpertProfile = '/api/task-experts/me';
  static const String myExpertServices = '/api/task-experts/me/services';
  static const String myExpertApplications = '/api/task-experts/me/applications';
  static const String myExpertDashboardStats =
      '/api/task-experts/me/dashboard/stats';
  static const String myExpertSchedule = '/api/task-experts/me/schedule';
  static const String myExpertClosedDates = '/api/task-experts/me/closed-dates';
  static const String myServiceApplications =
      '/api/users/me/service-applications';
  // --- 达人服务时间段 [RESERVED] ---
  static String serviceTimeSlots(int serviceId) =>
      '/api/task-experts/services/$serviceId/time-slots';
  static String myServiceTimeSlots(int serviceId) =>
      '/api/task-experts/me/services/$serviceId/time-slots';
  // --- 达人资料更新请求 [RESERVED] ---
  static const String myExpertProfileUpdateRequest =
      '/api/task-experts/me/profile-update-request';
  // --- 达人审核申请操作 ---
  static String approveServiceApplication(int applicationId) =>
      '/api/task-experts/applications/$applicationId/approve';
  static String rejectServiceApplication(int applicationId) =>
      '/api/task-experts/applications/$applicationId/reject';
  static String counterOfferServiceApplication(int applicationId) =>
      '/api/task-experts/applications/$applicationId/counter-offer';
  // --- 用户服务申请操作 ---
  static String respondServiceCounterOffer(int applicationId) =>
      '/api/users/me/service-applications/$applicationId/respond-counter-offer';
  static String cancelServiceApplication(int applicationId) =>
      '/api/users/me/service-applications/$applicationId/cancel';

  // ==================== 论坛相关 ====================
  // 后端: forum_routes.py (prefix: /api/forum)
  static const String forumVisibleCategories = '/api/forum/forums/visible';
  static const String forumCategories = '/api/forum/categories';
  static String forumCategoryById(int id) => '/api/forum/categories/$id';
  static const String forumCategoryRequest = '/api/forum/categories/request';
  static const String forumPosts = '/api/forum/posts';
  static String forumPostById(int id) => '/api/forum/posts/$id';
  static String forumPostReplies(int id) => '/api/forum/posts/$id/replies';
  static String forumReplyById(int replyId) => '/api/forum/replies/$replyId';
  static const String forumLikes = '/api/forum/likes';
  static const String forumFavorites = '/api/forum/favorites';
  static String forumPostLikes(int postId) =>
      '/api/forum/posts/$postId/likes';
  static String forumReplyLikes(int replyId) =>
      '/api/forum/replies/$replyId/likes';
  static const String myForumPosts = '/api/forum/my/posts';
  static const String myForumReplies = '/api/forum/my/replies';
  static const String myForumFavorites = '/api/forum/my/favorites';
  static const String myForumLikes = '/api/forum/my/likes';
  static const String forumNotifications = '/api/forum/notifications';
  static String forumNotificationRead(int id) =>
      '/api/forum/notifications/$id/read';
  static const String forumNotificationsReadAll =
      '/api/forum/notifications/read-all';
  static const String forumNotificationsUnreadCount =
      '/api/forum/notifications/unread-count';
  static const String forumSearch = '/api/forum/search';
  static const String forumReports = '/api/forum/reports';
  static const String forumHotPosts = '/api/forum/hot-posts';

  // --- 论坛分类收藏 ---
  static String forumCategoryFavorite(int categoryId) =>
      '/api/forum/categories/$categoryId/favorite';
  static String forumCategoryFavoriteStatus(int categoryId) =>
      '/api/forum/categories/$categoryId/favorite/status';
  static const String forumCategoryFavoritesBatch =
      '/api/forum/categories/favorites/batch';
  static const String myForumCategoryFavorites =
      '/api/forum/my/category-favorites';
  static const String myForumCategoryRequests =
      '/api/forum/categories/requests/my';

  // --- 论坛用户统计/排行 [RESERVED] ---
  static String forumUserStats(String userId) =>
      '/api/forum/users/$userId/stats';
  static String forumUserHotPosts(String userId) =>
      '/api/forum/users/$userId/hot-posts';
  static const String forumLeaderboardPosts = '/api/forum/leaderboard/posts';
  static const String forumLeaderboardFavorites =
      '/api/forum/leaderboard/favorites';
  static const String forumLeaderboardLikes = '/api/forum/leaderboard/likes';
  static String forumCategoryStats(int categoryId) =>
      '/api/forum/categories/$categoryId/stats';

  // ==================== 排行榜 ====================
  // 后端: custom_leaderboard_routes.py (prefix: /api/custom-leaderboards)
  static const String leaderboards = '/api/custom-leaderboards';
  static String leaderboardById(int id) => '/api/custom-leaderboards/$id';
  static String leaderboardItems(int id) =>
      '/api/custom-leaderboards/$id/items';
  static String leaderboardItemVote(int itemId) =>
      '/api/custom-leaderboards/items/$itemId/vote';
  static const String leaderboardCreateItem =
      '/api/custom-leaderboards/items';
  static const String leaderboardApply = '/api/custom-leaderboards/apply';
  static String leaderboardReview(int id) =>
      '/api/custom-leaderboards/$id/review';
  static String leaderboardReport(int id) =>
      '/api/custom-leaderboards/$id/report';
  static String leaderboardItemReport(int itemId) =>
      '/api/custom-leaderboards/items/$itemId/report';
  static String leaderboardFavorite(int id) =>
      '/api/custom-leaderboards/$id/favorite';
  static String leaderboardFavoriteStatus(int id) =>
      '/api/custom-leaderboards/$id/favorite/status';
  static const String leaderboardFavoritesBatch =
      '/api/custom-leaderboards/favorites/batch';
  static const String myLeaderboardFavorites =
      '/api/custom-leaderboards/my/favorites';
  static String leaderboardItemDetail(int itemId) =>
      '/api/custom-leaderboards/items/$itemId';
  static String leaderboardItemVotes(int itemId) =>
      '/api/custom-leaderboards/items/$itemId/votes';
  static String leaderboardVoteLike(int voteId) =>
      '/api/custom-leaderboards/votes/$voteId/like';

  // ==================== 消息相关（私信）====================
  // 后端: routers.py (prefix: /api/users)
  static const String sendMessage = '/api/users/messages/send';
  static const String messageContacts = '/api/users/contacts';
  static String messageHistory(String userId) =>
      '/api/users/messages/history/$userId';
  static String markChatRead(String contactId) =>
      '/api/users/messages/mark-chat-read/$contactId';
  static const String unreadMessages = '/api/users/messages/unread';
  static const String unreadMessagesCount = '/api/users/messages/unread/count';
  static const String messageGenerateImageUrl = // [RESERVED]
      '/api/messages/generate-image-url';

  // ==================== 任务聊天 ====================
  // 后端: task_chat_routes.py (prefix: /api)
  static const String taskChatList = '/api/messages/tasks';
  static const String taskChatUnreadCount = '/api/messages/tasks/unread/count';
  static String taskChatMessages(int taskId) =>
      '/api/messages/task/$taskId';
  static String taskChatSend(int taskId) =>
      '/api/messages/task/$taskId/send';
  static String taskChatRead(int taskId) =>
      '/api/messages/task/$taskId/read';

  // ==================== 通知相关 ====================
  // 后端: routers.py (prefix: /api/users)
  static const String notifications = '/api/users/notifications';
  static const String unreadNotifications = '/api/users/notifications/unread';
  static const String unreadNotificationCount =
      '/api/users/notifications/unread/count';
  static String notificationsWithRecentRead({int limit = 10}) =>
      '/api/users/notifications/with-recent-read?recent_read_limit=$limit';
  static String markNotificationRead(int id) =>
      '/api/users/notifications/$id/read';
  static const String markAllNotificationsRead =
      '/api/users/notifications/read-all';
  static String negotiationTokens(int notificationId) => // [RESERVED]
      '/api/notifications/$notificationId/negotiation-tokens';

  // ==================== 活动相关 ====================
  // 后端: multi_participant_routes.py (prefix: /api)
  static const String activities = '/api/activities';
  static String activityById(int id) => '/api/activities/$id';
  static String applyActivity(int id) => '/api/activities/$id/apply';
  static String activityFavorite(int id) => '/api/activities/$id/favorite';
  static String activityFavoriteStatus(int id) =>
      '/api/activities/$id/favorite/status';
  static const String myActivities = '/api/my/activities';
  static String officialActivityApply(int id) => '/api/official-activities/$id/apply';
  static String officialActivityResult(int id) => '/api/official-activities/$id/result';

  // ==================== 积分/优惠券 ====================
  // 后端: coupon_points_routes.py (prefix: /api/coupon-points)
  static const String pointsAccount = '/api/coupon-points/points/account';
  static const String pointsTransactions =
      '/api/coupon-points/points/transactions';
  static const String redeemCoupon = '/api/coupon-points/points/redeem/coupon';
  static const String availableCoupons = '/api/coupon-points/coupons/available';
  static const String myCoupons = '/api/coupon-points/coupons/my';
  static const String claimCoupon = '/api/coupon-points/coupons/claim';
  static const String validateCoupon = '/api/coupon-points/coupons/validate';
  static const String useCoupon = '/api/coupon-points/coupons/use';
  static const String validateInvitationCode =
      '/api/coupon-points/invitation-codes/validate';
  // NOTE: 后端没有独立的"使用邀请码"接口——邀请码在注册时自动使用。
  // 以下两个端点保留但实际不可用，调用方应使用 validateInvitationCode 验证后在注册时传入。
  static const String useInvitationCode = '/api/coupon-points/invitation-codes/validate';
  static const String invitationStatus =
      '/api/coupon-points/invitation-codes/validate';

  // --- 签到 ---
  static const String checkIn = '/api/coupon-points/checkin';
  static const String checkInStatus = '/api/coupon-points/checkin/status';
  static const String checkInRewards = '/api/coupon-points/checkin/rewards';

  // ==================== 支付相关 ====================
  // 后端: coupon_points_routes.py (prefix: /api/coupon-points)
  static String createTaskPayment(int taskId) =>
      '/api/coupon-points/tasks/$taskId/payment';
  static String taskPaymentStatus(int taskId) =>
      '/api/coupon-points/tasks/$taskId/payment-status';
  static const String paymentHistory = '/api/coupon-points/payment-history';
  static String createWeChatCheckout(int taskId) =>
      '/api/coupon-points/tasks/$taskId/wechat-checkout';

  // ==================== Stripe Connect ====================
  // 后端: stripe_connect_routes.py (prefix: /api/stripe/connect)
  static const String stripeConnectAccountCreate =
      '/api/stripe/connect/account/create';
  static const String stripeConnectAccountCreateEmbedded =
      '/api/stripe/connect/account/create-embedded';
  static const String stripeConnectAccountStatus =
      '/api/stripe/connect/account/status';
  static const String stripeConnectAccountDetails =
      '/api/stripe/connect/account/details';
  static const String stripeConnectAccountBalance =
      '/api/stripe/connect/account/balance';
  static const String stripeConnectExternalAccounts =
      '/api/stripe/connect/account/external-accounts';
  static const String stripeConnectPayout =
      '/api/stripe/connect/account/payout';
  static const String stripeConnectTransactions =
      '/api/stripe/connect/account/transactions';
  static const String stripeConnectOnboardingSession =
      '/api/stripe/connect/account/onboarding-session';
  static const String stripeConnectAccountSession =
      '/api/stripe/connect/account_session';

  // ==================== 学生认证 ====================
  // 后端: student_verification_routes.py (prefix: /api/student-verification)
  static const String studentVerificationStatus =
      '/api/student-verification/status';
  static const String submitStudentVerification =
      '/api/student-verification/submit';
  static String verifyStudentEmail(String token) =>
      '/api/student-verification/verify/$token';
  static const String renewStudentVerification =
      '/api/student-verification/renew';

  // ==================== 客服相关 ====================
  // 后端: routers.py → /user/customer-service/* (prefix: /api/users)
  static const String customerServiceAssign =
      '/api/users/user/customer-service/assign';
  static const String customerServiceChats =
      '/api/users/user/customer-service/chats';
  static String customerServiceMessages(String chatId) =>
      '/api/users/user/customer-service/chats/$chatId/messages';
  static String customerServiceEndChat(String chatId) =>
      '/api/users/user/customer-service/chats/$chatId/end';
  static String customerServiceRate(String chatId) =>
      '/api/users/user/customer-service/chats/$chatId/rate';
  static const String customerServiceQueueStatus =
      '/api/users/user/customer-service/queue-status';
  static const String customerServiceAvailability =
      '/api/users/user/customer-service/availability';

  // ==================== VIP ====================
  // 后端: routers.py → /users/vip/*
  static const String activateVIP = '/api/users/vip/activate';
  static const String vipStatus = '/api/users/vip/status'; // [RESERVED]
  static const String vipHistory = '/api/users/vip/history';
  static const String iapProducts = '/api/iap/products'; // [RESERVED]

  // ==================== 推荐 ====================
  static const String recommendations = '/api/recommendations';
  static String recommendationFeedback(int taskId) =>
      '/api/recommendations/$taskId/feedback';

  // ==================== 翻译 ====================
  // 后端: routers.py → /translate/*
  static const String translate = '/api/translate';
  static const String translateBatch = '/api/translate/batch';
  static String translateTask(int taskId) => '/api/translate/task/$taskId';
  static const String translateTasksBatch = '/api/translate/tasks/batch';

  // ==================== Discovery Feed ====================
  // 后端: discovery_routes.py (prefix: /api/discovery)
  static const String discoveryFeed = '/api/discovery/feed';

  // ==================== 论坛关联搜索 ====================
  static const String forumSearchLinkable = '/api/forum/search-linkable';
  static const String forumLinkableForUser = '/api/forum/linkable-for-user';

  // ==================== 通用/其他 ====================
  static const String uploadImage = '/api/upload/image';
  /// 优化版公开图片上传（任务/论坛/跳蚤等），返回公开 URL，支持临时目录迁移
  static const String uploadImageV2 = '/api/v2/upload/image';
  static const String uploadPublicImage = '/api/v2/upload/image'; // 公开图片统一使用V2
  static const String uploadFile = '/api/upload/file';
  static const String refreshImageUrl = '/api/refresh-image-url';
  static String privateImage(String imageId) => // [RESERVED]
      '/api/private-image/$imageId';
  static const String privateFile = '/api/private-file'; // [RESERVED]
  static const String banners = '/api/banners';
  static const String healthCheck = '/api/health';
  static const String systemSettingsPublic = '/api/system-settings/public';
  static const String jobPositions = '/api/job-positions';
  static String faq({String lang = 'zh'}) => '/api/faq?lang=$lang';
  static String legalDocument({required String type, String lang = 'zh'}) =>
      '/api/legal/$type?lang=$lang';

  // ==================== AI Agent ====================
  // 后端: ai_agent_routes.py (prefix: /api/ai)
  static const String aiConversations = '/api/ai/conversations';
  static String aiConversationDetail(String id) =>
      '/api/ai/conversations/$id';
  static String aiSendMessage(String conversationId) =>
      '/api/ai/conversations/$conversationId/messages';
}
