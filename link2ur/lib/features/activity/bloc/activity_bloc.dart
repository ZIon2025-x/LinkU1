import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../core/utils/cache_manager.dart';
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

/// 增强版申请事件 - 对标iOS applyToActivity(activityId:timeSlotId:preferredDeadline:isFlexibleTime:)
class ActivityApply extends ActivityEvent {
  const ActivityApply(
    this.activityId, {
    this.timeSlotId,
    this.preferredDeadline,
    this.isFlexibleTime = false,
  });

  final int activityId;
  final int? timeSlotId;
  final String? preferredDeadline;
  final bool isFlexibleTime;

  @override
  List<Object?> get props =>
      [activityId, timeSlotId, preferredDeadline, isFlexibleTime];
}

class ActivityLoadDetail extends ActivityEvent {
  const ActivityLoadDetail(this.activityId);

  final int activityId;

  @override
  List<Object?> get props => [activityId];
}

/// 加载服务时间段 - 对标iOS loadTimeSlots(serviceId:activityId:)
class ActivityLoadTimeSlots extends ActivityEvent {
  const ActivityLoadTimeSlots({
    required this.serviceId,
    required this.activityId,
  });

  final int serviceId;
  final int activityId;

  @override
  List<Object?> get props => [serviceId, activityId];
}

class ActivityApplyOfficial extends ActivityEvent {
  final int activityId;
  const ActivityApplyOfficial({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}

class ActivityCancelApplyOfficial extends ActivityEvent {
  final int activityId;
  const ActivityCancelApplyOfficial({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}

class ActivityLoadResult extends ActivityEvent {
  final int activityId;
  const ActivityLoadResult({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}

class ActivityToggleFavorite extends ActivityEvent {
  final int activityId;
  const ActivityToggleFavorite({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}

class ActivityLoadFavoriteStatus extends ActivityEvent {
  final int activityId;
  const ActivityLoadFavoriteStatus({required this.activityId});
  @override
  List<Object?> get props => [activityId];
}

// ==================== State ====================

enum OfficialApplyStatus { idle, applying, applied, full, error }

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
    this.timeSlots = const [],
    this.isLoadingTimeSlots = false,
    this.isLoadingMore = false,
    this.expert,
    this.officialApplyStatus = OfficialApplyStatus.idle,
    this.officialResult,
    this.isFavorited = false,
    this.isTogglingFavorite = false,
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
  final List<ServiceTimeSlot> timeSlots;
  final bool isLoadingTimeSlots;
  final bool isLoadingMore;

  /// 活动发布者的达人信息（对齐iOS viewModel.expert）
  final TaskExpert? expert;

  final OfficialApplyStatus officialApplyStatus;
  final OfficialActivityResult? officialResult;
  final bool isFavorited;
  final bool isTogglingFavorite;

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
    List<ServiceTimeSlot>? timeSlots,
    bool? isLoadingTimeSlots,
    bool? isLoadingMore,
    TaskExpert? expert,
    OfficialApplyStatus? officialApplyStatus,
    OfficialActivityResult? officialResult,
    bool clearOfficialResult = false,
    bool? isFavorited,
    bool? isTogglingFavorite,
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
      timeSlots: timeSlots ?? this.timeSlots,
      isLoadingTimeSlots: isLoadingTimeSlots ?? this.isLoadingTimeSlots,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      expert: expert ?? this.expert,
      officialApplyStatus: officialApplyStatus ?? this.officialApplyStatus,
      officialResult: clearOfficialResult ? null : (officialResult ?? this.officialResult),
      isFavorited: isFavorited ?? this.isFavorited,
      isTogglingFavorite: isTogglingFavorite ?? this.isTogglingFavorite,
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
        timeSlots,
        isLoadingTimeSlots,
        isLoadingMore,
        expert,
        officialApplyStatus,
        officialResult,
        isFavorited,
        isTogglingFavorite,
      ];
}

// ==================== Bloc ====================

class ActivityBloc extends Bloc<ActivityEvent, ActivityState> {
  ActivityBloc({
    required ActivityRepository activityRepository,
    TaskExpertRepository? taskExpertRepository,
  })  : _activityRepository = activityRepository,
        _taskExpertRepository = taskExpertRepository,
        super(const ActivityState()) {
    on<ActivityLoadRequested>(_onLoadRequested);
    on<ActivityLoadMore>(_onLoadMore);
    on<ActivityRefreshRequested>(_onRefresh);
    on<ActivityApply>(_onApply);
    on<ActivityLoadDetail>(_onLoadDetail);
    on<ActivityLoadTimeSlots>(_onLoadTimeSlots);
    on<ActivityApplyOfficial>(_onApplyOfficial);
    on<ActivityCancelApplyOfficial>(_onCancelApplyOfficial);
    on<ActivityLoadResult>(_onLoadResult);
    on<ActivityToggleFavorite>(_onToggleFavorite);
    on<ActivityLoadFavoriteStatus>(_onLoadFavoriteStatus);
  }

  final ActivityRepository _activityRepository;
  final TaskExpertRepository? _taskExpertRepository;

  Future<void> _onLoadRequested(
    ActivityLoadRequested event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(status: ActivityStatus.loading));

    try {
      final response = await _activityRepository.getActivities(
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
    // 防重复：正在加载中或无更多数据时跳过
    if (!state.hasMore || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = state.page + 1;
      final response = await _activityRepository.getActivities(
        page: nextPage,
      );

      emit(state.copyWith(
        activities: [...state.activities, ...response.activities],
        page: nextPage,
        hasMore: response.hasMore,
        isLoadingMore: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more activities', e);
      emit(state.copyWith(hasMore: false, isLoadingMore: false));
    }
  }

  Future<void> _onRefresh(
    ActivityRefreshRequested event,
    Emitter<ActivityState> emit,
  ) async {
    // 下拉刷新前失效缓存，确保获取最新数据
    await CacheManager.shared.invalidateActivitiesCache();

    try {
      final response = await _activityRepository.getActivities();

      emit(state.copyWith(
        status: ActivityStatus.loaded,
        activities: response.activities,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh activities', e);
      // 刷新失败时仍需 emit，以便 RefreshIndicator 的 firstWhere 完成、loading 立即停止
      emit(state.copyWith(errorMessage: e.toString()));
    }
  }

  /// 申请参加活动 - 增强版，支持时间段/灵活时间
  Future<void> _onApply(
    ActivityApply event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _activityRepository.applyActivity(
        event.activityId,
        timeSlotId: event.timeSlotId,
        preferredDeadline: event.preferredDeadline,
        isFlexibleTime: event.isFlexibleTime,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'registration_success',
      ));
      // 刷新列表和详情
      add(const ActivityRefreshRequested());
      if (state.activityDetail?.id == event.activityId) {
        add(ActivityLoadDetail(event.activityId));
      }
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'registration_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadDetail(
    ActivityLoadDetail event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(
      detailStatus: ActivityStatus.loading,
      officialApplyStatus: OfficialApplyStatus.idle,
      clearOfficialResult: true,
      isFavorited: false,
    ));

    try {
      final activity =
          await _activityRepository.getActivityById(event.activityId);
      emit(state.copyWith(
        detailStatus: ActivityStatus.loaded,
        activityDetail: activity,
      ));

      // 对齐iOS loadExpertInfo: 加载达人信息（名字、头像）
      if (activity.expertId.isNotEmpty && _taskExpertRepository != null) {
        try {
          final expert =
              await _taskExpertRepository.getExpertById(activity.expertId);
          emit(state.copyWith(expert: expert));
        } catch (e) {
          AppLogger.warning('Failed to load expert info', e);
        }
      }

      // 对齐iOS: 官方活动自动加载抽奖/申请结果
      if (activity.isOfficialActivity) {
        add(ActivityLoadResult(activityId: activity.id));
      }

      // 对齐iOS checkFavoriteStatus: 加载收藏状态
      add(ActivityLoadFavoriteStatus(activityId: activity.id));
    } catch (e) {
      AppLogger.error('Failed to load activity detail', e);
      emit(state.copyWith(
        detailStatus: ActivityStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// 加载时间段 - 对标iOS loadTimeSlots
  /// 只显示与该活动关联的时间段 (hasActivity == true && activityId 匹配)
  Future<void> _onLoadTimeSlots(
    ActivityLoadTimeSlots event,
    Emitter<ActivityState> emit,
  ) async {
    final repo = _taskExpertRepository;
    if (repo == null) return;

    emit(state.copyWith(isLoadingTimeSlots: true));

    try {
      final rawSlots =
          await repo.getServiceTimeSlots(event.serviceId);
      final allSlots =
          rawSlots.map((e) => ServiceTimeSlot.fromJson(e)).toList();

      // 只保留与该活动关联的时间段 - 对标iOS filter
      final activitySlots = allSlots
          .where((slot) =>
              slot.hasActivity == true && slot.activityId == event.activityId)
          .toList();

      emit(state.copyWith(
        isLoadingTimeSlots: false,
        timeSlots: activitySlots,
      ));
    } catch (e) {
      AppLogger.error('Failed to load time slots', e);
      emit(state.copyWith(
        isLoadingTimeSlots: false,
        timeSlots: const [],
      ));
    }
  }

  Future<void> _onApplyOfficial(
    ActivityApplyOfficial event,
    Emitter<ActivityState> emit,
  ) async {
    emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applying));
    try {
      await _activityRepository.applyOfficialActivity(event.activityId);
      emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.applied));
      // 刷新详情以更新名额计数，并加载结果
      add(ActivityLoadDetail(event.activityId));
    } on Exception catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('已满') || msg.contains('full') || msg.contains('no more')) {
        emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.full));
      } else {
        emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.error));
      }
    }
  }

  Future<void> _onCancelApplyOfficial(
    ActivityCancelApplyOfficial event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      await _activityRepository.cancelOfficialActivityApplication(event.activityId);
      emit(state.copyWith(officialApplyStatus: OfficialApplyStatus.idle));
      add(ActivityLoadDetail(event.activityId));
    } on Exception catch (e) {
      AppLogger.warning('Failed to cancel official activity application', e);
    }
  }

  Future<void> _onLoadResult(
    ActivityLoadResult event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final result = await _activityRepository.getOfficialActivityResult(event.activityId);
      emit(state.copyWith(officialResult: result));
    } on Exception {
      // ignore load errors
    }
  }

  Future<void> _onToggleFavorite(
    ActivityToggleFavorite event,
    Emitter<ActivityState> emit,
  ) async {
    if (state.isTogglingFavorite) return;
    emit(state.copyWith(isTogglingFavorite: true));
    try {
      await _activityRepository.toggleFavorite(event.activityId);
      emit(state.copyWith(
        isFavorited: !state.isFavorited,
        isTogglingFavorite: false,
      ));
    } catch (e) {
      AppLogger.warning('Failed to toggle favorite', e);
      emit(state.copyWith(isTogglingFavorite: false));
    }
  }

  Future<void> _onLoadFavoriteStatus(
    ActivityLoadFavoriteStatus event,
    Emitter<ActivityState> emit,
  ) async {
    try {
      final isFav = await _activityRepository.getFavoriteStatus(event.activityId);
      emit(state.copyWith(isFavorited: isFav));
    } catch (_) {}
  }
}
