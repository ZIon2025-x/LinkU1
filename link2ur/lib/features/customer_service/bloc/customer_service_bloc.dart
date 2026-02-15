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

/// 杩炴帴瀹㈡湇锛堝垎閰嶏級
class CustomerServiceConnectRequested extends CustomerServiceEvent {
  const CustomerServiceConnectRequested();
}

/// 鍔犺浇鑱婂ぉ娑堟伅
class CustomerServiceLoadMessages extends CustomerServiceEvent {
  const CustomerServiceLoadMessages(this.chatId);

  final String chatId;

  @override
  List<Object?> get props => [chatId];
}

/// 鍙戦€佹秷鎭?
class CustomerServiceSendMessage extends CustomerServiceEvent {
  const CustomerServiceSendMessage(this.content);

  final String content;

  @override
  List<Object?> get props => [content];
}

/// 缁撴潫鑱婂ぉ
class CustomerServiceEndChat extends CustomerServiceEvent {
  const CustomerServiceEndChat();
}

/// 璇勪环瀹㈡湇
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

/// 鍔犺浇鎺掗槦鐘舵€?
class CustomerServiceCheckQueue extends CustomerServiceEvent {
  const CustomerServiceCheckQueue();
}

/// 寮€濮嬫柊瀵硅瘽
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

  /// 杩炴帴瀹㈡湇
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
        // 鍙兘姝ｅ湪鎺掗槦
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
        // 鎴愬姛鍒嗛厤瀹㈡湇锛屽姞杞藉巻鍙叉秷鎭?
        List<CustomerServiceMessage> messages = [];
        try {
          final rawMessages =
              await _repository.getCustomerServiceMessages(chat.chatId);
          messages = rawMessages
              .map((m) => CustomerServiceMessage.fromJson(m))
              .toList();
        } catch (_) {
          // 濡傛灉鍔犺浇娑堟伅澶辫触锛屼笉闃诲杩炴帴
        }

        // 娣诲姞绯荤粺娆㈣繋娑堟伅
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

  /// 鍔犺浇鑱婂ぉ娑堟伅
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

  /// 鍙戦€佹秷鎭?
  Future<void> _onSendMessage(
    CustomerServiceSendMessage event,
    Emitter<CustomerServiceState> emit,
  ) async {
    if (state.chat == null || event.content.trim().isEmpty) return;

    // 涔愯鏇存柊锛氬厛鍦ㄦ湰鍦版坊鍔犳秷鎭?
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
      // 璋冪敤鍚庣鍙戦€佹秷鎭?
      // 鍚庣 customer service 娑堟伅閫氳繃 chat messages API 鍙戦€?
      // 閲嶆柊鍔犺浇娑堟伅鍒楄〃鑾峰彇鏈嶅姟绔‘璁?
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
      // 鍙戦€佸け璐ヤ絾淇濈暀涔愯鏇存柊鐨勬秷鎭?
      emit(state.copyWith(isSending: false));
      AppLogger.error('Failed to send CS message', e);
    }
  }

  /// 缁撴潫鑱婂ぉ
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

  /// 璇勪环瀹㈡湇
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

  /// 妫€鏌ユ帓闃熺姸鎬?
  Future<void> _onCheckQueue(
    CustomerServiceCheckQueue event,
    Emitter<CustomerServiceState> emit,
  ) async {
    try {
      final data = await _repository.getCustomerServiceQueueStatus();
      final queueStatus = CustomerServiceQueueStatus.fromJson(data);
      emit(state.copyWith(queueStatus: queueStatus));

      // 濡傛灉宸插垎閰嶏紝鑷姩杩炴帴
      if (queueStatus.status == 'assigned') {
        add(const CustomerServiceConnectRequested());
      }
    } catch (e) {
      AppLogger.error('Failed to check queue status', e);
    }
  }

  /// 寮€濮嬫柊瀵硅瘽
  Future<void> _onStartNew(
    CustomerServiceStartNew event,
    Emitter<CustomerServiceState> emit,
  ) async {
    emit(const CustomerServiceState());
  }
}

