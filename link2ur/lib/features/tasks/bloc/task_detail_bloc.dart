import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/task.dart';
import '../../../data/models/task_application.dart';
import '../../../data/models/review.dart';
import '../../../data/models/refund_request.dart';
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

/// 加载申请列表 (发布者用)
class TaskDetailLoadApplications extends TaskDetailEvent {
  const TaskDetailLoadApplications({this.currentUserId});
  final String? currentUserId;
}

/// 加载退款状态
class TaskDetailLoadRefundStatus extends TaskDetailEvent {
  const TaskDetailLoadRefundStatus();
}

/// 加载评价列表
class TaskDetailLoadReviews extends TaskDetailEvent {
  const TaskDetailLoadReviews();
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
  const TaskDetailAcceptApplicant(this.applicationId);

  final int applicationId;

  @override
  List<Object?> get props => [applicationId];
}

class TaskDetailRejectApplicant extends TaskDetailEvent {
  const TaskDetailRejectApplicant(this.applicationId);

  final int applicationId;

  @override
  List<Object?> get props => [applicationId];
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

/// 退款申请
class TaskDetailRequestRefund extends TaskDetailEvent {
  const TaskDetailRequestRefund({required this.reason, this.evidence});
  final String reason;
  final List<String>? evidence;

  @override
  List<Object?> get props => [reason, evidence];
}

/// 取消退款
class TaskDetailCancelRefund extends TaskDetailEvent {
  const TaskDetailCancelRefund(this.refundId);
  final int refundId;

  @override
  List<Object?> get props => [refundId];
}

/// 提交退款反驳
class TaskDetailSubmitRebuttal extends TaskDetailEvent {
  const TaskDetailSubmitRebuttal({
    required this.refundId,
    required this.content,
    this.evidence,
  });
  final int refundId;
  final String content;
  final List<String>? evidence;

  @override
  List<Object?> get props => [refundId, content, evidence];
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
    this.applications = const [],
    this.isLoadingApplications = false,
    this.userApplication,
    this.refundRequest,
    this.isLoadingRefundStatus = false,
    this.reviews = const [],
    this.isLoadingReviews = false,
  });

  final TaskDetailStatus status;
  final Task? task;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  // 申请列表
  final List<TaskApplication> applications;
  final bool isLoadingApplications;
  final TaskApplication? userApplication; // 当前用户的申请

  // 退款
  final RefundRequest? refundRequest;
  final bool isLoadingRefundStatus;

  // 评价
  final List<Review> reviews;
  final bool isLoadingReviews;

  bool get isLoading => status == TaskDetailStatus.loading;
  bool get isLoaded => status == TaskDetailStatus.loaded;

  TaskDetailState copyWith({
    TaskDetailStatus? status,
    Task? task,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
    List<TaskApplication>? applications,
    bool? isLoadingApplications,
    TaskApplication? userApplication,
    bool clearUserApplication = false,
    RefundRequest? refundRequest,
    bool clearRefundRequest = false,
    bool? isLoadingRefundStatus,
    List<Review>? reviews,
    bool? isLoadingReviews,
  }) {
    return TaskDetailState(
      status: status ?? this.status,
      task: task ?? this.task,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
      applications: applications ?? this.applications,
      isLoadingApplications:
          isLoadingApplications ?? this.isLoadingApplications,
      userApplication: clearUserApplication
          ? null
          : (userApplication ?? this.userApplication),
      refundRequest: clearRefundRequest
          ? null
          : (refundRequest ?? this.refundRequest),
      isLoadingRefundStatus:
          isLoadingRefundStatus ?? this.isLoadingRefundStatus,
      reviews: reviews ?? this.reviews,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
    );
  }

  @override
  List<Object?> get props => [
        status,
        task,
        errorMessage,
        isSubmitting,
        actionMessage,
        applications,
        isLoadingApplications,
        userApplication,
        refundRequest,
        isLoadingRefundStatus,
        reviews,
        isLoadingReviews,
      ];
}

// ==================== Bloc ====================

class TaskDetailBloc extends Bloc<TaskDetailEvent, TaskDetailState> {
  TaskDetailBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(const TaskDetailState()) {
    on<TaskDetailLoadRequested>(_onLoadRequested);
    on<TaskDetailLoadApplications>(_onLoadApplications);
    on<TaskDetailLoadRefundStatus>(_onLoadRefundStatus);
    on<TaskDetailLoadReviews>(_onLoadReviews);
    on<TaskDetailApplyRequested>(_onApplyRequested);
    on<TaskDetailCancelApplicationRequested>(_onCancelApplication);
    on<TaskDetailAcceptApplicant>(_onAcceptApplicant);
    on<TaskDetailRejectApplicant>(_onRejectApplicant);
    on<TaskDetailCompleteRequested>(_onCompleteRequested);
    on<TaskDetailConfirmCompletionRequested>(_onConfirmCompletion);
    on<TaskDetailCancelRequested>(_onCancelRequested);
    on<TaskDetailReviewRequested>(_onReviewRequested);
    on<TaskDetailRequestRefund>(_onRequestRefund);
    on<TaskDetailCancelRefund>(_onCancelRefund);
    on<TaskDetailSubmitRebuttal>(_onSubmitRebuttal);
  }

  final TaskRepository _taskRepository;

  int? get _taskId => state.task?.id;

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

  Future<void> _onLoadApplications(
    TaskDetailLoadApplications event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isLoadingApplications: true));

    try {
      final raw = await _taskRepository.getTaskApplications(_taskId!);
      final apps = raw.map((e) => TaskApplication.fromJson(e)).toList();

      // 找出当前用户的申请
      TaskApplication? userApp;
      if (event.currentUserId != null) {
        for (final app in apps) {
          if (app.applicantId == event.currentUserId) {
            userApp = app;
            break;
          }
        }
      }

      emit(state.copyWith(
        applications: apps,
        isLoadingApplications: false,
        userApplication: userApp,
        clearUserApplication: userApp == null,
      ));
    } catch (e) {
      AppLogger.error('Failed to load applications', e);
      emit(state.copyWith(isLoadingApplications: false));
    }
  }

  Future<void> _onLoadRefundStatus(
    TaskDetailLoadRefundStatus event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isLoadingRefundStatus: true));

    try {
      final raw = await _taskRepository.getRefundStatus(_taskId!);
      final refund = RefundRequest.fromJson(raw);
      emit(state.copyWith(
        refundRequest: refund,
        isLoadingRefundStatus: false,
      ));
    } catch (e) {
      // 没有退款记录时可能 404 → 清空即可
      emit(state.copyWith(
        isLoadingRefundStatus: false,
        clearRefundRequest: true,
      ));
    }
  }

  Future<void> _onLoadReviews(
    TaskDetailLoadReviews event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isLoadingReviews: true));

    try {
      final raw = await _taskRepository.getTaskReviews(_taskId!);
      final reviews = raw.map((e) => Review.fromJson(e)).toList();
      emit(state.copyWith(reviews: reviews, isLoadingReviews: false));
    } catch (e) {
      AppLogger.error('Failed to load reviews', e);
      emit(state.copyWith(isLoadingReviews: false));
    }
  }

  Future<void> _onApplyRequested(
    TaskDetailApplyRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.applyTask(_taskId!, message: event.message);
      final task = await _taskRepository.getTaskDetail(_taskId!);
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
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final appId = state.userApplication?.id;
      await _taskRepository.cancelApplication(_taskId!,
          applicationId: appId);
      final task = await _taskRepository.getTaskDetail(_taskId!);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: '已取消申请',
        clearUserApplication: true,
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
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.acceptApplication(_taskId!, event.applicationId);
      final task = await _taskRepository.getTaskDetail(_taskId!);
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

  Future<void> _onRejectApplicant(
    TaskDetailRejectApplicant event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.rejectApplication(_taskId!, event.applicationId);
      final task = await _taskRepository.getTaskDetail(_taskId!);
      // 重新加载申请列表
      final raw = await _taskRepository.getTaskApplications(_taskId!);
      final apps = raw.map((e) => TaskApplication.fromJson(e)).toList();
      emit(state.copyWith(
        task: task,
        applications: apps,
        isSubmitting: false,
        actionMessage: '已拒绝申请',
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
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.completeTask(
        _taskId!,
        evidence: event.evidence,
      );
      final task = await _taskRepository.getTaskDetail(_taskId!);
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
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.confirmCompletion(_taskId!);
      final task = await _taskRepository.getTaskDetail(_taskId!);
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
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.cancelTask(
        _taskId!,
        reason: event.reason,
      );
      final task = await _taskRepository.getTaskDetail(_taskId!);
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
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.reviewTask(_taskId!, event.review);
      final task = await _taskRepository.getTaskDetail(_taskId!);
      // 重新加载评价
      final raw = await _taskRepository.getTaskReviews(_taskId!);
      final reviews = raw.map((e) => Review.fromJson(e)).toList();
      emit(state.copyWith(
        task: task,
        reviews: reviews,
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

  Future<void> _onRequestRefund(
    TaskDetailRequestRefund event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final raw = await _taskRepository.requestRefund(
        _taskId!,
        reason: event.reason,
        evidence: event.evidence,
      );
      final refund = RefundRequest.fromJson(raw);
      final task = await _taskRepository.getTaskDetail(_taskId!);
      emit(state.copyWith(
        task: task,
        refundRequest: refund,
        isSubmitting: false,
        actionMessage: '退款申请已提交',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '退款申请失败',
      ));
    }
  }

  Future<void> _onCancelRefund(
    TaskDetailCancelRefund event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.cancelRefundRequest(_taskId!, event.refundId);
      final task = await _taskRepository.getTaskDetail(_taskId!);
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        clearRefundRequest: true,
        actionMessage: '退款申请已撤销',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '撤销失败',
      ));
    }
  }

  Future<void> _onSubmitRebuttal(
    TaskDetailSubmitRebuttal event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.submitRefundRebuttal(
        _taskId!,
        event.refundId,
        content: event.content,
        evidence: event.evidence,
      );
      // 重新加载退款状态
      final raw = await _taskRepository.getRefundStatus(_taskId!);
      final refund = RefundRequest.fromJson(raw);
      emit(state.copyWith(
        refundRequest: refund,
        isSubmitting: false,
        actionMessage: '反驳已提交',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: '提交反驳失败',
      ));
    }
  }
}
