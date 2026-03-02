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

// ==================== State ====================

enum CreateTaskStatus { initial, submitting, success, error }

class CreateTaskState extends Equatable {
  const CreateTaskState({
    this.status = CreateTaskStatus.initial,
    this.createdTask,
    this.errorMessage,
  });

  final CreateTaskStatus status;
  final Task? createdTask;
  final String? errorMessage;

  bool get isSubmitting => status == CreateTaskStatus.submitting;
  bool get isSuccess => status == CreateTaskStatus.success;

  CreateTaskState copyWith({
    CreateTaskStatus? status,
    Task? createdTask,
    String? errorMessage,
  }) {
    return CreateTaskState(
      status: status ?? this.status,
      createdTask: createdTask ?? this.createdTask,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, createdTask, errorMessage];
}

// ==================== Bloc ====================

class CreateTaskBloc extends Bloc<CreateTaskEvent, CreateTaskState> {
  CreateTaskBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(const CreateTaskState()) {
    on<CreateTaskSubmitted>(_onSubmitted, transformer: droppable());
    on<CreateTaskReset>(_onReset);
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
    } catch (e) {
      AppLogger.error('Failed to create task', e);
      emit(state.copyWith(
        status: CreateTaskStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  void _onReset(
    CreateTaskReset event,
    Emitter<CreateTaskState> emit,
  ) {
    emit(const CreateTaskState());
  }
}
