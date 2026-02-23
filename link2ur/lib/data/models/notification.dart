import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/localized_string.dart';

/// 通知模型
/// 参考后端 NotificationOut
class AppNotification extends Equatable {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.content,
    this.titleEn,
    this.contentEn,
    this.relatedId,
    this.relatedType,
    this.isRead = false,
    this.taskId,
    this.variables,
    this.createdAt,
  });

  final int id;
  final String userId;
  final String type;
  final String title;
  final String content;
  final String? titleEn;
  final String? contentEn;
  final int? relatedId;
  final String? relatedType; // task_id, application_id
  final bool isRead;
  final int? taskId;
  final Map<String, dynamic>? variables;
  final DateTime? createdAt;

  /// 显示标题（根据 locale 选择 zh/en，title 为默认/中文）
  String displayTitle(Locale locale) =>
      localizedString(title, titleEn, title, locale);

  /// 显示内容（根据 locale 选择 zh/en，content 为默认/中文）
  String displayContent(Locale locale) =>
      localizedString(content, contentEn, content, locale);

  /// 通知类型图标名称
  String get typeIcon {
    switch (type) {
      case 'task_applied':
      case 'task_accepted':
      case 'task_completed':
      case 'task_confirmed':
      case 'task_cancelled':
        return 'task';
      case 'message':
        return 'message';
      case 'payment':
        return 'payment';
      case 'system':
        return 'system';
      default:
        return 'notification';
    }
  }

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      userId: json['user_id']?.toString() ?? '',
      type: json['type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      titleEn: json['title_en'] as String?,
      contentEn: json['content_en'] as String?,
      relatedId: json['related_id'] as int?,
      relatedType: json['related_type'] as String?,
      isRead: (json['is_read'] is int)
          ? (json['is_read'] as int) == 1
          : (json['is_read'] as bool? ?? false),
      taskId: json['task_id'] as int?,
      variables: json['variables'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'title': title,
      'content': content,
      'title_en': titleEn,
      'content_en': contentEn,
      'related_id': relatedId,
      'related_type': relatedType,
      'is_read': isRead ? 1 : 0,
      'task_id': taskId,
      'variables': variables,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      type: type,
      title: title,
      content: content,
      titleEn: titleEn,
      contentEn: contentEn,
      relatedId: relatedId,
      relatedType: relatedType,
      isRead: isRead ?? this.isRead,
      taskId: taskId,
      variables: variables,
      createdAt: createdAt,
    );
  }

  @override
  List<Object?> get props => [id, type, isRead, createdAt];
}

/// 通知列表响应
class NotificationListResponse {
  const NotificationListResponse({
    required this.notifications,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<AppNotification> notifications;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => notifications.length >= pageSize;

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
    // 后端不同接口可能返回 'items', 'notifications' 或其他键名
    final items = (json['items'] ?? json['notifications'] ?? json['data'])
        as List<dynamic>?;
    return NotificationListResponse(
      notifications: items
              ?.map((e) =>
                  AppNotification.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }

  /// 从裸 List 响应构建（后端有时直接返回列表而非包装对象）
  factory NotificationListResponse.fromList(List<dynamic> list) {
    return NotificationListResponse(
      notifications: list
          .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: list.length,
      page: 1,
      pageSize: 20,
    );
  }
}

/// 未读通知数量
class UnreadNotificationCount {
  const UnreadNotificationCount({
    required this.count,
    this.forumCount = 0,
  });

  final int count;
  final int forumCount;

  int get totalCount => count + forumCount;

  factory UnreadNotificationCount.fromJson(Map<String, dynamic> json) {
    return UnreadNotificationCount(
      count: json['unread_count'] as int? ?? json['count'] as int? ?? 0,
      forumCount: json['forum_count'] as int? ?? 0,
    );
  }
}
