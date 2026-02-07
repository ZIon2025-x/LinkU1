import '../models/payment.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 支付仓库
/// 参考iOS APIService+Endpoints.swift 支付相关
class PaymentRepository {
  PaymentRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 创建支付意向
  Future<TaskPaymentResponse> createPaymentIntent({
    required int taskId,
    int? couponId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.createPaymentIntent,
      data: {
        'task_id': taskId,
        if (couponId != null) 'coupon_id': couponId,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '创建支付失败');
    }

    return TaskPaymentResponse.fromJson(response.data!);
  }

  /// 确认支付
  Future<Map<String, dynamic>> confirmPayment({
    required String paymentIntentId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.confirmPayment,
      data: {
        'payment_intent_id': paymentIntentId,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '确认支付失败');
    }

    return response.data!;
  }

  /// 获取支付方式列表
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.paymentMethods,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取支付方式失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  // ==================== Stripe Connect ====================

  /// 获取Stripe Connect入驻URL
  Future<String> getStripeConnectOnboardingUrl() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectOnboarding,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取入驻链接失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  /// 获取Stripe Connect收款记录
  Future<List<Map<String, dynamic>>> getConnectPayments({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectTransactions,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'type': 'payment',
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取收款记录失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取Stripe Connect提现记录
  Future<List<Map<String, dynamic>>> getConnectPayouts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectTransactions,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        'type': 'payout',
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取提现记录失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取Stripe Connect状态
  Future<StripeConnectStatus> getStripeConnectStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取Stripe Connect状态失败');
    }

    return StripeConnectStatus.fromJson(response.data!);
  }
}

/// 支付异常
class PaymentException implements Exception {
  PaymentException(this.message);

  final String message;

  @override
  String toString() => 'PaymentException: $message';
}
