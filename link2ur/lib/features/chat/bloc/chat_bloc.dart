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
  /// 浠诲姟鑱婂ぉ娓告爣鍒嗛〉锛氬姞杞芥洿澶氭椂浼犵粰鍚庣鐨?cursor
  final String? nextCursor;
  final bool isSending;
  final bool isLoadingMore;
  final String? errorMessage;

  bool get isTaskChat => taskId != null;

  /// Whether the task chat should be closed for input.
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

    // Listen to WebSocket chat events.
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
        // 浠诲姟鑱婂ぉ锛氬悗绔父鏍囧垎椤?limit + cursor
        final result = await _messageRepository.getTaskChatMessages(
          event.taskId!,
          limit: 50,
        );
        emit(state.copyWith(
          status: ChatStatus.loaded,
          messages: result.messages,
          page: 1,
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
        ));
      } else {
        // 绉佽亰
        final messages = await _messageRepository.getMessagesWith(
          event.userId,
          page: 1,
        );
        emit(state.copyWith(
          status: ChatStatus.loaded,
          messages: messages,
          page: 1,
          hasMore: messages.length >= 50,
        ));
      }

      // 鏍囪宸茶
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
        // Task chat uses cursor pagination for older messages.
        if (state.nextCursor == null || state.nextCursor!.isEmpty) {
          emit(state.copyWith(hasMore: false, isLoadingMore: false));
          return;
        }
        final result = await _messageRepository.getTaskChatMessages(
          state.taskId!,
          limit: 50,
          cursor: state.nextCursor,
        );
        // 鏇存棭鐨勬秷鎭拷鍔犲埌鍒楄〃鏈熬锛堝悗绔繑鍥炰粛涓?鏂扳啋鏃э紝鎵€浠?result.messages 鏄瘮褰撳墠 state.messages 鏇存棫鐨勪竴鎵癸級
        emit(state.copyWith(
          messages: [...state.messages, ...result.messages],
          hasMore: result.hasMore,
          nextCursor: result.nextCursor,
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
        // 浠诲姟鑱婂ぉ锛氫娇鐢ㄤ换鍔¤亰澶╀笓鐢ˋPI
        message = await _messageRepository.sendTaskChatMessage(
          state.taskId!,
          content: event.content,
          messageType: event.messageType,
        );
      } else {
        // 绉佽亰锛氫娇鐢ㄧ鑱夾PI
        message = await _messageRepository.sendMessage(
          SendMessageRequest(
            receiverId: state.userId,
            content: event.content,
            messageType: event.messageType,
            taskId: state.taskId,
            imageUrl: event.imageUrl,
          ),
        );

        // Send through websocket for direct chat too.
        _messageRepository.sendMessageViaWebSocket(
          SendMessageRequest(
            receiverId: state.userId,
            content: event.content,
            messageType: event.messageType,
            taskId: state.taskId,
          ),
        );
      }

      // 浠诲姟鑱婂ぉ state 涓烘渶鏂板湪鍓嶏紝鏂版秷鎭彃鍒板ご閮ㄦ墠浼氭樉绀哄湪鍒楄〃搴曢儴锛涚鑱婁繚鎸佽拷鍔犲埌鏈熬
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
      // 鍏堜笂浼犲浘鐗囪幏鍙朥RL
      final imageUrl = await _messageRepository.uploadImage(event.filePath);

      Message message;
      if (state.isTaskChat) {
        // Upload first, then send image message with attachment metadata.
        final filename = Uri.tryParse(imageUrl)?.pathSegments.last ?? 'image.jpg';
        message = await _messageRepository.sendTaskChatMessage(
          state.taskId!,
          content: '[Image]',
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
            content: '[Image]',
            messageType: 'image',
            taskId: state.taskId,
            imageUrl: imageUrl,
          ),
        );
      }

      // Task chat keeps newest-first; direct chat appends at the end.
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

    // 鍘婚噸妫€鏌?- 瀵归綈iOS deduplication
    if (state.messages.any((m) => m.id == message.id)) {
      return;
    }

    if (state.isTaskChat) {
      // 浠诲姟鑱婂ぉ锛氭寜taskId杩囨护锛屾柊娑堟伅鎻掑埌澶撮儴锛堟樉绀哄湪鍒楄〃搴曢儴锛? 瀵归綈iOS
      if (message.taskId == state.taskId) {
        emit(state.copyWith(
          messages: [message, ...state.messages],
        ));
        // 鑷姩鏍囪宸茶
        add(const ChatMarkAsRead());
      }
    } else {
      // 绉佽亰锛氭寜userId杩囨护锛岃拷鍔犲埌鏈熬
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
        // 浠诲姟鑱婂ぉ锛氫娇鐢ㄤ换鍔¤亰澶╂爣璁板凡璇籄PI锛屼紶鍏ユ渶鏂版秷鎭疘D
        // 鍚庣杩斿洖娑堟伅鎸?created_at DESC 鎺掑簭锛宮essages[0] 鏄渶鏂扮殑
        final latestId = state.messages.isNotEmpty ? state.messages.first.id : null;
        if (latestId != null) {
          await _messageRepository.markTaskChatRead(
            state.taskId!,
            uptoMessageId: latestId,
          );
        }
      } else {
        // 绉佽亰
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

