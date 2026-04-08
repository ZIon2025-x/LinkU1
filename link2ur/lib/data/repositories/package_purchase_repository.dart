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
      throw Exception(res.message ?? 'package_purchase_failed');
    }
    return res.data!;
  }

  /// buyer 查看单个套餐详情(含 bundle_breakdown + 历史)
  Future<Map<String, dynamic>> getMyPackageDetail(int packageId) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.myPackageDetail(packageId),
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.message ?? 'package_not_found');
    }
    return res.data!;
  }

  /// buyer 端拉 QR + OTP, TTL 60s
  Future<Map<String, dynamic>> getRedemptionQr(int packageId) async {
    final res = await _api.get<Map<String, dynamic>>(
      ApiEndpoints.myPackageRedemptionQr(packageId),
    );
    if (!res.isSuccess || res.data == null) {
      throw Exception(res.message ?? 'qr_generation_failed');
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
      throw Exception(res.message ?? 'redeem_failed');
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
      throw Exception(res.message ?? 'fetch_customer_packages_failed');
    }
    return res.data!;
  }
}
