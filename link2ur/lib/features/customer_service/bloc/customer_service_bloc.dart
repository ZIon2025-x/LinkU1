import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/customer_service.dart';
import '../../../data/repositories/common_repository.dart';
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
  }

  final CommonRepository _repository;

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

        emit(state.copyWith(
          status: chat.isEnded == 1
              ? CustomerServiceStatus.ended
              : CustomerServiceStatus.connected,
          chat: chat,
          serviceInfo: service,
          messages: messages,
        ));
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
      // 调用后端发送消息
      // 后端 customer service 消息通过 chat messages API 发送
      // 重新加载消息列表获取服务端确认
      await Future.delayed(const Duration(milliseconds: 500));
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
    emit(const CustomerServiceState());
  }
}
