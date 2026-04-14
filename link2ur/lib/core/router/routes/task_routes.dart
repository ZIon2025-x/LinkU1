import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../page_transitions.dart';
import '../../../features/tasks/views/tasks_view.dart';
import '../../../features/tasks/views/create_task_view.dart' show CreateTaskView, TaskDraftData;
import '../../../features/tasks/views/task_detail_view.dart';
import '../../../features/tasks/views/application_chat_view.dart';

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
        path: AppRoutes.taskDetail,
        name: 'taskDetail',
        pageBuilder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          if (id == null || id <= 0) {
            return platformDetailPage(
              context,
              key: state.pageKey,
              child: const SizedBox.shrink(),
            );
          }
          final notificationId = state.extra is int ? state.extra as int : null;
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: TaskDetailView(taskId: id, notificationId: notificationId),
          );
        },
      ),
      GoRoute(
        path: '/tasks/:taskId/applications/:applicationId/chat',
        name: 'applicationChat',
        pageBuilder: (context, state) {
          final taskId = int.tryParse(state.pathParameters['taskId'] ?? '');
          final applicationId =
              int.tryParse(state.pathParameters['applicationId'] ?? '');
          final isConsultation =
              state.uri.queryParameters['consultation'] == 'true';
          final readOnly =
              state.uri.queryParameters['readonly'] == 'true';
          final typeStr = state.uri.queryParameters['type'];
          final consultationType = switch (typeStr) {
            'task' => ConsultationType.task,
            'flea_market' => ConsultationType.fleaMarket,
            _ => ConsultationType.service,
          };
          if (taskId == null || taskId <= 0 || applicationId == null || applicationId <= 0) {
            return platformDetailPage(
              context,
              key: state.pageKey,
              child: const SizedBox.shrink(),
            );
          }
          return platformDetailPage(
            context,
            key: state.pageKey,
            child: ApplicationChatView(
              taskId: taskId,
              applicationId: applicationId,
              isConsultation: isConsultation,
              consultationType: consultationType,
              readOnly: readOnly,
            ),
          );
        },
      ),
    ];
