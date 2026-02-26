import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/tasks/views/tasks_view.dart';
import '../../../features/tasks/views/create_task_view.dart' show CreateTaskView, TaskDraftData;
import '../../../features/tasks/views/task_filter_view.dart';
import '../../../features/tasks/views/task_detail_view.dart';

/// 任务相关路由（列表、创建、筛选、详情）
List<RouteBase> get taskRoutes => [
      GoRoute(
        path: AppRoutes.tasks,
        name: 'tasks',
        builder: (context, state) => const TasksView(),
      ),
      GoRoute(
        path: AppRoutes.createTask,
        name: 'createTask',
        pageBuilder: (context, state) {
          final draft = state.extra is TaskDraftData
              ? state.extra as TaskDraftData
              : null;
          return SlideUpTransitionPage(
            key: state.pageKey,
            child: CreateTaskView(draft: draft),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.taskFilter,
        name: 'taskFilter',
        builder: (context, state) => const TaskFilterView(),
      ),
      GoRoute(
        path: AppRoutes.taskDetail,
        name: 'taskDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return platformDetailPage(
              context,
              key: state.pageKey,
              child: const Scaffold(
                  body: Center(child: Text('Invalid task ID'))),
            );
          }
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: TaskDetailView(taskId: id),
          );
        },
      ),
    ];
