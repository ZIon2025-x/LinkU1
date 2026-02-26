import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/notification.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/services/websocket_service.dart';
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

/// 开始轮询未读数（对齐 iOS 60 秒定时刷新，不依赖后端 WebSocket 推送）
class NotificationStartPolling extends NotificationEvent {
  const NotificationStartPolling();
}

/// 停止轮询（登出时调用）
class NotificationStopPolling extends NotificationEvent {
  const NotificationStopPolling();
}

/// 若列表已加载则刷新（系统通知 + 互动通知实时更新）
class NotificationRefreshListIfLoaded extends NotificationEvent {
  const NotificationRefreshListIfLoaded();
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
    on<NotificationStartPolling>(_onStartPolling);
    on<NotificationStopPolling>(_onStopPolling);
    on<NotificationRefreshListIfLoaded>(_onRefreshListIfLoaded);

    // 监听 WebSocket：新通知时刷新未读数 + 若列表已打开则刷新列表（系统/互动通知实时更新）
    _wsSubscription = WebSocketService.instance.messageStream.listen((wsMessage) {
      if (wsMessage.isNotification) {
        add(const NotificationLoadUnreadNotificationCount());
        add(const NotificationRefreshListIfLoaded());
      }
    });
  }

  final NotificationRepository _notificationRepository;
  StreamSubscription<WebSocketMessage>? _wsSubscription;
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 60);

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    _pollingTimer?.cancel();
    _pollingTimer = null;
    return super.close();
  }

  void _onStartPolling(
    NotificationStartPolling event,
    Emitter<NotificationState> emit,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      add(const NotificationLoadUnreadNotificationCount());
      add(const NotificationRefreshListIfLoaded());
    });
  }

  void _onRefreshListIfLoaded(
    NotificationRefreshListIfLoaded event,
    Emitter<NotificationState> emit,
  ) {
    if (state.status == NotificationStatus.loaded && state.selectedType != null) {
      add(NotificationLoadRequested(type: state.selectedType));
    } else if (state.status == NotificationStatus.loaded) {
      // 无 selectedType 时刷新系统消息（默认 Tab）
      add(const NotificationLoadRequested(type: 'system'));
    }
  }

  void _onStopPolling(
    NotificationStopPolling event,
    Emitter<NotificationState> emit,
  ) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

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
          
        );
        // 再加载系统通知中的排行榜部分
        final systemResponse = await _notificationRepository.getNotifications(
          
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
    // 1. 乐观更新：立即更新列表与未读数，不等待后端
    final prev = state.unreadCount;
    final updatedList = state.notifications.map((n) {
      if (n.id == event.notificationId) {
        return n.copyWith(isRead: true);
      }
      return n;
    }).toList();

    AppNotification? target;
    for (final n in state.notifications) {
      if (n.id == event.notificationId) {
        target = n;
        break;
      }
    }
    final isInteraction = target != null && _isInteractionType(target.type);
    final newUnread = isInteraction
        ? UnreadNotificationCount(
            count: prev.count,
            forumCount: prev.forumCount > 0 ? prev.forumCount - 1 : 0,
          )
        : UnreadNotificationCount(
            count: prev.count > 0 ? prev.count - 1 : 0,
            forumCount: prev.forumCount,
          );

    emit(state.copyWith(notifications: updatedList, unreadCount: newUnread));

    // 2. 异步请求后端，不阻塞 UI；失败仅打日志，下次轮询会拉回正确未读数
    _notificationRepository.markAsRead(event.notificationId).catchError((e) {
      AppLogger.error('Failed to mark notification as read', e);
    });
  }

  Future<void> _onMarkAllAsRead(
    NotificationMarkAllAsRead event,
    Emitter<NotificationState> emit,
  ) async {
    // 1. 乐观更新：立即全部已读、未读数清零，不等待后端
    final updatedList = state.notifications
        .map((n) => n.copyWith(isRead: true))
        .toList();

    emit(state.copyWith(
      notifications: updatedList,
      unreadCount: const UnreadNotificationCount(count: 0),
    ));

    // 2. 异步请求后端，不阻塞 UI；失败仅打日志，下次轮询会拉回正确未读数
    _notificationRepository.markAllAsRead().catchError((e) {
      AppLogger.error('Failed to mark all as read', e);
    });
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

