import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/profile/views/edit_profile_view.dart';
import '../../../features/profile/views/my_tasks_view.dart';
import '../../../features/profile/views/my_posts_view.dart';
import '../../../features/profile/views/user_profile_view.dart';
import '../../../features/profile/views/task_preferences_view.dart';

/// 个人与资料相关路由
List<RouteBase> get profileRoutes => [
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
      GoRoute(
        path: AppRoutes.userProfile,
        name: 'userProfile',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          return UserProfileView(userId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.taskPreferences,
        name: 'taskPreferences',
        builder: (context, state) => const TaskPreferencesView(),
      ),
    ];
