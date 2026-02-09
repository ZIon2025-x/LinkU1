import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/task_expert.dart';
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

  final int expertId;

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
  const TaskExpertLoadExpertReviews(this.expertId);

  final String expertId;

  @override
  List<Object?> get props => [expertId];
}

/// 加载服务时间段
class TaskExpertLoadServiceTimeSlots extends TaskExpertEvent {
  const TaskExpertLoadServiceTimeSlots(this.serviceId);

  final int serviceId;

  @override
  List<Object?> get props => [serviceId];
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

// ==================== State ====================

enum TaskExpertStatus { initial, loading, loaded, error }

class TaskExpertState extends Equatable {
  const TaskExpertState({
    this.status = TaskExpertStatus.initial,
    this.experts = const [],
    this.selectedExpert,
    this.services = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
    this.serviceDetail,
    this.selectedService,
    this.applications = const [],
    this.searchResults = const [],
    this.reviews = const [],
    this.isLoadingReviews = false,
    this.timeSlots = const [],
    this.isLoadingTimeSlots = false,
  });

  final TaskExpertStatus status;
  final List<TaskExpert> experts;
  final TaskExpert? selectedExpert;
  final List<TaskExpertService> services;
  final int total;
  final int page;
  final bool hasMore;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;
  final Map<String, dynamic>? serviceDetail;
  final TaskExpertService? selectedService;
  final List<Map<String, dynamic>> applications;
  final List<TaskExpert> searchResults;
  final List<Map<String, dynamic>> reviews;
  final bool isLoadingReviews;
  final List<ServiceTimeSlot> timeSlots;
  final bool isLoadingTimeSlots;

  bool get isLoading => status == TaskExpertStatus.loading;

  TaskExpertState copyWith({
    TaskExpertStatus? status,
    List<TaskExpert>? experts,
    TaskExpert? selectedExpert,
    List<TaskExpertService>? services,
    int? total,
    int? page,
    bool? hasMore,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
    Map<String, dynamic>? serviceDetail,
    TaskExpertService? selectedService,
    List<Map<String, dynamic>>? applications,
    List<TaskExpert>? searchResults,
    List<Map<String, dynamic>>? reviews,
    bool? isLoadingReviews,
    List<ServiceTimeSlot>? timeSlots,
    bool? isLoadingTimeSlots,
  }) {
    return TaskExpertState(
      status: status ?? this.status,
      experts: experts ?? this.experts,
      selectedExpert: selectedExpert ?? this.selectedExpert,
      services: services ?? this.services,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
      serviceDetail: serviceDetail,
      selectedService: selectedService ?? this.selectedService,
      applications: applications ?? this.applications,
      searchResults: searchResults ?? this.searchResults,
      reviews: reviews ?? this.reviews,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      timeSlots: timeSlots ?? this.timeSlots,
      isLoadingTimeSlots: isLoadingTimeSlots ?? this.isLoadingTimeSlots,
    );
  }

  @override
  List<Object?> get props => [
        status,
        experts,
        selectedExpert,
        services,
        total,
        page,
        hasMore,
        errorMessage,
        isSubmitting,
        actionMessage,
        serviceDetail,
        selectedService,
        applications,
        searchResults,
        reviews,
        isLoadingReviews,
        timeSlots,
        isLoadingTimeSlots,
      ];
}

// ==================== Bloc ====================

class TaskExpertBloc extends Bloc<TaskExpertEvent, TaskExpertState> {
  TaskExpertBloc({required TaskExpertRepository taskExpertRepository})
      : _taskExpertRepository = taskExpertRepository,
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
  }

  final TaskExpertRepository _taskExpertRepository;

  Future<void> _onLoadRequested(
    TaskExpertLoadRequested event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(status: TaskExpertStatus.loading));

    try {
      final response = await _taskExpertRepository.getExperts(
        page: 1,
        keyword: event.skill,
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
      final response = await _taskExpertRepository.getExperts(page: 1);

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

  Future<void> _onLoadDetail(
    TaskExpertLoadDetail event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(status: TaskExpertStatus.loading));

    try {
      final expert =
          await _taskExpertRepository.getExpertById(event.expertId.toString());
      final services =
          await _taskExpertRepository.getExpertServices(event.expertId.toString());

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        selectedExpert: expert,
        services: services,
      ));
    } catch (e) {
      AppLogger.error('Failed to load expert detail', e);
      emit(state.copyWith(
        status: TaskExpertStatus.error,
        errorMessage: e.toString(),
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
        actionMessage: '申请已提交',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '申请失败',
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

      emit(state.copyWith(
        status: TaskExpertStatus.loaded,
        selectedService: service,
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
    emit(state.copyWith(isLoadingReviews: true));
    try {
      final reviews =
          await _taskExpertRepository.getExpertReviews(event.expertId);
      emit(state.copyWith(
        reviews: reviews,
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
        actionMessage: '申请已提交',
        selectedService: service,
      ));
    } catch (e) {
      AppLogger.error('Failed to apply for service', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '申请失败: ${e.toString()}',
      ));
    }
  }
}
