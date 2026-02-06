import '../models/coupon_points.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 积分优惠券仓库
/// 参考iOS APIService+Endpoints.swift 积分优惠券相关
class CouponPointsRepository {
  CouponPointsRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  // ==================== 积分相关 ====================

  /// 获取积分账户信息
  Future<PointsAccount> getPointsAccount() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.pointsAccount,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取积分账户失败');
    }

    return PointsAccount.fromJson(response.data!);
  }

  /// 获取积分交易记录
  Future<List<PointsTransaction>> getPointsTransactions({
    int page = 1,
    int pageSize = 20,
    String? type,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.pointsTransactions,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (type != null) 'type': type,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取交易记录失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => PointsTransaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 每日签到
  Future<PointsTransaction> checkIn() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.checkIn,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '签到失败');
    }

    return PointsTransaction.fromJson(response.data!);
  }

  // ==================== 优惠券相关 ====================

  /// 获取可用优惠券列表
  Future<List<Coupon>> getAvailableCoupons() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.coupons,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取优惠券失败');
    }

    return response.data!
        .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取我的优惠券
  Future<List<UserCoupon>> getMyCoupons({
    String? status, // unused, used, expired
  }) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.myCoupons,
      queryParameters: {
        if (status != null) 'status': status,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取我的优惠券失败');
    }

    return response.data!
        .map((e) => UserCoupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 验证邀请码
  Future<Map<String, dynamic>> validateInvitationCode(String code) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.validateInvitationCode,
      data: {'code': code},
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '验证邀请码失败');
    }

    return response.data!;
  }
}

/// 积分优惠券异常
class CouponPointsException implements Exception {
  CouponPointsException(this.message);

  final String message;

  @override
  String toString() => 'CouponPointsException: $message';
}
