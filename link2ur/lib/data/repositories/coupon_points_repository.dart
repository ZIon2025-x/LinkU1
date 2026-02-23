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
    // 后端使用 page + limit 分页（coupon_points_routes.py）
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.pointsTransactions,
      queryParameters: {
        'page': page,
        'limit': pageSize,
        if (type != null) 'type': type,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取交易记录失败');
    }

    // 后端返回 "data" key（非 "items"）
    final items = response.data!['data'] as List<dynamic>? ?? [];
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
  /// 返回 API 原始响应（含 success, already_checked, check_in_date, consecutive_days, reward, message）
  Future<Map<String, dynamic>> checkIn() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.checkIn,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '签到失败');
    }

    return response.data!;
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
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.checkInRewards,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取奖励配置失败');
    }

    final rewards = response.data!['rewards'] as List<dynamic>? ?? [];
    return rewards.map((e) => e as Map<String, dynamic>).toList();
  }

  // ==================== 优惠券相关 ====================

  /// 获取可用优惠券列表
  Future<List<Coupon>> getAvailableCoupons() async {
    // 后端返回 {"data": [...]}（coupon_points_routes.py）
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.availableCoupons,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取优惠券失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items
        .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取我的优惠券
  Future<List<UserCoupon>> getMyCoupons({
    String? status,
  }) async {
    // 后端返回 {"data": [...]}（coupon_points_routes.py）
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myCoupons,
      queryParameters: {
        if (status != null) 'status': status,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '获取我的优惠券失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items
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
  Future<Map<String, dynamic>> useCoupon({
    required int userCouponId,
    required int taskId,
    required int orderAmount,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.useCoupon,
      data: {
        'user_coupon_id': userCouponId,
        'task_id': taskId,
        'order_amount': orderAmount,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '使用优惠券失败');
    }

    return response.data!;
  }

  /// 验证优惠券可用性
  Future<Map<String, dynamic>> validateCoupon({
    required String couponCode,
    required int orderAmount,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.validateCoupon,
      data: {
        'coupon_code': couponCode,
        'order_amount': orderAmount,
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

  /// 验证邀请码（后端无独立"使用"接口，邀请码在注册时自动使用）
  Future<Map<String, dynamic>> useInvitationCode(String code) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.validateInvitationCode,
      data: {'code': code},
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.message ?? '邀请码无效');
    }

    return response.data!;
  }
}

/// 积分优惠券异常
class CouponPointsException extends AppException {
  const CouponPointsException(super.message);
}
