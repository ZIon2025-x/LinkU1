import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/notification.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class NotificationEvent extends Equatable {
  const NotificationEvent();

  @override
  List<Object?> get props => [];
}

class NotificationLoadRequested extends NotificationEvent {
  const NotificationLoadRequested({this.type});

  final String? type;

  @override
  List<Object?> get props => [type];
}

class NotificationLoadMore extends NotificationEvent {
  const NotificationLoadMore();
}

class NotificationMarkAsRead extends NotificationEvent {
  const NotificationMarkAsRead(this.notificationId);

  final int notificationId;

  @override
  List<Object?> get props => [notificationId];
}

class NotificationMarkAllAsRead extends NotificationEvent {
  const NotificationMarkAllAsRead();
}

class NotificationLoadUnreadNotificationCount extends NotificationEvent {
  const NotificationLoadUnreadNotificationCount();
}

// ==================== State ====================

enum NotificationStatus { initial, loading, loaded, error }

class NotificationState extends Equatable {
  const NotificationState({
    this.status = NotificationStatus.initial,
    this.notifications = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.unreadCount = const UnreadNotificationCount(count: 0),
    this.errorMessage,
    this.selectedType,
  });

  final NotificationStatus status;
  final List<AppNotification> notifications;
  final int total;
  final int page;
  final bool hasMore;
  final UnreadNotificationCount unreadCount;
  final String? errorMessage;
  final String? selectedType;

  bool get isLoading => status == NotificationStatus.loading;
  bool get hasUnread => unreadCount.totalCount > 0;

  NotificationState copyWith({
    NotificationStatus? status,
    List<AppNotification>? notifications,
    int? total,
    int? page,
    bool? hasMore,
    UnreadNotificationCount? unreadCount,
    String? errorMessage,
    String? selectedType,
  }) {
    return NotificationState(
      status: status ?? this.status,
      notifications: notifications ?? this.notifications,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      unreadCount: unreadCount ?? this.unreadCount,
      errorMessage: errorMessage,
      selectedType: selectedType ?? this.selectedType,
    );
  }

  @override
  List<Object?> get props => [
        status,
        notifications,
        total,
        page,
        hasMore,
        unreadCount,
        errorMessage,
        selectedType,
      ];
}

// ==================== Bloc ====================

class NotificationBloc extends Bloc<NotificationEvent, NotificationState> {
  NotificationBloc(
      {required NotificationRepository notificationRepository})
      : _notificationRepository = notificationRepository,
        super(const NotificationState()) {
    on<NotificationLoadRequested>(_onLoadRequested);
    on<NotificationLoadMore>(_onLoadMore);
    on<NotificationMarkAsRead>(_onMarkAsRead);
    on<NotificationMarkAllAsRead>(_onMarkAllAsRead);
    on<NotificationLoadUnreadNotificationCount>(_onLoadUnreadNotificationCount);
  }

  final NotificationRepository _notificationRepository;

  /// 互动消息类型前缀（论坛 + 排行榜）
  static const _interactionTypePrefixes = ['forum_', 'leaderboard_'];

  /// 判断是否为互动消息类型
  static bool _isInteractionType(String type) {
    return _interactionTypePrefixes.any((prefix) => type.startsWith(prefix));
  }

  /// 判断是否为系统消息类型（非互动类型）
  static bool _isSystemType(String type) {
    return !_isInteractionType(type);
  }

  /// 根据请求的类型过滤通知列表
  List<AppNotification> _filterNotifications(
    List<AppNotification> notifications,
    String? type,
  ) {
    if (type == 'interaction') {
      // 互动消息：只保留 forum_* 和 leaderboard_* 类型
      return notifications.where((n) => _isInteractionType(n.type)).toList();
    } else if (type == 'system') {
      // 系统消息：排除 forum_* 和 leaderboard_* 类型
      return notifications.where((n) => _isSystemType(n.type)).toList();
    }
    return notifications;
  }

  Future<void> _onLoadRequested(
    NotificationLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(status: NotificationStatus.loading));

    try {
      NotificationListResponse response;

      if (event.type == 'interaction') {
        // 互动消息：合并论坛通知 + 排行榜相关的系统通知
        // 先加载论坛通知
        final forumResponse = await _notificationRepository.getForumNotifications(
          page: 1,
        );
        // 再加载系统通知中的排行榜部分
        final systemResponse = await _notificationRepository.getNotifications(
          page: 1,
        );

        // 合并：论坛通知 + 系统通知中 leaderboard_* 类型
        final leaderboardNotifications = systemResponse.notifications
            .where((n) => n.type.startsWith('leaderboard_'))
            .toList();

        final allInteraction = [
          ...forumResponse.notifications,
          ...leaderboardNotifications,
        ];

        // 按时间排序（最新在前）
        allInteraction.sort((a, b) {
          final aTime = a.createdAt ?? DateTime(2000);
          final bTime = b.createdAt ?? DateTime(2000);
          return bTime.compareTo(aTime);
        });

        response = NotificationListResponse(
          notifications: allInteraction,
          total: allInteraction.length,
          page: 1,
          pageSize: 20,
        );
      } else {
        // 系统消息或全部
        response = await _notificationRepository.getNotifications(
          page: 1,
          type: event.type,
        );
      }

      // 客户端二次过滤确保数据干净
      final filtered = _filterNotifications(response.notifications, event.type);

      emit(state.copyWith(
        status: NotificationStatus.loaded,
        notifications: filtered,
        total: filtered.length,
        page: 1,
        hasMore: event.type == 'interaction' ? false : response.hasMore,
        selectedType: event.type,
      ));
    } catch (e) {
      AppLogger.error('Failed to load notifications', e);
      emit(state.copyWith(
        status: NotificationStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMore(
    NotificationLoadMore event,
    Emitter<NotificationState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final response = await _notificationRepository.getNotifications(
        page: nextPage,
        type: state.selectedType,
      );

      emit(state.copyWith(
        notifications: [
          ...state.notifications,
          ...response.notifications,
        ],
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more notifications', e);
      emit(state.copyWith(hasMore: false));
    }
  }

  Future<void> _onMarkAsRead(
    NotificationMarkAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.markAsRead(event.notificationId);

      final updatedList = state.notifications.map((n) {
        if (n.id == event.notificationId) {
          return n.copyWith(isRead: true);
        }
        return n;
      }).toList();

      emit(state.copyWith(notifications: updatedList));

      // 更新未读数
      add(const NotificationLoadUnreadNotificationCount());
    } catch (e) {
      AppLogger.error('Failed to mark notification as read', e);
    }
  }

  Future<void> _onMarkAllAsRead(
    NotificationMarkAllAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      await _notificationRepository.markAllAsRead();

      final updatedList = state.notifications
          .map((n) => n.copyWith(isRead: true))
          .toList();

      emit(state.copyWith(
        notifications: updatedList,
        unreadCount: const UnreadNotificationCount(count: 0),
      ));
    } catch (e) {
      AppLogger.error('Failed to mark all as read', e);
    }
  }

  Future<void> _onLoadUnreadNotificationCount(
    NotificationLoadUnreadNotificationCount event,
    Emitter<NotificationState> emit,
  ) async {
    try {
      final unreadCount =
          await _notificationRepository.getUnreadCount();
      emit(state.copyWith(unreadCount: unreadCount));
    } catch (e) {
      AppLogger.error('Failed to load unread count', e);
    }
  }
}
