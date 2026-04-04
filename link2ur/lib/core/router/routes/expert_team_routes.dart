import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/expert_team/views/my_teams_view.dart';
import '../../../features/expert_team/views/create_team_view.dart';
import '../../../features/expert_team/views/expert_team_detail_view.dart';
import '../../../features/expert_team/views/expert_team_members_view.dart';
import '../../../features/expert_team/views/join_requests_view.dart';
import '../../../features/expert_team/views/my_invitations_view.dart';

/// 达人团队管理相关路由
List<RouteBase> get expertTeamRoutes => [
      GoRoute(
        path: AppRoutes.expertTeamMyTeams,
        name: 'expertTeamMyTeams',
        builder: (context, state) => const MyTeamsView(),
      ),
      GoRoute(
        path: AppRoutes.expertTeamCreate,
        name: 'expertTeamCreate',
        builder: (context, state) => const CreateTeamView(),
      ),
      GoRoute(
        path: AppRoutes.expertTeamInvitations,
        name: 'expertTeamInvitations',
        builder: (context, state) => const MyInvitationsView(),
      ),
      GoRoute(
        path: AppRoutes.expertTeamDetail,
        name: 'expertTeamDetail',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExpertTeamDetailView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertTeamMembers,
        name: 'expertTeamMembers',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ExpertTeamMembersView(expertId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.expertTeamJoinRequests,
        name: 'expertTeamJoinRequests',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return JoinRequestsView(expertId: id);
        },
      ),
    ];
