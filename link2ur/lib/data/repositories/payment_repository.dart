import '../models/payment.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';

/// 支付仓库
/// 与iOS PaymentViewModel + 后端 coupon_points_routes 对齐
class PaymentRepository {
  PaymentRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 创建任务支付（对应后端 /api/coupon-points/tasks/{taskId}/payment）
  ///
  /// [preferredPaymentMethod] 对齐 iOS PaymentViewModel：
  /// - `'card'` → 后端设置 `payment_method_types: ["card"]`
  /// - `'alipay'` → 后端设置 `payment_method_types: ["alipay"]`
  /// - `'wechat_pay'` → 微信走单独的 Checkout Session，不用此方法
  /// - `null` → 后端使用默认支付方式
  Future<TaskPaymentResponse> createTaskPayment({
    required int taskId,
    int? couponId,
    String? preferredPaymentMethod,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.createTaskPayment(taskId),
      data: {
        'payment_method': 'stripe',
        if (couponId != null) 'coupon_id': couponId,
        if (preferredPaymentMethod != null)
          'preferred_payment_method': preferredPaymentMethod,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '创建支付失败');
    }

    return TaskPaymentResponse.fromJson(response.data!);
  }

  /// 查询任务支付状态
  Future<Map<String, dynamic>> getTaskPaymentStatus(int taskId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskPaymentStatus(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '查询支付状态失败');
    }

    return response.data!;
  }

  /// 获取支付历史
  Future<List<Map<String, dynamic>>> getPaymentHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = {'page': page, 'page_size': pageSize};
    final cacheKey =
        CacheManager.buildKey('${CacheManager.prefixPayment}history_', params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.paymentHistory,
      queryParameters: params,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取支付历史失败');
    }

    // 支付数据使用个人TTL
    await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 创建微信支付 Checkout Session
  Future<String> createWeChatCheckoutSession({
    required int taskId,
    int? couponId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.createWeChatCheckout(taskId),
      data: {
        if (couponId != null) 'coupon_id': couponId,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '创建微信支付会话失败');
    }

    return response.data!['checkout_url'] as String? ?? '';
  }

  /// 创建支付意向（便捷方法，调用 createTaskPayment）
  Future<TaskPaymentResponse> createPaymentIntent({
    required int taskId,
    int? couponId,
    String? preferredPaymentMethod,
  }) async {
    return createTaskPayment(
      taskId: taskId,
      couponId: couponId,
      preferredPaymentMethod: preferredPaymentMethod,
    );
  }

  // 注意：支付确认由 Stripe SDK (PaymentSheet / Apple Pay) 在客户端完成，
  // 后端通过 Stripe Webhook 接收 payment_intent.succeeded 事件处理。
  // 无需手动调用后端确认端点。

  /// 获取支付方式列表
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectExternalAccounts,
    );

    if (!response.isSuccess || response.data == null) {
      return [];
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取 Connect 收款记录
  Future<List<Map<String, dynamic>>> getConnectPayments({
    int page = 1,
    int pageSize = 20,
  }) async {
    return getConnectTransactions(page: page, pageSize: pageSize);
  }

  /// 获取 Connect 提现记录
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
      return [];
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  // ==================== Stripe Connect ====================

  /// 创建Stripe Connect账户
  Future<Map<String, dynamic>> createStripeConnectAccount() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountCreate,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '创建Connect账户失败');
    }

    return response.data!;
  }

  /// 获取Stripe Connect入驻Session URL
  Future<String> getStripeConnectOnboardingUrl() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectOnboardingSession,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取入驻链接失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  /// 获取Stripe Connect状态
  Future<StripeConnectStatus> getStripeConnectStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取Stripe Connect状态失败');
    }

    return StripeConnectStatus.fromJson(response.data!);
  }

  /// 获取Stripe Connect账户详情
  Future<Map<String, dynamic>> getStripeConnectDetails() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountDetails,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取Connect详情失败');
    }

    return response.data!;
  }

  /// 获取Stripe Connect余额
  Future<Map<String, dynamic>> getStripeConnectBalance() async {
    final cacheKey = '${CacheManager.prefixPayment}balance';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountBalance,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取余额失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

    return response.data!;
  }

  /// 获取Stripe Connect交易记录
  Future<List<Map<String, dynamic>>> getConnectTransactions({
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = {'page': page, 'page_size': pageSize};
    final cacheKey =
        CacheManager.buildKey('${CacheManager.prefixPayment}transactions_', params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectTransactions,
      queryParameters: params,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取交易记录失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取VIP历史
  Future<List<Map<String, dynamic>>> getVipHistory({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.vipHistory,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取VIP历史失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 发起提现
  Future<Map<String, dynamic>> requestPayout({
    required int amount,
    String currency = 'gbp',
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectPayout,
      data: {
        'amount': amount,
        'currency': currency,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '提现请求失败');
    }

    // 提现后失效支付相关缓存
    await _cache.invalidatePaymentCache();

    return response.data!;
  }
}

/// 支付异常
class PaymentException implements Exception {
  PaymentException(this.message);

  final String message;

  @override
  String toString() => 'PaymentException: $message';
}
