import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/message/views/message_view.dart';
import '../../../features/chat/views/chat_view.dart';
import '../../../features/chat/views/task_chat_view.dart';
import '../../../features/notification/views/notification_center_view.dart';
import '../../../features/notification/views/notification_list_view.dart';
import '../../../features/notification/views/task_chat_list_view.dart';

/// 消息与通知相关路由
List<RouteBase> get messageRoutes => [
      GoRoute(
        path: AppRoutes.messages,
        name: 'messages',
        builder: (context, state) => const MessageView(),
      ),
      GoRoute(
        path: AppRoutes.chat,
        name: 'chat',
        builder: (context, state) {
          final userId = state.pathParameters['userId'] ?? '';
          return ChatView(userId: userId);
        },
      ),
      GoRoute(
        path: AppRoutes.taskChat,
        name: 'taskChat',
        builder: (context, state) {
          final taskId = int.tryParse(state.pathParameters['taskId'] ?? '');
          if (taskId == null || taskId <= 0) {
            return const Scaffold(
                body: Center(child: Text('Invalid task ID')));
          }
          return TaskChatView(taskId: taskId);
        },
      ),
      GoRoute(
        path: AppRoutes.taskChatList,
        name: 'taskChatList',
        builder: (context, state) => const TaskChatListView(),
      ),
      GoRoute(
        path: AppRoutes.notifications,
        name: 'notifications',
        builder: (context, state) => const NotificationCenterView(),
      ),
      GoRoute(
        path: AppRoutes.notificationList,
        name: 'notificationList',
        builder: (context, state) {
          final type = state.pathParameters['type'];
          return NotificationListView(type: type);
        },
      ),
    ];
