import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/ai_chat.dart';
import '../../../data/services/ai_chat_service.dart';

// ==================== Events ====================

abstract class AIChatEvent extends Equatable {
  const AIChatEvent();

  @override
  List<Object?> get props => [];
}

/// 加载对话列表
class AIChatLoadConversations extends AIChatEvent {
  const AIChatLoadConversations();
}

/// 创建新对话
class AIChatCreateConversation extends AIChatEvent {
  const AIChatCreateConversation();
}

/// 加载对话历史消息
class AIChatLoadHistory extends AIChatEvent {
  const AIChatLoadHistory(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

/// 发送消息
class AIChatSendMessage extends AIChatEvent {
  const AIChatSendMessage(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}

/// SSE token 到达
class _AIChatTokenReceived extends AIChatEvent {
  const _AIChatTokenReceived(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}

/// 工具调用事件
class _AIChatToolCall extends AIChatEvent {
  const _AIChatToolCall(this.toolName, this.toolInput);

  final String toolName;
  final Map<String, dynamic>? toolInput;

  @override
  List<Object?> get props => [toolName];
}

/// 工具结果事件
class _AIChatToolResult extends AIChatEvent {
  const _AIChatToolResult(this.toolName, this.toolResult);

  final String toolName;
  final Map<String, dynamic>? toolResult;

  @override
  List<Object?> get props => [toolName];
}

/// 消息完成
class _AIChatMessageCompleted extends AIChatEvent {
  const _AIChatMessageCompleted(this.messageId);

  final int? messageId;

  @override
  List<Object?> get props => [messageId];
}

/// 错误事件
class _AIChatError extends AIChatEvent {
  const _AIChatError(this.error);

  final String error;

  @override
  List<Object?> get props => [error];
}

/// 客服可用性信号（内部事件）
class _AIChatCSAvailable extends AIChatEvent {
  const _AIChatCSAvailable(this.available, this.contactEmail);

  final bool available;
  final String? contactEmail;

  @override
  List<Object?> get props => [available, contactEmail];
}

/// 任务草稿事件（内部事件）
class _AIChatTaskDraft extends AIChatEvent {
  const _AIChatTaskDraft(this.draft);

  final Map<String, dynamic> draft;

  @override
  List<Object?> get props => [draft];
}

/// 清除任务草稿（用户点击后清除）
class AIChatClearTaskDraft extends AIChatEvent {
  const AIChatClearTaskDraft();
}

/// 归档对话
class AIChatArchiveConversation extends AIChatEvent {
  const AIChatArchiveConversation(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

// ==================== State ====================

enum AIChatStatus { initial, loading, loaded, error }

class AIChatState extends Equatable {
  const AIChatState({
    this.status = AIChatStatus.initial,
    this.conversations = const [],
    this.currentConversationId,
    this.messages = const [],
    this.isReplying = false,
    this.streamingContent = '',
    this.activeToolCall,
    this.errorMessage,
    this.csAvailableSignal,
    this.csContactEmail,
    this.taskDraft,
    this.lastToolName,
  });

  final AIChatStatus status;
  final List<AIConversation> conversations;
  final String? currentConversationId;
  final List<AIMessage> messages;
  final bool isReplying;
  final String streamingContent;
  final String? activeToolCall;
  final String? errorMessage;
  final bool? csAvailableSignal;
  final String? csContactEmail;
  final Map<String, dynamic>? taskDraft;
  final String? lastToolName;

  AIChatState copyWith({
    AIChatStatus? status,
    List<AIConversation>? conversations,
    String? currentConversationId,
    List<AIMessage>? messages,
    bool? isReplying,
    String? streamingContent,
    String? activeToolCall,
    String? errorMessage,
    bool? csAvailableSignal,
    String? csContactEmail,
    Map<String, dynamic>? taskDraft,
    String? lastToolName,
  }) {
    return AIChatState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      currentConversationId:
          currentConversationId ?? this.currentConversationId,
      messages: messages ?? this.messages,
      isReplying: isReplying ?? this.isReplying,
      streamingContent: streamingContent ?? this.streamingContent,
      activeToolCall: activeToolCall,
      errorMessage: errorMessage,
      csAvailableSignal: csAvailableSignal,
      csContactEmail: csContactEmail,
      taskDraft: taskDraft,
      lastToolName: lastToolName,
    );
  }

  @override
  List<Object?> get props => [
        status,
        conversations,
        currentConversationId,
        messages,
        isReplying,
        streamingContent,
        activeToolCall,
        errorMessage,
        taskDraft,
        lastToolName,
      ];
}

// ==================== BLoC ====================

class AIChatBloc extends Bloc<AIChatEvent, AIChatState> {
  AIChatBloc({required AIChatService aiChatService})
      : _aiChatService = aiChatService,
        super(const AIChatState()) {
    on<AIChatLoadConversations>(_onLoadConversations);
    on<AIChatCreateConversation>(_onCreateConversation);
    on<AIChatLoadHistory>(_onLoadHistory);
    on<AIChatSendMessage>(_onSendMessage);
    on<_AIChatTokenReceived>(_onTokenReceived);
    on<_AIChatToolCall>(_onToolCall);
    on<_AIChatToolResult>(_onToolResult);
    on<_AIChatMessageCompleted>(_onMessageCompleted);
    on<_AIChatError>(_onError);
    on<_AIChatCSAvailable>(_onCSAvailable);
    on<_AIChatTaskDraft>(_onTaskDraft);
    on<AIChatClearTaskDraft>(_onClearTaskDraft);
    on<AIChatArchiveConversation>(_onArchiveConversation);
  }

  final AIChatService _aiChatService;
  StreamSubscription<AIChatEvent>? _sseSubscription;

  @override
  Future<void> close() {
    _sseSubscription?.cancel();
    return super.close();
  }

  Future<void> _onLoadConversations(
    AIChatLoadConversations event,
    Emitter<AIChatState> emit,
  ) async {
    emit(state.copyWith(status: AIChatStatus.loading));
    try {
      final conversations = await _aiChatService.getConversations();
      emit(state.copyWith(
        status: AIChatStatus.loaded,
        conversations: conversations,
      ));
    } catch (e) {
      AppLogger.error('Failed to load AI conversations', e);
      emit(state.copyWith(
        status: AIChatStatus.error,
        errorMessage: '加载对话列表失败',
      ));
    }
  }

  Future<void> _onCreateConversation(
    AIChatCreateConversation event,
    Emitter<AIChatState> emit,
  ) async {
    try {
      final conv = await _aiChatService.createConversation();
      if (conv != null) {
        emit(state.copyWith(
          currentConversationId: conv.id,
          messages: [],
          conversations: [conv, ...state.conversations],
          streamingContent: '',
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to create AI conversation', e);
      emit(state.copyWith(errorMessage: '创建对话失败'));
    }
  }

  Future<void> _onLoadHistory(
    AIChatLoadHistory event,
    Emitter<AIChatState> emit,
  ) async {
    emit(state.copyWith(
      status: AIChatStatus.loading,
      currentConversationId: event.conversationId,
    ));
    try {
      final messages = await _aiChatService.getHistory(event.conversationId);
      emit(state.copyWith(
        status: AIChatStatus.loaded,
        messages: messages,
        streamingContent: '',
      ));
    } catch (e) {
      AppLogger.error('Failed to load AI history', e);
      emit(state.copyWith(
        status: AIChatStatus.error,
        errorMessage: '加载消息历史失败',
      ));
    }
  }

  Future<void> _onSendMessage(
    AIChatSendMessage event,
    Emitter<AIChatState> emit,
  ) async {
    final conversationId = state.currentConversationId;
    if (conversationId == null) return;

    // 添加用户消息到列表
    final userMessage = AIMessage(
      role: 'user',
      content: event.content,
      createdAt: DateTime.now(),
    );
    emit(state.copyWith(
      messages: [...state.messages, userMessage],
      isReplying: true,
      streamingContent: '',
      lastToolName: null,
    ));

    // 取消之前的 SSE 订阅
    await _sseSubscription?.cancel();

    // 开始 SSE 流
    _sseSubscription = _aiChatService
        .sendMessage(conversationId, event.content)
        .map<AIChatEvent>((sseEvent) {
      switch (sseEvent.type) {
        case AIChatEventType.token:
          return _AIChatTokenReceived(sseEvent.content ?? '');
        case AIChatEventType.toolCall:
          return _AIChatToolCall(
              sseEvent.toolName ?? '', sseEvent.toolInput);
        case AIChatEventType.toolResult:
          return _AIChatToolResult(
              sseEvent.toolName ?? '', sseEvent.toolResult);
        case AIChatEventType.done:
          return _AIChatMessageCompleted(sseEvent.messageId);
        case AIChatEventType.error:
          return _AIChatError(sseEvent.error ?? '未知错误');
        case AIChatEventType.csAvailable:
          return _AIChatCSAvailable(
              sseEvent.csAvailable ?? false, sseEvent.contactEmail);
        case AIChatEventType.taskDraft:
          return _AIChatTaskDraft(sseEvent.taskDraft ?? {});
      }
    }).listen(
      (event) => add(event),
      onError: (e) => add(_AIChatError(e.toString())),
    );
  }

  void _onTokenReceived(
    _AIChatTokenReceived event,
    Emitter<AIChatState> emit,
  ) {
    emit(state.copyWith(
      streamingContent: state.streamingContent + event.content,
    ));
  }

  void _onToolCall(
    _AIChatToolCall event,
    Emitter<AIChatState> emit,
  ) {
    emit(state.copyWith(activeToolCall: event.toolName));
  }

  void _onToolResult(
    _AIChatToolResult event,
    Emitter<AIChatState> emit,
  ) {
    // 工具结果到达，清除 activeToolCall（LLM 会继续生成），记录 lastToolName
    emit(state.copyWith(lastToolName: event.toolName));
  }

  void _onMessageCompleted(
    _AIChatMessageCompleted event,
    Emitter<AIChatState> emit,
  ) {
    // 将流式内容转化为完整消息
    if (state.streamingContent.isNotEmpty) {
      final assistantMessage = AIMessage(
        id: event.messageId,
        role: 'assistant',
        content: state.streamingContent,
        createdAt: DateTime.now(),
        toolName: state.lastToolName,
      );
      emit(state.copyWith(
        messages: [...state.messages, assistantMessage],
        isReplying: false,
        streamingContent: '',
        lastToolName: null,
      ));
    } else {
      emit(state.copyWith(isReplying: false, lastToolName: null));
    }
  }

  void _onCSAvailable(
    _AIChatCSAvailable event,
    Emitter<AIChatState> emit,
  ) {
    emit(state.copyWith(
      csAvailableSignal: event.available,
      csContactEmail: event.contactEmail,
    ));
  }

  void _onTaskDraft(
    _AIChatTaskDraft event,
    Emitter<AIChatState> emit,
  ) {
    emit(state.copyWith(taskDraft: event.draft));
  }

  void _onClearTaskDraft(
    AIChatClearTaskDraft event,
    Emitter<AIChatState> emit,
  ) {
    emit(state.copyWith());
  }

  void _onError(
    _AIChatError event,
    Emitter<AIChatState> emit,
  ) {
    // 如果有部分内容，保留它
    if (state.streamingContent.isNotEmpty) {
      final assistantMessage = AIMessage(
        role: 'assistant',
        content: state.streamingContent,
        createdAt: DateTime.now(),
      );
      emit(state.copyWith(
        messages: [...state.messages, assistantMessage],
        isReplying: false,
        streamingContent: '',
        errorMessage: event.error,
      ));
    } else {
      emit(state.copyWith(
        isReplying: false,
        errorMessage: event.error,
      ));
    }
  }

  Future<void> _onArchiveConversation(
    AIChatArchiveConversation event,
    Emitter<AIChatState> emit,
  ) async {
    try {
      await _aiChatService.archiveConversation(event.conversationId);
      final updated = state.conversations
          .where((c) => c.id != event.conversationId)
          .toList();
      emit(state.copyWith(
        conversations: updated,
        currentConversationId:
            state.currentConversationId == event.conversationId
                ? null
                : state.currentConversationId,
        messages: state.currentConversationId == event.conversationId
            ? []
            : state.messages,
      ));
    } catch (e) {
      AppLogger.error('Failed to archive conversation', e);
    }
  }
}
