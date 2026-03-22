import 'dart:async';
import 'dart:typed_data';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/network_monitor.dart';
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
    /// 当前用户 id，用于乐观更新时显示“我”发出的消息；不传则不做乐观更新
    this.senderId,
  });

  final String content;
  final String messageType;
  final String? imageUrl;
  final String? senderId;

  @override
  List<Object?> get props => [content, messageType, imageUrl, senderId];
}

class ChatSendImage extends ChatEvent {
  const ChatSendImage({
    required this.bytes,
    required this.filename,
    /// 当前用户 id，用于乐观更新时显示”我”发出的消息；不传则不做乐观更新
    this.senderId,
  });

  final Uint8List bytes;
  final String filename;
  final String? senderId;

  @override
  List<Object?> get props => [bytes, filename, senderId];
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

class ChatPeerTypingReceived extends ChatEvent {
  const ChatPeerTypingReceived(this.senderId);
  final String senderId;
  @override
  List<Object?> get props => [senderId];
}

class ChatReadReceiptReceived extends ChatEvent {
  const ChatReadReceiptReceived(this.senderId);
  final String senderId;
  @override
  List<Object?> get props => [senderId];
}

class ChatClearError extends ChatEvent {
  const ChatClearError();
}

class _ChatPeerTypingTimeout extends ChatEvent {
  const _ChatPeerTypingTimeout();
}

class _ChatRefreshTaskStatus extends ChatEvent {
  const _ChatRefreshTaskStatus();
}

class _ChatDoMarkAsRead extends ChatEvent {
  const _ChatDoMarkAsRead();
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
    this.peerIsTyping = false,
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
  final bool peerIsTyping;

  bool get isTaskChat => taskId != null;

  /// 任务是否已关闭（对齐iOS: 已完成/已取消/已过期等禁用输入）
  bool get isTaskClosed {
    if (taskStatus == null) return false;
    return taskStatus == AppConstants.taskStatusCompleted ||
        taskStatus == AppConstants.taskStatusCancelled ||
        taskStatus == AppConstants.taskStatusExpired ||
        taskStatus == AppConstants.taskStatusClosed;
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
    bool? peerIsTyping,
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
      peerIsTyping: peerIsTyping ?? this.peerIsTyping,
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
        peerIsTyping,
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
    on<ChatPeerTypingReceived>(_onPeerTyping);
    on<ChatReadReceiptReceived>(_onReadReceipt);
    on<ChatClearError>((event, emit) {
      emit(state.copyWith());
    });
    on<_ChatPeerTypingTimeout>((event, emit) {
      emit(state.copyWith(peerIsTyping: false));
    });
    on<_ChatRefreshTaskStatus>(_onRefreshTaskStatus);
    on<_ChatDoMarkAsRead>(_onDoMarkAsRead);

    _wsSubscription = WebSocketService.instance.messageStream.listen(
      (wsMessage) {
        if (wsMessage.data == null) return;
        final data = wsMessage.data!;

        if (wsMessage.isReadReceipt) {
          // Filter by taskId for task chats to avoid cross-chat interference
          if (state.isTaskChat) {
            final receiptTaskId = data['task_id'];
            if (receiptTaskId != null && receiptTaskId != state.taskId) return;
          }
          final senderId = data['sender_id']?.toString() ?? '';
          if (senderId.isNotEmpty) add(ChatReadReceiptReceived(senderId));
          return;
        }

        if (wsMessage.isTyping) {
          // Filter typing by context: task chat checks taskId, private chat checks userId
          if (state.isTaskChat) {
            final typingTaskId = data['task_id'];
            if (typingTaskId != null && typingTaskId != state.taskId) return;
          }
          final senderId = data['sender_id']?.toString() ??
              data['receiver_id']?.toString() ?? '';
          if (senderId.isNotEmpty) add(ChatPeerTypingReceived(senderId));
          return;
        }

        if (!wsMessage.isChatMessage) return;
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
  Timer? _taskStatusTimer;
  Timer? _markAsReadDebounce;

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
        // 任务聊天：保持后端顺序 新→旧，配合 ListView reverse:true 一进入即视口在底部
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
        // 任务聊天：定期刷新任务状态，防止对方完成/取消任务后聊天页不更新
        _startTaskStatusRefresh();
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
        errorMessage: 'chat_load_failed',
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
        // 更早的一批后端仍为 新→旧，append 到列表末尾（reverse 时在视口顶部）
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
        errorMessage: 'chat_load_more_failed',
      ));
    }
  }

  /// 生成乐观更新用的临时消息 id（负数递减，避免与后端 id 冲突）
  static int _pendingCounter = 0;
  static int _nextPendingId() => -(++_pendingCounter);

  Future<void> _onSendMessage(
    ChatSendMessage event,
    Emitter<ChatState> emit,
  ) async {
    if (!NetworkMonitor.instance.isConnected) {
      emit(state.copyWith(errorMessage: 'chat_network_offline'));
      return;
    }

    final senderId = event.senderId?.trim();
    final canOptimistic = senderId != null && senderId.isNotEmpty;

    Message? pendingMessage;
    if (canOptimistic) {
      pendingMessage = Message(
        id: _nextPendingId(),
        senderId: senderId,
        receiverId: state.userId,
        content: event.content,
        messageType: event.messageType,
        imageUrl: event.imageUrl,
        createdAt: DateTime.now().toUtc(),
      );
      // 任务聊天：新→旧，新消息插到头部；私聊：旧→新，追加到末尾
      final newMessages = state.isTaskChat
          ? [pendingMessage, ...state.messages]
          : [...state.messages, pendingMessage];
      emit(state.copyWith(messages: newMessages, isSending: true));
    } else {
      emit(state.copyWith(isSending: true));
    }

    try {
      Message message;

      if (state.isTaskChat) {
        message = await _messageRepository.sendTaskChatMessage(
          state.taskId!,
          content: event.content,
          messageType: event.messageType,
        );
      } else {
        message = await _messageRepository.sendMessage(
          SendMessageRequest(
            receiverId: state.userId,
            content: event.content,
            messageType: event.messageType,
            taskId: state.taskId,
            imageUrl: event.imageUrl,
          ),
        );
      }

      if (canOptimistic && pendingMessage != null) {
        final list = state.messages
            .map((m) => m.id == pendingMessage!.id ? message : m)
            .toList();
        emit(state.copyWith(messages: list, isSending: false));
      } else {
        // 任务聊天插头，私聊追加尾
        emit(state.copyWith(
          messages: state.isTaskChat
              ? [message, ...state.messages]
              : [...state.messages, message],
          isSending: false,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to send message', e);
      if (canOptimistic && pendingMessage != null) {
        final list =
            state.messages.where((m) => m.id != pendingMessage!.id).toList();
        emit(state.copyWith(
          messages: list,
          isSending: false,
          errorMessage: 'chat_send_message_failed',
        ));
      } else {
        emit(state.copyWith(
          isSending: false,
          errorMessage: 'chat_send_message_failed',
        ));
      }
    }
  }

  Future<void> _onSendImage(
    ChatSendImage event,
    Emitter<ChatState> emit,
  ) async {
    if (!NetworkMonitor.instance.isConnected) {
      emit(state.copyWith(errorMessage: 'chat_network_offline'));
      return;
    }

    emit(state.copyWith(isSending: true));
    int? pendingId;

    try {
      final imageUrl = await _messageRepository.uploadImage(event.bytes, event.filename);

      final senderId = event.senderId?.trim();
      final canOptimistic = senderId != null && senderId.isNotEmpty;
      Message? pendingMessage;
      if (canOptimistic) {
        pendingId = _nextPendingId();
        pendingMessage = Message(
          id: pendingId,
          senderId: senderId,
          receiverId: state.userId,
          content: '[图片]',
          messageType: 'image',
          imageUrl: imageUrl,
          createdAt: DateTime.now().toUtc(),
        );
        // 任务聊天插头，私聊追加尾
        emit(state.copyWith(
          messages: state.isTaskChat
              ? [pendingMessage, ...state.messages]
              : [...state.messages, pendingMessage],
        ));
      }

      Message message;
      if (state.isTaskChat) {
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

      if (canOptimistic && pendingMessage != null) {
        final list = state.messages
            .map((m) => m.id == pendingMessage!.id ? message : m)
            .toList();
        emit(state.copyWith(messages: list, isSending: false));
      } else {
        emit(state.copyWith(
          messages: state.isTaskChat
              ? [message, ...state.messages]
              : [...state.messages, message],
          isSending: false,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to send image', e);
      if (pendingId != null) {
        final list = state.messages.where((m) => m.id != pendingId).toList();
        emit(state.copyWith(
          messages: list,
          isSending: false,
          errorMessage: 'chat_send_image_failed',
        ));
      } else {
        emit(state.copyWith(
          isSending: false,
          errorMessage: 'chat_send_image_failed',
        ));
      }
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
      // 任务聊天：state.messages 为 新→旧，新消息插到头部（reverse 时在底部）
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
        // 自动标记已读
        add(const ChatMarkAsRead());
      }
    }
  }

  Future<void> _onMarkAsRead(
    ChatMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    // 防抖：快速连续收到多条消息时，合并为一次 markAsRead 请求
    _markAsReadDebounce?.cancel();
    _markAsReadDebounce = Timer(const Duration(milliseconds: 500), () {
      if (!isClosed) add(const _ChatDoMarkAsRead());
    });
  }

  Future<void> _onDoMarkAsRead(
    _ChatDoMarkAsRead event,
    Emitter<ChatState> emit,
  ) async {
    try {
      if (state.isTaskChat) {
        final latestId = state.messages.isNotEmpty ? state.messages.first.id : null;
        if (latestId != null) {
          await _messageRepository.markTaskChatRead(
            state.taskId!,
            uptoMessageId: latestId,
          );
        }
      } else {
        await _messageRepository.markMessagesRead(state.userId);
      }
    } catch (e) {
      AppLogger.warning('Failed to mark as read', e);
    }
  }

  Timer? _typingTimer;

  void _onPeerTyping(
    ChatPeerTypingReceived event,
    Emitter<ChatState> emit,
  ) {
    // 任务聊天：WebSocket 已按 taskId 过滤，接受任何参与者的打字状态
    // 私聊：仅接受对方（state.userId）的打字状态
    if (!state.isTaskChat && event.senderId != state.userId) return;
    emit(state.copyWith(peerIsTyping: true));
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 3), () {
      if (!isClosed) add(const _ChatPeerTypingTimeout());
    });
  }

  void _onReadReceipt(
    ChatReadReceiptReceived event,
    Emitter<ChatState> emit,
  ) {
    if (state.isTaskChat) {
      // 任务聊天：回执发送者已读 → 标记非其本人发送的未读消息为已读
      final updated = state.messages.map((m) {
        if (m.isRead) return m;
        if (m.senderId == event.senderId) return m; // 回执发送者自己的消息无需标记
        return m.copyWith(isRead: true);
      }).toList();
      emit(state.copyWith(messages: updated));
    } else {
      // 私聊：仅当回执来自对方时，标记自己发出的未读消息为已读
      if (event.senderId != state.userId) return;
      final updated = state.messages.map((m) {
        if (m.isRead) return m;
        if (m.senderId != state.userId) return m;
        return m.copyWith(isRead: true);
      }).toList();
      emit(state.copyWith(messages: updated));
    }
  }

  /// 任务聊天：每 30 秒刷新一次任务状态
  void _startTaskStatusRefresh() {
    _taskStatusTimer?.cancel();
    _taskStatusTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!isClosed) add(const _ChatRefreshTaskStatus());
    });
  }

  Future<void> _onRefreshTaskStatus(
    _ChatRefreshTaskStatus event,
    Emitter<ChatState> emit,
  ) async {
    if (state.taskId == null) return;
    try {
      final result = await _messageRepository.getTaskChatMessages(
        state.taskId!,
        limit: 1, // 仅需 taskStatus，最小化请求负载
      );
      if (result.taskStatus != null && result.taskStatus != state.taskStatus) {
        emit(state.copyWith(taskStatus: result.taskStatus));
        // 终态任务不再轮询
        if (state.isTaskClosed) {
          _taskStatusTimer?.cancel();
        }
      }
    } catch (_) {
      // 静默失败，不影响聊天
    }
  }

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    _typingTimer?.cancel();
    _taskStatusTimer?.cancel();
    _markAsReadDebounce?.cancel();
    return super.close();
  }
}
