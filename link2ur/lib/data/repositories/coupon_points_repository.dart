import '../models/coupon_points.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 积分优惠券仓库
/// 与iOS CouponPointsViewModel + 后端 coupon_points_routes 对齐
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

  /// 积分兑换优惠券
  Future<Map<String, dynamic>> redeemCoupon(int couponId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.redeemCoupon,
      data: {'coupon_id': couponId},
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '兑换优惠券失败');
    }

    return response.data!;
  }

  // ==================== 签到相关 ====================

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

  /// 获取签到状态
  Future<Map<String, dynamic>> getCheckInStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.checkInStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取签到状态失败');
    }

    return response.data!;
  }

  /// 获取签到奖励配置
  Future<List<Map<String, dynamic>>> getCheckInRewards() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.checkInRewards,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取奖励配置失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  // ==================== 优惠券相关 ====================

  /// 获取可用优惠券列表
  Future<List<Coupon>> getAvailableCoupons() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.availableCoupons,
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
    String? status,
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

  /// 领取优惠券
  Future<Map<String, dynamic>> claimCoupon(int couponId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.claimCoupon,
      data: {'coupon_id': couponId},
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '领取优惠券失败');
    }

    return response.data!;
  }

  /// 使用优惠券
  Future<Map<String, dynamic>> useCoupon(int couponId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.useCoupon(couponId),
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '使用优惠券失败');
    }

    return response.data!;
  }

  /// 验证优惠券可用性
  Future<Map<String, dynamic>> validateCoupon({
    required int couponId,
    int? taskId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.validateCoupon,
      data: {
        'coupon_id': couponId,
        if (taskId != null) 'task_id': taskId,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '验证优惠券失败');
    }

    return response.data!;
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

  /// 使用邀请码
  Future<Map<String, dynamic>> useInvitationCode(String code) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.useInvitationCode,
      data: {'code': code},
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '使用邀请码失败');
    }

    return response.data!;
  }

  /// 获取邀请码状态
  Future<Map<String, dynamic>> getInvitationStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.invitationStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取邀请状态失败');
    }

    return response.data!;
  }
}

/// 积分优惠券异常
class CouponPointsException extends AppException {
  const CouponPointsException(super.message);
}
