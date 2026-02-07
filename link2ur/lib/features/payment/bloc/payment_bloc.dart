import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class PaymentEvent extends Equatable {
  const PaymentEvent();

  @override
  List<Object?> get props => [];
}

/// 创建支付意向
class PaymentCreateIntent extends PaymentEvent {
  const PaymentCreateIntent({
    required this.taskId,
    this.couponId,
  });

  final int taskId;
  final int? couponId;

  @override
  List<Object?> get props => [taskId, couponId];
}

/// 确认支付
class PaymentConfirm extends PaymentEvent {
  const PaymentConfirm({required this.paymentIntentId});

  final String paymentIntentId;

  @override
  List<Object?> get props => [paymentIntentId];
}

/// 选择优惠券
class PaymentSelectCoupon extends PaymentEvent {
  const PaymentSelectCoupon({this.couponId, this.couponName});

  final int? couponId;
  final String? couponName;

  @override
  List<Object?> get props => [couponId, couponName];
}

/// 移除优惠券
class PaymentRemoveCoupon extends PaymentEvent {
  const PaymentRemoveCoupon();
}

/// 查询支付状态
class PaymentCheckStatus extends PaymentEvent {
  const PaymentCheckStatus(this.taskId);

  final int taskId;

  @override
  List<Object?> get props => [taskId];
}

/// 创建微信支付会话
class PaymentCreateWeChatSession extends PaymentEvent {
  const PaymentCreateWeChatSession({
    required this.taskId,
    this.couponId,
  });

  final int taskId;
  final int? couponId;

  @override
  List<Object?> get props => [taskId, couponId];
}

/// 标记支付成功（由外部回调触发）
class PaymentMarkSuccess extends PaymentEvent {
  const PaymentMarkSuccess();
}

/// 标记支付失败
class PaymentMarkFailed extends PaymentEvent {
  const PaymentMarkFailed(this.error);

  final String error;

  @override
  List<Object?> get props => [error];
}

// ==================== State ====================

enum PaymentStatus { initial, loading, ready, processing, success, error }

class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentStatus.initial,
    this.paymentResponse,
    this.selectedCouponId,
    this.selectedCouponName,
    this.weChatCheckoutUrl,
    this.errorMessage,
  });

  final PaymentStatus status;
  final TaskPaymentResponse? paymentResponse;
  final int? selectedCouponId;
  final String? selectedCouponName;
  final String? weChatCheckoutUrl;
  final String? errorMessage;

  bool get isLoading => status == PaymentStatus.loading;
  bool get isProcessing => status == PaymentStatus.processing;
  bool get isReady => status == PaymentStatus.ready;
  bool get isSuccess => status == PaymentStatus.success;

  PaymentState copyWith({
    PaymentStatus? status,
    TaskPaymentResponse? paymentResponse,
    int? selectedCouponId,
    String? selectedCouponName,
    String? weChatCheckoutUrl,
    String? errorMessage,
    bool clearCoupon = false,
    bool clearWeChatUrl = false,
  }) {
    return PaymentState(
      status: status ?? this.status,
      paymentResponse: paymentResponse ?? this.paymentResponse,
      selectedCouponId:
          clearCoupon ? null : (selectedCouponId ?? this.selectedCouponId),
      selectedCouponName:
          clearCoupon ? null : (selectedCouponName ?? this.selectedCouponName),
      weChatCheckoutUrl: clearWeChatUrl
          ? null
          : (weChatCheckoutUrl ?? this.weChatCheckoutUrl),
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        paymentResponse,
        selectedCouponId,
        selectedCouponName,
        weChatCheckoutUrl,
        errorMessage,
      ];
}

// ==================== Bloc ====================

class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc({required PaymentRepository paymentRepository})
      : _repository = paymentRepository,
        super(const PaymentState()) {
    on<PaymentCreateIntent>(_onCreateIntent);
    on<PaymentConfirm>(_onConfirm);
    on<PaymentSelectCoupon>(_onSelectCoupon);
    on<PaymentRemoveCoupon>(_onRemoveCoupon);
    on<PaymentCheckStatus>(_onCheckStatus);
    on<PaymentCreateWeChatSession>(_onCreateWeChatSession);
    on<PaymentMarkSuccess>(_onMarkSuccess);
    on<PaymentMarkFailed>(_onMarkFailed);
  }

  final PaymentRepository _repository;

  Future<void> _onCreateIntent(
    PaymentCreateIntent event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.loading));

    try {
      final response = await _repository.createPaymentIntent(
        taskId: event.taskId,
        couponId: event.couponId ?? state.selectedCouponId,
      );

      emit(state.copyWith(
        status: PaymentStatus.ready,
        paymentResponse: response,
      ));
    } catch (e) {
      AppLogger.error('Failed to create payment intent', e);
      emit(state.copyWith(
        status: PaymentStatus.error,
        errorMessage: _formatError(e),
      ));
    }
  }

  Future<void> _onConfirm(
    PaymentConfirm event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.processing));

    try {
      await _repository.confirmPayment(
        paymentIntentId: event.paymentIntentId,
      );
      emit(state.copyWith(status: PaymentStatus.success));
    } catch (e) {
      AppLogger.error('Failed to confirm payment', e);
      emit(state.copyWith(
        status: PaymentStatus.error,
        errorMessage: _formatError(e),
      ));
    }
  }

  Future<void> _onSelectCoupon(
    PaymentSelectCoupon event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(
      selectedCouponId: event.couponId,
      selectedCouponName: event.couponName,
    ));
  }

  Future<void> _onRemoveCoupon(
    PaymentRemoveCoupon event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(clearCoupon: true));
  }

  Future<void> _onCheckStatus(
    PaymentCheckStatus event,
    Emitter<PaymentState> emit,
  ) async {
    try {
      final statusData = await _repository.getTaskPaymentStatus(event.taskId);
      final paymentStatus = statusData['status'] as String?;
      if (paymentStatus == 'paid' || paymentStatus == 'succeeded') {
        emit(state.copyWith(status: PaymentStatus.success));
      }
    } catch (e) {
      AppLogger.error('Failed to check payment status', e);
    }
  }

  Future<void> _onCreateWeChatSession(
    PaymentCreateWeChatSession event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.processing));

    try {
      final checkoutUrl = await _repository.createWeChatCheckoutSession(
        taskId: event.taskId,
        couponId: event.couponId ?? state.selectedCouponId,
      );

      emit(state.copyWith(
        status: PaymentStatus.ready,
        weChatCheckoutUrl: checkoutUrl,
      ));
    } catch (e) {
      AppLogger.error('Failed to create WeChat session', e);
      emit(state.copyWith(
        status: PaymentStatus.error,
        errorMessage: _formatError(e),
      ));
    }
  }

  Future<void> _onMarkSuccess(
    PaymentMarkSuccess event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.success));
  }

  Future<void> _onMarkFailed(
    PaymentMarkFailed event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(
      status: PaymentStatus.error,
      errorMessage: event.error,
    ));
  }

  String _formatError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('insufficient_funds')) {
      return '余额不足，请更换支付方式或充值后重试。';
    } else if (msg.contains('card_declined')) {
      return '银行卡被拒绝，请更换银行卡或联系银行。';
    } else if (msg.contains('expired_card')) {
      return '银行卡已过期，请更换银行卡。';
    } else if (msg.contains('network')) {
      return '网络连接失败，请检查网络后重试。';
    } else if (msg.contains('timeout')) {
      return '请求超时，请稍后重试。';
    }
    return msg
        .replaceAll('PaymentException: ', '')
        .replaceAll('Exception: ', '');
  }
}
