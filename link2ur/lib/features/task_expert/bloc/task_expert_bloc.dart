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
}
