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

/// 创建支付意向（对齐 iOS createPaymentIntent）
///
/// [preferredPaymentMethod]: 'card' / 'alipay' / null
/// [isMethodSwitch]: true 表示切换支付方式时重建，不会重置 UI 为 loading 状态
class PaymentCreateIntent extends PaymentEvent {
  const PaymentCreateIntent({
    required this.taskId,
    this.couponId,
    this.preferredPaymentMethod,
    this.isMethodSwitch = false,
  });

  final int taskId;
  final int? couponId;
  final String? preferredPaymentMethod;
  final bool isMethodSwitch;

  @override
  List<Object?> get props => [taskId, couponId, preferredPaymentMethod, isMethodSwitch];
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

/// 创建微信支付 Checkout Session（对齐 iOS confirmWeChatPayment）
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

/// 开始处理中（用于 PaymentSheet / Apple Pay 等客户端 UI 支付流程）
class PaymentStartProcessing extends PaymentEvent {
  const PaymentStartProcessing();
}

/// 清除错误信息
class PaymentClearError extends PaymentEvent {
  const PaymentClearError();
}

/// 标记支付成功（由 Stripe SDK 回调触发）
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
    this.preferredPaymentMethod,
    this.weChatCheckoutUrl,
    this.errorMessage,
    this.isMethodSwitching = false,
  });

  final PaymentStatus status;
  final TaskPaymentResponse? paymentResponse;
  final int? selectedCouponId;
  final String? selectedCouponName;
  /// 当前 PaymentIntent 对应的支付方式（'card' / 'alipay'）
  final String? preferredPaymentMethod;
  final String? weChatCheckoutUrl;
  final String? errorMessage;
  /// 是否正在切换支付方式（不应重置整个 UI）
  final bool isMethodSwitching;

  bool get isLoading => status == PaymentStatus.loading;
  bool get isProcessing => status == PaymentStatus.processing;
  bool get isReady => status == PaymentStatus.ready;
  bool get isSuccess => status == PaymentStatus.success;

  PaymentState copyWith({
    PaymentStatus? status,
    TaskPaymentResponse? paymentResponse,
    int? selectedCouponId,
    String? selectedCouponName,
    String? preferredPaymentMethod,
    String? weChatCheckoutUrl,
    String? errorMessage,
    bool? isMethodSwitching,
    bool clearCoupon = false,
    bool clearWeChatUrl = false,
    bool clearError = false,
  }) {
    return PaymentState(
      status: status ?? this.status,
      paymentResponse: paymentResponse ?? this.paymentResponse,
      selectedCouponId:
          clearCoupon ? null : (selectedCouponId ?? this.selectedCouponId),
      selectedCouponName:
          clearCoupon ? null : (selectedCouponName ?? this.selectedCouponName),
      preferredPaymentMethod:
          preferredPaymentMethod ?? this.preferredPaymentMethod,
      weChatCheckoutUrl: clearWeChatUrl
          ? null
          : (weChatCheckoutUrl ?? this.weChatCheckoutUrl),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isMethodSwitching: isMethodSwitching ?? false,
    );
  }

  @override
  List<Object?> get props => [
        status,
        paymentResponse,
        selectedCouponId,
        selectedCouponName,
        preferredPaymentMethod,
        weChatCheckoutUrl,
        errorMessage,
        isMethodSwitching,
      ];
}

// ==================== Bloc ====================

/// 支付 BLoC
///
/// 对齐 iOS PaymentViewModel 的支付流程：
/// 1. 创建 PaymentIntent（带 preferred_payment_method）
/// 2. Stripe SDK 在客户端完成支付（PaymentSheet / Apple Pay）
/// 3. 后端通过 Webhook 接收确认通知
///
/// 注意：卡支付和支付宝都通过 Stripe PaymentSheet 完成，
/// 微信支付通过 Stripe Checkout Session + WebView 完成。
class PaymentBloc extends Bloc<PaymentEvent, PaymentState> {
  PaymentBloc({required PaymentRepository paymentRepository})
      : _repository = paymentRepository,
        super(const PaymentState()) {
    on<PaymentCreateIntent>(_onCreateIntent);
    on<PaymentSelectCoupon>(_onSelectCoupon);
    on<PaymentRemoveCoupon>(_onRemoveCoupon);
    on<PaymentCheckStatus>(_onCheckStatus);
    on<PaymentCreateWeChatSession>(_onCreateWeChatSession);
    on<PaymentStartProcessing>(_onStartProcessing);
    on<PaymentClearError>(_onClearError);
    on<PaymentMarkSuccess>(_onMarkSuccess);
    on<PaymentMarkFailed>(_onMarkFailed);
  }

  final PaymentRepository _repository;

  /// 创建支付意向
  ///
  /// 对齐 iOS PaymentViewModel.createPaymentIntent()
  /// - 初始加载：status → loading → ready
  /// - 方法切换：保持当前 UI，静默刷新（isMethodSwitching = true）
  Future<void> _onCreateIntent(
    PaymentCreateIntent event,
    Emitter<PaymentState> emit,
  ) async {
    if (event.isMethodSwitch) {
      // 方法切换：不清空 UI，保留旧的 paymentResponse 显示金额信息
      emit(state.copyWith(
        isMethodSwitching: true,
        clearError: true,
      ));
    } else {
      emit(state.copyWith(status: PaymentStatus.loading, clearError: true));
    }

    try {
      final response = await _repository.createPaymentIntent(
        taskId: event.taskId,
        couponId: event.couponId ?? state.selectedCouponId,
        preferredPaymentMethod: event.preferredPaymentMethod,
      );

      emit(state.copyWith(
        status: PaymentStatus.ready,
        paymentResponse: response,
        preferredPaymentMethod: event.preferredPaymentMethod,
        isMethodSwitching: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to create payment intent', e);
      emit(state.copyWith(
        status: event.isMethodSwitch ? PaymentStatus.ready : PaymentStatus.error,
        errorMessage: _formatError(e),
        isMethodSwitching: false,
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

  /// 创建微信支付 Checkout Session
  ///
  /// 对齐 iOS PaymentViewModel.confirmWeChatPayment()
  /// 微信支付不走 PaymentIntent → PaymentSheet 流程，
  /// 而是创建 Stripe Checkout Session → 在 WebView 中完成支付
  Future<void> _onCreateWeChatSession(
    PaymentCreateWeChatSession event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.processing, clearError: true));

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

  Future<void> _onStartProcessing(
    PaymentStartProcessing event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(status: PaymentStatus.processing, clearError: true));
  }

  Future<void> _onClearError(
    PaymentClearError event,
    Emitter<PaymentState> emit,
  ) async {
    emit(state.copyWith(
      status: state.paymentResponse != null
          ? PaymentStatus.ready
          : PaymentStatus.initial,
      clearError: true,
      clearWeChatUrl: true,
    ));
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

  /// 格式化 Stripe / 网络错误为本地化 key 或用户友好消息
  ///
  /// 对齐 iOS PaymentViewModel.formatPaymentError()
  String _formatError(dynamic error) {
    final msg = error.toString();
    // Stripe 卡支付相关错误
    if (msg.contains('insufficient_funds')) {
      return 'error_insufficient_funds';
    } else if (msg.contains('card_declined')) {
      return 'error_card_declined';
    } else if (msg.contains('expired_card')) {
      return 'error_expired_card';
    } else if (msg.contains('incorrect_cvc')) {
      return 'error_incorrect_cvc';
    } else if (msg.contains('incorrect_number')) {
      return 'error_incorrect_number';
    } else if (msg.contains('authentication_required')) {
      return 'error_authentication_required';
    } else if (msg.contains('processing_error')) {
      return 'error_processing';
    } else if (msg.contains('rate_limit')) {
      return 'error_rate_limit';
    } else if (msg.contains('invalid_request')) {
      return 'error_invalid_request';
    }
    // 网络/超时
    if (msg.contains('network') || msg.contains('SocketException')) {
      return 'error_network_connection';
    } else if (msg.contains('timeout') || msg.contains('TimeoutException')) {
      return 'error_network_timeout';
    }
    return msg
        .replaceAll('PaymentException: ', '')
        .replaceAll('Exception: ', '');
  }
}
