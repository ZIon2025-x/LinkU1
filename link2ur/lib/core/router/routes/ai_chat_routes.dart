import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../app_routes.dart';
import '../../widgets/error_state_view.dart';
import '../../../features/ai_chat/views/ai_chat_routes.dart' deferred as ai_chat;

/// 统一聊天相关路由（仅保留统一页 + 对话列表，已移除独立 AI 页）
/// [rootNavigatorKey] 用于 support-chat：从综合/消息页快捷操作进入时推到根 navigator，避免在 Shell 内闪退
List<RouteBase> aiChatRoutes(GlobalKey<NavigatorState>? rootNavigatorKey) => [
      // 对话列表（历史入口，点某条进入统一页并加载该对话）
      GoRoute(
        path: AppRoutes.aiChatList,
        name: 'aiChatList',
        builder: (context, state) => _DeferredLoader(
          builder: () => ai_chat.AIChatListView(),
        ),
      ),
      // 统一页：新对话
      GoRoute(
        path: AppRoutes.supportChat,
        name: 'supportChat',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _DeferredLoader(
          builder: () => ai_chat.UnifiedChatView(),
        ),
      ),
      // 统一页：加载指定对话
      GoRoute(
        path: '${AppRoutes.supportChat}/:conversationId',
        name: 'supportChatConversation',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => _DeferredLoader(
          builder: () => ai_chat.UnifiedChatView(
            conversationId: state.pathParameters['conversationId'],
          ),
        ),
      ),
    ];

/// Deferred library loader with error handling and retry support.
/// Wraps FutureBuilder in a StatefulWidget so that retry can trigger a rebuild
/// by replacing the future instance.
class _DeferredLoader extends StatefulWidget {
  const _DeferredLoader({required this.builder});

  /// Called after the deferred library is loaded to build the target widget.
  final Widget Function() builder;

  @override
  State<_DeferredLoader> createState() => _DeferredLoaderState();
}

class _DeferredLoaderState extends State<_DeferredLoader> {
  late Future<void> _future;

  @override
  void initState() {
    super.initState();
    _future = ai_chat.loadLibrary();
  }

  void _retry() {
    setState(() {
      _future = ai_chat.loadLibrary();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(),
            body: ErrorStateView(
              message: snapshot.error.toString(),
              onRetry: _retry,
            ),
          );
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return widget.builder();
        }
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      },
    );
  }
}
