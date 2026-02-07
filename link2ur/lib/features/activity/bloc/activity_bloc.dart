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

class ActivityLoadDetail extends ActivityEvent {
  const ActivityLoadDetail(this.activityId);

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
    this.activityDetail,
    this.detailStatus = ActivityStatus.initial,
  });

  final ActivityStatus status;
  final List<Activity> activities;
  final int total;
  final int page;
  final bool hasMore;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;
  final Activity? activityDetail;
  final ActivityStatus detailStatus;

  bool get isLoading => status == ActivityStatus.loading;
  bool get isDetailLoading => detailStatus == ActivityStatus.loading;

  ActivityState copyWith({
    ActivityStatus? status,
    List<Activity>? activities,
    int? total,
    int? page,
    bool? hasMore,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
    Activity? activityDetail,
    ActivityStatus? detailStatus,
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
      activityDetail: activityDetail ?? this.activityDetail,
      detailStatus: detailStatus ?? this.detailStatus,
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
        activityDetail,
        detailStatus,
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
    on<ActivityLoadDetail>(_onLoadDetail);
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
      // 刷新列表和详情
      add(const ActivityRefreshRequested());
      if (state.activityDetail?.id == event.activityId) {
        add(ActivityLoadDetail(event.activityId));
      }
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '报名失败',
      ));
    }
  }

  Future<void> _onLoadDetail(
    ActivityLoadDetail event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(detailStatus: ActivityStatus.loading));

    try {
      final activity = await _activityRepository.getActivityById(event.activityId);
      emit(state.copyWith(
        detailStatus: ActivityStatus.loaded,
        activityDetail: activity,
      ));
    } catch (e) {
      AppLogger.error('Failed to load activity detail', e);
      emit(state.copyWith(
        detailStatus: ActivityStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
