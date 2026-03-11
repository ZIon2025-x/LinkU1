import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/customer_service.dart';
import '../../../data/repositories/common_repository.dart';
import '../../../data/services/websocket_service.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class CustomerServiceEvent extends Equatable {
  const CustomerServiceEvent();

  @override
  List<Object?> get props => [];
}

/// 连接客服（分配）
class CustomerServiceConnectRequested extends CustomerServiceEvent {
  const CustomerServiceConnectRequested();
}

/// 加载聊天消息
class CustomerServiceLoadMessages extends CustomerServiceEvent {
  const CustomerServiceLoadMessages(this.chatId);

  final String chatId;

  @override
  List<Object?> get props => [chatId];
}

/// 发送消息
class CustomerServiceSendMessage extends CustomerServiceEvent {
  const CustomerServiceSendMessage(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}

/// 结束聊天
class CustomerServiceEndChat extends CustomerServiceEvent {
  const CustomerServiceEndChat();
}

/// 评价客服
class CustomerServiceRateChat extends CustomerServiceEvent {
  const CustomerServiceRateChat({
    required this.rating,
    this.comment,
  });

  final int rating;
  final String? comment;

  @override
  List<Object?> get props => [rating, comment];
}

/// 加载排队状态
class CustomerServiceCheckQueue extends CustomerServiceEvent {
  const CustomerServiceCheckQueue();
}

/// 开始新对话
class CustomerServiceStartNew extends CustomerServiceEvent {
  const CustomerServiceStartNew();
}

/// WebSocket收到客服消息
class _CustomerServiceMessageReceived extends CustomerServiceEvent {
  const _CustomerServiceMessageReceived(this.message);

  final CustomerServiceMessage message;

  @override
  List<Object?> get props => [message];
}

/// 轮询刷新消息
class _CustomerServicePollMessages extends CustomerServiceEvent {
  const _CustomerServicePollMessages();
}

// ==================== State ====================

enum CustomerServiceStatus { initial, connecting, connected, ended, error }

class CustomerServiceState extends Equatable {
  const CustomerServiceState({
    this.status = CustomerServiceStatus.initial,
    this.chat,
    this.serviceInfo,
    this.messages = const [],
    this.queueStatus,
    this.errorMessage,
    this.isSending = false,
    this.isRating = false,
    this.actionMessage,
  });

  final CustomerServiceStatus status;
  final CustomerServiceChat? chat;
  final CustomerServiceInfo? serviceInfo;
  final List<CustomerServiceMessage> messages;
  final CustomerServiceQueueStatus? queueStatus;
  final String? errorMessage;
  final bool isSending;
  final bool isRating;
  final String? actionMessage;

  bool get isConnected => status == CustomerServiceStatus.connected;
  bool get isEnded => status == CustomerServiceStatus.ended;
  bool get isConnecting => status == CustomerServiceStatus.connecting;

  CustomerServiceState copyWith({
    CustomerServiceStatus? status,
    CustomerServiceChat? chat,
    CustomerServiceInfo? serviceInfo,
    List<CustomerServiceMessage>? messages,
    CustomerServiceQueueStatus? queueStatus,
    String? errorMessage,
    bool? isSending,
    bool? isRating,
    String? actionMessage,
  }) {
    return CustomerServiceState(
      status: status ?? this.status,
      chat: chat ?? this.chat,
      serviceInfo: serviceInfo ?? this.serviceInfo,
      messages: messages ?? this.messages,
      queueStatus: queueStatus ?? this.queueStatus,
      errorMessage: errorMessage,
      isSending: isSending ?? this.isSending,
      isRating: isRating ?? this.isRating,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        chat,
        serviceInfo,
        messages,
        queueStatus,
        errorMessage,
        isSending,
        isRating,
        actionMessage,
      ];
}

// ==================== Bloc ====================

class CustomerServiceBloc
    extends Bloc<CustomerServiceEvent, CustomerServiceState> {
  CustomerServiceBloc({required CommonRepository commonRepository})
      : _repository = commonRepository,
        super(const CustomerServiceState()) {
    on<CustomerServiceConnectRequested>(_onConnect);
    on<CustomerServiceLoadMessages>(_onLoadMessages);
    on<CustomerServiceSendMessage>(_onSendMessage);
    on<CustomerServiceEndChat>(_onEndChat);
    on<CustomerServiceRateChat>(_onRateChat);
    on<CustomerServiceCheckQueue>(_onCheckQueue);
    on<CustomerServiceStartNew>(_onStartNew);
    on<_CustomerServiceMessageReceived>(_onMessageReceived);
    on<_CustomerServicePollMessages>(_onPollMessages);
  }

  final CommonRepository _repository;
  StreamSubscription? _wsSubscription;
  Timer? _pollTimer;

  void _startListening(String chatId) {
    // WebSocket监听客服消息
    _wsSubscription?.cancel();
    _wsSubscription =
        WebSocketService.instance.messageStream.listen((wsMessage) {
      if (wsMessage.type != 'cs_message') return;
      final data = wsMessage.data;
      if (data == null || data['chat_id'] != chatId) return;

      final message = CustomerServiceMessage(
        messageId: data['message_id'] as int?,
        content: data['content'] as String? ?? '',
        senderType: data['sender_type'] as String? ?? 'customer_service',
        messageType: 'text',
        createdAt: data['created_at'] as String?,
        chatId: data['chat_id'] as String?,
      );
      add(_CustomerServiceMessageReceived(message));
    });

    // 轮询兜底：每5秒刷新一次消息（WebSocket可能不可用）
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!isClosed && state.isConnected) {
        add(const _CustomerServicePollMessages());
      }
    });
  }

  void _stopListening() {
    _wsSubscription?.cancel();
    _wsSubscription = null;
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// 连接客服
  Future<void> _onConnect(
    CustomerServiceConnectRequested event,
    Emitter<CustomerServiceState> emit,
  ) async {
    emit(state.copyWith(status: CustomerServiceStatus.connecting));

    try {
      final response = await _repository.assignCustomerService();
      final assignResponse =
          CustomerServiceAssignResponse.fromJson(response);

      if (assignResponse.error != null) {
        // 可能正在排队
        emit(state.copyWith(
          status: CustomerServiceStatus.connecting,
          queueStatus: assignResponse.queueStatus,
          errorMessage: assignResponse.message,
        ));
        return;
      }

      final chat = assignResponse.chat;
      final service = assignResponse.service;

      if (chat != null) {
        // 成功分配客服，加载历史消息
        List<CustomerServiceMessage> messages = [];
        try {
          final rawMessages =
              await _repository.getCustomerServiceMessages(chat.chatId);
          messages = rawMessages
              .map((m) => CustomerServiceMessage.fromJson(m))
              .toList();
        } catch (_) {
          // 如果加载消息失败，不阻塞连接
        }

        // 添加系统欢迎消息
        if (messages.isEmpty && assignResponse.systemMessage != null) {
          messages = [
            CustomerServiceMessage(
              content: assignResponse.systemMessage!.content,
              senderType: 'customer_service',
              messageType: 'system',
            ),
          ];
        }

        final isEnded = chat.isEnded == 1;
        emit(state.copyWith(
          status: isEnded
              ? CustomerServiceStatus.ended
              : CustomerServiceStatus.connected,
          chat: chat,
          serviceInfo: service,
          messages: messages,
        ));

        // 连接成功后开始监听实时消息
        if (!isEnded) {
          _startListening(chat.chatId);
        }
      } else {
        emit(state.copyWith(
          status: CustomerServiceStatus.error,
          errorMessage:
              assignResponse.message ?? 'customer_service_no_available_agent',
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to connect customer service', e);
      emit(state.copyWith(
        status: CustomerServiceStatus.error,
        errorMessage: e.toString().replaceAll('CommonException: ', ''),
      ));
    }
  }

  /// 加载聊天消息
  Future<void> _onLoadMessages(
    CustomerServiceLoadMessages event,
    Emitter<CustomerServiceState> emit,
  ) async {
    try {
      final rawMessages =
          await _repository.getCustomerServiceMessages(event.chatId);
      final messages = rawMessages
          .map((m) => CustomerServiceMessage.fromJson(m))
          .toList();

      emit(state.copyWith(messages: messages));
    } catch (e) {
      AppLogger.error('Failed to load CS messages', e);
    }
  }

  /// WebSocket收到客服消息
  Future<void> _onMessageReceived(
    _CustomerServiceMessageReceived event,
    Emitter<CustomerServiceState> emit,
  ) async {
    // 去重：检查消息ID是否已存在
    if (event.message.messageId != null &&
        state.messages.any((m) => m.messageId == event.message.messageId)) {
      return;
    }
    emit(state.copyWith(
      messages: [...state.messages, event.message],
    ));
  }

  /// 轮询刷新消息
  Future<void> _onPollMessages(
    _CustomerServicePollMessages event,
    Emitter<CustomerServiceState> emit,
  ) async {
    if (state.chat == null || !state.isConnected) return;

    try {
      final rawMessages =
          await _repository.getCustomerServiceMessages(state.chat!.chatId);
      final messages = rawMessages
          .map((m) => CustomerServiceMessage.fromJson(m))
          .toList();

      // 只在消息数量变化时更新（避免不必要的rebuild）
      if (messages.length != state.messages.length) {
        emit(state.copyWith(messages: messages));
      }
    } catch (e) {
      // 轮询失败不影响使用，静默忽略
    }
  }

  /// 发送消息
  Future<void> _onSendMessage(
    CustomerServiceSendMessage event,
    Emitter<CustomerServiceState> emit,
  ) async {
    if (state.chat == null || event.content.trim().isEmpty) return;

    // 乐观更新：先在本地添加消息
    final optimisticMessage = CustomerServiceMessage(
      content: event.content.trim(),
      senderType: 'user',
      messageType: 'text',
      createdAt: DateTime.now().toIso8601String(),
    );

    emit(state.copyWith(
      isSending: true,
      messages: [...state.messages, optimisticMessage],
    ));

    try {
      // POST 消息到后端
      await _repository.sendCustomerServiceMessage(
        state.chat!.chatId,
        event.content.trim(),
      );

      // 重新加载消息列表获取服务端确认
      final rawMessages =
          await _repository.getCustomerServiceMessages(state.chat!.chatId);
      final messages = rawMessages
          .map((m) => CustomerServiceMessage.fromJson(m))
          .toList();

      emit(state.copyWith(
        isSending: false,
        messages: messages,
      ));
    } catch (e) {
      // 发送失败但保留乐观更新的消息
      emit(state.copyWith(isSending: false));
      AppLogger.error('Failed to send CS message', e);
    }
  }

  /// 结束聊天
  Future<void> _onEndChat(
    CustomerServiceEndChat event,
    Emitter<CustomerServiceState> emit,
  ) async {
    if (state.chat == null) return;

    try {
      await _repository.endCustomerServiceChat(state.chat!.chatId);
      _stopListening();
      emit(state.copyWith(
        status: CustomerServiceStatus.ended,
        actionMessage: 'conversation_ended',
      ));
    } catch (e) {
      emit(state.copyWith(
        actionMessage: 'end_conversation_failed',
      ));
    }
  }

  /// 评价客服
  Future<void> _onRateChat(
    CustomerServiceRateChat event,
    Emitter<CustomerServiceState> emit,
  ) async {
    if (state.chat == null) return;

    emit(state.copyWith(isRating: true));

    try {
      await _repository.rateCustomerService(
        state.chat!.chatId,
        rating: event.rating,
        comment: event.comment,
      );
      emit(state.copyWith(
        isRating: false,
        actionMessage: 'feedback_success',
      ));
    } catch (e) {
      emit(state.copyWith(
        isRating: false,
        actionMessage: 'feedback_failed',
      ));
    }
  }

  /// 检查排队状态
  Future<void> _onCheckQueue(
    CustomerServiceCheckQueue event,
    Emitter<CustomerServiceState> emit,
  ) async {
    try {
      final data = await _repository.getCustomerServiceQueueStatus();
      final queueStatus = CustomerServiceQueueStatus.fromJson(data);
      emit(state.copyWith(queueStatus: queueStatus));

      // 如果已分配，自动连接
      if (queueStatus.status == 'assigned') {
        add(const CustomerServiceConnectRequested());
      }
    } catch (e) {
      AppLogger.error('Failed to check queue status', e);
    }
  }

  /// 开始新对话
  Future<void> _onStartNew(
    CustomerServiceStartNew event,
    Emitter<CustomerServiceState> emit,
  ) async {
    _stopListening();
    emit(const CustomerServiceState());
  }

  @override
  Future<void> close() {
    _stopListening();
    return super.close();
  }
}
