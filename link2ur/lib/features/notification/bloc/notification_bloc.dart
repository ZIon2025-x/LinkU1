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

  Future<void> _onLoadRequested(
    NotificationLoadRequested event,
    Emitter<NotificationState> emit,
  ) async {
    emit(state.copyWith(status: NotificationStatus.loading));

    try {
      final response = await _notificationRepository.getNotifications(
        page: 1,
        type: event.type,
      );

      emit(state.copyWith(
        status: NotificationStatus.loaded,
        notifications: response.notifications,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
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
