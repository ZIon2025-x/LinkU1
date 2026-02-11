import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'page_transitions.dart';
import '../../l10n/app_localizations.dart';
import '../../features/auth/bloc/auth_bloc.dart';

import '../../features/auth/views/login_view.dart';
import '../../features/auth/views/register_view.dart';
import '../../features/main/main_tab_view.dart';
import '../../features/home/views/home_view.dart';
import '../../features/tasks/views/tasks_view.dart';
import '../../features/tasks/views/task_detail_view.dart';
import '../../features/tasks/views/create_task_view.dart';
import '../../features/flea_market/views/flea_market_view.dart';
import '../../features/flea_market/views/flea_market_detail_view.dart';
import '../../features/flea_market/views/create_flea_market_item_view.dart';
import '../../features/task_expert/views/task_expert_list_view.dart';
import '../../features/task_expert/views/task_expert_detail_view.dart';
import '../../features/forum/views/forum_view.dart';
import '../../features/forum/views/forum_post_detail_view.dart';
import '../../features/forum/views/create_post_view.dart';
import '../../features/leaderboard/views/leaderboard_view.dart';
import '../../features/leaderboard/views/leaderboard_detail_view.dart';
import '../../features/message/views/message_view.dart';
import '../../features/chat/views/chat_view.dart';
import '../../features/chat/views/task_chat_view.dart';
import '../../features/notification/views/notification_center_view.dart';
import '../../features/profile/views/profile_view.dart';
import '../../features/profile/views/edit_profile_view.dart';
import '../../features/profile/views/my_tasks_view.dart';
import '../../features/profile/views/my_posts_view.dart';
import '../../features/wallet/views/wallet_view.dart';
import '../../features/settings/views/settings_view.dart';
import '../../features/activity/views/activity_list_view.dart';
import '../../features/activity/views/activity_detail_view.dart';
import '../../features/student_verification/views/student_verification_view.dart';
import '../../features/onboarding/views/onboarding_view.dart';
import '../../features/customer_service/views/customer_service_view.dart';
import '../../features/coupon_points/views/coupon_points_view.dart';
import '../../features/info/views/info_views.dart';
import '../../features/info/views/vip_purchase_view.dart';
import '../../features/flea_market/views/edit_flea_market_item_view.dart';
import '../../features/forum/views/forum_post_list_view.dart';
import '../../features/forum/views/forum_category_request_view.dart';
import '../../features/profile/views/user_profile_view.dart';
import '../../features/profile/views/task_preferences_view.dart';
import '../../features/profile/views/my_forum_posts_view.dart';
import '../../features/task_expert/views/task_expert_search_view.dart';
import '../../features/task_expert/views/service_detail_view.dart';
import '../../features/task_expert/views/my_service_applications_view.dart';
import '../../features/task_expert/views/task_experts_intro_view.dart';
import '../../features/tasks/views/task_filter_view.dart';
import '../../features/leaderboard/views/leaderboard_item_detail_view.dart';
import '../../features/leaderboard/views/apply_leaderboard_view.dart';
import '../../features/leaderboard/views/submit_leaderboard_item_view.dart';
import '../../features/payment/views/stripe_connect_onboarding_view.dart';
import '../../features/payment/views/stripe_connect_payments_view.dart';
import '../../features/payment/views/stripe_connect_payouts_view.dart';
import '../../features/notification/views/notification_list_view.dart';
import '../../features/notification/views/task_chat_list_view.dart';
import '../../features/auth/views/forgot_password_view.dart';
import '../../features/info/views/vip_view.dart';
import '../../features/publish/views/publish_view.dart';
import '../../features/search/views/search_view.dart';

/// 路由路径常量
class AppRoutes {
  AppRoutes._();

  // 认证
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // 主页
  static const String main = '/';
  static const String home = '/home';

  // 发布（统一入口）
  static const String publish = '/publish';

  // 任务
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';
  static const String createTask = '/tasks/create';
  static const String taskFilter = '/tasks/filter';

  // 跳蚤市场
  static const String fleaMarket = '/flea-market';
  static const String fleaMarketDetail = '/flea-market/:id';
  static const String createFleaMarketItem = '/flea-market/create';
  static const String editFleaMarketItem = '/flea-market/:id/edit';

  // 任务达人
  static const String taskExperts = '/task-experts';
  static const String taskExpertDetail = '/task-experts/:id';
  static const String taskExpertSearch = '/task-experts/search';
  static const String taskExpertsIntro = '/task-experts/intro';
  static const String serviceDetail = '/service/:id';
  static const String myServiceApplications = '/my-service-applications';

  // 论坛
  static const String forum = '/forum';
  static const String forumPostDetail = '/forum/posts/:id';
  static const String createPost = '/forum/posts/create';
  static const String forumCategoryRequest = '/forum/category-request';
  static const String forumPostList = '/forum/category/:categoryId';
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

  // 通知
  static const String notifications = '/notifications';
  static const String notificationList = '/notifications/:type';

  // 个人
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String myTasks = '/profile/my-tasks';
  static const String myPosts = '/profile/my-posts';
  static const String userProfile = '/user/:id';
  static const String avatarPicker = '/profile/avatar';
  static const String taskPreferences = '/profile/task-preferences';

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

  // 客服
  static const String customerService = '/customer-service';

  // 支付
  static const String payment = '/payment';
  static const String stripeConnectOnboarding = '/payment/stripe-connect/onboarding';
  static const String stripeConnectPayments = '/payment/stripe-connect/payments';
  static const String stripeConnectPayouts = '/payment/stripe-connect/payouts';

  // 积分与优惠券
  static const String couponPoints = '/coupon-points';

  // 搜索
  static const String search = '/search';

  // 信息
  static const String faq = '/faq';
  static const String terms = '/terms';
  static const String privacy = '/privacy';
  static const String about = '/about';
  static const String vip = '/vip';
  static const String vipPurchase = '/vip/purchase';
}

/// 需要认证才能访问的路由（其余公开路由无需登录）
const _authRequiredRoutes = <String>{
  AppRoutes.publish,
  AppRoutes.createTask,
  AppRoutes.createFleaMarketItem,
  AppRoutes.createPost,
  AppRoutes.forumCategoryRequest,
  AppRoutes.editProfile,
  AppRoutes.myTasks,
  AppRoutes.myPosts,
  AppRoutes.myForumPosts,
  AppRoutes.myServiceApplications,
  AppRoutes.wallet,
  AppRoutes.payment,
  AppRoutes.stripeConnectOnboarding,
  AppRoutes.stripeConnectPayments,
  AppRoutes.stripeConnectPayouts,
  AppRoutes.couponPoints,
  AppRoutes.studentVerification,
  AppRoutes.taskPreferences,
  AppRoutes.chat,
  AppRoutes.taskChat,
  AppRoutes.taskChatList,
  AppRoutes.notifications,
  AppRoutes.notificationList,
};

/// 应用路由配置
class AppRouter {
  AppRouter({required AuthBloc authBloc}) : _authBloc = authBloc;

  final AuthBloc _authBloc;

  /// 检查路径是否需要认证（支持参数化路径匹配）
  static bool _requiresAuth(String location) {
    for (final route in _authRequiredRoutes) {
      // 将路由模板转为正则：/chat/:userId → /chat/[^/]+
      final pattern = route.replaceAllMapped(
        RegExp(r':(\w+)'),
        (m) => r'[^/]+',
      );
      if (RegExp('^$pattern\$').hasMatch(location)) return true;
    }
    return false;
  }

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.main,
    debugLogDiagnostics: false,
    // 监听 AuthBloc 状态变化，自动触发路由重定向（如 Token 失效时跳转登录页）
    refreshListenable: _GoRouterBlocRefreshStream(_authBloc.stream),
    redirect: (BuildContext context, GoRouterState state) {
      final authState = context.read<AuthBloc>().state;
      final isAuthenticated = authState.isAuthenticated;
      final location = state.matchedLocation;

      // 认证检查中，不做跳转
      if (authState.status == AuthStatus.initial ||
          authState.status == AuthStatus.checking) {
        return null;
      }

      final isAuthRoute = location == AppRoutes.login ||
          location == AppRoutes.register ||
          location == AppRoutes.forgotPassword;

      // 未登录 + 需要认证的路由 → 跳转到登录
      if (!isAuthenticated && _requiresAuth(location)) {
        return AppRoutes.login;
      }

      // 已登录 + 在认证页 → 跳转到首页
      if (isAuthenticated && isAuthRoute) {
        return AppRoutes.main;
      }

      return null;
    },
    routes: [
      // 主页面（底部导航栏）
      // StatefulShellRoute.indexedStack 原生保持各分支 State，避免手动缓存导致 GlobalKey 冲突
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            MainTabView(navigationShell: navigationShell),
        branches: [
          // Branch 0: 首页
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.main,
                name: 'main',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: HomeView(),
                ),
              ),
            ],
          ),
          // Branch 1: 社区
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/community',
                name: 'community',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ForumView(),
                ),
              ),
            ],
          ),
          // Branch 2: 消息
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/messages-tab',
                name: 'messages-tab',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: MessageView(),
                ),
              ),
            ],
          ),
          // Branch 3: 我的
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile-tab',
                name: 'profile-tab',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ProfileView(),
                ),
              ),
            ],
          ),
        ],
      ),

      // 认证 — 淡入缩放转场
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: const LoginView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: const RegisterView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: 'forgotPassword',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: const ForgotPasswordView(),
        ),
      ),

      // 统一发布页（从底部滑入）
      GoRoute(
        path: AppRoutes.publish,
        name: 'publish',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const PublishView(),
        ),
      ),

      // 任务（具体路径在参数化路径之前）
      GoRoute(
        path: AppRoutes.tasks,
        name: 'tasks',
        builder: (context, state) => const TasksView(),
      ),
      GoRoute(
        path: AppRoutes.createTask,
        name: 'createTask',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const CreateTaskView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.taskFilter,
        name: 'taskFilter',
        builder: (context, state) => const TaskFilterView(),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        name: 'taskDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SpringSlideTransitionPage(
            key: state.pageKey,
            child: TaskDetailView(taskId: id),
          );
        },
      ),

      // 跳蚤市场（具体路径在参数化路径之前）
      GoRoute(
        path: AppRoutes.fleaMarket,
        name: 'fleaMarket',
        builder: (context, state) => const FleaMarketView(),
      ),
      GoRoute(
        path: AppRoutes.createFleaMarketItem,
        name: 'createFleaMarketItem',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const CreateFleaMarketItemView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.editFleaMarketItem,
        name: 'editFleaMarketItem',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          final item = state.extra as dynamic;
          return SlideUpTransitionPage(
            key: state.pageKey,
            child: EditFleaMarketItemView(itemId: id, item: item),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.fleaMarketDetail,
        name: 'fleaMarketDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SpringSlideTransitionPage(
            key: state.pageKey,
            child: FleaMarketDetailView(itemId: id),
          );
        },
      ),

      // 任务达人（具体路径在参数化路径之前）
      GoRoute(
        path: AppRoutes.taskExperts,
        name: 'taskExperts',
        builder: (context, state) => const TaskExpertListView(),
      ),
      GoRoute(
        path: AppRoutes.taskExpertSearch,
        name: 'taskExpertSearch',
        builder: (context, state) => const TaskExpertSearchView(),
      ),
      GoRoute(
        path: AppRoutes.taskExpertsIntro,
        name: 'taskExpertsIntro',
        builder: (context, state) => const TaskExpertsIntroView(),
      ),
      GoRoute(
        path: AppRoutes.taskExpertDetail,
        name: 'taskExpertDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SpringSlideTransitionPage(
            key: state.pageKey,
            child: TaskExpertDetailView(expertId: id),
          );
        },
      ),

      // 论坛（具体路径在参数化路径之前）
      GoRoute(
        path: AppRoutes.forum,
        name: 'forum',
        builder: (context, state) => const ForumView(),
      ),
      GoRoute(
        path: AppRoutes.createPost,
        name: 'createPost',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const CreatePostView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.forumCategoryRequest,
        name: 'forumCategoryRequest',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const ForumCategoryRequestView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.myForumPosts,
        name: 'myForumPosts',
        builder: (context, state) => const MyForumPostsView(),
      ),
      GoRoute(
        path: AppRoutes.forumPostDetail,
        name: 'forumPostDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SpringSlideTransitionPage(
            key: state.pageKey,
            child: ForumPostDetailView(postId: id),
          );
        },
      ),

      // 排行榜（具体路径在参数化路径之前）
      GoRoute(
        path: AppRoutes.leaderboard,
        name: 'leaderboard',
        builder: (context, state) => const LeaderboardView(),
      ),
      GoRoute(
        path: AppRoutes.applyLeaderboard,
        name: 'applyLeaderboard',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const ApplyLeaderboardView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.leaderboardItemDetail,
        name: 'leaderboardItemDetail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return LeaderboardItemDetailView(itemId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.submitLeaderboardItem,
        name: 'submitLeaderboardItem',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SlideUpTransitionPage(
            key: state.pageKey,
            child: SubmitLeaderboardItemView(leaderboardId: id),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.leaderboardDetail,
        name: 'leaderboardDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SpringSlideTransitionPage(
            key: state.pageKey,
            child: LeaderboardDetailView(leaderboardId: id),
          );
        },
      ),

      // 消息
      GoRoute(
        path: AppRoutes.messages,
        name: 'messages',
        builder: (context, state) => const MessageView(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return ChatView(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.taskChat,
        name: 'taskChat',
        builder: (context, state) {
          final taskId = int.tryParse(state.pathParameters['taskId'] ?? '') ?? 0;
          return TaskChatView(taskId: taskId);
        },
      ),
      GoRoute(
        path: AppRoutes.taskChatList,
        name: 'taskChatList',
        builder: (context, state) => const TaskChatListView(),
      ),

      // 通知
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationCenterView(),
      ),

      // 个人
      GoRoute(
        path: AppRoutes.editProfile,
        name: 'editProfile',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const EditProfileView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.myTasks,
        name: 'myTasks',
        builder: (context, state) => const MyTasksView(),
      ),
      GoRoute(
        path: AppRoutes.myPosts,
        name: 'myPosts',
        builder: (context, state) => const MyPostsView(),
      ),

      // 钱包
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        builder: (context, state) => const WalletView(),
      ),

      // 设置
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsView(),
      ),

      // 活动
      GoRoute(
        path: AppRoutes.activities,
        name: 'activities',
        builder: (context, state) => const ActivityListView(),
      ),
      GoRoute(
        path: AppRoutes.activityDetail,
        name: 'activityDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return SpringSlideTransitionPage(
            key: state.pageKey,
            child: ActivityDetailView(activityId: id),
          );
        },
      ),

      // 学生认证
      GoRoute(
        path: AppRoutes.studentVerification,
        name: 'studentVerification',
        builder: (context, state) => const StudentVerificationView(),
      ),

      // 引导页 — 淡入缩放转场
      GoRoute(
        path: AppRoutes.onboarding,
        name: 'onboarding',
        pageBuilder: (context, state) => FadeScaleTransitionPage(
          key: state.pageKey,
          child: OnboardingView(
            onComplete: () => Navigator.of(context).pop(),
          ),
        ),
      ),

      // 客服
      GoRoute(
        path: AppRoutes.customerService,
        name: 'customerService',
        builder: (context, state) => const CustomerServiceView(),
      ),

      // 积分与优惠券
      GoRoute(
        path: AppRoutes.couponPoints,
        name: 'couponPoints',
        builder: (context, state) => const CouponPointsView(),
      ),

      // FAQ
      GoRoute(
        path: AppRoutes.faq,
        name: 'faq',
        builder: (context, state) => const FAQView(),
      ),

      // 服务条款
      GoRoute(
        path: AppRoutes.terms,
        name: 'terms',
        builder: (context, state) => const TermsView(),
      ),

      // 隐私政策
      GoRoute(
        path: AppRoutes.privacy,
        name: 'privacy',
        builder: (context, state) => const PrivacyView(),
      ),

      // 关于
      GoRoute(
        path: AppRoutes.about,
        name: 'about',
        builder: (context, state) => const AboutView(),
      ),

      // VIP 会员中心
      GoRoute(
        path: AppRoutes.vip,
        name: 'vip',
        builder: (context, state) => const VipView(),
      ),

      // VIP 购买
      GoRoute(
        path: AppRoutes.vipPurchase,
        name: 'vipPurchase',
        builder: (context, state) => const VIPPurchaseView(),
      ),

      // 全局搜索
      GoRoute(
        path: AppRoutes.search,
        name: 'search',
        builder: (context, state) => const SearchView(),
      ),


      // 论坛分类帖子列表
      GoRoute(
        path: AppRoutes.forumPostList,
        name: 'forumPostList',
        builder: (context, state) {
          final category = state.extra as dynamic;
          return ForumPostListView(category: category);
        },
      ),

      // 用户公开资料
      GoRoute(
        path: AppRoutes.userProfile,
        name: 'userProfile',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return UserProfileView(userId: id);
        },
      ),

      // 任务偏好设置
      GoRoute(
        path: AppRoutes.taskPreferences,
        name: 'taskPreferences',
        builder: (context, state) => const TaskPreferencesView(),
      ),

      // 服务详情
      GoRoute(
        path: AppRoutes.serviceDetail,
        name: 'serviceDetail',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
          return ServiceDetailView(serviceId: id);
        },
      ),

      // 我的服务申请
      GoRoute(
        path: AppRoutes.myServiceApplications,
        name: 'myServiceApplications',
        builder: (context, state) => const MyServiceApplicationsView(),
      ),


      // 通知列表
      GoRoute(
        path: AppRoutes.notificationList,
        name: 'notificationList',
        builder: (context, state) {
          final type = state.pathParameters['type'];
          return NotificationListView(type: type);
        },
      ),

      // Stripe Connect 入驻（对标iOS：自动检查状态→创建账户→入驻）
      GoRoute(
        path: AppRoutes.stripeConnectOnboarding,
        name: 'stripeConnectOnboarding',
        builder: (context, state) {
          return const StripeConnectOnboardingView();
        },
      ),

      // Stripe Connect 收款
      GoRoute(
        path: AppRoutes.stripeConnectPayments,
        name: 'stripeConnectPayments',
        builder: (context, state) => const StripeConnectPaymentsView(),
      ),

      // Stripe Connect 提现
      GoRoute(
        path: AppRoutes.stripeConnectPayouts,
        name: 'stripeConnectPayouts',
        builder: (context, state) => const StripeConnectPayoutsView(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(AppLocalizations.of(context)?.errorPageNotFound(state.uri.toString()) ?? 'Page not found: ${state.uri}'),
      ),
    ),
  );
}

/// 全局导航防抖：防止快速双击导致同一页面被 push 两次
/// 所有导航方法（go/push）都经过此锁，500ms 内只允许一次导航
class _NavigationThrottle {
  static DateTime _lastNavigationTime = DateTime(2000);
  static const _minInterval = Duration(milliseconds: 500);

  /// 如果距上次导航超过 500ms 返回 true，否则返回 false（丢弃本次导航）
  static bool acquire() {
    final now = DateTime.now();
    if (now.difference(_lastNavigationTime) < _minInterval) {
      return false;
    }
    _lastNavigationTime = now;
    return true;
  }
}

/// 路由扩展方法
extension GoRouterExtension on BuildContext {
  /// 带防抖的 push，防止快速双击导致同一页面被 push 两次
  void safePush(String location, {Object? extra}) {
    if (!_NavigationThrottle.acquire()) return;
    push(location, extra: extra);
  }

  /// 带防抖的 go
  void safeGo(String location, {Object? extra}) {
    if (!_NavigationThrottle.acquire()) return;
    go(location);
  }

  /// 跳转到任务详情
  void goToTaskDetail(int taskId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/tasks/$taskId');
  }

  /// 跳转到跳蚤市场详情
  void goToFleaMarketDetail(int itemId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/flea-market/$itemId');
  }

  /// 跳转到达人详情
  void goToTaskExpertDetail(int expertId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/task-experts/$expertId');
  }

  /// 跳转到帖子详情
  void goToForumPostDetail(int postId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/forum/posts/$postId');
  }

  /// 跳转到聊天
  void goToChat(String userId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/chat/$userId');
  }

  /// 跳转到任务聊天
  void goToTaskChat(int taskId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/task-chat/$taskId');
  }

  /// 跳转到用户资料
  void goToUserProfile(String userId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/user/$userId');
  }

  /// 跳转到排行榜条目详情
  void goToLeaderboardItemDetail(int itemId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/leaderboard/item/$itemId');
  }

  /// 跳转到服务详情
  void goToServiceDetail(int serviceId) {
    if (!_NavigationThrottle.acquire()) return;
    push('/service/$serviceId');
  }

  /// 跳转到论坛分类
  void goToForumCategory(dynamic category) {
    if (!_NavigationThrottle.acquire()) return;
    push('/forum/category/${category.id}', extra: category);
  }

  /// 跳转到VIP购买
  void goToVIPPurchase() {
    if (!_NavigationThrottle.acquire()) return;
    push('/vip/purchase');
  }

  /// 跳转到任务偏好
  void goToTaskPreferences() {
    if (!_NavigationThrottle.acquire()) return;
    push('/profile/task-preferences');
  }

  /// 跳转到我的论坛帖子
  void goToMyForumPosts() {
    if (!_NavigationThrottle.acquire()) return;
    push('/forum/my-posts');
  }

  /// 跳转到任务达人搜索
  void goToTaskExpertSearch() {
    if (!_NavigationThrottle.acquire()) return;
    push('/task-experts/search');
  }
}

/// 将 Bloc Stream 转为 GoRouter 可监听的 ChangeNotifier
/// 当 AuthBloc 状态变化时通知 GoRouter 重新评估 redirect
class _GoRouterBlocRefreshStream extends ChangeNotifier {
  _GoRouterBlocRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
