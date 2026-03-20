import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/profile/views/profile_view.dart';
import '../../../features/profile/views/edit_profile_view.dart';
import '../../../features/profile/views/my_tasks_view.dart';
import '../../../features/profile/views/my_posts_view.dart';
import '../../../features/profile/views/user_profile_view.dart';
import '../../../features/profile/views/task_preferences_view.dart';
import '../../../features/user_profile/views/my_profile_view.dart';
import '../../../features/user_profile/views/capability_edit_view.dart';
import '../../../features/user_profile/views/preference_edit_view.dart';

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
        builder: (context, state) => const MyPostsView(),
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
        path: AppRoutes.taskPreferences,
        name: 'taskPreferences',
        builder: (context, state) => const TaskPreferencesView(),
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
