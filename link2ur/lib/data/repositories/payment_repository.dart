import '../models/payment.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 支付仓库
/// 与iOS PaymentViewModel + 后端 coupon_points_routes 对齐
class PaymentRepository {
  PaymentRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 创建任务支付（对应后端 /api/coupon-points/tasks/{taskId}/payment）
  /// [userCouponId] 用户优惠券 ID（后端字段 user_coupon_id），选券后传入以抵扣
  /// [preferredPaymentMethod] 对齐 iOS：card / alipay / null
  /// [taskSource] 任务来源（如 flea_market），用于跳蚤市场支付时补充 PI metadata
  /// [fleaMarketItemId] 跳蚤市场商品 ID，用于 webhook 更新商品状态
  Future<TaskPaymentResponse> createTaskPayment({
    required int taskId,
    int? userCouponId,
    String? preferredPaymentMethod,
    String? taskSource,
    String? fleaMarketItemId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.createTaskPayment(taskId),
      data: {
        'payment_method': 'stripe',
        if (userCouponId != null) 'user_coupon_id': userCouponId,
        if (preferredPaymentMethod != null)
          'preferred_payment_method': preferredPaymentMethod,
        if (taskSource != null) 'task_source': taskSource,
        if (fleaMarketItemId != null) 'flea_market_item_id': fleaMarketItemId,
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
    // 后端使用 skip/limit 分页（coupon_points_routes.py）
    final skip = (page - 1) * pageSize;
    final params = {'skip': skip, 'limit': pageSize};
    final cacheKey =
        CacheManager.buildKey('${CacheManager.prefixPayment}history_', params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      // 后端返回 "payments" key
      final items = cached['payments'] as List<dynamic>? ?? [];
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

    // 后端返回 "payments" key（非 "items"）
    final items = response.data!['payments'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 创建微信支付 Checkout Session
  /// [couponId] 用户优惠券 ID（user_coupon_id），与 createTaskPayment 一致
  /// [taskSource] 任务来源（如 flea_market），用于跳蚤市场支付时补充 Session metadata
  /// [fleaMarketItemId] 跳蚤市场商品 ID，用于 webhook 更新商品状态
  Future<String> createWeChatCheckoutSession({
    required int taskId,
    int? couponId,
    String? taskSource,
    String? fleaMarketItemId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.createWeChatCheckout(taskId),
      data: {
        if (couponId != null) 'user_coupon_id': couponId,
        if (taskSource != null) 'task_source': taskSource,
        if (fleaMarketItemId != null) 'flea_market_item_id': fleaMarketItemId,
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
    int? userCouponId,
    String? preferredPaymentMethod,
    String? taskSource,
    String? fleaMarketItemId,
  }) async {
    return createTaskPayment(
      taskId: taskId,
      userCouponId: userCouponId,
      preferredPaymentMethod: preferredPaymentMethod,
      taskSource: taskSource,
      fleaMarketItemId: fleaMarketItemId,
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
    final cacheKey = CacheManager.buildKey(
      '${CacheManager.prefixPayment}payouts_',
      {'p': page, 'ps': pageSize},
    );

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    }

    try {
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

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

      final items = response.data!['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        final items = stale['items'] as List<dynamic>? ?? [];
        return items.map((e) => e as Map<String, dynamic>).toList();
      }
      rethrow;
    }
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

  /// 创建Stripe Connect嵌入式账户（对标iOS create-embedded）
  /// 返回 account_id, client_secret 等
  Future<Map<String, dynamic>> createStripeConnectAccountEmbedded() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountCreateEmbedded,
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

  /// 为已有账户创建新的 onboarding session（每次打开入驻页前调用，获取新的 client_secret，避免 Stripe "already been claimed"）
  Future<Map<String, dynamic>> createStripeConnectOnboardingSession() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectOnboardingSession,
    );
    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取入驻会话失败');
    }
    return response.data!;
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

  /// 获取Stripe Connect账户详情（强类型）
  Future<StripeConnectAccountDetails> getStripeConnectAccountDetails() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountDetails,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取Connect详情失败');
    }

    return StripeConnectAccountDetails.fromJson(response.data!);
  }

  /// 获取Stripe Connect账户详情（原始Map，向后兼容）
  Future<Map<String, dynamic>> getStripeConnectDetails() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountDetails,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取Connect详情失败');
    }

    return response.data!;
  }

  /// 获取Stripe Connect余额（强类型）
  Future<StripeConnectBalance> getStripeConnectBalanceTyped() async {
    const cacheKey = '${CacheManager.prefixPayment}balance';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return StripeConnectBalance.fromJson(cached);

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectAccountBalance,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取余额失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

    return StripeConnectBalance.fromJson(response.data!);
  }

  /// 获取Stripe Connect余额（原始Map，向后兼容）
  Future<Map<String, dynamic>> getStripeConnectBalance() async {
    const cacheKey = '${CacheManager.prefixPayment}balance';

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

  /// 获取外部账户列表（银行账户/银行卡）
  Future<List<ExternalAccount>> getExternalAccounts() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectExternalAccounts,
    );

    if (!response.isSuccess || response.data == null) {
      return [];
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => ExternalAccount.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取 Stripe Connect 交易记录（强类型）
  Future<List<StripeConnectTransaction>> getStripeConnectTransactions({
    int limit = 100,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.stripeConnectTransactions,
      queryParameters: {'limit': limit},
    );

    if (!response.isSuccess || response.data == null) {
      return [];
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => StripeConnectTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取任务支付记录（强类型）
  Future<List<TaskPaymentRecord>> getTaskPaymentRecords({
    int limit = 100,
    int skip = 0,
  }) async {
    final cacheKey = CacheManager.buildKey(
      '${CacheManager.prefixPayment}task_records_',
      {'l': limit, 's': skip},
    );

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['payments'] as List<dynamic>? ?? [];
      return items
          .map((e) => TaskPaymentRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.paymentHistory,
        queryParameters: {'limit': limit, 'skip': skip},
      );

      if (!response.isSuccess || response.data == null) {
        return [];
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

      final items = response.data!['payments'] as List<dynamic>? ?? [];
      return items
          .map((e) => TaskPaymentRecord.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        final items = stale['payments'] as List<dynamic>? ?? [];
        return items
            .map((e) => TaskPaymentRecord.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
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
    final cacheKey = CacheManager.buildKey(
      '${CacheManager.prefixPayment}vip_history_',
      {'p': page, 'ps': pageSize},
    );

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    }

    try {
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

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

      final items = response.data!['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        final items = stale['items'] as List<dynamic>? ?? [];
        return items.map((e) => e as Map<String, dynamic>).toList();
      }
      rethrow;
    }
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

  /// 获取IAP产品列表
  Future<List<Map<String, dynamic>>> getIapProducts() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.iapProducts,
    );

    if (!response.isSuccess || response.data == null) {
      throw PaymentException(response.message ?? '获取IAP产品列表失败');
    }

    final items = response.data!['products'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }
}

/// 支付异常
class PaymentException extends AppException {
  const PaymentException(super.message);
}
