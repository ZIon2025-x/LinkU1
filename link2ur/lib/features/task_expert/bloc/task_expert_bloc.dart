import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class TaskExpertEvent extends Equatable {
  const TaskExpertEvent();

  @override
  List<Object?> get props => [];
}

class TaskExpertLoadRequested extends TaskExpertEvent {
  const TaskExpertLoadRequested({this.skill});

  final String? skill;

  @override
  List<Object?> get props => [skill];
}

class TaskExpertLoadMore extends TaskExpertEvent {
  const TaskExpertLoadMore();
}

class TaskExpertRefreshRequested extends TaskExpertEvent {
  const TaskExpertRefreshRequested();
}

class TaskExpertLoadDetail extends TaskExpertEvent {
  const TaskExpertLoadDetail(this.expertId);

  final String expertId;

  @override
  List<Object?> get props => [expertId];
}

class TaskExpertApplyService extends TaskExpertEvent {
  const TaskExpertApplyService(this.serviceId, {this.message});

  final int serviceId;
  final String? message;

  @override
  List<Object?> get props => [serviceId, message];
}

class TaskExpertLoadServiceDetail extends TaskExpertEvent {
  const TaskExpertLoadServiceDetail(this.serviceId, {this.forceRefresh = false});

  final int serviceId;
  final bool forceRefresh;

  @override
  List<Object?> get props => [serviceId, forceRefresh];
}

class TaskExpertLoadMyApplications extends TaskExpertEvent {
  const TaskExpertLoadMyApplications();
}

class TaskExpertSearchRequested extends TaskExpertEvent {
  const TaskExpertSearchRequested(this.keyword);

  final String keyword;

  @override
  List<Object?> get props => [keyword];
}

/// 加载服务评价
class TaskExpertLoadServiceReviews extends TaskExpertEvent {
  const TaskExpertLoadServiceReviews(this.serviceId);

  final int serviceId;

  @override
  List<Object?> get props => [serviceId];
}

/// 加载达人评价
class TaskExpertLoadExpertReviews extends TaskExpertEvent {
  const TaskExpertLoadExpertReviews(this.expertId, {this.loadMore = false});

  final String expertId;
  final bool loadMore;

  @override
  List<Object?> get props => [expertId, loadMore];
}


/// 加载服务时间段
class TaskExpertLoadServiceTimeSlots extends TaskExpertEvent {
  const TaskExpertLoadServiceTimeSlots(this.serviceId);

  final int serviceId;

  @override
  List<Object?> get props => [serviceId];
}

/// 达人筛选条件改变（类型 + 城市）
class TaskExpertFilterChanged extends TaskExpertEvent {
  const TaskExpertFilterChanged({this.category, this.city});

  /// 达人类型，'all' 或 null 表示全部
  final String? category;

  /// 城市，'all' 或 null 表示全部
  final String? city;

  @override
  List<Object?> get props => [category, city];
}

/// 加载达人收到的申请列表
class TaskExpertLoadExpertApplications extends TaskExpertEvent {
  const TaskExpertLoadExpertApplications();
}

/// 达人同意申请
class TaskExpertApproveApplication extends TaskExpertEvent {
  const TaskExpertApproveApplication(this.applicationId);

  final int applicationId;

  @override
  List<Object?> get props => [applicationId];
}

/// 达人拒绝申请
class TaskExpertRejectApplication extends TaskExpertEvent {
  const TaskExpertRejectApplication(this.applicationId, {this.reason});

  final int applicationId;
  final String? reason;

  @override
  List<Object?> get props => [applicationId, reason];
}

/// 达人再次议价
class TaskExpertCounterOffer extends TaskExpertEvent {
  const TaskExpertCounterOffer(this.applicationId, {required this.counterPrice, this.message});

  final int applicationId;
  final double counterPrice;
  final String? message;

  @override
  List<Object?> get props => [applicationId, counterPrice, message];
}

/// 增强版申请服务事件（支持议价/时间段/期限/灵活时间）
class TaskExpertApplyServiceEnhanced extends TaskExpertEvent {
  const TaskExpertApplyServiceEnhanced(
    this.serviceId, {
    this.message,
    this.counterPrice,
    this.timeSlotId,
    this.preferredDeadline,
    this.isFlexibleTime = false,
  });

  final int serviceId;
  final String? message;
  final double? counterPrice;
  final int? timeSlotId;
  final String? preferredDeadline;
  final bool isFlexibleTime;

  @override
  List<Object?> get props =>
      [serviceId, message, counterPrice, timeSlotId, preferredDeadline, isFlexibleTime];
}

/// 加载我的达人申请状态 — 对标 iOS getMyExpertApplication
class TaskExpertLoadMyExpertApplicationStatus extends TaskExpertEvent {
  const TaskExpertLoadMyExpertApplicationStatus();
}

// ==================== State ====================

enum TaskExpertStatus { initial, loading, loaded, error }

class TaskExpertState extends Equatable {
  const TaskExpertState({
    this.status = TaskExpertStatus.initial,
    this.experts = const [],
    this.selectedExpert,
    this.services = const [],
    this.expertActivities = const [],
    this.isLoadingExpertActivities = false,
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
    this.serviceDetail,
    this.selectedService,
    this.applications = const [],
    this.expertApplications = const [],
    this.searchResults = const [],
    this.reviews = const [],
    this.isLoadingReviews = false,
    this.reviewsTotal = 0,
    this.hasMoreReviews = true,
    this.timeSlots = const [],
    this.isLoadingTimeSlots = false,
    this.selectedCategory = 'all',
    this.selectedCity = 'all',
    this.searchKeyword,
    this.myExpertApplicationStatus,
  });

  final TaskExpertStatus status;
  final List<TaskExpert> experts;
  final TaskExpert? selectedExpert;
  final List<TaskExpertService> services;
  /// 达人详情页：该达人发布的活动列表（方案 A）
  final List<Activity> expertActivities;
  final bool isLoadingExpertActivities;
  final int total;
  final int page;
  final bool hasMore;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;
  final Map<String, dynamic>? serviceDetail;
  final TaskExpertService? selectedService;
  final List<Map<String, dynamic>> applications;
  /// 达人收到的申请列表（别人申请我的服务）
  final List<Map<String, dynamic>> expertApplications;
  final List<TaskExpert> searchResults;
  final List<Map<String, dynamic>> reviews;
  final bool isLoadingReviews;
  final int reviewsTotal;
  final bool hasMoreReviews;
  final List<ServiceTimeSlot> timeSlots;
  final bool isLoadingTimeSlots;

  /// 选中的达人类型筛选，'all' 表示全部
  final String selectedCategory;

  /// 选中的城市筛选，'all' 表示全部
  final String selectedCity;

  /// 当前搜索关键词
  final String? searchKeyword;

  /// 我的达人申请状态 (pending/approved/rejected/null=未申请)
  final Map<String, dynamic>? myExpertApplicationStatus;

  bool get isLoading => status == TaskExpertStatus.loading;

  /// 当前是否有激活的筛选条件（类型非全部 或 城市非全部）
  bool get hasActiveFilters => selectedCategory != 'all' || selectedCity != 'all';

  TaskExpertState copyWith({
    TaskExpertStatus? status,
    List<TaskExpert>? experts,
    TaskExpert? selectedExpert,
    List<TaskExpertService>? services,
    List<Activity>? expertActivities,
    bool? isLoadingExpertActivities,
    int? total,
    int? page,
    bool? hasMore,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
    Map<String, dynamic>? serviceDetail,
    TaskExpertService? selectedService,
    List<Map<String, dynamic>>? applications,
    List<Map<String, dynamic>>? expertApplications,
    List<TaskExpert>? searchResults,
    List<Map<String, dynamic>>? reviews,
    bool? isLoadingReviews,
    int? reviewsTotal,
    bool? hasMoreReviews,
    List<ServiceTimeSlot>? timeSlots,
    bool? isLoadingTimeSlots,
    String? selectedCategory,
    String? selectedCity,
    String? searchKeyword,
    Map<String, dynamic>? myExpertApplicationStatus,
    bool clearMyExpertApplicationStatus = false,
  }) {
    return TaskExpertState(
      status: status ?? this.status,
      experts: experts ?? this.experts,
      selectedExpert: selectedExpert ?? this.selectedExpert,
      services: services ?? this.services,
      expertActivities: expertActivities ?? this.expertActivities,
      isLoadingExpertActivities: isLoadingExpertActivities ?? this.isLoadingExpertActivities,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
      serviceDetail: serviceDetail,
      selectedService: selectedService ?? this.selectedService,
      applications: applications ?? this.applications,
      expertApplications: expertApplications ?? this.expertApplications,
      searchResults: searchResults ?? this.searchResults,
      reviews: reviews ?? this.reviews,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      reviewsTotal: reviewsTotal ?? this.reviewsTotal,
      hasMoreReviews: hasMoreReviews ?? this.hasMoreReviews,
      timeSlots: timeSlots ?? this.timeSlots,
      isLoadingTimeSlots: isLoadingTimeSlots ?? this.isLoadingTimeSlots,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedCity: selectedCity ?? this.selectedCity,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      myExpertApplicationStatus: clearMyExpertApplicationStatus
          ? null
          : (myExpertApplicationStatus ?? this.myExpertApplicationStatus),
    );
  }

  @override
  List<Object?> get props => [
        status,
        experts,
        selectedExpert,
        services,
        expertActivities,
        isLoadingExpertActivities,
        total,
        page,
        hasMore,
        errorMessage,
        isSubmitting,
        actionMessage,
        serviceDetail,
        selectedService,
        applications,
        expertApplications,
        searchResults,
        reviews,
        isLoadingReviews,
        reviewsTotal,
        hasMoreReviews,
        timeSlots,
        isLoadingTimeSlots,
        selectedCategory,
        selectedCity,
        searchKeyword,
        myExpertApplicationStatus,
      ];
}

// ==================== Bloc ====================

class TaskExpertBloc extends Bloc<TaskExpertEvent, TaskExpertState> {
  TaskExpertBloc({
    required TaskExpertRepository taskExpertRepository,
    ActivityRepository? activityRepository,
  })  : _taskExpertRepository = taskExpertRepository,
        _activityRepository = activityRepository,
        super(const TaskExpertState()) {
    on<TaskExpertLoadRequested>(_onLoadRequested);
    on<TaskExpertLoadMore>(_onLoadMore);
    on<TaskExpertRefreshRequested>(_onRefresh);
    on<TaskExpertLoadDetail>(_onLoadDetail);
    on<TaskExpertApplyService>(_onApplyService);
    on<TaskExpertLoadServiceDetail>(_onLoadServiceDetail);
    on<TaskExpertLoadMyApplications>(_onLoadMyApplications);
    on<TaskExpertSearchRequested>(_onSearchRequested);
    on<TaskExpertLoadServiceReviews>(_onLoadServiceReviews);
    on<TaskExpertLoadExpertReviews>(_onLoadExpertReviews);
    on<TaskExpertLoadServiceTimeSlots>(_onLoadServiceTimeSlots);
    on<TaskExpertApplyServiceEnhanced>(_onApplyServiceEnhanced);
    on<TaskExpertFilterChanged>(_onFilterChanged);
    on<TaskExpertLoadExpertApplications>(_onLoadExpertApplications);
    on<TaskExpertApproveApplication>(_onApproveApplication);
    on<TaskExpertRejectApplication>(_onRejectApplication);
    on<TaskExpertCounterOffer>(_onCounterOffer);
    on<TaskExpertLoadMyExpertApplicationStatus>(_onLoadMyExpertApplicationStatus);
  }

  final TaskExpertRepository _taskExpertRepository;
  final ActivityRepository? _activityRepository;

  /// 获取城市筛选参数，'all' 时返回 null
  String? _cityParam(String city) => city == 'all' ? null : city;

  /// 获取类型筛选参数，'all' 时返回 null
  String? _categoryParam(String cat) => cat == 'all' ? null : cat;

  Future<void> _onLoadRequested(
    TaskExpertLoadRequested event,
    Emitter<TaskExpertState> emit,
  ) async {
    // 如果传了 skill，更新 searchKeyword
    final keyword = event.skill;
    emit(state.copyWith(
      status: TaskExpertStatus.loading,
      searchKeyword: keyword ?? '',
    ));

    try {
      final response = await _taskExpertRepository.getExperts(
        keyword: keyword,
        category: _categoryParam(state.selectedCategory),
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        experts: response.experts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load task experts', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMore(
    TaskExpertLoadMore event,
    Emitter<TaskExpertState> emit,
  ) async {
    if (!state.hasMore) return;

    try {
      final nextPage = state.page + 1;
      final response = await _taskExpertRepository.getExperts(
        page: nextPage,
        keyword: (state.searchKeyword?.isNotEmpty ?? false) ? state.searchKeyword : null,
        category: _categoryParam(state.selectedCategory),
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        experts: [...state.experts, ...response.experts],
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more experts', e);
    }
  }

  Future<void> _onRefresh(
    TaskExpertRefreshRequested event,
    Emitter<TaskExpertState> emit,
  ) async {
    try {
      final response = await _taskExpertRepository.getExperts(
        keyword: (state.searchKeyword?.isNotEmpty ?? false) ? state.searchKeyword : null,
        category: _categoryParam(state.selectedCategory),
        location: _cityParam(state.selectedCity),
        forceRefresh: true,
      );

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        experts: response.experts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh experts', e);
    }
  }

  Future<void> _onFilterChanged(
    TaskExpertFilterChanged event,
    Emitter<TaskExpertState> emit,
  ) async {
    final newCategory = event.category ?? state.selectedCategory;
    final newCity = event.city ?? state.selectedCity;

    emit(state.copyWith(
      selectedCategory: newCategory,
      selectedCity: newCity,
      status: TaskExpertStatus.loading,
    ));

    try {
      final response = await _taskExpertRepository.getExperts(
        keyword: (state.searchKeyword?.isNotEmpty ?? false) ? state.searchKeyword : null,
        category: _categoryParam(newCategory),
        location: _cityParam(newCity),
      );

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        experts: response.experts,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to filter experts', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadDetail(
    TaskExpertLoadDetail event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(
      status: TaskExpertStatus.loading,
      isLoadingExpertActivities: true,
      expertActivities: const [],
    ));

    try {
      final expert =
          await _taskExpertRepository.getExpertById(event.expertId);
      final services =
          await _taskExpertRepository.getExpertServices(event.expertId);

      List<Activity> activities = const [];
      final activityRepo = _activityRepository;
      if (activityRepo != null) {
        try {
          final res = await activityRepo.getActivities(
            expertId: event.expertId,
            status: 'open',
          );
          activities = res.activities;
        } catch (e) {
          AppLogger.warning('Failed to load expert activities', e);
        }
      }

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        selectedExpert: expert,
        services: services,
        expertActivities: activities,
        isLoadingExpertActivities: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load expert detail', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
        isLoadingExpertActivities: false,
      ));
    }
  }

  Future<void> _onApplyService(
    TaskExpertApplyService event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskExpertRepository.applyService(
        event.serviceId,
        message: event.message,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_submitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadServiceDetail(
    TaskExpertLoadServiceDetail event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(status: TaskExpertStatus.loading));

    try {
      final service = await _taskExpertRepository.getServiceDetailParsed(
        event.serviceId,
        forceRefresh: event.forceRefresh,
      );

      List<Activity> activities = const [];
      final activityRepo = _activityRepository;
      if (activityRepo != null &&
          service.expertId.isNotEmpty) {
        try {
          final res = await activityRepo.getActivities(
            expertId: service.expertId,
            status: 'open',
          );
          activities = res.activities;
        } catch (e) {
          AppLogger.warning('Failed to load expert activities for service', e);
        }
      }

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        selectedService: service,
        expertActivities: activities,
        isLoadingExpertActivities: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load service detail', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadMyApplications(
    TaskExpertLoadMyApplications event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(status: TaskExpertStatus.loading));

    try {
      final applications =
          await _taskExpertRepository.getMyServiceApplications();

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        applications: applications,
      ));
    } catch (e) {
      AppLogger.error('Failed to load my applications', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSearchRequested(
    TaskExpertSearchRequested event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(status: TaskExpertStatus.loading));

    try {
      final results = await _taskExpertRepository.searchExperts(
        keyword: event.keyword,
      );

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        searchResults: results,
      ));
    } catch (e) {
      AppLogger.error('Failed to search experts', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadServiceReviews(
    TaskExpertLoadServiceReviews event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isLoadingReviews: true));
    try {
      final reviews =
          await _taskExpertRepository.getServiceReviews(event.serviceId);
      emit(state.copyWith(
        reviews: reviews,
        isLoadingReviews: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load service reviews', e);
      emit(state.copyWith(isLoadingReviews: false));
    }
  }

  Future<void> _onLoadExpertReviews(
    TaskExpertLoadExpertReviews event,
    Emitter<TaskExpertState> emit,
  ) async {
    if (event.loadMore && !state.hasMoreReviews) return;

    emit(state.copyWith(isLoadingReviews: true));
    try {
      final offset = event.loadMore ? state.reviews.length : 0;
      final result = await _taskExpertRepository.getExpertReviews(
        event.expertId,
        offset: offset,
      );
      final items = result['items'] as List<Map<String, dynamic>>;
      final total = result['total'] as int;
      final merged = event.loadMore ? [...state.reviews, ...items] : items;

      emit(state.copyWith(
        reviews: merged,
        reviewsTotal: total,
        hasMoreReviews: merged.length < total,
        isLoadingReviews: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load expert reviews', e);
      emit(state.copyWith(isLoadingReviews: false));
    }
  }

  Future<void> _onLoadServiceTimeSlots(
    TaskExpertLoadServiceTimeSlots event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isLoadingTimeSlots: true));
    try {
      final rawSlots =
          await _taskExpertRepository.getServiceTimeSlots(event.serviceId);
      final timeSlots =
          rawSlots.map((e) => ServiceTimeSlot.fromJson(e)).toList();
      emit(state.copyWith(
        timeSlots: timeSlots,
        isLoadingTimeSlots: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load service time slots', e);
      emit(state.copyWith(isLoadingTimeSlots: false));
    }
  }

  Future<void> _onApplyServiceEnhanced(
    TaskExpertApplyServiceEnhanced event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.applyService(
        event.serviceId,
        message: event.message,
        counterPrice: event.counterPrice,
        timeSlotId: event.timeSlotId,
        preferredDeadline: event.preferredDeadline,
        isFlexibleTime: event.isFlexibleTime,
      );

      // 刷新服务详情以获取最新申请状态
      final service = await _taskExpertRepository.getServiceDetailParsed(
        event.serviceId,
        forceRefresh: true,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_submitted',
        selectedService: service,
      ));
    } catch (e) {
      AppLogger.error('Failed to apply for service', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadExpertApplications(
    TaskExpertLoadExpertApplications event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(status: TaskExpertStatus.loading));

    try {
      final expertApplications =
          await _taskExpertRepository.getMyExpertApplications();

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        expertApplications: expertApplications,
      ));
    } catch (e) {
      AppLogger.error('Failed to load expert applications', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onApproveApplication(
    TaskExpertApproveApplication event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskExpertRepository.approveServiceApplication(event.applicationId);

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_approved',
      ));

      add(const TaskExpertLoadExpertApplications());
    } catch (e) {
      AppLogger.error('Failed to approve application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRejectApplication(
    TaskExpertRejectApplication event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskExpertRepository.rejectServiceApplication(
        event.applicationId,
        reason: event.reason,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_rejected',
      ));

      add(const TaskExpertLoadExpertApplications());
    } catch (e) {
      AppLogger.error('Failed to reject application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCounterOffer(
    TaskExpertCounterOffer event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskExpertRepository.counterOfferServiceApplication(
        event.applicationId,
        counterPrice: event.counterPrice,
        message: event.message,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'counter_offer_sent',
      ));

      add(const TaskExpertLoadExpertApplications());
    } catch (e) {
      AppLogger.error('Failed to send counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  /// 加载我的达人申请状态 — 对标 iOS getMyExpertApplication
  Future<void> _onLoadMyExpertApplicationStatus(
    TaskExpertLoadMyExpertApplicationStatus event,
    Emitter<TaskExpertState> emit,
  ) async {
    try {
      final result = await _taskExpertRepository.getMyExpertApplication();
      if (emit.isDone) return;
      emit(state.copyWith(myExpertApplicationStatus: result));
    } catch (e) {
      AppLogger.error('Failed to load my expert application status', e);
    }
  }
}
