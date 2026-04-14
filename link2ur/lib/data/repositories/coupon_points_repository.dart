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
      throw CouponPointsException(response.errorCode ?? response.message ?? '获取积分账户失败', code: response.errorCode);
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
      throw CouponPointsException(response.errorCode ?? response.message ?? '获取交易记录失败', code: response.errorCode);
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
      throw CouponPointsException(response.errorCode ?? response.message ?? '兑换优惠券失败', code: response.errorCode);
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
      throw CouponPointsException(response.errorCode ?? response.message ?? '签到失败', code: response.errorCode);
    }

    return response.data!;
  }

  /// 获取签到状态
  Future<Map<String, dynamic>> getCheckInStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.checkInStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.errorCode ?? response.message ?? '获取签到状态失败', code: response.errorCode);
    }

    return response.data!;
  }

  /// 获取签到奖励配置
  Future<List<Map<String, dynamic>>> getCheckInRewards() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.checkInRewards,
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.errorCode ?? response.message ?? '获取奖励配置失败', code: response.errorCode);
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
      throw CouponPointsException(response.errorCode ?? response.message ?? '获取优惠券失败', code: response.errorCode);
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items
        .map((e) => Coupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取我的优惠券
  ///
  /// 当传入 [taskId] 时，后端会对每张券做适用性校验，
  /// 返回的 JSON 包含 `applicable` (bool) 和 `inapplicable_reason` (String?)。
  Future<List<UserCoupon>> getMyCoupons({
    String? status,
    int? taskId,
  }) async {
    // 后端返回 {"data": [...]}（coupon_points_routes.py）
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myCoupons,
      queryParameters: {
        if (status != null) 'status': status,
        if (taskId != null) 'task_id': taskId,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.errorCode ?? response.message ?? '获取我的优惠券失败', code: response.errorCode);
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items
        .map((e) => UserCoupon.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 领取优惠券（按优惠券 ID）
  Future<Map<String, dynamic>> claimCoupon(int couponId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.claimCoupon,
      data: {'coupon_id': couponId},
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.errorCode ?? response.message ?? '领取优惠券失败', code: response.errorCode);
    }

    return response.data!;
  }

  /// 凭兑换码领取优惠券（对标 iOS claimCoupon(couponId: nil, promotionCode: code)）
  Future<Map<String, dynamic>> claimCouponByCode(String promotionCode) async {
    final code = promotionCode.trim();
    if (code.isEmpty) {
      throw const CouponPointsException('请输入兑换码');
    }
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.claimCoupon,
      data: {'promotion_code': code},
    );

    if (!response.isSuccess || response.data == null) {
      throw CouponPointsException(response.errorCode ?? response.message ?? '兑换码无效或已失效', code: response.errorCode);
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
      throw CouponPointsException(response.errorCode ?? response.message ?? '验证邀请码失败', code: response.errorCode);
    }

    return response.data!;
  }
}

/// 积分优惠券异常
class CouponPointsException extends AppException {
  const CouponPointsException(super.message, {super.code});
}
