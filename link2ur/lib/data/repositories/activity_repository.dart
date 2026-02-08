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
  Future<ActivityListResponse> getActivities({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? keyword,
  }) async {
    final params = {
      'page': page,
      'page_size': pageSize,
      if (status != null) 'status': status,
      if (keyword != null) 'keyword': keyword,
    };

    final cacheKey = keyword == null
        ? CacheManager.buildKey(CacheManager.prefixActivities, params)
        : null;

    if (cacheKey != null) {
      final cached = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return ActivityListResponse.fromJson(cached);
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.activities,
        queryParameters: params,
      );

      if (!response.isSuccess || response.data == null) {
        throw ActivityException(response.message ?? '获取活动列表失败');
      }

      if (cacheKey != null) {
        await _cache.set(cacheKey, response.data!, ttl: CacheManager.shortTTL);
      }

      return ActivityListResponse.fromJson(response.data!);
    } catch (e) {
      if (cacheKey != null) {
        final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
        if (stale != null) return ActivityListResponse.fromJson(stale);
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

  /// 申请参加活动
  Future<Map<String, dynamic>> applyActivity(
    int activityId, {
    String? preferredTimeSlot,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.applyActivity(activityId),
      data: {
        if (preferredTimeSlot != null)
          'preferred_time_slot': preferredTimeSlot,
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
  Future<ActivityListResponse> getMyActivities({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myActivities,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ActivityException(response.message ?? '获取我的活动失败');
    }

    return ActivityListResponse.fromJson(response.data!);
  }
}

/// 活动异常
class ActivityException extends AppException {
  const ActivityException(super.message);
}
