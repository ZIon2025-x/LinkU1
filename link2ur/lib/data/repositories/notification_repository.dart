import '../models/notification.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/logger.dart';

/// 通知仓库
/// 与iOS NotificationViewModel + 后端路由对齐
class NotificationRepository {
  NotificationRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 将 API 响应（可能是 List 或 Map）统一解析为 NotificationListResponse
  NotificationListResponse _parseNotificationResponse(dynamic data) {
    if (data is List) {
      return NotificationListResponse.fromList(data);
    }
    if (data is Map<String, dynamic>) {
      return NotificationListResponse.fromJson(data);
    }
    AppLogger.warning('Unexpected notification response type: ${data.runtimeType}');
    return const NotificationListResponse(
      notifications: [],
      total: 0,
      page: 1,
      pageSize: 20,
    );
  }

  /// 获取通知列表
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int pageSize = 20,
    String? type,
  }) async {
    final params = {
      'page': page,
      'page_size': pageSize,
      if (type != null) 'type': type,
    };
    final cacheKey =
        CacheManager.buildKey(CacheManager.prefixNotifications, params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return NotificationListResponse.fromJson(cached);
    }

    final response = await _apiService.get<dynamic>(
      ApiEndpoints.notifications,
      queryParameters: params,
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取通知列表失败');
    }

    // 缓存仅支持 Map；如果后端返回 List 则不缓存
    if (response.data is Map<String, dynamic>) {
      await _cache.set(cacheKey, response.data!, ttl: CacheManager.shortTTL);
    }

    return _parseNotificationResponse(response.data);
  }

  /// 获取带最近已读的通知
  Future<NotificationListResponse> getNotificationsWithRecentRead({
    int recentReadLimit = 10,
  }) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.notificationsWithRecentRead(limit: recentReadLimit),
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取通知列表失败');
    }

    return _parseNotificationResponse(response.data);
  }

  /// 标记通知已读
  Future<void> markAsRead(int notificationId) async {
    final response = await _apiService.post(
      ApiEndpoints.markNotificationRead(notificationId),
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '标记已读失败');
    }

    await _cache.invalidateNotificationsCache();
  }

  /// 标记所有通知已读
  Future<void> markAllAsRead() async {
    final response = await _apiService.post(
      ApiEndpoints.markAllNotificationsRead,
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '标记全部已读失败');
    }

    await _cache.invalidateNotificationsCache();
  }

  /// 获取未读通知数量
  Future<UnreadNotificationCount> getUnreadCount() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.unreadNotificationCount,
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取未读数量失败');
    }

    return UnreadNotificationCount.fromJson(response.data!);
  }

  /// 获取未读通知列表
  Future<NotificationListResponse> getUnreadNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.unreadNotifications,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取未读通知失败');
    }

    return _parseNotificationResponse(response.data);
  }

  /// 获取论坛通知
  Future<NotificationListResponse> getForumNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.forumNotifications,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取论坛通知失败');
    }

    return _parseNotificationResponse(response.data);
  }

  /// 上传设备Token
  Future<void> registerDeviceToken(String token) async {
    final response = await _apiService.post(
      ApiEndpoints.deviceToken,
      data: {'token': token},
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '注册设备Token失败');
    }
  }

  /// 删除设备Token
  Future<void> deleteDeviceToken() async {
    final response = await _apiService.delete(
      ApiEndpoints.deviceToken,
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '删除设备Token失败');
    }
  }
}

/// 通知异常
class NotificationException implements Exception {
  NotificationException(this.message);

  final String message;

  @override
  String toString() => 'NotificationException: $message';
}
