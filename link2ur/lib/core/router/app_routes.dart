/// 路由路径常量与需认证路由集合
/// 从 app_router 拆出，供路由模块与扩展方法使用
class AppRoutes {
  AppRoutes._();

  // 认证
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // 主页
  static const String main = '/';

  // 发布（统一入口）
  static const String publish = '/publish';

  // 任务
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';
  static const String createTask = '/tasks/create';
  // 跳蚤市场
  static const String fleaMarket = '/flea-market';
  static const String fleaMarketDetail = '/flea-market/:id';
  static const String createFleaMarketItem = '/flea-market/create';
  static const String editFleaMarketItem = '/flea-market/:id/edit';
  static const String fleaMarketRentalDetail = '/flea-market/rental/:id';
  static const String fleaMarketMyRentals = '/flea-market/my-rentals';

  // 任务达人
  static const String taskExperts = '/task-experts';
  static const String taskExpertDetail = '/task-experts/:id';
  static const String taskExpertSearch = '/task-experts/search';
  static const String taskExpertsIntro = '/task-experts/intro';
  static const String serviceDetail = '/service/:id';
  static const String myServiceApplications = '/my-service-applications';
  static const String myServices = '/services/my';
  static const String createService = '/services/create';
  static const String editService = '/services/edit/:id';
  static const String myReceivedServiceApplications = '/services/my/applications';
  static const String expertDashboard = '/expert-dashboard';
  static const String expertDashboardWithId = '/expert-dashboard/:expertId';
  static const String expertDashboardManagement =
      '/expert-dashboard/:expertId/management';

  // 达人团队管理
  static const String expertTeamMyTeams = '/expert-teams';
  static const String expertTeamDetail = '/expert-teams/:id';
  static const String expertTeamCreate = '/expert-teams/create';
  static const String expertTeamInvitations = '/expert-teams/invitations';
  static const String expertTeamPackages = '/my-packages';
  static const String groupBuy = '/group-buy/:activityId';

  // 论坛
  static const String forum = '/forum';
  static const String forumPostDetail = '/forum/posts/:id';
  static const String forumPostEdit = '/forum/posts/:id/edit';
  static const String forumPdfPreview = '/forum/pdf-preview';
  static const String createPost = '/forum/posts/create';
  static const String forumCategoryRequest = '/forum/category-request';
  static const String forumPostList = '/forum/category/:categoryId';
  static const String forumSkillFeed = '/forum/skill/:categoryId';
  static const String myForumPosts = '/forum/my-posts';

  // 排行榜
  static const String leaderboard = '/leaderboard';
  static const String leaderboardDetail = '/leaderboard/:id';
  static const String leaderboardItemDetail = '/leaderboard/item/:id';
  static const String applyLeaderboard = '/leaderboard/apply';
  static const String submitLeaderboardItem = '/leaderboard/:id/submit';

  // 消息
  static const String messages = '/messages';
  static const String chat = '/chat/:userId';
  static const String taskChat = '/task-chat/:taskId';
  static const String taskChatList = '/task-chats';
  static const String applicationChat =
      '/tasks/:taskId/applications/:applicationId/chat';

  // 通知
  static const String notifications = '/notifications';
  static const String notificationList = '/notifications/:type';

  // 个人
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String myTasks = '/profile/my-tasks';
  static const String myPosts = '/profile/my-posts';
  static const String userProfile = '/user/:id';
  static const String taskStatistics = '/profile/task-statistics';
  static const String myProfilePage = '/my-profile';
  static const String capabilityEdit = '/my-profile/capabilities';
  static const String preferenceEdit = '/my-profile/preferences';
  static const String profileSetup = '/profile-setup';

  // 钱包
  static const String wallet = '/wallet';

  // 设置
  static const String settings = '/settings';

  // 活动
  static const String activities = '/activities';
  static const String activityDetail = '/activities/:id';

  // 学生认证
  static const String studentVerification = '/student-verification';

  // 引导
  static const String onboarding = '/onboarding';
  static const String identityOnboarding = '/onboarding/identity';

  // 支付
  static const String payment = '/payment';
  static const String stripeConnectOnboarding = '/payment/stripe-connect/onboarding';
  static const String stripeConnectPayments = '/payment/stripe-connect/payments';
  static const String stripeConnectPayouts = '/payment/stripe-connect/payouts';
  static const String paymentDetail = '/payment/detail';

  // 积分与优惠券
  static const String couponPoints = '/coupon-points';

  // 新手任务
  static const String newbieTasks = '/newbie-tasks';

  // 技能排行榜
  static const String skillLeaderboard = '/skill-leaderboard';

  // 搜索
  static const String search = '/search';

  // 统一聊天（Linker，唯一 AI 入口；对话列表为历史入口）
  static const String aiChatList = '/ai-chat-list';
  static const String supportChat = '/support-chat';

  // 信息
  static const String faq = '/faq';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String communityGuidelines = '/community-guidelines';
  static const String about = '/about';
  static const String vip = '/vip';
  static const String vipPurchase = '/vip/purchase';
}

/// 需要认证才能访问的路由（其余公开路由无需登录）
const authRequiredRoutes = <String>{
  AppRoutes.publish,
  AppRoutes.createTask,
  AppRoutes.createFleaMarketItem,
  AppRoutes.editFleaMarketItem,
  AppRoutes.createPost,
  AppRoutes.forumPostEdit,
  AppRoutes.forumCategoryRequest,
  AppRoutes.editProfile,
  AppRoutes.myTasks,
  AppRoutes.myPosts,
  AppRoutes.myForumPosts,
  AppRoutes.forumSkillFeed,
  AppRoutes.myServiceApplications,
  AppRoutes.myServices,
  AppRoutes.createService,
  AppRoutes.editService,
  AppRoutes.myReceivedServiceApplications,
  AppRoutes.expertDashboard,
  AppRoutes.applyLeaderboard,
  AppRoutes.submitLeaderboardItem,
  AppRoutes.fleaMarketRentalDetail,
  AppRoutes.fleaMarketMyRentals,
  AppRoutes.wallet,
  AppRoutes.payment,
  AppRoutes.stripeConnectOnboarding,
  AppRoutes.stripeConnectPayments,
  AppRoutes.stripeConnectPayouts,
  AppRoutes.couponPoints,
  AppRoutes.studentVerification,
  AppRoutes.taskStatistics,
  AppRoutes.newbieTasks,
  AppRoutes.chat,
  AppRoutes.taskChat,
  AppRoutes.taskChatList,
  AppRoutes.applicationChat,
  AppRoutes.notifications,
  AppRoutes.notificationList,
  AppRoutes.settings,
  AppRoutes.myProfilePage,
  AppRoutes.capabilityEdit,
  AppRoutes.preferenceEdit,
  AppRoutes.profileSetup,
};
