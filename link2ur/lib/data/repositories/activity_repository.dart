import '../models/activity.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 活动仓库
/// 参考iOS APIService+Endpoints.swift 活动相关
class ActivityRepository {
  ActivityRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取活动列表
  Future<ActivityListResponse> getActivities({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? keyword,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.activities,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (status != null) 'status': status,
        if (keyword != null) 'keyword': keyword,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ActivityException(response.message ?? '获取活动列表失败');
    }

    return ActivityListResponse.fromJson(response.data!);
  }

  /// 获取活动详情
  Future<Activity> getActivityById(int id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.activityById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw ActivityException(response.message ?? '获取活动详情失败');
    }

    return Activity.fromJson(response.data!);
  }

  /// 申请参加活动
  Future<Map<String, dynamic>> applyActivity(
    int activityId, {
    String? preferredTimeSlot,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.applyActivity(activityId),
      data: {
        if (preferredTimeSlot != null) 'preferred_time_slot': preferredTimeSlot,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ActivityException(response.message ?? '申请活动失败');
    }

    return response.data!;
  }
}

/// 活动异常
class ActivityException implements Exception {
  ActivityException(this.message);

  final String message;

  @override
  String toString() => 'ActivityException: $message';
}
