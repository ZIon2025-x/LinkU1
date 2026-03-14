import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../data/models/newbie_task.dart';
import '../../../data/models/official_task.dart';
import '../../../data/repositories/newbie_tasks_repository.dart';
import '../../../data/repositories/official_tasks_repository.dart';

// ==================== Events ====================

abstract class NewbieTasksEvent extends Equatable {
  const NewbieTasksEvent();

  @override
  List<Object?> get props => [];
}

/// Load all newbie task data (progress + stages + official tasks)
class NewbieTasksLoadRequested extends NewbieTasksEvent {
  const NewbieTasksLoadRequested();
}

/// Claim reward for a completed newbie task
class NewbieTaskClaimRequested extends NewbieTasksEvent {
  final String taskKey;
  const NewbieTaskClaimRequested(this.taskKey);

  @override
  List<Object?> get props => [taskKey];
}

/// Claim stage completion bonus
class NewbieStageBonusClaimRequested extends NewbieTasksEvent {
  final int stage;
  const NewbieStageBonusClaimRequested(this.stage);

  @override
  List<Object?> get props => [stage];
}

// ==================== State ====================

enum NewbieTasksStatus { initial, loading, loaded, error }

class NewbieTasksState extends Equatable {
  const NewbieTasksState({
    this.status = NewbieTasksStatus.initial,
    this.tasks = const [],
    this.stages = const [],
    this.officialTasks = const [],
    this.errorMessage,
    this.claimingTaskKey,
    this.claimingStage,
  });

  final NewbieTasksStatus status;
  final List<NewbieTaskProgress> tasks;
  final List<StageProgress> stages;
  final List<OfficialTask> officialTasks;
  final String? errorMessage;
  final String? claimingTaskKey;
  final int? claimingStage;

  bool get isLoading => status == NewbieTasksStatus.loading;

  /// Get tasks filtered by stage number
  List<NewbieTaskProgress> getTasksByStage(int stage) =>
      tasks.where((t) => t.config.stage == stage).toList();

  /// Number of tasks that have been claimed
  int get completedCount => tasks.where((t) => t.isClaimed).length;

  /// Total number of tasks
  int get totalCount => tasks.length;

  NewbieTasksState copyWith({
    NewbieTasksStatus? status,
    List<NewbieTaskProgress>? tasks,
    List<StageProgress>? stages,
    List<OfficialTask>? officialTasks,
    String? errorMessage,
    String? claimingTaskKey,
    int? claimingStage,
    bool clearError = false,
    bool clearClaiming = false,
  }) {
    return NewbieTasksState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      stages: stages ?? this.stages,
      officialTasks: officialTasks ?? this.officialTasks,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      claimingTaskKey:
          clearClaiming ? null : (claimingTaskKey ?? this.claimingTaskKey),
      claimingStage:
          clearClaiming ? null : (claimingStage ?? this.claimingStage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        tasks,
        stages,
        officialTasks,
        errorMessage,
        claimingTaskKey,
        claimingStage,
      ];
}

// ==================== Bloc ====================

class NewbieTasksBloc extends Bloc<NewbieTasksEvent, NewbieTasksState> {
  NewbieTasksBloc({
    required NewbieTasksRepository newbieTasksRepository,
    required OfficialTasksRepository officialTasksRepository,
  })  : _newbieTasksRepository = newbieTasksRepository,
        _officialTasksRepository = officialTasksRepository,
        super(const NewbieTasksState()) {
    on<NewbieTasksLoadRequested>(_onLoadRequested);
    on<NewbieTaskClaimRequested>(_onClaimRequested);
    on<NewbieStageBonusClaimRequested>(_onStageBonusClaim);
  }

  final NewbieTasksRepository _newbieTasksRepository;
  final OfficialTasksRepository _officialTasksRepository;

  Future<void> _onLoadRequested(
    NewbieTasksLoadRequested event,
    Emitter<NewbieTasksState> emit,
  ) async {
    emit(state.copyWith(status: NewbieTasksStatus.loading, clearError: true));

    try {
      final results = await Future.wait([
        _newbieTasksRepository.getProgress(),
        _newbieTasksRepository.getStages(),
        _officialTasksRepository.getOfficialTasks(),
      ]);

      final progressData = results[0];
      final stagesData = results[1];
      final officialData = results[2];

      AppLogger.info('NewbieTasks API response - '
          'progress: ${progressData.length} items, '
          'stages: ${stagesData.length} items, '
          'official: ${officialData.length} items');
      if (progressData.isNotEmpty) {
        AppLogger.info('NewbieTasks first item: ${progressData.first}');
      }

      final tasks =
          progressData.map((e) => NewbieTaskProgress.fromJson(e)).toList();
      final stages =
          stagesData.map((e) => StageProgress.fromJson(e)).toList();
      final officialTasks =
          officialData.map((e) => OfficialTask.fromJson(e)).toList();

      AppLogger.info('NewbieTasks parsed - '
          'tasks: ${tasks.length}, '
          'stages: ${stages.length} (stages: ${stages.map((s) => s.stage).toList()}), '
          'officialTasks: ${officialTasks.length}');
      if (tasks.isNotEmpty) {
        AppLogger.info('NewbieTasks first task: '
            'key=${tasks.first.taskKey}, '
            'status=${tasks.first.status}, '
            'stage=${tasks.first.config.stage}');
      }

      emit(state.copyWith(
        status: NewbieTasksStatus.loaded,
        tasks: tasks,
        stages: stages,
        officialTasks: officialTasks,
        clearClaiming: true,
      ));
    } catch (e, stackTrace) {
      AppLogger.error('Failed to load newbie tasks: $e\n$stackTrace');
      emit(state.copyWith(
        status: NewbieTasksStatus.error,
        errorMessage: 'newbie_tasks_load_failed',
      ));
    }
  }

  Future<void> _onClaimRequested(
    NewbieTaskClaimRequested event,
    Emitter<NewbieTasksState> emit,
  ) async {
    emit(state.copyWith(claimingTaskKey: event.taskKey, clearError: true));

    try {
      await _newbieTasksRepository.claimTask(event.taskKey);

      // Reload all data to get updated progress
      add(const NewbieTasksLoadRequested());
    } catch (e) {
      AppLogger.error('Failed to claim newbie task: ${event.taskKey}', e);
      emit(state.copyWith(
        errorMessage: 'newbie_task_claim_failed',
        clearClaiming: true,
      ));
    }
  }

  Future<void> _onStageBonusClaim(
    NewbieStageBonusClaimRequested event,
    Emitter<NewbieTasksState> emit,
  ) async {
    emit(state.copyWith(claimingStage: event.stage, clearError: true));

    try {
      await _newbieTasksRepository.claimStageBonus(event.stage);

      // Reload all data to get updated stage progress
      add(const NewbieTasksLoadRequested());
    } catch (e) {
      AppLogger.error('Failed to claim stage bonus: stage ${event.stage}', e);
      emit(state.copyWith(
        errorMessage: 'newbie_stage_claim_failed',
        clearClaiming: true,
      ));
    }
  }
}
