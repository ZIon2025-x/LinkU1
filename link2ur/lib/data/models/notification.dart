import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
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
    this.relatedSecondaryId,
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
  // 辅助 id(migration 214):咨询类通知带 application_id,与 relatedId(task_id) 组合使用
  final int? relatedSecondaryId;
  final String? relatedType; // task_id / application_id / service_consultation / task_consultation / flea_market_consultation
  final bool isRead;
  final int? taskId;
  final Map<String, dynamic>? variables;
  final DateTime? createdAt;

  /// 是否是咨询类通知(按 related_type 判断)
  bool get isConsultationNotification =>
      relatedType == 'service_consultation' ||
      relatedType == 'task_consultation' ||
      relatedType == 'flea_market_consultation';

  /// 咨询路由用的 type 参数(service/task/flea_market,跟 task_chat_list_view 对齐)
  String? get consultationType {
    switch (relatedType) {
      case 'service_consultation':
        return 'service';
      case 'task_consultation':
        return 'task';
      case 'flea_market_consultation':
        return 'flea_market';
    }
    return null;
  }

  /// 显示标题（根据 locale 选择 zh/en，title 为默认/中文）
  String displayTitle(Locale locale) =>
      localizedString(title, titleEn, title, locale);

  /// 显示内容（根据 locale 选择 zh/en，content 为默认/中文）
  String displayContent(Locale locale) =>
      localizedString(content, contentEn, content, locale);

  /// 通知类型分类（用于图标和颜色区分）
  String get typeCategory {
    // 任务相关
    if (type.startsWith('task_')) return 'task';
    // 支付相关
    if (type.startsWith('payment') || type == 'wallet_earning' ||
        type == 'withdrawal') {
      return 'payment';
    }
    // 论坛互动
    if (type.startsWith('forum_like') || type == 'forum_feature_post' ||
        type == 'forum_pin_post') {
      return 'forum_like';
    }
    if (type.startsWith('forum_reply')) return 'forum_reply';
    if (type.startsWith('forum_')) return 'forum';
    // 排行榜
    if (type.startsWith('leaderboard_')) return 'leaderboard';
    // 消息
    if (type == 'message' || type == 'new_message') return 'message';
    // 系统/公告
    if (type == 'system' || type == 'announcement') return 'system';
    // 优惠券/积分
    if (type.startsWith('coupon') || type.startsWith('points')) return 'reward';
    return 'notification';
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
      relatedSecondaryId: json['related_secondary_id'] as int?,
      relatedType: json['related_type'] as String?,
      isRead: parseBool(json['is_read']),
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
      'related_secondary_id': relatedSecondaryId,
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
      relatedSecondaryId: relatedSecondaryId,
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
    this.hasMoreFromServer,
  });

  final List<AppNotification> notifications;
  final int total;
  final int page;
  final int pageSize;
  final bool? hasMoreFromServer;

  /// 优先使用后端返回的 has_more，回退到根据列表长度推断
  bool get hasMore => hasMoreFromServer ?? notifications.length >= pageSize;

  factory NotificationListResponse.fromJson(Map<String, dynamic> json) {
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
      hasMoreFromServer: json['has_more'] as bool?,
    );
  }

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
