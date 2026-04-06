import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../features/expert_dashboard/views/expert_dashboard_shell.dart';
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
        builder: (context, state) => const ExpertDashboardShell(),
      ),
      // Placeholder for Phase C — real management center replaces this
      GoRoute(
        path: AppRoutes.expertDashboardManagement,
        name: 'expertDashboardManagement',
        builder: (context, state) => Scaffold(
          appBar: AppBar(title: const Text('Management')),
          body: const Center(
            child: Text('Coming soon'),
          ),
        ),
      ),
    ];
