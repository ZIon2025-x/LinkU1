import 'package:equatable/equatable.dart';

/// AI 对话会话
class AIConversation extends Equatable {
  const AIConversation({
    required this.id,
    this.title = '',
    this.modelUsed = '',
    this.totalTokens = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String modelUsed;
  final int totalTokens;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory AIConversation.fromJson(Map<String, dynamic> json) {
    return AIConversation(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      modelUsed: json['model_used'] as String? ?? '',
      totalTokens: json['total_tokens'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, title, totalTokens, updatedAt];
}

/// AI 对话消息
class AIMessage extends Equatable {
  const AIMessage({
    this.id,
    required this.role,
    required this.content,
    this.toolCalls,
    this.toolResults,
    this.createdAt,
    this.isStreaming = false,
  });

  final int? id;
  final String role; // user, assistant
  final String content;
  final List<AIToolCall>? toolCalls;
  final List<AIToolResult>? toolResults;
  final DateTime? createdAt;
  final bool isStreaming; // 正在流式接收中

  bool get isUser => role == 'user';
  bool get isAssistant => role == 'assistant';
  bool get hasToolCalls => toolCalls != null && toolCalls!.isNotEmpty;

  AIMessage copyWith({
    int? id,
    String? role,
    String? content,
    List<AIToolCall>? toolCalls,
    List<AIToolResult>? toolResults,
    DateTime? createdAt,
    bool? isStreaming,
  }) {
    return AIMessage(
      id: id ?? this.id,
      role: role ?? this.role,
      content: content ?? this.content,
      toolCalls: toolCalls ?? this.toolCalls,
      toolResults: toolResults ?? this.toolResults,
      createdAt: createdAt ?? this.createdAt,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  factory AIMessage.fromJson(Map<String, dynamic> json) {
    return AIMessage(
      id: json['id'] as int?,
      role: json['role'] as String? ?? 'assistant',
      content: json['content'] as String? ?? '',
      toolCalls: json['tool_calls'] != null
          ? (json['tool_calls'] as List)
              .map((e) => AIToolCall.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      toolResults: json['tool_results'] != null
          ? (json['tool_results'] as List)
              .map((e) => AIToolResult.fromJson(e as Map<String, dynamic>))
              .toList()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, role, content, isStreaming];
}

/// AI 工具调用
class AIToolCall extends Equatable {
  const AIToolCall({
    required this.id,
    required this.name,
    required this.input,
  });

  final String id;
  final String name;
  final Map<String, dynamic> input;

  factory AIToolCall.fromJson(Map<String, dynamic> json) {
    return AIToolCall(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      input: json['input'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  List<Object?> get props => [id, name];
}

/// AI 工具执行结果
class AIToolResult extends Equatable {
  const AIToolResult({
    required this.toolUseId,
    required this.result,
  });

  final String toolUseId;
  final Map<String, dynamic> result;

  factory AIToolResult.fromJson(Map<String, dynamic> json) {
    return AIToolResult(
      toolUseId: json['tool_use_id']?.toString() ?? '',
      result: json['result'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  List<Object?> get props => [toolUseId];
}

/// SSE 事件类型
enum AIChatEventType { token, toolCall, toolResult, done, error }

/// SSE 事件
class AIChatEvent {
  const AIChatEvent({
    required this.type,
    this.content,
    this.toolName,
    this.toolInput,
    this.toolResult,
    this.messageId,
    this.inputTokens,
    this.outputTokens,
    this.error,
  });

  final AIChatEventType type;
  final String? content;
  final String? toolName;
  final Map<String, dynamic>? toolInput;
  final Map<String, dynamic>? toolResult;
  final int? messageId;
  final int? inputTokens;
  final int? outputTokens;
  final String? error;
}
