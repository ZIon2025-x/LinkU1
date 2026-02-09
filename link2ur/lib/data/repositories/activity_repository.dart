import '../models/activity.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 活动仓库
/// 与iOS ActivityViewModel + 后端路由对齐
class ActivityRepository {
  ActivityRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 获取活动列表
  /// 后端使用 limit/offset 分页，返回 JSON 数组 (List<ActivityOut>)
  Future<ActivityListResponse> getActivities({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? keyword,
  }) async {
    final offset = (page - 1) * pageSize;
    final params = {
      'limit': pageSize,
      'offset': offset,
      if (status != null) 'status': status,
      if (keyword != null) 'keyword': keyword,
    };

    final cacheKey = keyword == null
        ? CacheManager.buildKey(CacheManager.prefixActivities, params)
        : null;

    if (cacheKey != null) {
      final cached = _cache.get<List<dynamic>>(cacheKey);
      if (cached != null) {
        return ActivityListResponse.fromList(cached, page: page, pageSize: pageSize);
      }
    }

    try {
      // 后端 /api/activities 返回 List<ActivityOut>（JSON 数组）
      final response = await _apiService.get(
        ApiEndpoints.activities,
        queryParameters: params,
      );

      if (!response.isSuccess || response.data == null) {
        throw ActivityException(response.message ?? '获取活动列表失败');
      }

      final data = response.data;
      final List<dynamic> listData;

      if (data is List<dynamic>) {
        listData = data;
      } else if (data is Map<String, dynamic>) {
        // 兼容：如果后端后续改为分页格式
        return ActivityListResponse.fromJson(data, page: page, pageSize: pageSize);
      } else {
        throw ActivityException('活动列表返回格式异常');
      }

      if (cacheKey != null) {
        await _cache.set(cacheKey, listData, ttl: CacheManager.shortTTL);
      }

      return ActivityListResponse.fromList(listData, page: page, pageSize: pageSize);
    } catch (e) {
      if (cacheKey != null) {
        final stale = _cache.getStale<List<dynamic>>(cacheKey);
        if (stale != null) {
          return ActivityListResponse.fromList(stale, page: page, pageSize: pageSize);
        }
      }
      rethrow;
    }
  }

  /// 获取活动详情
  Future<Activity> getActivityById(int id) async {
    final cacheKey = '${CacheManager.prefixActivityDetail}$id';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return Activity.fromJson(cached);

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.activityById(id),
      );

      if (!response.isSuccess || response.data == null) {
        throw ActivityException(response.message ?? '获取活动详情失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.defaultTTL);
      return Activity.fromJson(response.data!);
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) return Activity.fromJson(stale);
      rethrow;
    }
  }

  /// 申请参加活动 - 对标iOS applyToActivity
  Future<Map<String, dynamic>> applyActivity(
    int activityId, {
    int? timeSlotId,
    String? preferredDeadline,
    bool isFlexibleTime = false,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.applyActivity(activityId),
      data: {
        if (timeSlotId != null) 'time_slot_id': timeSlotId,
        if (preferredDeadline != null)
          'preferred_deadline': preferredDeadline,
        'is_flexible_time': isFlexibleTime,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ActivityException(response.message ?? '申请活动失败');
    }

    // 申请后失效缓存
    await _cache.remove('${CacheManager.prefixActivityDetail}$activityId');
    await _cache.invalidateActivitiesCache();

    return response.data!;
  }

  /// 收藏/取消收藏活动
  Future<void> toggleFavorite(int activityId) async {
    final response = await _apiService.post(
      ApiEndpoints.activityFavorite(activityId),
    );

    if (!response.isSuccess) {
      throw ActivityException(response.message ?? '操作失败');
    }
  }

  /// 获取活动收藏状态
  Future<bool> getFavoriteStatus(int activityId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.activityFavoriteStatus(activityId),
    );

    if (!response.isSuccess || response.data == null) {
      return false;
    }

    return response.data!['is_favorite'] as bool? ?? false;
  }

  /// 获取我参与的活动
  /// 后端返回 {"success": true, "data": {"activities": [...], "total": ..., ...}}
  Future<ActivityListResponse> getMyActivities({
    int page = 1,
    int pageSize = 20,
  }) async {
    final offset = (page - 1) * pageSize;
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myActivities,
      queryParameters: {
        'limit': pageSize,
        'offset': offset,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ActivityException(response.message ?? '获取我的活动失败');
    }

    final data = response.data!;
    // 后端嵌套在 data 字段中
    final innerData = data['data'] as Map<String, dynamic>? ?? data;
    return ActivityListResponse.fromJson(innerData, page: page, pageSize: pageSize);
  }
}

/// 活动异常
class ActivityException extends AppException {
  const ActivityException(super.message);
}
