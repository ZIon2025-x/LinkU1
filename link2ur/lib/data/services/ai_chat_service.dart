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
      // 使用 Dio 与 createConversation 同 baseUrl、同拦截器（token/签名），后端才能收到请求
      final response = await _apiService.dio.post<ResponseBody>(
        ApiEndpoints.aiSendMessage(conversationId),
        data: {'content': content},
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Accept': 'text/event-stream'},
          receiveTimeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode == 401) {
        controller.add(const AIChatEvent(
          type: AIChatEventType.error,
          error: '登录已过期，请重新登录',
        ));
        return;
      }
      if (response.statusCode == 429) {
        controller.add(const AIChatEvent(
          type: AIChatEventType.error,
          error: '请求过于频繁，请稍后再试',
        ));
        return;
      }
      if (response.statusCode == 503) {
        controller.add(const AIChatEvent(
          type: AIChatEventType.error,
          error: 'AI 服务暂不可用',
        ));
        return;
      }
      if (response.statusCode != 200 || response.data == null) {
        controller.add(const AIChatEvent(
          type: AIChatEventType.error,
          error: '网络错误，请重试',
        ));
        return;
      }

      final stream = response.data!.stream;
      String buffer = '';
      await for (final chunk in stream) {
        if (controller.isClosed) return;
        final String s = chunk is String ? chunk as String : utf8.decode(chunk as List<int>);
        buffer += s;
        buffer = buffer.replaceAll('\r\n', '\n');
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 2);
          if (eventBlock.isEmpty) continue;
          final event = _parseSSEEvent(eventBlock);
          if (event != null && !controller.isClosed) {
            controller.add(event);
          }
        }
      }
      if (buffer.trim().isNotEmpty && !controller.isClosed) {
        final event = _parseSSEEvent(buffer.trim());
        if (event != null) controller.add(event);
      }
    } on DioException catch (e) {
      AppLogger.error('AI chat SSE DioException', e);
      if (!controller.isClosed) {
        final message = e.response?.statusCode == 401
            ? '登录已过期，请重新登录'
            : (e.message ?? '网络错误，请重试');
        controller.add(AIChatEvent(type: AIChatEventType.error, error: message));
        controller.close();
      }
    } catch (e) {
      AppLogger.error('AI chat SSE error', e);
      if (!controller.isClosed) {
        controller.add(const AIChatEvent(
          type: AIChatEventType.error,
          error: '网络错误，请重试',
        ));
        controller.close();
      }
    }
  }

  AIChatEvent? _parseSSEEvent(String block) {
    String? eventType;
    String? data;

    for (final line in block.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('event: ')) {
        eventType = trimmed.substring(7).trim();
      } else if (trimmed.startsWith('data: ')) {
        data = trimmed.substring(6).trim();
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
        case 'cs_available':
          return AIChatEvent(
            type: AIChatEventType.csAvailable,
            csAvailable: json['available'] as bool? ?? false,
            contactEmail: json['contact_email'] as String?,
          );
        case 'task_draft':
          return AIChatEvent(
            type: AIChatEventType.taskDraft,
            taskDraft: json,
          );
        case 'error':
          return AIChatEvent(
            type: AIChatEventType.error,
            error: json['error'] as String? ?? 'Unknown error',
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
