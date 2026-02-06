import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/task.dart';
import '../../../data/models/review.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class TaskDetailEvent extends Equatable {
  const TaskDetailEvent();

  @override
  List<Object?> get props => [];
}

class TaskDetailLoadRequested extends TaskDetailEvent {
  const TaskDetailLoadRequested(this.taskId);

  final int taskId;

  @override
  List<Object?> get props => [taskId];
}

class TaskDetailApplyRequested extends TaskDetailEvent {
  const TaskDetailApplyRequested({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class TaskDetailCancelApplicationRequested extends TaskDetailEvent {
  const TaskDetailCancelApplicationRequested();
}

class TaskDetailAcceptApplicant extends TaskDetailEvent {
  const TaskDetailAcceptApplicant(this.applicantId);

  final int applicantId;

  @override
  List<Object?> get props => [applicantId];
}

class TaskDetailCompleteRequested extends TaskDetailEvent {
  const TaskDetailCompleteRequested({this.evidence});

  final String? evidence;

  @override
  List<Object?> get props => [evidence];
}

class TaskDetailConfirmCompletionRequested extends TaskDetailEvent {
  const TaskDetailConfirmCompletionRequested();
}

class TaskDetailCancelRequested extends TaskDetailEvent {
  const TaskDetailCancelRequested({this.reason});

  final String? reason;

  @override
  List<Object?> get props => [reason];
}

class TaskDetailReviewRequested extends TaskDetailEvent {
  const TaskDetailReviewRequested(this.review);

  final CreateReviewRequest review;

  @override
  List<Object?> get props => [review];
}

// ==================== State ====================

enum TaskDetailStatus { initial, loading, loaded, error }

class TaskDetailState extends Equatable {
  const TaskDetailState({
    this.status = TaskDetailStatus.initial,
    this.task,
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final TaskDetailStatus status;
  final Task? task;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage; // 操作成功/失败消息

  bool get isLoading => status == TaskDetailStatus.loading;
  bool get isLoaded => status == TaskDetailStatus.loaded;

  TaskDetailState copyWith({
    TaskDetailStatus? status,
    Task? task,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return TaskDetailState(
      status: status ?? this.status,
      task: task ?? this.task,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props =>
      [status, task, errorMessage, isSubmitting, actionMessage];
}

// ==================== Bloc ====================

class TaskDetailBloc extends Bloc<TaskDetailEvent, TaskDetailState> {
  TaskDetailBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(const TaskDetailState()) {
    on<TaskDetailLoadRequested>(_onLoadRequested);
    on<TaskDetailApplyRequested>(_onApplyRequested);
    on<TaskDetailCancelApplicationRequested>(_onCancelApplication);
    on<TaskDetailAcceptApplicant>(_onAcceptApplicant);
    on<TaskDetailCompleteRequested>(_onCompleteRequested);
    on<TaskDetailConfirmCompletionRequested>(_onConfirmCompletion);
    on<TaskDetailCancelRequested>(_onCancelRequested);
    on<TaskDetailReviewRequested>(_onReviewRequested);
  }

  final TaskRepository _taskRepository;

  Future<void> _onLoadRequested(
    TaskDetailLoadRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    emit(state.copyWith(status: TaskDetailStatus.loading));

    try {
      final task = await _taskRepository.getTaskDetail(event.taskId);
      emit(state.copyWith(
        status: TaskDetailStatus.loaded,
        task: task,
      ));
    } catch (e) {
      AppLogger.error('Failed to load task detail', e);
      emit(state.copyWith(
        status: TaskDetailStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onApplyRequested(
    TaskDetailApplyRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.task == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.applyTask(state.task!.id, message: event.message);
      // 重新加载任务详情
      final task = await _taskRepository.getTaskDetail(state.task!.id);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '申请已提交',
      ));
    } catch (e) {
      AppLogger.error('Failed to apply task', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '申请失败: ${e.toString()}',
      ));
    }
  }

  Future<void> _onCancelApplication(
    TaskDetailCancelApplicationRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.task == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.cancelApplication(state.task!.id);
      final task = await _taskRepository.getTaskDetail(state.task!.id);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '已取消申请',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '取消申请失败',
      ));
    }
  }

  Future<void> _onAcceptApplicant(
    TaskDetailAcceptApplicant event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.task == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.acceptApplicant(state.task!.id, event.applicantId);
      final task = await _taskRepository.getTaskDetail(state.task!.id);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '已接受申请',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '操作失败',
      ));
    }
  }

  Future<void> _onCompleteRequested(
    TaskDetailCompleteRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.task == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.completeTask(
        state.task!.id,
        evidence: event.evidence,
      );
      final task = await _taskRepository.getTaskDetail(state.task!.id);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '已提交完成',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '提交失败',
      ));
    }
  }

  Future<void> _onConfirmCompletion(
    TaskDetailConfirmCompletionRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.task == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.confirmCompletion(state.task!.id);
      final task = await _taskRepository.getTaskDetail(state.task!.id);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '已确认完成',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '确认失败',
      ));
    }
  }

  Future<void> _onCancelRequested(
    TaskDetailCancelRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.task == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.cancelTask(
        state.task!.id,
        reason: event.reason,
      );
      final task = await _taskRepository.getTaskDetail(state.task!.id);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '任务已取消',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '取消失败',
      ));
    }
  }

  Future<void> _onReviewRequested(
    TaskDetailReviewRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.task == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.reviewTask(state.task!.id, event.review);
      final task = await _taskRepository.getTaskDetail(state.task!.id);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '评价已提交',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '评价失败',
      ));
    }
  }
}
