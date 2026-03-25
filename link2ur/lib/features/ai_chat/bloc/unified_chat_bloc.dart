import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ai_chat.dart';
import '../../../data/models/customer_service.dart';
import '../../../data/repositories/common_repository.dart';
import '../../../data/services/ai_chat_service.dart';
import '../../customer_service/bloc/customer_service_bloc.dart';
import 'ai_chat_bloc.dart';

/// Private sentinel for copyWith — distinguishes "not provided" from "explicitly null".
const _sentinel = Object();

// ==================== Chat Mode ====================

enum ChatMode { ai, transferring, csConnected, csEnded }

// ==================== Events ====================

abstract class UnifiedChatEvent extends Equatable {
  const UnifiedChatEvent();

  @override
  List<Object?> get props => [];
}

/// 页面初始化，创建 AI 对话
class UnifiedChatInit extends UnifiedChatEvent {
  const UnifiedChatInit();
}

/// 发送消息（根据 mode 路由到 AI 或 CS）
class UnifiedChatSendMessage extends UnifiedChatEvent {
  const UnifiedChatSendMessage(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}

/// 用户点击"连接人工"按钮
class UnifiedChatRequestHumanCS extends UnifiedChatEvent {
  const UnifiedChatRequestHumanCS();
}

/// 结束人工对话
class UnifiedChatCSEndChat extends UnifiedChatEvent {
  const UnifiedChatCSEndChat();
}

/// 评价客服
class UnifiedChatCSRateChat extends UnifiedChatEvent {
  const UnifiedChatCSRateChat({required this.rating, this.comment});

  final int rating;
  final String? comment;

  @override
  List<Object?> get props => [rating, comment];
}

/// 客服结束后返回 AI 模式
class UnifiedChatReturnToAI extends UnifiedChatEvent {
  const UnifiedChatReturnToAI();
}

/// 加载指定对话历史（从历史记录入口进入）
class UnifiedChatLoadHistory extends UnifiedChatEvent {
  const UnifiedChatLoadHistory(this.conversationId);

  final String conversationId;

  @override
  List<Object?> get props => [conversationId];
}

/// 清除任务草稿（用户确认后跳发布页）
class UnifiedChatClearTaskDraft extends UnifiedChatEvent {
  const UnifiedChatClearTaskDraft();
}

/// 清除服务草稿（用户确认后跳发布页）
class UnifiedChatClearServiceDraft extends UnifiedChatEvent {
  const UnifiedChatClearServiceDraft();
}

/// 加载客服聊天历史（从历史记录入口进入）
class UnifiedChatLoadCSHistory extends UnifiedChatEvent {
  const UnifiedChatLoadCSHistory({
    required this.chatId,
    required this.isEnded,
  });

  final String chatId;
  final bool isEnded;

  @override
  List<Object?> get props => [chatId, isEnded];
}

/// 内部：AI 子 BLoC 状态变化
class _AIStateChanged extends UnifiedChatEvent {
  const _AIStateChanged(this.state);

  final AIChatState state;

  @override
  List<Object?> get props => [state];
}

/// 内部：CS 子 BLoC 状态变化
class _CSStateChanged extends UnifiedChatEvent {
  const _CSStateChanged(this.state);

  final CustomerServiceState state;

  @override
  List<Object?> get props => [state];
}

// ==================== State ====================

class UnifiedChatState extends Equatable {
  const UnifiedChatState({
    this.mode = ChatMode.ai,
    this.aiMessages = const [],
    this.csMessages = const [],
    this.isTyping = false,
    this.streamingContent = '',
    this.activeToolCall,
    this.toolCallCompleted = false,
    this.taskDraft,
    this.serviceDraft,
    this.csOnlineStatus,
    this.csContactEmail,
    this.csServiceName,
    this.csChatId,
    this.errorMessage,
    this.actionMessage,
    this.isRating = false,
  });

  final ChatMode mode;
  final List<AIMessage> aiMessages;
  final List<CustomerServiceMessage> csMessages;
  final bool isTyping;
  final String streamingContent;
  final String? activeToolCall;
  final bool toolCallCompleted;
  final Map<String, dynamic>? taskDraft;
  final Map<String, dynamic>? serviceDraft;
  final bool? csOnlineStatus; // null=未检查, true/false=结果
  final String? csContactEmail;
  final String? csServiceName;
  final String? csChatId;
  final String? errorMessage;
  final String? actionMessage;
  final bool isRating;

  /// Sentinel-based copyWith: omitting a nullable field preserves its current
  /// value; passing `null` explicitly clears it.
  UnifiedChatState copyWith({
    ChatMode? mode,
    List<AIMessage>? aiMessages,
    List<CustomerServiceMessage>? csMessages,
    bool? isTyping,
    String? streamingContent,
    Object? activeToolCall = _sentinel,
    bool? toolCallCompleted,
    Object? taskDraft = _sentinel,
    Object? serviceDraft = _sentinel,
    bool? csOnlineStatus,
    String? csContactEmail,
    String? csServiceName,
    String? csChatId,
    Object? errorMessage = _sentinel,
    Object? actionMessage = _sentinel,
    bool? isRating,
  }) {
    return UnifiedChatState(
      mode: mode ?? this.mode,
      aiMessages: aiMessages ?? this.aiMessages,
      csMessages: csMessages ?? this.csMessages,
      isTyping: isTyping ?? this.isTyping,
      streamingContent: streamingContent ?? this.streamingContent,
      activeToolCall: identical(activeToolCall, _sentinel)
          ? this.activeToolCall
          : activeToolCall as String?,
      toolCallCompleted: toolCallCompleted ?? this.toolCallCompleted,
      taskDraft: identical(taskDraft, _sentinel)
          ? this.taskDraft
          : taskDraft as Map<String, dynamic>?,
      serviceDraft: identical(serviceDraft, _sentinel)
          ? this.serviceDraft
          : serviceDraft as Map<String, dynamic>?,
      csOnlineStatus: csOnlineStatus ?? this.csOnlineStatus,
      csContactEmail: csContactEmail ?? this.csContactEmail,
      csServiceName: csServiceName ?? this.csServiceName,
      csChatId: csChatId ?? this.csChatId,
      errorMessage: identical(errorMessage, _sentinel)
          ? this.errorMessage
          : errorMessage as String?,
      actionMessage: identical(actionMessage, _sentinel)
          ? this.actionMessage
          : actionMessage as String?,
      isRating: isRating ?? this.isRating,
    );
  }

  @override
  List<Object?> get props => [
        mode,
        aiMessages,
        csMessages,
        isTyping,
        streamingContent,
        activeToolCall,
        toolCallCompleted,
        taskDraft,
        serviceDraft,
        csOnlineStatus,
        csContactEmail,
        csServiceName,
        csChatId,
        errorMessage,
        actionMessage,
        isRating,
      ];
}

// ==================== Bloc ====================

class UnifiedChatBloc extends Bloc<UnifiedChatEvent, UnifiedChatState> {
  UnifiedChatBloc({
    required AIChatService aiChatService,
    required CommonRepository commonRepository,
  })  : _repository = commonRepository,
        _aiBloc = AIChatBloc(aiChatService: aiChatService),
        _csBloc = CustomerServiceBloc(commonRepository: commonRepository),
        super(const UnifiedChatState()) {
    // Register handlers
    on<UnifiedChatInit>(_onInit);
    on<UnifiedChatSendMessage>(_onSendMessage);
    on<UnifiedChatRequestHumanCS>(_onRequestHumanCS);
    on<UnifiedChatCSEndChat>(_onCSEndChat);
    on<UnifiedChatCSRateChat>(_onCSRateChat);
    on<UnifiedChatReturnToAI>(_onReturnToAI);
    on<UnifiedChatLoadHistory>(_onLoadHistory);
    on<UnifiedChatClearTaskDraft>(_onClearTaskDraft);
    on<UnifiedChatClearServiceDraft>(_onClearServiceDraft);
    on<UnifiedChatLoadCSHistory>(_onLoadCSHistory);
    on<_AIStateChanged>(_onAIStateChanged);
    on<_CSStateChanged>(_onCSStateChanged);

    // Subscribe to sub-bloc streams
    _aiSubscription = _aiBloc.stream.listen(
      (aiState) => add(_AIStateChanged(aiState)),
    );
    _csSubscription = _csBloc.stream.listen(
      (csState) => add(_CSStateChanged(csState)),
    );
  }

  final CommonRepository _repository;
  final AIChatBloc _aiBloc;
  final CustomerServiceBloc _csBloc;
  StreamSubscription<AIChatState>? _aiSubscription;
  StreamSubscription<CustomerServiceState>? _csSubscription;

  @override
  Future<void> close() async {
    await _aiSubscription?.cancel();
    await _csSubscription?.cancel();
    await _aiBloc.close();
    await _csBloc.close();
    return super.close();
  }

  /// 初始化：创建 AI 对话
  Future<void> _onInit(
    UnifiedChatInit event,
    Emitter<UnifiedChatState> emit,
  ) async {
    _aiBloc.add(const AIChatCreateConversation());
  }

  /// 发送消息：根据 mode 路由
  Future<void> _onSendMessage(
    UnifiedChatSendMessage event,
    Emitter<UnifiedChatState> emit,
  ) async {
    if (event.content.trim().isEmpty) return;

    if (state.mode == ChatMode.ai) {
      _aiBloc.add(AIChatSendMessage(event.content));
    } else if (state.mode == ChatMode.csConnected) {
      _csBloc.add(CustomerServiceSendMessage(event.content));
    }
  }

  /// 请求连接人工客服
  Future<void> _onRequestHumanCS(
    UnifiedChatRequestHumanCS event,
    Emitter<UnifiedChatState> emit,
  ) async {
    emit(state.copyWith(mode: ChatMode.transferring));
    _csBloc.add(const CustomerServiceConnectRequested());
  }

  /// 结束 CS 对话
  Future<void> _onCSEndChat(
    UnifiedChatCSEndChat event,
    Emitter<UnifiedChatState> emit,
  ) async {
    _csBloc.add(const CustomerServiceEndChat());
  }

  /// 评价客服
  Future<void> _onCSRateChat(
    UnifiedChatCSRateChat event,
    Emitter<UnifiedChatState> emit,
  ) async {
    _csBloc.add(CustomerServiceRateChat(
      rating: event.rating,
      comment: event.comment,
    ));
  }

  /// 返回 AI 模式
  Future<void> _onReturnToAI(
    UnifiedChatReturnToAI event,
    Emitter<UnifiedChatState> emit,
  ) async {
    emit(state.copyWith(
      mode: ChatMode.ai,
    ));
  }

  /// 加载指定对话历史
  Future<void> _onLoadHistory(
    UnifiedChatLoadHistory event,
    Emitter<UnifiedChatState> emit,
  ) async {
    if (state.mode != ChatMode.ai) return;
    _aiBloc.add(AIChatLoadHistory(event.conversationId));
  }

  /// 清除任务草稿并转发给 AI Bloc
  void _onClearTaskDraft(
    UnifiedChatClearTaskDraft event,
    Emitter<UnifiedChatState> emit,
  ) {
    _aiBloc.add(const AIChatClearTaskDraft());
    emit(state.copyWith(taskDraft: null));
  }

  /// 清除服务草稿并转发给 AI Bloc
  void _onClearServiceDraft(
    UnifiedChatClearServiceDraft event,
    Emitter<UnifiedChatState> emit,
  ) {
    _aiBloc.add(const AIChatClearServiceDraft());
    emit(state.copyWith(serviceDraft: null));
  }

  /// 加载客服聊天历史
  Future<void> _onLoadCSHistory(
    UnifiedChatLoadCSHistory event,
    Emitter<UnifiedChatState> emit,
  ) async {
    try {
      final rawMessages =
          await _repository.getCustomerServiceMessages(event.chatId);
      final messages = rawMessages
          .map((m) => CustomerServiceMessage.fromJson(m))
          .toList();

      if (event.isEnded) {
        // 已结束：只读模式，仅展示历史消息
        emit(state.copyWith(
          mode: ChatMode.csEnded,
          csMessages: messages,
          csChatId: event.chatId,
        ));
      } else {
        // 未结束：先加载历史消息，再通过 CS sub-bloc 恢复连接
        emit(state.copyWith(
          mode: ChatMode.csConnected,
          csMessages: messages,
          csChatId: event.chatId,
        ));
        _csBloc.add(const CustomerServiceConnectRequested());
      }
    } catch (e) {
      emit(state.copyWith(
        errorMessage: e.toString().replaceAll('CommonException: ', ''),
      ));
    }
  }

  /// AI 子 BLoC 状态投射
  void _onAIStateChanged(
    _AIStateChanged event,
    Emitter<UnifiedChatState> emit,
  ) {
    final aiState = event.state;

    // 只在 AI 模式下投射
    if (state.mode != ChatMode.ai) return;

    emit(state.copyWith(
      aiMessages: aiState.messages,
      isTyping: aiState.isReplying,
      streamingContent: aiState.streamingContent,
      activeToolCall: aiState.activeToolCall,
      toolCallCompleted: aiState.toolCallCompleted,
      taskDraft: aiState.taskDraft,
      serviceDraft: aiState.serviceDraft,
      errorMessage: aiState.errorMessage,
      // 检测 csAvailableSignal
      csOnlineStatus: aiState.csAvailableSignal ?? state.csOnlineStatus,
      csContactEmail: aiState.csContactEmail ?? state.csContactEmail,
    ));
  }

  /// CS 子 BLoC 状态投射
  void _onCSStateChanged(
    _CSStateChanged event,
    Emitter<UnifiedChatState> emit,
  ) {
    final csState = event.state;

    switch (csState.status) {
      case CustomerServiceStatus.connected:
        emit(state.copyWith(
          mode: ChatMode.csConnected,
          csMessages: csState.messages,
          csServiceName: csState.serviceInfo?.name,
          csChatId: csState.chat?.chatId,
          isTyping: csState.isSending,
          actionMessage: csState.actionMessage,
        ));
      case CustomerServiceStatus.ended:
        emit(state.copyWith(
          mode: ChatMode.csEnded,
          csMessages: csState.messages,
          isTyping: false,
          isRating: csState.isRating,
          actionMessage: csState.actionMessage,
        ));
      case CustomerServiceStatus.connecting:
        emit(state.copyWith(
          mode: ChatMode.transferring,
          errorMessage: csState.errorMessage,
        ));
      case CustomerServiceStatus.error:
        // 连接失败，回到 AI 模式
        emit(state.copyWith(
          mode: ChatMode.ai,
          errorMessage: csState.errorMessage,
        ));
      case CustomerServiceStatus.initial:
        // CS 重置（e.g. StartNew），保持当前
        break;
    }
  }
}
