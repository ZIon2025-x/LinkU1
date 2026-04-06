import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/expert_team/views/my_teams_view.dart';
import '../../../features/expert_team/views/create_team_view.dart';
import '../../../features/expert_team/views/expert_team_detail_view.dart';
import '../../../features/expert_team/views/my_invitations_view.dart';
import '../../../features/expert_team/views/expert_packages_view.dart';
import '../../../features/expert_team/views/group_buy_view.dart';

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
        path: AppRoutes.expertTeamPackages,
        name: 'expertTeamPackages',
        builder: (context, state) => const ExpertPackagesView(),
      ),
      GoRoute(
        path: AppRoutes.groupBuy,
        name: 'groupBuy',
        builder: (context, state) {
          final activityId = int.parse(state.pathParameters['activityId']!);
          return GroupBuyView(activityId: activityId);
        },
      ),
    ];
