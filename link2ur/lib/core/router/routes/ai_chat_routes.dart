import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../../features/ai_chat/views/ai_chat_routes.dart' deferred as ai_chat;

/// AI 助手相关路由（deferred 加载）
List<RouteBase> get aiChatRoutes => [
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
      GoRoute(
        path: AppRoutes.aiChat,
        name: 'aiChat',
        builder: (context, state) => FutureBuilder(
          future: ai_chat.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return ai_chat.AIChatView();
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
      GoRoute(
        path: '${AppRoutes.aiChat}/:conversationId',
        name: 'aiChatConversation',
        builder: (context, state) => FutureBuilder(
          future: ai_chat.loadLibrary(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return ai_chat.AIChatView(
                conversationId: state.pathParameters['conversationId'],
              );
            }
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          },
        ),
      ),
      GoRoute(
        path: AppRoutes.supportChat,
        name: 'supportChat',
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
    ];
