import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/activity.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class ActivityEvent extends Equatable {
  const ActivityEvent();

  @override
  List<Object?> get props => [];
}

class ActivityLoadRequested extends ActivityEvent {
  const ActivityLoadRequested({this.status});

  final String? status;

  @override
  List<Object?> get props => [status];
}

class ActivityLoadMore extends ActivityEvent {
  const ActivityLoadMore();
}

class ActivityRefreshRequested extends ActivityEvent {
  const ActivityRefreshRequested();
}

class ActivityApply extends ActivityEvent {
  const ActivityApply(this.activityId);

  final int activityId;

  @override
  List<Object?> get props => [activityId];
}

// ==================== State ====================

enum ActivityStatus { initial, loading, loaded, error }

class ActivityState extends Equatable {
  const ActivityState({
    this.status = ActivityStatus.initial,
    this.activities = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final ActivityStatus status;
  final List<Activity> activities;
  final int total;
  final int page;
  final bool hasMore;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  bool get isLoading => status == ActivityStatus.loading;

  ActivityState copyWith({
    ActivityStatus? status,
    List<Activity>? activities,
    int? total,
    int? page,
    bool? hasMore,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return ActivityState(
      status: status ?? this.status,
      activities: activities ?? this.activities,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        activities,
        total,
        page,
        hasMore,
        errorMessage,
        isSubmitting,
        actionMessage,
      ];
}

// ==================== Bloc ====================

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc({required ActivityRepository activityRepository})
      : _activityRepository = activityRepository,
        super(const ActivityState()) {
    on<ActivityLoadRequested>(_onLoadRequested);
    on<ActivityLoadMore>(_onLoadMore);
    on<ActivityRefreshRequested>(_onRefresh);
    on<ActivityApply>(_onApply);
  }

  final ActivityRepository _activityRepository;

  Future<void> _onLoadRequested(
    ActivityLoadRequested event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(status: ActivityStatus.loading));

    try {
      final response = await _activityRepository.getActivities(
        page: 1,
        status: event.status,
      );

      emit(state.copyWith(
        status: ActivityStatus.loaded,
        activities: response.activities,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load activities', e);
      emit(state.copyWith(
        status: ActivityStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMore(
    ActivityLoadMore event,
    Emitter<ActivityState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final response = await _activityRepository.getActivities(
        page: nextPage,
      );

      emit(state.copyWith(
        activities: [...state.activities, ...response.activities],
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more activities', e);
    }
  }

  Future<void> _onRefresh(
    ActivityRefreshRequested event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final response = await _activityRepository.getActivities(page: 1);

      emit(state.copyWith(
        status: ActivityStatus.loaded,
        activities: response.activities,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh activities', e);
    }
  }

  Future<void> _onApply(
    ActivityApply event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _activityRepository.applyActivity(event.activityId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '报名成功',
      ));
      // 刷新列表
      add(const ActivityRefreshRequested());
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '报名失败',
      ));
    }
  }
}
