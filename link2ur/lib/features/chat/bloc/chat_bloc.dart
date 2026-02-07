import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/message.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/services/websocket_service.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class ChatEvent extends Equatable {
  const ChatEvent();

  @override
  List<Object?> get props => [];
}

class ChatLoadMessages extends ChatEvent {
  const ChatLoadMessages({
    required this.userId,
    this.taskId,
  });

  final int userId;
  final int? taskId;

  @override
  List<Object?> get props => [userId, taskId];
}

class ChatLoadMore extends ChatEvent {
  const ChatLoadMore();
}

class ChatSendMessage extends ChatEvent {
  const ChatSendMessage({
    required this.content,
    this.messageType = 'text',
    this.imageUrl,
  });

  final String content;
  final String messageType;
  final String? imageUrl;

  @override
  List<Object?> get props => [content, messageType];
}

class ChatSendImage extends ChatEvent {
  const ChatSendImage({required this.filePath});

  final String filePath;

  @override
  List<Object?> get props => [filePath];
}

class ChatMessageReceived extends ChatEvent {
  const ChatMessageReceived(this.message);

  final Message message;

  @override
  List<Object?> get props => [message];
}

class ChatMarkAsRead extends ChatEvent {
  const ChatMarkAsRead();
}

// ==================== State ====================

enum ChatStatus { initial, loading, loaded, error }

class ChatState extends Equatable {
  const ChatState({
    this.status = ChatStatus.initial,
    this.messages = const [],
    this.userId = 0,
    this.taskId,
    this.page = 1,
    this.hasMore = true,
    this.isSending = false,
    this.errorMessage,
  });

  final ChatStatus status;
  final List<Message> messages;
  final int userId;
  final int? taskId;
  final int page;
  final bool hasMore;
  final bool isSending;
  final String? errorMessage;

  bool get isTaskChat => taskId != null;

  ChatState copyWith({
    ChatStatus? status,
    List<Message>? messages,
    int? userId,
    int? taskId,
    int? page,
    bool? hasMore,
    bool? isSending,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isSending: isSending ?? this.isSending,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, messages, userId, taskId, page, hasMore, isSending];
}

// ==================== Bloc ====================

class ChatBloc extends Bloc<ChatEvent, ChatState> {
  ChatBloc({required MessageRepository messageRepository})
      : _messageRepository = messageRepository,
        super(const ChatState()) {
    on<ChatLoadMessages>(_onLoadMessages);
    on<ChatLoadMore>(_onLoadMore);
    on<ChatSendMessage>(_onSendMessage);
    on<ChatSendImage>(_onSendImage);
    on<ChatMessageReceived>(_onMessageReceived);
    on<ChatMarkAsRead>(_onMarkAsRead);

    // 监听WebSocket消息
    _wsSubscription = WebSocketService.instance.messageStream.listen(
      (wsMessage) {
        if (wsMessage.isChatMessage && wsMessage.data != null) {
          final message = Message.fromJson(wsMessage.data!);
          add(ChatMessageReceived(message));
        }
      },
    );
  }

  final MessageRepository _messageRepository;
  StreamSubscription? _wsSubscription;

  Future<void> _onLoadMessages(
    ChatLoadMessages event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(
      status: ChatStatus.loading,
      userId: event.userId,
      taskId: event.taskId,
    ));

    try {
      List<Message> messages;
      if (event.taskId != null) {
        messages = await _messageRepository.getTaskChatMessages(
          event.taskId!,
          page: 1,
        );
      } else {
        messages = await _messageRepository.getMessagesWith(
          event.userId,
          page: 1,
        );
      }

      emit(state.copyWith(
        status: ChatStatus.loaded,
        messages: messages,
        page: 1,
        hasMore: messages.length >= 50,
      ));

      // 标记已读
      add(const ChatMarkAsRead());
    } catch (e) {
      AppLogger.error('Failed to load messages', e);
      emit(state.copyWith(
        status: ChatStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMore(
    ChatLoadMore event,
    Emitter<ChatState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      List<Message> messages;

      if (state.taskId != null) {
        messages = await _messageRepository.getTaskChatMessages(
          state.taskId!,
          page: nextPage,
        );
      } else {
        messages = await _messageRepository.getMessagesWith(
          state.userId,
          page: nextPage,
        );
      }

      emit(state.copyWith(
        messages: [...state.messages, ...messages],
        page: nextPage,
        hasMore: messages.length >= 50,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more messages', e);
    }
  }

  Future<void> _onSendMessage(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isSending: true));

    try {
      final message = await _messageRepository.sendMessage(
        SendMessageRequest(
          receiverId: state.userId,
          content: event.content,
          messageType: event.messageType,
          taskId: state.taskId,
          imageUrl: event.imageUrl,
        ),
      );

      emit(state.copyWith(
        messages: [message, ...state.messages],
        isSending: false,
      ));

      // 同时通过WebSocket发送
      _messageRepository.sendMessageViaWebSocket(
        SendMessageRequest(
          receiverId: state.userId,
          content: event.content,
          messageType: event.messageType,
          taskId: state.taskId,
        ),
      );
    } catch (e) {
      AppLogger.error('Failed to send message', e);
      emit(state.copyWith(isSending: false));
    }
  }

  Future<void> _onSendImage(
    ChatSendImage event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isSending: true));

    try {
      // 先上传图片获取URL
      final imageUrl = await _messageRepository.uploadImage(event.filePath);

      // 然后发送图片消息
      final message = await _messageRepository.sendMessage(
        SendMessageRequest(
          receiverId: state.userId,
          content: '[图片]',
          messageType: 'image',
          taskId: state.taskId,
          imageUrl: imageUrl,
        ),
      );

      emit(state.copyWith(
        messages: [message, ...state.messages],
        isSending: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to send image', e);
      emit(state.copyWith(isSending: false));
    }
  }

  void _onMessageReceived(
    ChatMessageReceived event,
    Emitter<ChatState> emit,
  ) {
    // 只处理当前聊天的消息
    if (event.message.senderId == state.userId ||
        event.message.receiverId == state.userId) {
      emit(state.copyWith(
        messages: [event.message, ...state.messages],
      ));
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      await _messageRepository.markMessagesRead(state.userId);
    } catch (e) {
      AppLogger.warning('Failed to mark as read', e);
    }
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    return super.close();
  }
}
