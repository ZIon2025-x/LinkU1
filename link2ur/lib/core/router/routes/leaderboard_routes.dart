import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/leaderboard/views/leaderboard_view.dart';
import '../../../features/leaderboard/views/leaderboard_detail_view.dart';
import '../../../features/leaderboard/views/leaderboard_item_detail_view.dart';
import '../../../features/leaderboard/views/apply_leaderboard_view.dart';
import '../../../features/leaderboard/views/submit_leaderboard_item_view.dart';

/// 排行榜相关路由
List<RouteBase> get leaderboardRoutes => [
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
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return const Scaffold(
                body: Center(child: Text('Invalid item ID')));
          }
          return LeaderboardItemDetailView(itemId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.submitLeaderboardItem,
        name: 'submitLeaderboardItem',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return SlideUpTransitionPage(
              key: state.pageKey,
              child: const Scaffold(
                  body: Center(child: Text('Invalid leaderboard ID'))),
            );
          }
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
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return platformDetailPage(
              context,
              key: state.pageKey,
              child: const Scaffold(
                  body: Center(child: Text('Invalid leaderboard ID'))),
            );
          }
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: LeaderboardDetailView(leaderboardId: id),
          );
        },
      ),
    ];
