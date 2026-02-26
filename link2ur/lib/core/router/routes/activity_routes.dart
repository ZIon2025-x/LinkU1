import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/activity/views/activity_list_view.dart';
import '../../../features/activity/views/activity_detail_view.dart';

/// 活动相关路由
List<RouteBase> get activityRoutes => [
      GoRoute(
        path: AppRoutes.activities,
        name: 'activities',
        builder: (context, state) => const ActivityListView(),
      ),
      GoRoute(
        path: AppRoutes.activityDetail,
        name: 'activityDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return platformDetailPage(
              context,
              key: state.pageKey,
              child: const Scaffold(
                  body: Center(child: Text('Invalid activity ID'))),
            );
          }
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: ActivityDetailView(activityId: id),
          );
        },
      ),
    ];
