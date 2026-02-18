import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/ai_chat.dart';
import '../../../data/models/customer_service.dart';
import '../../../data/repositories/common_repository.dart';
import '../../../data/services/ai_chat_service.dart';
import '../../customer_service/bloc/customer_service_bloc.dart';
import 'ai_chat_bloc.dart';

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
  final bool? csOnlineStatus; // null=未检查, true/false=结果
  final String? csContactEmail;
  final String? csServiceName;
  final String? csChatId;
  final String? errorMessage;
  final String? actionMessage;
  final bool isRating;

  UnifiedChatState copyWith({
    ChatMode? mode,
    List<AIMessage>? aiMessages,
    List<CustomerServiceMessage>? csMessages,
    bool? isTyping,
    String? streamingContent,
    String? activeToolCall,
    bool? csOnlineStatus,
    String? csContactEmail,
    String? csServiceName,
    String? csChatId,
    String? errorMessage,
    String? actionMessage,
    bool? isRating,
  }) {
    return UnifiedChatState(
      mode: mode ?? this.mode,
      aiMessages: aiMessages ?? this.aiMessages,
      csMessages: csMessages ?? this.csMessages,
      isTyping: isTyping ?? this.isTyping,
      streamingContent: streamingContent ?? this.streamingContent,
      activeToolCall: activeToolCall,
      csOnlineStatus: csOnlineStatus ?? this.csOnlineStatus,
      csContactEmail: csContactEmail ?? this.csContactEmail,
      csServiceName: csServiceName ?? this.csServiceName,
      csChatId: csChatId ?? this.csChatId,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
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
        csOnlineStatus,
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
  })  : _aiBloc = AIChatBloc(aiChatService: aiChatService),
        _csBloc = CustomerServiceBloc(commonRepository: commonRepository),
        super(const UnifiedChatState()) {
    // Register handlers
    on<UnifiedChatInit>(_onInit);
    on<UnifiedChatSendMessage>(_onSendMessage);
    on<UnifiedChatRequestHumanCS>(_onRequestHumanCS);
    on<UnifiedChatCSEndChat>(_onCSEndChat);
    on<UnifiedChatCSRateChat>(_onCSRateChat);
    on<UnifiedChatReturnToAI>(_onReturnToAI);
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
