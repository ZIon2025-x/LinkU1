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
  static const String logoutAll = '/api/secure-auth/logout-all';
  static const String logoutOthers = '/api/secure-auth/logout-others';
  static const String activeSessions = '/api/secure-auth/sessions';
  static String revokeSession(String sessionId) =>
      '/api/secure-auth/sessions/$sessionId';

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
  static String updateTaskReward(int taskId) => '/api/tasks/$taskId/reward';
  static String updateTaskVisibility(int taskId) =>
      '/api/tasks/$taskId/visibility';
  static String rejectTask(int id) => '/api/tasks/$id/reject';
  static String reviewTask(int id) => '/api/tasks/$id/review';
  static String taskReviews(int id) => '/api/tasks/$id/reviews';
  static String taskHistory(int id) => '/api/tasks/$id/history';
  static String disputeTask(int id) => '/api/tasks/$id/dispute';
  static const String myTasks = '/api/users/my-tasks';
  static const String aiOptimizeTask = '/api/tasks/ai-optimize';

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
  static String taskParticipants(int taskId) =>
      '/api/tasks/$taskId/participants';
  static String participantComplete(int taskId) =>
      '/api/tasks/$taskId/participants/me/complete';
  static String participantExitRequest(int taskId) =>
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
  static String takerCounterOffer(int taskId) =>
      '/api/tasks/$taskId/taker-counter-offer';
  static String respondTakerCounterOffer(int taskId) =>
      '/api/tasks/$taskId/respond-taker-counter-offer';
  static String sendApplicationMessage(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/send-message';
  static String replyApplicationMessage(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/reply-message';
  static String publicReplyApplication(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/public-reply';
  static String startApplicationChat(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/start-chat';
  static String proposePrice(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/propose-price';
  static String confirmAndPay(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/confirm-and-pay';

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
  static String fleaMarketApprovePurchaseRequest(String requestId) =>
      '/api/flea-market/purchase-requests/$requestId/approve';

  // --- 跳蚤市场租赁 ---
  static String fleaMarketRentalRequest(String id) => '/api/flea-market/items/$id/rental-request';
  static String fleaMarketItemRentalRequests(String id) => '/api/flea-market/items/$id/rental-requests';
  static String fleaMarketRentalRequestApprove(String requestId) => '/api/flea-market/rental-requests/$requestId/approve';
  static String fleaMarketRentalRequestReject(String requestId) => '/api/flea-market/rental-requests/$requestId/reject';
  static String fleaMarketRentalRequestCounterOffer(String requestId) => '/api/flea-market/rental-requests/$requestId/counter-offer';
  static String fleaMarketRentalRequestRespondCounterOffer(String requestId) => '/api/flea-market/rental-requests/$requestId/respond-counter-offer';
  static String fleaMarketRentalRenterConfirmReturn(String rentalId) => '/api/flea-market/rentals/$rentalId/renter-confirm-return';
  static String fleaMarketRentalConfirmReturn(String rentalId) => '/api/flea-market/rentals/$rentalId/confirm-return';
  static String fleaMarketRentalDetail(String rentalId) => '/api/flea-market/rentals/$rentalId';
  static const String fleaMarketMyRentals = '/api/flea-market/my-rentals';

  // ==================== 任务达人 ====================
  // 后端: 新达人路由 (已迁移到 /api/experts/*)
  // 公开查询
  static const String taskExperts = '/api/experts';
  static String taskExpertById(String id) => '/api/experts/$id';
  static String taskExpertServices(String expertId) =>
      '/api/experts/$expertId/services';
  static String taskExpertReviews(String expertId) =>
      '/api/experts/$expertId/reviews';

  // 达人申请（旧流程保留兼容）
  static const String applyToBeExpert = '/api/experts/apply';
  static const String myExpertApplication = '/api/experts/my-applications';

  // 达人面板（需要 expertId）
  static String expertDashboardStats(String expertId) =>
      '/api/experts/$expertId/dashboard/stats';
  static String expertClosedDates(String expertId) =>
      '/api/experts/$expertId/closed-dates';
  static String expertClosedDateById(String expertId, int id) =>
      '/api/experts/$expertId/closed-dates/$id';

  // 服务管理（需要 expertId）
  static String expertServiceById(String expertId, int serviceId) =>
      '/api/experts/$expertId/services/$serviceId';

  // 服务时间段（需要 expertId）
  static String expertServiceTimeSlots(String expertId, int serviceId) =>
      '/api/experts/$expertId/services/$serviceId/time-slots';
  static String expertServiceTimeSlotById(String expertId, int serviceId, int slotId) =>
      '/api/experts/$expertId/services/$serviceId/time-slots/$slotId';

  // 公开服务查询
  static String publicServiceTimeSlots(int serviceId) =>
      '/api/services/$serviceId/time-slots';
  static String publicServiceDetail(int serviceId) =>
      '/api/services/$serviceId'; // Phase B1: service_public_routes

  // 服务申请/咨询（不需要 expertId，用 serviceId/applicationId）
  static String applyForService(int serviceId) =>
      '/api/services/$serviceId/apply';
  static String consultService(int serviceId) =>
      '/api/services/$serviceId/consult';
  static String negotiateConsultation(int applicationId) =>
      '/api/applications/$applicationId/negotiate';
  static String quoteApplication(int applicationId) =>
      '/api/applications/$applicationId/quote';
  static String negotiateResponse(int applicationId) =>
      '/api/applications/$applicationId/negotiate-response';
  static String formalApply(int applicationId) =>
      '/api/applications/$applicationId/formal-apply';
  static String closeConsultation(int applicationId) =>
      '/api/applications/$applicationId/close';
  static String approveServiceApplication(int applicationId) =>
      '/api/applications/$applicationId/approve';
  static String rejectServiceApplication(int applicationId) =>
      '/api/applications/$applicationId/reject';
  static String counterOfferServiceApplication(int applicationId) =>
      '/api/applications/$applicationId/counter-offer';
  static String consultationStatus(int applicationId) =>
      '/api/applications/$applicationId/status';

  // 我的申请
  static const String myServiceApplications = '/api/my/service-applications';
  static String expertApplicationsList(String expertId) =>
      '/api/experts/$expertId/applications';

  // 服务公开申请列表/回复 — Phase B1 收口: 走 service_public_routes,
  // 新 ExpertMember ownership 解析,新团队 owner/admin 都能 reply
  static String serviceApplications(int serviceId) =>
      '/api/services/$serviceId/applications';
  static String replyServiceApplication(int serviceId, int applicationId) =>
      '/api/services/$serviceId/applications/$applicationId/reply';

  // 服务评价
  static String taskExpertServiceReviews(int serviceId) =>
      '/api/services/$serviceId/reviews';

  // 公开服务时间段（已迁移到新公开端点；新端点已包含关门日过滤 / user_has_applied / 多人参与者计数）
  static String serviceTimeSlots(int serviceId) =>
      '/api/services/$serviceId/time-slots';
  // 服务详情 — Phase B1 收口: 切到 service_public_routes 的 /api/services/{id},
  // 新 owner_type/owner_id 解析, 团队/个人服务都正确返回 owner 信息
  static String taskExpertServiceDetail(int serviceId) =>
      '/api/services/$serviceId';
  static String respondServiceCounterOffer(int applicationId) =>
      '/api/users/me/service-applications/$applicationId/respond-counter-offer';
  static String cancelServiceApplication(int applicationId) =>
      '/api/users/me/service-applications/$applicationId/cancel';

  // ==================== A1 套餐购买 + QR 核销 ====================
  static String purchasePackage(int serviceId) =>
      '/api/services/$serviceId/purchase-package';
  static String myPackageDetail(int packageId) =>
      '/api/my/packages/$packageId';
  static String myPackageRedemptionQr(int packageId) =>
      '/api/my/packages/$packageId/redemption-qr';
  static String redeemPackage(String expertId) =>
      '/api/experts/$expertId/packages/redeem';
  static String customerPackages(String expertId) =>
      '/api/experts/$expertId/customer-packages';

  // ==================== Expert Team ====================
  static const String expertTeams = '/api/experts';
  static const String expertTeamApply = '/api/experts/apply';
  static const String expertTeamMyApplications = '/api/experts/my-applications';
  static const String expertTeamMyTeams = '/api/experts/my-teams';
  static const String expertTeamMyInvitations = '/api/experts/my-invitations';
  static String expertTeamById(String id) => '/api/experts/$id';
  static String expertTeamMembers(String id) => '/api/experts/$id/members';
  static String expertTeamFollow(String id) => '/api/experts/$id/follow';
  static String expertTeamInvite(String id) => '/api/experts/$id/invite';
  static String expertTeamJoin(String id) => '/api/experts/$id/join';
  static String expertTeamJoinRequests(String id) => '/api/experts/$id/join-requests';
  static String expertTeamReviewJoinRequest(String expertId, int requestId) =>
      '/api/experts/$expertId/join-requests/$requestId';
  static String expertTeamMemberRole(String expertId, String userId) =>
      '/api/experts/$expertId/members/$userId/role';
  static String expertTeamTransfer(String id) => '/api/experts/$id/transfer';
  static String expertTeamRemoveMember(String expertId, String userId) =>
      '/api/experts/$expertId/members/$userId';
  static String expertTeamLeave(String id) => '/api/experts/$id/leave';
  static String expertTeamProfileUpdateRequest(String id) =>
      '/api/experts/$id/profile-update-request';
  static String expertTeamRespondInvitation(int invitationId) =>
      '/api/experts/invitations/$invitationId/respond';
  // Chat participants
  static String chatInviteToTask(int taskId) => '/api/chat/tasks/$taskId/invite';
  static String chatTaskParticipants(int taskId) => '/api/chat/tasks/$taskId/participants';

  static String expertTeamServices(String expertId) => '/api/experts/$expertId/services';
  static String expertTeamServiceById(String expertId, int serviceId) =>
      '/api/experts/$expertId/services/$serviceId';
  static const String expertTeamFeatured = '/api/experts/featured';
  static const String expertTeamMyFollowing = '/api/experts/my-following';
  static String expertTeamDissolve(String id) => '/api/experts/$id/dissolve';
  static String expertTeamAllowApplications(String id) => '/api/experts/$id/allow-applications';
  static String expertTeamCouponById(String expertId, int couponId) =>
      '/api/experts/$expertId/coupons/$couponId';
  static String groupBuyJoin(int activityId) => '/api/group-buy/activities/$activityId/join';
  static String groupBuyCancel(int activityId) => '/api/group-buy/activities/$activityId/cancel';
  static String groupBuyStatus(int activityId) => '/api/group-buy/activities/$activityId/status';
  static const String myPackages = '/api/my/packages';
  static String expertTeamPackageUse(String expertId, int packageId) =>
      '/api/experts/$expertId/packages/$packageId/use';
  static String expertTeamCoupons(String expertId) => '/api/experts/$expertId/coupons';
  static String expertTeamStripeConnect(String id) => '/api/experts/$id/stripe-connect';
  static String expertTeamStripeStatus(String id) => '/api/experts/$id/stripe-connect/status';
  static String reviewReply(int reviewId) => '/api/reviews/$reviewId/reply';

  // Task consultation endpoints
  static String consultTask(int taskId) => '/api/tasks/$taskId/consult';
  static String taskConsultNegotiate(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/consult-negotiate';
  static String taskConsultQuote(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/consult-quote';
  static String taskConsultRespond(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/consult-respond';
  static String taskConsultFormalApply(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/consult-formal-apply';
  static String taskConsultClose(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/consult-close';
  static String taskConsultStatus(int taskId, int applicationId) =>
      '/api/tasks/$taskId/applications/$applicationId/consult-status';

  // Flea market consultation endpoints
  static String consultFleaMarketItem(String itemId) => '/api/flea-market/items/$itemId/consult';
  static String fleaMarketConsultNegotiate(int requestId) =>
      '/api/flea-market/purchase-requests/$requestId/consult-negotiate';
  static String fleaMarketConsultQuote(int requestId) =>
      '/api/flea-market/purchase-requests/$requestId/consult-quote';
  static String fleaMarketConsultRespond(int requestId) =>
      '/api/flea-market/purchase-requests/$requestId/consult-respond';
  static String fleaMarketConsultFormalBuy(int requestId) =>
      '/api/flea-market/purchase-requests/$requestId/consult-formal-buy';
  static String fleaMarketConsultClose(int requestId) =>
      '/api/flea-market/purchase-requests/$requestId/consult-close';
  static String fleaMarketConsultStatus(int requestId) =>
      '/api/flea-market/purchase-requests/$requestId/consult-status';

  // ==================== 个人服务 ====================
  // Personal Services (non-expert users publishing their own services)
  static const String myPersonalServices = '/api/services/me';
  static String myPersonalServiceById(String id) => '/api/services/me/$id';
  static const String browseServices = '/api/services/browse';
  static String personalServiceToggleStatus(String id) =>
      '/api/services/me/$id/status';
  static String serviceReviews(int serviceId) =>
      '/api/services/$serviceId/reviews';
  static String serviceReviewSummary(int serviceId) =>
      '/api/services/$serviceId/reviews/summary';
  // --- 服务所有者管理收到的申请（个人服务 + 达人服务通用） ---
  static const String myReceivedApplications =
      '/api/users/me/service-applications/received';
  static String ownerApproveApplication(int applicationId) =>
      '/api/users/me/service-applications/$applicationId/owner-approve';
  static String ownerRejectApplication(int applicationId) =>
      '/api/users/me/service-applications/$applicationId/owner-reject';
  static String ownerCounterOffer(int applicationId) =>
      '/api/users/me/service-applications/$applicationId/owner-counter-offer';

  // ==================== 问答相关 ====================
  // 后端: routes/questions.py (prefix: /api/questions)
  static const String questions = '/api/questions';
  static String questionReply(int id) => '/api/questions/$id/reply';
  static String questionDelete(int id) => '/api/questions/$id';

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
  static const String trendingSearches = '/api/trending/searches';
  static const String trendingLogSearch = '/api/trending/log-search';
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
  static String forumSkillFeed(int categoryId) =>
      '/api/forum/categories/$categoryId/feed';

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
  static const String interactionNotifications =
      '/api/users/notifications/interaction';
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
  /// 取消官方活动报名（DELETE 同路径）— 后端 official_activity_routes.py
  static String officialActivityCancel(int id) => '/api/official-activities/$id/apply';
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
  static const String validateInvitationCode =
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
  static String paymentReceipt(int paymentId) =>
      '/api/coupon-points/payment-history/$paymentId/receipt';
  static String createWeChatCheckout(int taskId) =>
      '/api/coupon-points/tasks/$taskId/wechat-checkout';

  // ==================== Wallet endpoints ====================
  static const String walletBalance = '/api/wallet/balance';
  static const String walletTransactions = '/api/wallet/transactions';
  static const String walletWithdraw = '/api/wallet/withdraw';

  // ==================== Stripe Connect ====================
  // 后端: stripe_connect_routes.py (prefix: /api/stripe/connect)
  static const String stripeConnectSupportedCountries =
      '/api/stripe/connect/account/supported-countries';
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
  static const String changeVerificationEmail =
      '/api/student-verification/change-email';
  static const String listUniversities =
      '/api/student-verification/universities';

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

  // ==================== Follow system ====================
  static const String followFeed = '/api/follow/feed';
  static const String feedTicker = '/api/feed/ticker';

  // ==================== 论坛关联搜索 ====================
  static const String forumSearchLinkable = '/api/forum/search-linkable';
  static const String forumLinkableForUser = '/api/forum/linkable-for-user';

  // ==================== 通用/其他 ====================
  static const String uploadImage = '/api/upload/image';
  /// 优化版公开图片上传（任务/论坛/跳蚤等），返回公开 URL，支持临时目录迁移
  static const String uploadImageV2 = '/api/v2/upload/image';
  static const String uploadPublicImage = '/api/v2/upload/image'; // 公开图片统一使用V2
  static const String uploadFile = '/api/upload/file';
  static const String uploadForumFile = '/api/v2/upload/forum-file';
  static const String refreshImageUrl = '/api/refresh-image-url';
  static String privateImage(String imageId) => // [RESERVED]
      '/api/private-image/$imageId';
  static const String privateFile = '/api/private-file'; // [RESERVED]
  static const String banners = '/api/banners';
  static const String healthCheck = '/api/health';
  static const String versionCheck = '/api/app/version-check';
  static const String systemSettingsPublic = '/api/system-settings/public';
  static const String jobPositions = '/api/job-positions';
  static String faq({String lang = 'zh'}) => '/api/faq?lang=$lang';
  static String legalDocument({required String type, String lang = 'zh'}) =>
      '/api/legal/$type?lang=$lang';

  // ==================== Newbie Tasks ====================
  // 后端: newbie_tasks_routes.py
  static const String newbieTasksProgress = '/api/newbie-tasks/progress';
  static const String newbieTasksClaim = '/api/newbie-tasks'; // /{task_key}/claim
  static const String newbieTasksStages = '/api/newbie-tasks/stages';

  // ==================== Official Tasks ====================
  static const String officialTasks = '/api/official-tasks/';

  // ==================== User Skills ====================
  static const String userSkillsMy = '/api/skills/my';
  static const String skillCategories = '/api/skills/categories';

  // ==================== Skill Leaderboard ====================
  static const String leaderboardSkills = '/api/leaderboard/skills';

  // ==================== Badges ====================
  static const String badgesMy = '/api/badges/my';
  static const String badgesUser = '/api/badges/user'; // /{user_id}

  // ==================== User Profile ====================
  static const String profileCapabilities = '/api/profile/capabilities';
  static const String profilePreferences = '/api/profile/preferences';
  static const String profileReliability = '/api/profile/reliability';
  static const String profileDemand = '/api/profile/demand';
  static const String profileSummary = '/api/profile/summary';
  static const String profileOnboarding = '/api/profile/onboarding';
  static const String profileLocation = '/api/profile/location';

  // ==================== AI Agent ====================
  // 后端: ai_agent_routes.py (prefix: /api/ai)
  static const String aiConversations = '/api/ai/conversations';
  static String aiConversationDetail(String id) =>
      '/api/ai/conversations/$id';
  static String aiSendMessage(String conversationId) =>
      '/api/ai/conversations/$conversationId/messages';
}
