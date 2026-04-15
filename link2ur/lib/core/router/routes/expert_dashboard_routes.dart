import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../data/repositories/package_purchase_repository.dart';
import '../../../features/expert_dashboard/views/expert_dashboard_shell.dart';
import '../../../features/expert_dashboard/views/management/coupons_view.dart';
import '../../../features/expert_dashboard/views/management/customer_packages_view.dart';
import '../../../features/expert_dashboard/views/management/edit_forum_board_view.dart';
import '../../../features/expert_dashboard/views/management/edit_team_profile_view.dart';
import '../../../features/expert_dashboard/views/management/join_requests_view.dart';
import '../../../features/expert_dashboard/views/management/management_center_view.dart';
import '../../../features/expert_dashboard/views/management/members_view.dart';
import '../../../features/expert_dashboard/views/management/package_redemption_scan_view.dart';
import '../../../features/expert_dashboard/views/management/packages_view.dart';
import '../../../features/expert_dashboard/views/management/review_replies_view.dart';
import '../app_routes.dart';

List<RouteBase> get expertDashboardRoutes => [
      // 入口：无 expertId，shell 解析并选择默认团队
      GoRoute(
        path: AppRoutes.expertDashboard,
        name: 'expertDashboard',
        builder: (context, state) => const ExpertDashboardShell(),
      ),
      // 显式 expertId 版本
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
        path: AppRoutes.expertDashboardManagementMembers,
        name: 'expertDashboardManagementMembers',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return MembersView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementJoinRequests,
        name: 'expertDashboardManagementJoinRequests',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return JoinRequestsView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementEditProfile,
        name: 'expertDashboardManagementEditProfile',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return EditTeamProfileView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementEditForumBoard,
        name: 'expertDashboardManagementEditForumBoard',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return EditForumBoardView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementCoupons,
        name: 'expertDashboardManagementCoupons',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return CouponsView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementReviewReplies,
        name: 'expertDashboardManagementReviewReplies',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return ReviewRepliesView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementPackages,
        name: 'expertDashboardManagementPackages',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          return PackagesView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementCustomerPackages,
        name: 'expertDashboardManagementCustomerPackages',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          final repo = context.read<PackagePurchaseRepository>();
          return CustomerPackagesView(expertId: id, repository: repo);
        },
      ),
      GoRoute(
        path: AppRoutes.expertDashboardManagementPackageRedeem,
        name: 'expertDashboardManagementPackageRedeem',
        builder: (context, state) {
          final id = state.pathParameters['expertId']!;
          final repo = context.read<PackagePurchaseRepository>();
          return PackageRedemptionScanView(
            expertId: id,
            repository: repo,
          );
        },
      ),
    ];
