import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
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

  final String userId;
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
    this.userId = '',
    this.taskId,
    this.taskStatus,
    this.page = 1,
    this.hasMore = true,
    this.nextCursor,
    this.isSending = false,
    this.isLoadingMore = false,
    this.errorMessage,
  });

  final ChatStatus status;
  final List<Message> messages;
  final String userId;
  final int? taskId;
  final String? taskStatus;
  final int page;
  final bool hasMore;
  /// 任务聊天游标分页：加载更多时传给后端的 cursor
  final String? nextCursor;
  final bool isSending;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isTaskChat => taskId != null;

  /// 任务是否已关闭（对齐iOS: 已完成/已取消/已过期等禁用输入）
  bool get isTaskClosed {
    if (taskStatus == null) return false;
    return taskStatus == AppConstants.taskStatusCompleted ||
        taskStatus == AppConstants.taskStatusCancelled ||
        taskStatus == 'expired' ||
        taskStatus == 'closed';
  }

  ChatState copyWith({
    ChatStatus? status,
    List<Message>? messages,
    String? userId,
    int? taskId,
    String? taskStatus,
    int? page,
    bool? hasMore,
    String? nextCursor,
    bool? isSending,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return ChatState(
      status: status ?? this.status,
      messages: messages ?? this.messages,
      userId: userId ?? this.userId,
      taskId: taskId ?? this.taskId,
      taskStatus: taskStatus ?? this.taskStatus,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      nextCursor: nextCursor ?? this.nextCursor,
      isSending: isSending ?? this.isSending,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        messages,
        userId,
        taskId,
        taskStatus,
        page,
        hasMore,
        nextCursor,
        isSending,
        isLoadingMore,
        errorMessage,
      ];
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

    // 监听WebSocket消息（task_message 格式为 { type, message: {...} }，对齐 iOS）
    _wsSubscription = WebSocketService.instance.messageStream.listen(
      (wsMessage) {
        if (!wsMessage.isChatMessage || wsMessage.data == null) return;
        final data = wsMessage.data!;
        final Map<String, dynamic> messageMap =
            (wsMessage.type == 'task_message' && data['message'] is Map<String, dynamic>)
                ? (data['message'] as Map<String, dynamic>)
                : data;
        try {
          final message = Message.fromJson(messageMap);
          add(ChatMessageReceived(message));
        } catch (e) {
          AppLogger.warning('WebSocket chat message parse failed', e);
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
      if (event.taskId != null) {
        // 任务聊天：后端游标分页 limit + cursor，并写入任务状态用于 UI（进行中/已关闭、关闭提示条等）
        final result = await _messageRepository.getTaskChatMessages(
          event.taskId!,
        );
        emit(state.copyWith(
          status: ChatStatus.loaded,
          messages: result.messages,
          page: 1,
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
          taskStatus: result.taskStatus,
        ));
      } else {
        // 私聊
        final messages = await _messageRepository.getMessagesWith(
          event.userId,
        );
        emit(state.copyWith(
          status: ChatStatus.loaded,
          messages: messages,
          page: 1,
          hasMore: messages.length >= 50,
        ));
      }

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
    if (!state.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      if (state.taskId != null) {
        // 任务聊天：用 cursor 加载更早的消息
        if (state.nextCursor == null || state.nextCursor!.isEmpty) {
          emit(state.copyWith(hasMore: false, isLoadingMore: false));
          return;
        }
        final result = await _messageRepository.getTaskChatMessages(
          state.taskId!,
          cursor: state.nextCursor,
        );
        // 更早的消息追加到列表末尾（后端返回仍为 新→旧，所以 result.messages 是比当前 state.messages 更旧的一批）
        // 若首屏未拿到 taskStatus，加载更多时也可补上
        emit(state.copyWith(
          messages: [...state.messages, ...result.messages],
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
          taskStatus: result.taskStatus ?? state.taskStatus,
          isLoadingMore: false,
        ));
      } else {
        final nextPage = state.page + 1;
        final messages = await _messageRepository.getMessagesWith(
          state.userId,
          page: nextPage,
        );
        emit(state.copyWith(
          messages: [...state.messages, ...messages],
          page: nextPage,
          hasMore: messages.length >= 50,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to load more messages', e);
      emit(state.copyWith(
        hasMore: false,
        isLoadingMore: false,
      ));
    }
  }

  Future<void> _onSendMessage(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    emit(state.copyWith(isSending: true));

    try {
      Message message;

      if (state.isTaskChat) {
        // 任务聊天：使用任务聊天专用API
        message = await _messageRepository.sendTaskChatMessage(
          state.taskId!,
          content: event.content,
          messageType: event.messageType,
        );
      } else {
        // 私聊：使用私聊API
        message = await _messageRepository.sendMessage(
          SendMessageRequest(
            receiverId: state.userId,
            content: event.content,
            messageType: event.messageType,
            taskId: state.taskId,
            imageUrl: event.imageUrl,
          ),
        );

        // 私聊同时通过WebSocket发送
        _messageRepository.sendMessageViaWebSocket(
          SendMessageRequest(
            receiverId: state.userId,
            content: event.content,
            messageType: event.messageType,
            taskId: state.taskId,
          ),
        );
      }

      // 任务聊天 state 为最新在前，新消息插到头部才会显示在列表底部；私聊保持追加到末尾
      final newMessages = state.isTaskChat
          ? [message, ...state.messages]
          : [...state.messages, message];
      emit(state.copyWith(
        messages: newMessages,
        isSending: false,
      ));
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

      Message message;
      if (state.isTaskChat) {
        // 任务聊天：先上传再发送带附件的消息（对齐 iOS sendMessageWithAttachment）
        final filename = Uri.tryParse(imageUrl)?.pathSegments.last ?? 'image.jpg';
        message = await _messageRepository.sendTaskChatMessage(
          state.taskId!,
          content: '[图片]',
          messageType: 'image',
          attachments: [
            {
              'attachment_type': 'image',
              'url': imageUrl,
              'meta': {'original_filename': filename},
            },
          ],
        );
      } else {
        message = await _messageRepository.sendMessage(
          SendMessageRequest(
            receiverId: state.userId,
            content: '[图片]',
            messageType: 'image',
            taskId: state.taskId,
            imageUrl: imageUrl,
          ),
        );
      }

      // 任务聊天 state 为最新在前，新消息插到头部；私聊保持追加到末尾
      final newMessages = state.isTaskChat
          ? [message, ...state.messages]
          : [...state.messages, message];
      emit(state.copyWith(
        messages: newMessages,
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
    final message = event.message;

    // 去重检查 - 对齐iOS deduplication
    if (state.messages.any((m) => m.id == message.id)) {
      return;
    }

    if (state.isTaskChat) {
      // 任务聊天：按taskId过滤，新消息插到头部（显示在列表底部）- 对齐iOS
      if (message.taskId == state.taskId) {
        emit(state.copyWith(
          messages: [message, ...state.messages],
        ));
        // 自动标记已读
        add(const ChatMarkAsRead());
      }
    } else {
      // 私聊：按userId过滤，追加到末尾
      if (message.senderId == state.userId ||
          message.receiverId == state.userId) {
        emit(state.copyWith(
          messages: [...state.messages, message],
        ));
      }
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      if (state.isTaskChat) {
        // 任务聊天：使用任务聊天标记已读API，传入最新消息ID
        // 后端返回消息按 created_at DESC 排序，messages[0] 是最新的
        final latestId = state.messages.isNotEmpty ? state.messages.first.id : null;
        if (latestId != null) {
          await _messageRepository.markTaskChatRead(
            state.taskId!,
            uptoMessageId: latestId,
          );
        }
      } else {
        // 私聊
        await _messageRepository.markMessagesRead(state.userId);
      }
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
