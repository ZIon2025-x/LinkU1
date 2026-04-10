import '../../core/constants/api_endpoints.dart';
import '../services/api_service.dart';

/// 套餐购买 + QR 核销 repository (A1)
class PackagePurchaseRepository {
  final ApiService _api;

  PackagePurchaseRepository(this._api);

  /// buyer 发起套餐购买,返回 client_secret
  Future<Map<String, dynamic>> purchasePackage(int serviceId) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.purchasePackage(serviceId),
      data: {},
    );
    if (!res.isSuccess || res.data == null) {
      // 优先抛 error_code (稳定),让 error_localizer 能做 i18n; 无 code 时 fallback 到 message
      throw Exception(res.errorCode ?? res.message ?? 'package_purchase_failed');
    }
    return res.data!;
  }

  /// buyer 列出我购买的所有套餐
  Future<List<Map<String, dynamic>>> listMyPackages() async {
    final res = await _api.get<List<dynamic>>(ApiEndpoints.myPackages);
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'fetch_my_packages_failed');
    }
    return res.data!
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  /// 轮询等待支付后 webhook 创建 UserServicePackage
  ///
  /// 调用方: Stripe PaymentSheet 返回成功后,但 webhook 是异步的,
  /// 直接跳"我的套餐"可能空列表。此方法按 [paymentIntentId] 轮询,
  /// 直到对应套餐出现或超时。
  Future<Map<String, dynamic>?> waitForPackageByPaymentIntent(
    String paymentIntentId, {
    Duration timeout = const Duration(seconds: 20),
    Duration pollInterval = const Duration(milliseconds: 1500),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final items = await listMyPackages();
        for (final item in items) {
          if (item['payment_intent_id'] == paymentIntentId) {
            return item;
          }
        }
      } catch (_) {
        // 网络抖动不打断轮询
      }
      await Future<void>.delayed(pollInterval);
    }
    return null;
  }

  /// buyer 查看单个套餐详情(含 bundle_breakdown + 历史)
  Future<Map<String, dynamic>> getMyPackageDetail(int packageId) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.myPackageDetail(packageId),
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'package_not_found');
    }
    return res.data!;
  }

  /// buyer 端拉 QR + OTP, TTL 60s
  Future<Map<String, dynamic>> getRedemptionQr(int packageId) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.myPackageRedemptionQr(packageId),
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'qr_generation_failed');
    }
    return res.data!;
  }

  /// 团队 owner/admin 扫码核销
  /// [qrData] 或 [otp] 二选一
  /// [subServiceId] bundle 套餐必填
  Future<Map<String, dynamic>> redeemPackage({
    required String expertId,
    String? qrData,
    String? otp,
    int? subServiceId,
    String? note,
  }) async {
    final body = <String, dynamic>{};
    if (qrData != null) body['qr_data'] = qrData;
    if (otp != null) body['otp'] = otp;
    if (subServiceId != null) body['sub_service_id'] = subServiceId;
    if (note != null) body['note'] = note;
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.redeemPackage(expertId),
      data: body,
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'redeem_failed');
    }
    return res.data!;
  }

  /// 申请退款(后端根据 cooldown + usage 自动判断全额/按比例)
  Future<Map<String, dynamic>> requestRefund(int packageId,
      {String? reason}) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.myPackageRefund(packageId),
      data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'refund_failed');
    }
    return res.data!;
  }

  /// 提交套餐评价
  Future<Map<String, dynamic>> submitReview(
    int packageId, {
    required int rating,
    required String comment,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.myPackageReview(packageId),
      data: {'rating': rating, 'comment': comment},
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'review_failed');
    }
    return res.data!;
  }

  /// 发起套餐争议(需已使用至少 1 次)
  Future<Map<String, dynamic>> openDispute(
    int packageId, {
    required String reason,
  }) async {
    final res = await _api.post<Map<String, dynamic>>(
      ApiEndpoints.myPackageDispute(packageId),
      data: {'reason': reason},
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'dispute_failed');
    }
    return res.data!;
  }

  /// 团队"我的客户"列表
  Future<Map<String, dynamic>> getCustomerPackages(
    String expertId, {
    String? statusFilter,
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.customerPackages(expertId),
      queryParameters: {
        if (statusFilter != null) 'status': statusFilter,
        'limit': limit,
        'offset': offset,
      },
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.errorCode ?? res.message ?? 'fetch_customer_packages_failed');
    }
    return res.data!;
  }
}
