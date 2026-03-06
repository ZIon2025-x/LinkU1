import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';

import '../../../data/models/task.dart';
import '../../../data/models/task_application.dart';
import '../../../data/models/review.dart';
import '../../../data/models/refund_request.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/notification_repository.dart';
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
  const TaskDetailApplyRequested({
    this.message,
    this.negotiatedPrice,
    this.currency,
  });

  final String? message;
  final double? negotiatedPrice;
  final String? currency;

  @override
  List<Object?> get props => [message, negotiatedPrice, currency];
}

class TaskDetailCancelApplicationRequested extends TaskDetailEvent {
  const TaskDetailCancelApplicationRequested();
}

/// 批准申请后需支付时清除支付数据，避免重复弹支付页
class TaskDetailClearAcceptPaymentData extends TaskDetailEvent {
  const TaskDetailClearAcceptPaymentData();
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

/// 批准申请后后端返回的支付信息（需打开支付页完成支付，对齐 iOS）
class AcceptPaymentData extends Equatable {
  const AcceptPaymentData({
    required this.taskId,
    required this.clientSecret,
    required this.customerId,
    required this.ephemeralKeySecret,
    this.amountDisplay,
    this.applicationId,
    this.paymentExpiresAt,
    this.taskTitle,
    this.applicantName,
    this.taskSource,
    this.fleaMarketItemId,
  });

  final int taskId;
  final String clientSecret;
  final String customerId;
  final String ephemeralKeySecret;
  final String? amountDisplay;
  final int? applicationId;
  /// 支付过期时间（ISO 8601），用于显示倒计时 Banner（对齐 iOS）
  final String? paymentExpiresAt;
  /// 任务标题（批准后支付页显示「任务信息」卡片，对齐 iOS）
  final String? taskTitle;
  /// 被批准申请者姓名（批准后支付页显示，对齐 iOS）
  final String? applicantName;
  /// 任务来源（如 flea_market），用于跳蚤市场支付时补充 PI metadata
  final String? taskSource;
  /// 跳蚤市场商品 ID（如 S0123），用于 webhook 更新商品状态
  final String? fleaMarketItemId;

  @override
  List<Object?> get props =>
      [taskId, clientSecret, customerId, ephemeralKeySecret, taskSource, fleaMarketItemId];
}

class TaskDetailCompleteRequested extends TaskDetailEvent {
  const TaskDetailCompleteRequested({this.evidenceImages, this.evidenceText});

  final List<String>? evidenceImages;
  final String? evidenceText;

  @override
  List<Object?> get props => [evidenceImages, evidenceText];
}

class TaskDetailConfirmCompletionRequested extends TaskDetailEvent {
  const TaskDetailConfirmCompletionRequested({
    this.partialTransferAmount,
    this.partialTransferReason,
  });

  final double? partialTransferAmount;
  final String? partialTransferReason;

  @override
  List<Object?> get props => [partialTransferAmount, partialTransferReason];
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

/// 退款申请（对齐 iOS RefundRequestCreate + 后端 RefundRequestCreate schema）
class TaskDetailRequestRefund extends TaskDetailEvent {
  const TaskDetailRequestRefund({
    required this.reasonType,
    required this.reason,
    required this.refundType,
    this.evidenceFiles,
    this.refundAmount,
    this.refundPercentage,
  });

  final String reasonType; // completion_time_unsatisfactory / not_completed / quality_issue / other
  final String reason; // 详细退款原因（10-2000字符）
  final String refundType; // full / partial
  final List<String>? evidenceFiles;
  final double? refundAmount; // 部分退款金额
  final double? refundPercentage; // 部分退款百分比

  @override
  List<Object?> get props =>
      [reasonType, reason, refundType, evidenceFiles, refundAmount, refundPercentage];
}

/// 加载退款历史
class TaskDetailLoadRefundHistory extends TaskDetailEvent {
  const TaskDetailLoadRefundHistory();
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

/// 任务发布者给申请者发留言
class TaskDetailSendApplicationMessage extends TaskDetailEvent {
  const TaskDetailSendApplicationMessage({
    required this.applicationId,
    required this.content,
    this.negotiatedPrice,
  });
  final int applicationId;
  final String content;
  final double? negotiatedPrice;

  @override
  List<Object?> get props => [applicationId, content, negotiatedPrice];
}

/// 指定任务接单方提交报价
class TaskDetailQuoteDesignatedPriceRequested extends TaskDetailEvent {
  const TaskDetailQuoteDesignatedPriceRequested({required this.price});
  final double price;
  @override
  List<Object?> get props => [price];
}

/// 被指定方提交反报价
class TaskDetailSubmitCounterOfferRequested extends TaskDetailEvent {
  const TaskDetailSubmitCounterOfferRequested({required this.price});
  final double price;
  @override
  List<Object?> get props => [price];
}

/// 发布方响应被指定方的反报价
class TaskDetailRespondCounterOfferRequested extends TaskDetailEvent {
  const TaskDetailRespondCounterOfferRequested({required this.action});
  final String action; // 'accept' or 'reject'
  @override
  List<Object?> get props => [action];
}

/// 接单方回应议价通知（接受/拒绝）
class TaskDetailRespondNegotiationRequested extends TaskDetailEvent {
  const TaskDetailRespondNegotiationRequested({
    required this.action,
    required this.notificationId,
  });
  final String action; // 'accept' or 'reject'
  final int notificationId;
  @override
  List<Object?> get props => [action, notificationId];
}

/// 切换任务资料可见性（公开/隐藏）
class TaskDetailToggleProfileVisibility extends TaskDetailEvent {
  const TaskDetailToggleProfileVisibility({required this.isPublic});

  final bool isPublic;

  @override
  List<Object?> get props => [isPublic];
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
    this.acceptPaymentData,
    this.applications = const [],
    this.isLoadingApplications = false,
    this.userApplication,
    this.refundRequest,
    this.isLoadingRefundStatus = false,
    this.refundHistory = const [],
    this.isLoadingRefundHistory = false,
    this.reviews = const [],
    this.isLoadingReviews = false,
    this.hasSubmittedReview = false,
  });

  final TaskDetailStatus status;
  final Task? task;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;
  /// 批准申请后需支付时由后端返回，用于打开支付页（对齐 iOS）
  final AcceptPaymentData? acceptPaymentData;

  // 申请列表
  final List<TaskApplication> applications;
  final bool isLoadingApplications;
  final TaskApplication? userApplication; // 当前用户的申请

  // 退款
  final RefundRequest? refundRequest;
  final bool isLoadingRefundStatus;
  final List<RefundRequest> refundHistory;
  final bool isLoadingRefundHistory;

  // 评价
  final List<Review> reviews;
  final bool isLoadingReviews;
  /// 当前会话中是否已提交过评价（覆盖匿名评价不在 reviews 列表中的情况）
  final bool hasSubmittedReview;

  bool get isLoading => status == TaskDetailStatus.loading;
  bool get isLoaded => status == TaskDetailStatus.loaded;

  TaskDetailState copyWith({
    TaskDetailStatus? status,
    Task? task,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
    AcceptPaymentData? acceptPaymentData,
    bool clearAcceptPaymentData = false,
    List<TaskApplication>? applications,
    bool? isLoadingApplications,
    TaskApplication? userApplication,
    bool clearUserApplication = false,
    RefundRequest? refundRequest,
    bool clearRefundRequest = false,
    bool? isLoadingRefundStatus,
    List<RefundRequest>? refundHistory,
    bool? isLoadingRefundHistory,
    List<Review>? reviews,
    bool? isLoadingReviews,
    bool? hasSubmittedReview,
  }) {
    return TaskDetailState(
      status: status ?? this.status,
      task: task ?? this.task,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
      acceptPaymentData: clearAcceptPaymentData
          ? null
          : (acceptPaymentData ?? this.acceptPaymentData),
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
      refundHistory: refundHistory ?? this.refundHistory,
      isLoadingRefundHistory:
          isLoadingRefundHistory ?? this.isLoadingRefundHistory,
      reviews: reviews ?? this.reviews,
      isLoadingReviews: isLoadingReviews ?? this.isLoadingReviews,
      hasSubmittedReview: hasSubmittedReview ?? this.hasSubmittedReview,
    );
  }

  @override
  List<Object?> get props => [
        status,
        task,
        errorMessage,
        isSubmitting,
        actionMessage,
        acceptPaymentData,
        applications,
        isLoadingApplications,
        userApplication,
        refundRequest,
        isLoadingRefundStatus,
        refundHistory,
        isLoadingRefundHistory,
        reviews,
        isLoadingReviews,
        hasSubmittedReview,
      ];
}

// ==================== Bloc ====================

class TaskDetailBloc extends Bloc<TaskDetailEvent, TaskDetailState> {
  TaskDetailBloc({
    required TaskRepository taskRepository,
    required NotificationRepository notificationRepository,
  })  : _taskRepository = taskRepository,
        _notificationRepository = notificationRepository,
        super(const TaskDetailState()) {
    on<TaskDetailLoadRequested>(_onLoadRequested, transformer: restartable());
    on<TaskDetailLoadApplications>(_onLoadApplications, transformer: restartable());
    on<TaskDetailLoadRefundStatus>(_onLoadRefundStatus);
    on<TaskDetailLoadReviews>(_onLoadReviews);
    on<TaskDetailApplyRequested>(_onApplyRequested, transformer: droppable());
    on<TaskDetailCancelApplicationRequested>(_onCancelApplication);
    on<TaskDetailAcceptApplicant>(_onAcceptApplicant);
    on<TaskDetailClearAcceptPaymentData>(_onClearAcceptPaymentData);
    on<TaskDetailRejectApplicant>(_onRejectApplicant);
    on<TaskDetailCompleteRequested>(_onCompleteRequested);
    on<TaskDetailConfirmCompletionRequested>(_onConfirmCompletion);
    on<TaskDetailCancelRequested>(_onCancelRequested);
    on<TaskDetailReviewRequested>(_onReviewRequested);
    on<TaskDetailRequestRefund>(_onRequestRefund);
    on<TaskDetailLoadRefundHistory>(_onLoadRefundHistory);
    on<TaskDetailCancelRefund>(_onCancelRefund);
    on<TaskDetailSubmitRebuttal>(_onSubmitRebuttal);
    on<TaskDetailSendApplicationMessage>(_onSendApplicationMessage);
    on<TaskDetailQuoteDesignatedPriceRequested>(_onQuoteDesignatedPrice, transformer: droppable());
    on<TaskDetailSubmitCounterOfferRequested>(_onSubmitCounterOffer, transformer: droppable());
    on<TaskDetailRespondCounterOfferRequested>(_onRespondCounterOffer, transformer: droppable());
    on<TaskDetailRespondNegotiationRequested>(_onRespondNegotiation, transformer: droppable());
    on<TaskDetailToggleProfileVisibility>(_onToggleProfileVisibility, transformer: droppable());
  }

  final TaskRepository _taskRepository;
  final NotificationRepository _notificationRepository;

  int? get _taskId => state.task?.id;

  /// 刷新任务详情 — 复用于各操作完成后
  Future<Task> _refreshTask() => _taskRepository.getTaskDetail(_taskId!);

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
      emit(state.copyWith(
        isLoadingApplications: false,
        errorMessage: e.toString(),
      ));
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
      if (raw == null) {
        // 无退款记录（404）→ 清空
        emit(state.copyWith(
          isLoadingRefundStatus: false,
          clearRefundRequest: true,
        ));
        return;
      }
      final refund = RefundRequest.fromJson(raw);
      emit(state.copyWith(
        refundRequest: refund,
        isLoadingRefundStatus: false,
      ));
    } catch (e) {
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
      emit(state.copyWith(
        isLoadingReviews: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onApplyRequested(
    TaskDetailApplyRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.applyTask(
        _taskId!,
        message: event.message,
        negotiatedPrice: event.negotiatedPrice,
        currency: event.currency,
      );
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: 'application_submitted',
      ));
    } catch (e) {
      AppLogger.error('Failed to apply task', e);
      final isStripeSetup = e is TaskException &&
          e.message == 'stripe_setup_required';
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage:
            isStripeSetup ? 'stripe_setup_required' : 'application_failed',
        errorMessage: isStripeSetup ? null : e.toString(),
      ));
    }
  }

  Future<void> _onCancelApplication(
    TaskDetailCancelApplicationRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final appId = state.userApplication?.id;
      if (appId == null) {
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: 'cancel_failed',
          errorMessage: 'Application ID not found',
        ));
        return;
      }
      await _taskRepository.cancelApplication(_taskId!,
          applicationId: appId);
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: 'application_cancelled',
        clearUserApplication: true,
      ));
    } catch (e) {
      AppLogger.error('Failed to cancel application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'cancel_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onAcceptApplicant(
    TaskDetailAcceptApplicant event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final data = await _taskRepository.acceptApplication(
          _taskId!, event.applicationId);
      final clientSecret = data != null
          ? data['client_secret'] as String?
          : null;
      final needPayment = clientSecret != null && clientSecret.isNotEmpty;

      if (needPayment) {
        final customerId =
            (data!['customer_id'] as String?) ?? '';
        final ephemeralKey =
            (data['ephemeral_key_secret'] as String?) ?? '';
        final amountDisplay =
            data['amount_display'] as String?;
        TaskApplication? approvedApp;
        try {
          approvedApp = state.applications
              .firstWhere((a) => a.id == event.applicationId);
        } catch (_) {
          approvedApp = null;
        }
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: 'open_payment',
          acceptPaymentData: AcceptPaymentData(
            taskId: _taskId!,
            clientSecret: clientSecret,
            customerId: customerId,
            ephemeralKeySecret: ephemeralKey,
            amountDisplay: amountDisplay,
            applicationId: event.applicationId,
            taskTitle: state.task?.title,
            applicantName: approvedApp?.applicantName,
          ),
        ));
      } else {
        final results = await Future.wait([
          _refreshTask(),
          _taskRepository.getTaskApplications(_taskId!),
        ]);
        final task = results[0] as Task;
        final raw = results[1] as List<Map<String, dynamic>>;
        final apps = raw.map((e) => TaskApplication.fromJson(e)).toList();
        emit(state.copyWith(
          task: task,
          applications: apps,
          isSubmitting: false,
          actionMessage: 'application_accepted',
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to accept applicant', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'operation_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  void _onClearAcceptPaymentData(
    TaskDetailClearAcceptPaymentData event,
    Emitter<TaskDetailState> emit,
  ) {
    emit(state.copyWith(clearAcceptPaymentData: true));
  }

  Future<void> _onRejectApplicant(
    TaskDetailRejectApplicant event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.rejectApplication(_taskId!, event.applicationId);
      // 并行刷新任务详情和申请列表，减少等待时间
      final results = await Future.wait([
        _refreshTask(),
        _taskRepository.getTaskApplications(_taskId!),
      ]);
      final task = results[0] as Task;
      final raw = results[1] as List<Map<String, dynamic>>;
      final apps = raw.map((e) => TaskApplication.fromJson(e)).toList();
      emit(state.copyWith(
        task: task,
        applications: apps,
        isSubmitting: false,
        actionMessage: 'application_rejected',
      ));
    } catch (e) {
      AppLogger.error('Failed to reject applicant', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'operation_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCompleteRequested(
    TaskDetailCompleteRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.completeTask(
        _taskId!,
        evidenceImages: event.evidenceImages,
        evidenceText: event.evidenceText,
      );
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: 'task_completed',
      ));
    } catch (e) {
      AppLogger.error('Failed to complete task', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'submit_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onConfirmCompletion(
    TaskDetailConfirmCompletionRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.confirmCompletion(
        _taskId!,
        partialTransferAmount: event.partialTransferAmount,
        partialTransferReason: event.partialTransferReason,
      );
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: 'completion_confirmed',
      ));
    } catch (e) {
      AppLogger.error('Failed to confirm completion', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'confirm_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCancelRequested(
    TaskDetailCancelRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final directlyCancelled = await _taskRepository.cancelTask(
        _taskId!,
        reason: event.reason,
      );
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: directlyCancelled ? 'task_cancelled' : 'cancel_request_submitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'cancel_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onReviewRequested(
    TaskDetailReviewRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.reviewTask(_taskId!, event.review);
      // 并行刷新任务详情和评价列表，减少等待时间
      final results = await Future.wait([
        _refreshTask(),
        _taskRepository.getTaskReviews(_taskId!),
      ]);
      final task = results[0] as Task;
      final raw = results[1] as List<Map<String, dynamic>>;
      final reviews = raw.map((e) => Review.fromJson(e)).toList();
      emit(state.copyWith(
        task: task,
        reviews: reviews,
        isSubmitting: false,
        hasSubmittedReview: true,
        actionMessage: 'review_submitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'review_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRequestRefund(
    TaskDetailRequestRefund event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      final raw = await _taskRepository.requestRefund(
        _taskId!,
        reasonType: event.reasonType,
        reason: event.reason,
        refundType: event.refundType,
        evidenceFiles: event.evidenceFiles,
        refundAmount: event.refundAmount,
        refundPercentage: event.refundPercentage,
      );
      final refund = RefundRequest.fromJson(raw);
      // 退款请求已返回 refund 数据，仅刷新任务状态
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        refundRequest: refund,
        isSubmitting: false,
        actionMessage: 'refund_submitted',
      ));
    } catch (e) {
      AppLogger.error('Failed to request refund', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'refund_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadRefundHistory(
    TaskDetailLoadRefundHistory event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null) return;
    emit(state.copyWith(isLoadingRefundHistory: true));

    try {
      final rawList = await _taskRepository.getRefundHistory(_taskId!);
      final history =
          rawList.map((e) => RefundRequest.fromJson(e)).toList();
      emit(state.copyWith(
        refundHistory: history,
        isLoadingRefundHistory: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load refund history', e);
      emit(state.copyWith(
        isLoadingRefundHistory: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCancelRefund(
    TaskDetailCancelRefund event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.cancelRefundRequest(_taskId!, event.refundId);
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        clearRefundRequest: true,
        actionMessage: 'refund_revoked',
      ));
    } catch (e) {
      AppLogger.error('Failed to cancel refund', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'revoke_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSubmitRebuttal(
    TaskDetailSubmitRebuttal event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
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
      if (raw != null) {
        final refund = RefundRequest.fromJson(raw);
        emit(state.copyWith(
          refundRequest: refund,
          isSubmitting: false,
          actionMessage: 'dispute_submitted',
        ));
      } else {
        emit(state.copyWith(
          isSubmitting: false,
          actionMessage: 'dispute_submitted',
          clearRefundRequest: true,
        ));
      }
    } catch (e) {
      AppLogger.error('Failed to submit rebuttal', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'dispute_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  /// 任务发布者给申请者发留言
  Future<void> _onSendApplicationMessage(
    TaskDetailSendApplicationMessage event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.sendApplicationMessage(
        _taskId!,
        event.applicationId,
        content: event.content,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_message_sent',
      ));
    } catch (e) {
      AppLogger.error('Failed to send application message', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_message_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onQuoteDesignatedPrice(
    TaskDetailQuoteDesignatedPriceRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    bool applied = false;
    try {
      await _taskRepository.applyTask(
        _taskId!,
        negotiatedPrice: event.price,
      );
      applied = true;
      await _taskRepository.acceptTask(_taskId!);
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: 'quote_submitted',
      ));
    } catch (e) {
      AppLogger.error('Failed to submit designated task quote', e);
      // If applyTask succeeded but acceptTask failed, refresh to reflect actual state
      if (applied) {
        try {
          final task = await _refreshTask();
          emit(state.copyWith(task: task));
        } catch (_) {}
      }
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'quote_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSubmitCounterOffer(
    TaskDetailSubmitCounterOfferRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskRepository.submitTakerCounterOffer(_taskId!, price: event.price);
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: 'counter_offer_submitted',
      ));
    } catch (e) {
      AppLogger.error('Failed to submit counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'counter_offer_submit_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRespondCounterOffer(
    TaskDetailRespondCounterOfferRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskRepository.respondTakerCounterOffer(_taskId!, action: event.action);
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: event.action == 'accept'
            ? 'counter_offer_accepted'
            : 'counter_offer_rejected',
      ));
    } catch (e) {
      AppLogger.error('Failed to respond to counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'counter_offer_respond_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRespondNegotiation(
    TaskDetailRespondNegotiationRequested event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (_taskId == null || state.isSubmitting) return;
    assert(event.action == 'accept' || event.action == 'reject',
        'action must be "accept" or "reject", got: ${event.action}');
    final appId = state.userApplication?.id;
    if (appId == null) {
      emit(state.copyWith(
        actionMessage: 'operation_failed',
      ));
      return;
    }
    emit(state.copyWith(isSubmitting: true));
    try {
      final tokenData = await _notificationRepository.getNegotiationTokens(event.notificationId);
      final token = event.action == 'accept'
          ? tokenData['accept_token'] as String?
          : tokenData['reject_token'] as String?;
      if (token == null || token.isEmpty) {
        throw const TaskException('negotiation_token_missing');
      }
      await _taskRepository.respondNegotiation(
        _taskId!,
        appId,
        action: event.action,
        token: token,
      );
      final task = await _refreshTask();
      emit(state.copyWith(
        task: task,
        isSubmitting: false,
        actionMessage: event.action == 'accept' ? 'negotiation_accepted' : 'negotiation_rejected',
      ));
    } catch (e) {
      AppLogger.error('Failed to respond to negotiation', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'operation_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onToggleProfileVisibility(
    TaskDetailToggleProfileVisibility event,
    Emitter<TaskDetailState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskRepository.updateTaskVisibility(
        state.task!.id,
        isPublic: event.isPublic,
      );
      // Reload task to get updated is_public/taker_public from server
      add(TaskDetailLoadRequested(state.task!.id));
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'visibility_updated',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'visibility_update_failed',
        errorMessage: e.toString(),
      ));
    }
  }
}
