import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/publish/views/publish_view.dart';
import '../../../features/wallet/views/wallet_view.dart';
import '../../../features/settings/views/settings_view.dart';
import '../../../features/student_verification/views/student_verification_view.dart';
import '../../../features/forum/views/forum_post_list_view.dart';

/// 杂项路由：发布、钱包、设置、学生认证、论坛分类列表
List<RouteBase> get miscRoutes => [
      GoRoute(
        path: AppRoutes.publish,
        name: 'publish',
        pageBuilder: (context, state) => SlideUpTransitionPage(
          key: state.pageKey,
          child: const PublishView(),
        ),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        name: 'wallet',
        builder: (context, state) => const WalletView(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (context, state) => const SettingsView(),
      ),
      GoRoute(
        path: AppRoutes.studentVerification,
        name: 'studentVerification',
        builder: (context, state) => const StudentVerificationView(),
      ),
      GoRoute(
        path: AppRoutes.forumPostList,
        name: 'forumPostList',
        builder: (context, state) {
          final category = state.extra as dynamic;
          return ForumPostListView(category: category);
        },
      ),
    ];
