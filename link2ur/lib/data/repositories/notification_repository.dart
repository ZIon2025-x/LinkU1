import '../models/notification.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 通知仓库
/// 参考iOS APIService+Endpoints.swift 通知相关
class NotificationRepository {
  NotificationRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取通知列表
  Future<NotificationListResponse> getNotifications({
    int page = 1,
    int pageSize = 20,
    String? type,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.notifications,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (type != null) 'type': type,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取通知列表失败');
    }

    return NotificationListResponse.fromJson(response.data!);
  }

  /// 标记通知已读
  Future<void> markAsRead(int notificationId) async {
    final response = await _apiService.post(
      ApiEndpoints.markNotificationRead(notificationId),
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '标记已读失败');
    }
  }

  /// 标记所有通知已读
  Future<void> markAllAsRead() async {
    final response = await _apiService.post(
      ApiEndpoints.markAllNotificationsRead,
    );

    if (!response.isSuccess) {
      throw NotificationException(response.message ?? '标记全部已读失败');
    }
  }

  /// 获取未读通知数量
  Future<UnreadNotificationCount> getUnreadCount() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.unreadCount,
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取未读数量失败');
    }

    return UnreadNotificationCount.fromJson(response.data!);
  }

  /// 获取论坛通知
  Future<NotificationListResponse> getForumNotifications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumNotifications,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw NotificationException(response.message ?? '获取论坛通知失败');
    }

    return NotificationListResponse.fromJson(response.data!);
  }
}

/// 通知异常
class NotificationException implements Exception {
  NotificationException(this.message);

  final String message;

  @override
  String toString() => 'NotificationException: $message';
}
