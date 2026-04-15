import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/profile/views/profile_view.dart';
import '../../../features/profile/views/edit_profile_view.dart';
import '../../../features/profile/views/my_tasks_view.dart';
import '../../../features/profile/views/my_posts_view.dart';
import '../../../features/profile/views/user_profile_view.dart';
import '../../../features/profile/views/task_statistics_view.dart';
import '../../../features/user_profile/views/my_profile_view.dart';
import '../../../features/user_profile/views/capability_edit_view.dart';
import '../../../features/user_profile/views/preference_edit_view.dart';

/// 解析 `/profile/my-posts?tab=<name-or-index>` 查询参数为 Tab 索引。
/// Tab 顺序 (与 MyPostsView 对齐):
///   0=selling, 1=sold, 2=bought, 3=rented-out, 4=rented-in, 5=favorites
int _parseMyPostsTabIndex(String? tab) {
  switch (tab) {
    case 'selling':
      return 0;
    case 'sold':
      return 1;
    case 'bought':
    case 'purchased':
      return 2;
    case 'rented-out':
      return 3;
    case 'rented-in':
      return 4;
    case 'favorites':
    case 'favorite':
      return 5;
    default:
      final n = int.tryParse(tab ?? '');
      return (n != null && n >= 0 && n <= 5) ? n : 0;
  }
}

/// 个人与资料相关路由
List<RouteBase> get profileRoutes => [
      GoRoute(
        path: AppRoutes.profile,
        name: 'profile',
        builder: (context, state) => const ProfileView(),
      ),
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
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          final tab = tabStr != null ? int.tryParse(tabStr) : null;
          return MyTasksView(initialTab: tab);
        },
      ),
      GoRoute(
        path: AppRoutes.myPosts,
        name: 'myPosts',
        builder: (context, state) {
          final tabStr = state.uri.queryParameters['tab'];
          return MyPostsView(initialTab: _parseMyPostsTabIndex(tabStr));
        },
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        name: 'userProfile',
        builder: (context, state) {
          final id = state.pathParameters['id'] ?? '';
          if (id.isEmpty) return const SizedBox.shrink();
          return UserProfileView(userId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.taskStatistics,
        name: 'taskStatistics',
        builder: (context, state) => const TaskStatisticsView(),
      ),
      GoRoute(
        path: AppRoutes.myProfilePage,
        name: 'myProfilePage',
        builder: (context, state) => const MyProfileView(),
        routes: [
          GoRoute(
            path: 'capabilities',
            name: 'capabilityEdit',
            builder: (context, state) => const CapabilityEditView(),
          ),
          GoRoute(
            path: 'preferences',
            name: 'preferenceEdit',
            builder: (context, state) => const PreferenceEditView(),
          ),
        ],
      ),
    ];
