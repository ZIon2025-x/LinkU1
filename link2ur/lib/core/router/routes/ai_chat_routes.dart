import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/ai_chat/views/ai_chat_routes.dart' deferred as ai_chat;

/// 统一聊天相关路由（仅保留统一页 + 对话列表，已移除独立 AI 页）
/// [rootNavigatorKey] 用于 support-chat：从综合/消息页快捷操作进入时推到根 navigator，避免在 Shell 内闪退
List<RouteBase> aiChatRoutes(GlobalKey<NavigatorState>? rootNavigatorKey) => [
      // 对话列表（历史入口，点某条进入统一页并加载该对话）
      GoRoute(
        path: AppRoutes.aiChatList,
        name: 'aiChatList',
        builder: (context, state) => FutureBuilder(
          future: ai_chat.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return ai_chat.AIChatListView();
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
      // 统一页：新对话
      GoRoute(
        path: AppRoutes.supportChat,
        name: 'supportChat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => FutureBuilder(
          future: ai_chat.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return ai_chat.UnifiedChatView();
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
      // 统一页：加载指定对话
      GoRoute(
        path: '${AppRoutes.supportChat}/:conversationId',
        name: 'supportChatConversation',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => FutureBuilder(
          future: ai_chat.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return ai_chat.UnifiedChatView(
                conversationId: state.pathParameters['conversationId'],
              );
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
    ];
