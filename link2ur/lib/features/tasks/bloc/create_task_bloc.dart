import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class CreateTaskEvent extends Equatable {
  const CreateTaskEvent();

  @override
  List<Object?> get props => [];
}

class CreateTaskSubmitted extends CreateTaskEvent {
  const CreateTaskSubmitted(this.request);

  final CreateTaskRequest request;

  @override
  List<Object?> get props => [request];
}

class CreateTaskReset extends CreateTaskEvent {
  const CreateTaskReset();
}

class CreateTaskAIOptimize extends CreateTaskEvent {
  const CreateTaskAIOptimize({
    required this.title,
    required this.description,
    this.taskType,
  });
  final String title;
  final String description;
  final String? taskType;

  @override
  List<Object?> get props => [title, description, taskType];
}

// ==================== State ====================

enum CreateTaskStatus { initial, submitting, success, error, aiOptimizing }

class CreateTaskState extends Equatable {
  const CreateTaskState({
    this.status = CreateTaskStatus.initial,
    this.createdTask,
    this.errorMessage,
    this.optimizedTitle,
    this.optimizedDescription,
    this.suggestedSkills = const [],
  });

  final CreateTaskStatus status;
  final Task? createdTask;
  final String? errorMessage;
  final String? optimizedTitle;
  final String? optimizedDescription;
  final List<String> suggestedSkills;

  bool get isSubmitting => status == CreateTaskStatus.submitting;
  bool get isSuccess => status == CreateTaskStatus.success;
  bool get isAiOptimizing => status == CreateTaskStatus.aiOptimizing;

  CreateTaskState copyWith({
    CreateTaskStatus? status,
    Task? createdTask,
    String? errorMessage,
    String? optimizedTitle,
    String? optimizedDescription,
    List<String>? suggestedSkills,
  }) {
    return CreateTaskState(
      status: status ?? this.status,
      createdTask: createdTask ?? this.createdTask,
      errorMessage: errorMessage,           // direct assign, null = clear
      optimizedTitle: optimizedTitle,       // direct assign, null = clear
      optimizedDescription: optimizedDescription, // direct assign, null = clear
      suggestedSkills: suggestedSkills ?? this.suggestedSkills,
    );
  }

  @override
  List<Object?> get props => [status, createdTask, errorMessage,
      optimizedTitle, optimizedDescription, suggestedSkills];
}

// ==================== Bloc ====================

class CreateTaskBloc extends Bloc<CreateTaskEvent, CreateTaskState> {
  CreateTaskBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(const CreateTaskState()) {
    on<CreateTaskSubmitted>(_onSubmitted, transformer: droppable());
    on<CreateTaskReset>(_onReset);
    on<CreateTaskAIOptimize>(_onAIOptimize);
  }

  final TaskRepository _taskRepository;

  Future<void> _onSubmitted(
    CreateTaskSubmitted event,
    Emitter<CreateTaskState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(status: CreateTaskStatus.submitting));

    try {
      final task = await _taskRepository.createTask(event.request);
      emit(state.copyWith(
        status: CreateTaskStatus.success,
        createdTask: task,
      ));
    } on TaskException catch (e) {
      emit(state.copyWith(
        status: CreateTaskStatus.error,
        errorMessage: e.message,
      ));
    } catch (e) {
      AppLogger.error('Failed to create task', e);
      emit(state.copyWith(
        status: CreateTaskStatus.error,
        errorMessage: 'create_task_failed',
      ));
    }
  }

  void _onReset(
    CreateTaskReset event,
    Emitter<CreateTaskState> emit,
  ) {
    emit(const CreateTaskState());
  }

  Future<void> _onAIOptimize(
    CreateTaskAIOptimize event,
    Emitter<CreateTaskState> emit,
  ) async {
    emit(state.copyWith(status: CreateTaskStatus.aiOptimizing));
    try {
      final result = await _taskRepository.aiOptimizeTask(
        title: event.title,
        description: event.description,
        taskType: event.taskType,
      );
      emit(state.copyWith(
        status: CreateTaskStatus.initial,
        optimizedTitle: result['optimized_title'] as String?,
        optimizedDescription: result['optimized_description'] as String?,
        suggestedSkills: (result['suggested_skills'] as List<dynamic>?)
            ?.map((e) => e as String).toList() ?? [],
      ));
    } catch (e) {
      AppLogger.error('Failed to AI optimize task', e);
      emit(state.copyWith(
        status: CreateTaskStatus.error,
        errorMessage: 'ai_optimize_failed',
      ));
    }
  }
}
