import 'package:go_router/go_router.dart';

import '../../../features/expert_dashboard/views/expert_dashboard_shell.dart';
import '../../../features/expert_dashboard/views/management/coupons_view.dart';
import '../../../features/expert_dashboard/views/management/edit_team_profile_view.dart';
import '../../../features/expert_dashboard/views/management/join_requests_view.dart';
import '../../../features/expert_dashboard/views/management/management_center_view.dart';
import '../../../features/expert_dashboard/views/management/members_view.dart';
import '../../../features/expert_dashboard/views/management/review_replies_view.dart';
import '../app_routes.dart';

List<RouteBase> get expertDashboardRoutes => [
      // 入口：无 expertId，shell 解析并选择默认团队
      GoRoute(
        path: AppRoutes.expertDashboard,
        name: 'expertDashboard',
        builder: (context, state) => const ExpertDashboardShell(),
      ),
      // 显式 expertId 版本（Phase B 之后启用，暂时也指向 shell）
      GoRoute(
        path: AppRoutes.expertDashboardWithId,
        name: 'expertDashboardWithId',
        builder: (context, state) {
          final expertId = state.pathParameters['expertId'];
          return ExpertDashboardShell(initialExpertId: expertId);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagement,
        name: 'expertDashboardManagement',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return ManagementCenterView(expertId: id);
        },
      ),
      GoRoute(
        path: '/expert-dashboard/:expertId/management/members',
        name: 'expertDashboardManagementMembers',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return MembersView(expertId: id);
        },
      ),
      GoRoute(
        path: '/expert-dashboard/:expertId/management/join-requests',
        name: 'expertDashboardManagementJoinRequests',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return JoinRequestsView(expertId: id);
        },
      ),
      GoRoute(
        path: '/expert-dashboard/:expertId/management/edit-profile',
        name: 'expertDashboardManagementEditProfile',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return EditTeamProfileView(expertId: id);
        },
      ),
      GoRoute(
        path: '/expert-dashboard/:expertId/management/coupons',
        name: 'expertDashboardManagementCoupons',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return CouponsView(expertId: id);
        },
      ),
      GoRoute(
        path: '/expert-dashboard/:expertId/management/review-replies',
        name: 'expertDashboardManagementReviewReplies',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return ReviewRepliesView(expertId: id);
        },
      ),
    ];
