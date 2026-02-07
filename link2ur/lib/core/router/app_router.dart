import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

/// 路由路径常量
class AppRoutes {
  AppRoutes._();

  // 认证
  static const String login = '/login';
  static const String register = '/register';

  // 主页
  static const String main = '/';
  static const String home = '/home';

  // 任务
  static const String tasks = '/tasks';
  static const String taskDetail = '/tasks/:id';
  static const String createTask = '/tasks/create';

  // 跳蚤市场
  static const String fleaMarket = '/flea-market';
  static const String fleaMarketDetail = '/flea-market/:id';
  static const String createFleaMarketItem = '/flea-market/create';

  // 任务达人
  static const String taskExperts = '/task-experts';
  static const String taskExpertDetail = '/task-experts/:id';

  // 论坛
  static const String forum = '/forum';
  static const String forumPostDetail = '/forum/posts/:id';
  static const String createPost = '/forum/posts/create';

  // 排行榜
  static const String leaderboard = '/leaderboard';
  static const String leaderboardDetail = '/leaderboard/:id';

  // 消息
  static const String messages = '/messages';
  static const String chat = '/chat/:userId';
  static const String taskChat = '/task-chat/:taskId';

  // 通知
  static const String notifications = '/notifications';

  // 个人
  static const String profile = '/profile';
  static const String editProfile = '/profile/edit';
  static const String myTasks = '/profile/my-tasks';
  static const String myPosts = '/profile/my-posts';

  // 钱包
  static const String wallet = '/wallet';

  // 设置
  static const String settings = '/settings';

  // 活动
  static const String activities = '/activities';
  static const String activityDetail = '/activities/:id';

  // 学生认证
  static const String studentVerification = '/student-verification';
}

/// 应用路由配置
class AppRouter {
  AppRouter();

  late final GoRouter router = GoRouter(
    initialLocation: AppRoutes.main,
    debugLogDiagnostics: true,
    routes: [
      // 主页面（底部导航栏）
      ShellRoute(
        builder: (context, state, child) => MainTabView(child: child),
        routes: [
          GoRoute(
            path: AppRoutes.main,
            name: 'main',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: HomeView(),
            ),
          ),
          GoRoute(
            path: '/community',
            name: 'community',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ForumView(),
            ),
          ),
          GoRoute(
            path: '/messages-tab',
            name: 'messages-tab',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: MessageView(),
            ),
          ),
          GoRoute(
            path: '/profile-tab',
            name: 'profile-tab',
            pageBuilder: (context, state) => const NoTransitionPage(
              child: ProfileView(),
            ),
          ),
        ],
      ),

      // 认证
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginView(),
      ),
      GoRoute(
        path: AppRoutes.register,
        name: 'register',
        builder: (context, state) => const RegisterView(),
      ),

      // 任务
      GoRoute(
        path: AppRoutes.tasks,
        name: 'tasks',
        builder: (context, state) => const TasksView(),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        name: 'taskDetail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TaskDetailView(taskId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.createTask,
        name: 'createTask',
        builder: (context, state) => const CreateTaskView(),
      ),

      // 跳蚤市场
      GoRoute(
        path: AppRoutes.fleaMarket,
        name: 'fleaMarket',
        builder: (context, state) => const FleaMarketView(),
      ),
      GoRoute(
        path: AppRoutes.fleaMarketDetail,
        name: 'fleaMarketDetail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return FleaMarketDetailView(itemId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.createFleaMarketItem,
        name: 'createFleaMarketItem',
        builder: (context, state) => const CreateFleaMarketItemView(),
      ),

      // 任务达人
      GoRoute(
        path: AppRoutes.taskExperts,
        name: 'taskExperts',
        builder: (context, state) => const TaskExpertListView(),
      ),
      GoRoute(
        path: AppRoutes.taskExpertDetail,
        name: 'taskExpertDetail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return TaskExpertDetailView(expertId: id);
        },
      ),

      // 论坛
      GoRoute(
        path: AppRoutes.forum,
        name: 'forum',
        builder: (context, state) => const ForumView(),
      ),
      GoRoute(
        path: AppRoutes.forumPostDetail,
        name: 'forumPostDetail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ForumPostDetailView(postId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.createPost,
        name: 'createPost',
        builder: (context, state) => const CreatePostView(),
      ),

      // 排行榜
      GoRoute(
        path: AppRoutes.leaderboard,
        name: 'leaderboard',
        builder: (context, state) => const LeaderboardView(),
      ),
      GoRoute(
        path: AppRoutes.leaderboardDetail,
        name: 'leaderboardDetail',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return LeaderboardDetailView(leaderboardId: id);
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
          final userId = int.parse(state.pathParameters['userId']!);
          return ChatView(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.taskChat,
        name: 'taskChat',
        builder: (context, state) {
          final taskId = int.parse(state.pathParameters['taskId']!);
          return TaskChatView(taskId: taskId);
        },
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
        builder: (context, state) => const EditProfileView(),
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
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ActivityDetailView(activityId: id);
        },
      ),

      // 学生认证
      GoRoute(
        path: AppRoutes.studentVerification,
        name: 'studentVerification',
        builder: (context, state) => const StudentVerificationView(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('页面不存在: ${state.uri}'),
      ),
    ),
  );
}

/// 路由扩展方法
extension GoRouterExtension on BuildContext {
  /// 跳转到任务详情
  void goToTaskDetail(int taskId) {
    go('/tasks/$taskId');
  }

  /// 跳转到跳蚤市场详情
  void goToFleaMarketDetail(int itemId) {
    go('/flea-market/$itemId');
  }

  /// 跳转到达人详情
  void goToTaskExpertDetail(int expertId) {
    go('/task-experts/$expertId');
  }

  /// 跳转到帖子详情
  void goToForumPostDetail(int postId) {
    go('/forum/posts/$postId');
  }

  /// 跳转到聊天
  void goToChat(int userId) {
    go('/chat/$userId');
  }

  /// 跳转到任务聊天
  void goToTaskChat(int taskId) {
    go('/task-chat/$taskId');
  }
}
