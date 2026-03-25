import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';
import '../models/ai_chat.dart';
import 'api_service.dart';

/// AI 聊天服务 — 处理 SSE 流式响应，含 Railway 非流式回退
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

  /// 发送消息并接收 SSE 流。
  /// 如果 SSE 流失败或 Railway 代理缓冲导致无事件到达，
  /// 自动回退到轮询历史记录获取 AI 回复。
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
    bool receivedDone = false;
    bool receivedAnyEvent = false;

    try {
      // 使用 Dio 与 createConversation 同 baseUrl、同拦截器（token/签名），后端才能收到请求
      final response = await _apiService.dio.post<ResponseBody>(
        ApiEndpoints.aiSendMessage(conversationId),
        data: {'content': content},
        options: Options(
          responseType: ResponseType.stream,
          headers: {
            'Accept': 'text/event-stream',
            'Cache-Control': 'no-cache',
            'Connection': 'keep-alive',
            // 防止代理层压缩导致缓冲（Railway/Nginx/Cloudflare）
            'Accept-Encoding': 'identity',
          },
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
        final String s = chunk is String
            ? chunk as String
            : utf8.decode(chunk as List<int>);
        buffer += s;
        buffer = buffer.replaceAll('\r\n', '\n');
        while (buffer.contains('\n\n')) {
          final idx = buffer.indexOf('\n\n');
          final eventBlock = buffer.substring(0, idx).trim();
          buffer = buffer.substring(idx + 2);
          if (eventBlock.isEmpty) continue;
          final event = _parseSSEEvent(eventBlock);
          if (event != null && !controller.isClosed) {
            receivedAnyEvent = true;
            if (event.type == AIChatEventType.done) receivedDone = true;
            controller.add(event);
          }
        }
      }
      // 处理最后一个不完整的事件块
      if (buffer.trim().isNotEmpty && !controller.isClosed) {
        final event = _parseSSEEvent(buffer.trim());
        if (event != null) {
          receivedAnyEvent = true;
          if (event.type == AIChatEventType.done) receivedDone = true;
          controller.add(event);
        }
      }
    } on DioException catch (e) {
      AppLogger.error('AI chat SSE DioException', e);
      if (!controller.isClosed) {
        final message = e.response?.statusCode == 401
            ? '登录已过期，请重新登录'
            : (e.message ?? '网络错误，请重试');
        controller.add(
            AIChatEvent(type: AIChatEventType.error, error: message));
        controller.close();
        return;
      }
    } catch (e) {
      AppLogger.error('AI chat SSE error', e);
      // 不立即返回错误 — 走下方 fallback 逻辑
    }

    // ── Railway 非流式回退 ──
    // SSE 流结束但未收到 done 事件（Railway 代理可能把整个响应缓冲后一次性返回，
    // 或者完全吞掉了流式响应）。轮询历史记录获取 AI 回复。
    if (!receivedDone && !controller.isClosed) {
      AppLogger.warning(
        'SSE stream ended without done event '
        '(receivedAny=$receivedAnyEvent). Falling back to history poll.',
      );
      await _fallbackPollHistory(conversationId, controller);
    }
  }

  /// 非流式回退：轮询对话历史获取最新 assistant 消息
  Future<void> _fallbackPollHistory(
    String conversationId,
    StreamController<AIChatEvent> controller,
  ) async {
    // 最多等 60 秒，每 2 秒查一次
    const maxAttempts = 30;
    const pollInterval = Duration(seconds: 2);

    for (var i = 0; i < maxAttempts; i++) {
      if (controller.isClosed) return;
      await Future.delayed(pollInterval);
      if (controller.isClosed) return;

      try {
        final messages = await getHistory(conversationId);
        if (messages.isEmpty) continue;

        // 找到最后一条 assistant 消息
        final lastAssistant = messages.lastWhere(
          (m) => m.isAssistant,
          orElse: () => const AIMessage(role: '', content: ''),
        );
        if (lastAssistant.content.isEmpty) continue;

        // 成功获取到 AI 回复
        // 用 contentReplace 替换（而非追加）流式内容，避免与已接收的 token 重复
        if (!controller.isClosed) {
          controller.add(AIChatEvent(
            type: AIChatEventType.contentReplace,
            content: lastAssistant.content,
          ));
        }
        // 检查是否有 tool 信息（从历史消息中提取）
        if (lastAssistant.toolCalls != null &&
            lastAssistant.toolCalls!.isNotEmpty) {
          for (final tc in lastAssistant.toolCalls!) {
            if (!controller.isClosed) {
              controller.add(AIChatEvent(
                type: AIChatEventType.toolResult,
                toolName: tc.name,
              ));
            }
          }
        }
        if (!controller.isClosed) {
          controller.add(AIChatEvent(
            type: AIChatEventType.done,
            messageId: lastAssistant.id,
          ));
        }
        return;
      } catch (e) {
        AppLogger.warning('Fallback poll attempt $i failed: $e');
      }
    }

    // 超时仍未获取到回复
    if (!controller.isClosed) {
      controller.add(const AIChatEvent(
        type: AIChatEventType.error,
        error: 'ai_chat_response_timeout',
      ));
    }
  }

  /// 解析 SSE 事件块。支持多行 data: 字段（按 SSE 规范拼接）。
  AIChatEvent? _parseSSEEvent(String block) {
    String? eventType;
    final dataLines = <String>[];

    for (final line in block.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.startsWith('event:')) {
        eventType = trimmed.substring(6).trim();
      } else if (trimmed.startsWith('data:')) {
        dataLines.add(trimmed.substring(5).trim());
      }
      // 忽略 id:, retry:, 注释(:) 等
    }

    if (eventType == null || dataLines.isEmpty) return null;
    // SSE 规范：多个 data: 行用 \n 拼接
    final data = dataLines.join('\n');

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
        case 'service_draft':
          return AIChatEvent(
            type: AIChatEventType.serviceDraft,
            serviceDraft: json,
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
