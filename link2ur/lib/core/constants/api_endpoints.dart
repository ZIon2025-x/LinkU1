/// API端点常量
/// 参考iOS项目 APIEndpoints.swift
class ApiEndpoints {
  ApiEndpoints._();

  // ==================== 认证相关 ====================
  static const String login = '/api/secure-auth/login';
  static const String loginWithCode = '/api/secure-auth/login-with-code';
  static const String loginWithPhoneCode = '/api/secure-auth/login-with-phone-code';
  static const String register = '/api/secure-auth/register';
  static const String logout = '/api/secure-auth/logout';
  static const String refreshToken = '/api/secure-auth/refresh';
  static const String sendVerificationCode = '/api/secure-auth/send-verification-code';
  static const String sendPhoneCode = '/api/secure-auth/send-phone-verification-code';
  static const String captchaSiteKey = '/api/secure-auth/captcha-site-key';
  static const String resetPassword = '/api/secure-auth/reset-password';

  // ==================== 用户相关 ====================
  static const String userProfile = '/api/users/me';
  static const String updateProfile = '/api/users/me';
  static const String uploadAvatar = '/api/users/me/avatar';
  static String userById(int id) => '/api/users/$id';
  static String userPublicProfile(int id) => '/api/users/$id/public';
  static const String userPreferences = '/api/users/me/preferences';

  // ==================== 任务相关 ====================
  static const String tasks = '/api/tasks';
  static String taskById(int id) => '/api/tasks/$id';
  static String applyTask(int id) => '/api/tasks/$id/apply';
  static String cancelApplication(int id) => '/api/tasks/$id/cancel-application';
  static String acceptApplicant(int taskId, int applicantId) => '/api/tasks/$taskId/accept/$applicantId';
  static String completeTask(int id) => '/api/tasks/$id/complete';
  static String confirmCompletion(int id) => '/api/tasks/$id/confirm';
  static String cancelTask(int id) => '/api/tasks/$id/cancel';
  static String reviewTask(int id) => '/api/tasks/$id/review';
  static const String myTasks = '/api/tasks/my';
  static const String myPostedTasks = '/api/tasks/posted';
  static const String recommendedTasks = '/api/tasks/recommended';
  static const String nearbyTasks = '/api/tasks/nearby';

  // ==================== 跳蚤市场 ====================
  static const String fleaMarket = '/api/flea-market';
  static String fleaMarketById(int id) => '/api/flea-market/$id';
  static String purchaseFleaMarket(int id) => '/api/flea-market/$id/purchase';
  static const String myFleaMarketItems = '/api/flea-market/my';

  // ==================== 任务达人 ====================
  static const String taskExperts = '/api/task-experts';
  static String taskExpertById(int id) => '/api/task-experts/$id';
  static String taskExpertServices(int id) => '/api/task-experts/$id/services';
  static String applyService(int serviceId) => '/api/task-expert-services/$serviceId/apply';
  static const String myServiceApplications = '/api/task-expert-services/my-applications';

  // ==================== 论坛相关 ====================
  static const String forumCategories = '/api/forum/categories';
  static const String forumPosts = '/api/forum/posts';
  static String forumPostById(int id) => '/api/forum/posts/$id';
  static String forumPostReplies(int id) => '/api/forum/posts/$id/replies';
  static String likePost(int id) => '/api/forum/posts/$id/like';
  static String favoritePost(int id) => '/api/forum/posts/$id/favorite';
  static const String myForumPosts = '/api/forum/posts/my';
  static const String favoriteForumPosts = '/api/forum/posts/favorites';
  static const String likedForumPosts = '/api/forum/posts/liked';

  // ==================== 任务达人补充 ====================
  static const String taskExpertServiceDetail = '/api/task-expert-services';

  // ==================== 排行榜 ====================
  static const String leaderboards = '/api/leaderboards';
  static String leaderboardById(int id) => '/api/leaderboards/$id';
  static String leaderboardItems(int id) => '/api/leaderboards/$id/items';
  static String voteItem(int itemId) => '/api/leaderboard-items/$itemId/vote';
  static const String myLeaderboards = '/api/leaderboards/my';
  static const String leaderboardItemById = '/api/leaderboard-items';
  static const String applyLeaderboard = '/api/leaderboards/apply';
  static String submitLeaderboardItem(int id) => '/api/leaderboards/$id/items';

  // ==================== 消息相关 ====================
  static const String messages = '/api/messages';
  static const String contacts = '/api/messages/contacts';
  static String messagesWith(int userId) => '/api/messages/with/$userId';
  static String markMessagesRead(int contactId) => '/api/messages/read/$contactId';
  static const String taskChats = '/api/task-chats';
  static String taskChatMessages(int taskId) => '/api/task-chats/$taskId/messages';

  // ==================== 通知相关 ====================
  static const String notifications = '/api/notifications';
  static String markNotificationRead(int id) => '/api/notifications/$id/read';
  static const String markAllNotificationsRead = '/api/notifications/read-all';
  static const String unreadCount = '/api/notifications/unread-count';
  static const String forumNotifications = '/api/forum/notifications';

  // ==================== 活动相关 ====================
  static const String activities = '/api/activities';
  static String activityById(int id) => '/api/activities/$id';
  static String applyActivity(int id) => '/api/activities/$id/apply';

  // ==================== 积分优惠券 ====================
  static const String pointsAccount = '/api/points/account';
  static const String pointsTransactions = '/api/points/transactions';
  static const String checkIn = '/api/points/check-in';
  static const String coupons = '/api/coupons';
  static const String myCoupons = '/api/coupons/my';
  static const String validateInvitationCode = '/api/coupons/validate-invitation';

  // ==================== 钱包相关 ====================
  static const String walletInfo = '/api/wallet/info';
  static const String transactions = '/api/wallet/transactions';

  // ==================== 支付相关 ====================
  static const String createPaymentIntent = '/api/payments/create-intent';
  static const String confirmPayment = '/api/payments/confirm';
  static const String paymentMethods = '/api/payments/methods';
  static const String stripeConnectOnboarding = '/api/stripe-connect/onboarding';
  static const String stripeConnectStatus = '/api/stripe-connect/status';
  static const String stripeConnectTransactions = '/api/stripe-connect/transactions';

  // ==================== 学生认证 ====================
  static const String studentVerificationStatus = '/api/student-verification/status';
  static const String submitStudentVerification = '/api/student-verification/submit';
  static const String verifyStudentEmail = '/api/student-verification/verify';
  static const String universities = '/api/universities';

  // ==================== 客服相关 ====================
  static const String customerServiceInfo = '/api/customer-service/info';
  static const String customerServiceChats = '/api/customer-service/chats';
  static const String startCustomerServiceChat = '/api/customer-service/start';

  // ==================== 微信支付 ====================
  static const String wechatCheckout = '/api/payments/wechat-checkout';
  static String taskPaymentStatus(int taskId) => '/api/payments/tasks/$taskId/status';

  // ==================== IAP / VIP ====================
  static const String activateVIP = '/api/vip/activate';
  static const String vipStatus = '/api/vip/status';
  static const String iapProducts = '/api/iap/products';

  // ==================== 翻译 ====================
  static const String translate = '/api/translate';
  static const String translateBatch = '/api/translate/batch';

  // ==================== 其他 ====================
  static const String banners = '/api/banners';
  static const String faq = '/api/faq';
  static const String legalDocuments = '/api/legal-documents';
  static const String appVersion = '/api/app/version';
  static const String uploadImage = '/api/upload/image';
}
