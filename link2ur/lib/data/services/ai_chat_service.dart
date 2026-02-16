import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';
import '../models/ai_chat.dart';
import 'api_service.dart';

/// AI 聊天服务 — 处理 SSE 流式响应
class AIChatService {
  AIChatService({required ApiService apiService}) : _apiService = apiService;

  final ApiService _apiService;

  /// 创建新对话
  Future<AIConversation?> createConversation() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.aiConversations,
    );
    if (response.isSuccess && response.data != null) {
      return AIConversation.fromJson(response.data!);
    }
    return null;
  }

  /// 获取对话列表
  Future<List<AIConversation>> getConversations({int page = 1}) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.aiConversations,
      queryParameters: {'page': page},
    );
    if (response.isSuccess && response.data != null) {
      final list = response.data!['conversations'] as List? ?? [];
      return list
          .map((e) => AIConversation.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 获取对话消息历史
  Future<List<AIMessage>> getHistory(String conversationId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.aiConversationDetail(conversationId),
    );
    if (response.isSuccess && response.data != null) {
      final list = response.data!['messages'] as List? ?? [];
      return list
          .map((e) => AIMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// 归档对话
  Future<bool> archiveConversation(String conversationId) async {
    final response = await _apiService.delete<dynamic>(
      ApiEndpoints.aiConversationDetail(conversationId),
    );
    return response.isSuccess;
  }

  /// 发送消息并接收 SSE 流
  Stream<AIChatEvent> sendMessage(String conversationId, String content) {
    final controller = StreamController<AIChatEvent>();

    _sendMessageStream(conversationId, content, controller).then((_) {
      if (!controller.isClosed) controller.close();
    }).catchError((e) {
      if (!controller.isClosed) {
        controller.add(AIChatEvent(
          type: AIChatEventType.error,
          error: e.toString(),
        ));
        controller.close();
      }
    });

    return controller.stream;
  }

  Future<void> _sendMessageStream(
    String conversationId,
    String content,
    StreamController<AIChatEvent> controller,
  ) async {
    try {
      // 使用 Dio 直接发起流式请求
      final dio = _apiService.dio;
      final response = await dio.post(
        ApiEndpoints.aiSendMessage(conversationId),
        data: {'content': content},
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
        ),
      );

      final stream = response.data.stream as Stream<List<int>>;
      String buffer = '';

      await for (final chunk in stream) {
        buffer += utf8.decode(chunk);
        // 按双换行分割 SSE 事件
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, idx);
          buffer = buffer.substring(idx + 2);

          final event = _parseSSEEvent(eventBlock);
          if (event != null && !controller.isClosed) {
            controller.add(event);
          }
        }
      }
    } on DioException catch (e) {
      AppLogger.error('AI chat SSE error', e);
      if (!controller.isClosed) {
        final message = e.response?.statusCode == 429
            ? '请求过于频繁，请稍后再试'
            : e.response?.statusCode == 503
                ? 'AI 服务暂不可用'
                : '网络错误，请重试';
        controller.add(AIChatEvent(
          type: AIChatEventType.error,
          error: message,
        ));
      }
    }
  }

  AIChatEvent? _parseSSEEvent(String block) {
    String? eventType;
    String? data;

    for (final line in block.split('\n')) {
      if (line.startsWith('event: ')) {
        eventType = line.substring(7).trim();
      } else if (line.startsWith('data: ')) {
        data = line.substring(6);
      }
    }

    if (eventType == null || data == null) return null;

    try {
      final json = jsonDecode(data) as Map<String, dynamic>;

      switch (eventType) {
        case 'token':
          return AIChatEvent(
            type: AIChatEventType.token,
            content: json['content'] as String? ?? '',
          );
        case 'tool_call':
          return AIChatEvent(
            type: AIChatEventType.toolCall,
            toolName: json['tool'] as String?,
            toolInput: json['input'] as Map<String, dynamic>?,
          );
        case 'tool_result':
          return AIChatEvent(
            type: AIChatEventType.toolResult,
            toolName: json['tool'] as String?,
            toolResult: json['result'] as Map<String, dynamic>?,
          );
        case 'done':
          return AIChatEvent(
            type: AIChatEventType.done,
            messageId: json['message_id'] as int?,
            inputTokens: json['input_tokens'] as int?,
            outputTokens: json['output_tokens'] as int?,
          );
        default:
          return null;
      }
    } catch (e) {
      AppLogger.warning('Failed to parse SSE event: $e');
      return null;
    }
  }
}
