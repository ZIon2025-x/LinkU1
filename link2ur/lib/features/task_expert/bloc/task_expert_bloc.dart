import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/activity.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/models/task_question.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/question_repository.dart';
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
  const TaskExpertLoadServiceReviews(this.serviceId, {this.loadMore = false});

  final int serviceId;
  final bool loadMore;

  @override
  List<Object?> get props => [serviceId, loadMore];
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

/// 达人筛选条件改变（类型 + 城市 + 排序）
class TaskExpertFilterChanged extends TaskExpertEvent {
  const TaskExpertFilterChanged({this.category, this.city, this.sort});

  /// 达人类型，'all' 或 null 表示全部
  final String? category;

  /// 城市，'all' 或 null 表示全部
  final String? city;

  /// 排序方式，'rating_desc' / 'completed_desc' / 'newest'
  final String? sort;

  @override
  List<Object?> get props => [category, city, sort];
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

/// 服务主同意申请（个人服务）
class TaskExpertOwnerApproveApplication extends TaskExpertEvent {
  const TaskExpertOwnerApproveApplication(this.applicationId);
  final int applicationId;

  @override
  List<Object?> get props => [applicationId];
}

/// 申请方在 price_agreed 下确认订单并付款（仅团队咨询）
class TaskExpertPayAndFinalize extends TaskExpertEvent {
  const TaskExpertPayAndFinalize(
    this.applicationId, {
    this.deadline,
    this.isFlexible,
  });

  final int applicationId;
  final String? deadline;
  final bool? isFlexible;

  @override
  List<Object?> get props => [applicationId, deadline, isFlexible];
}

/// 清除 pay-and-finalize 数据(view 导航后触发)
class TaskExpertClearPayAndFinalizeData extends TaskExpertEvent {
  const TaskExpertClearPayAndFinalizeData();
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
  const TaskExpertCounterOffer(this.applicationId, {required this.counterPrice, this.message, this.serviceId});

  final int applicationId;
  final double counterPrice;
  final String? message;
  final int? serviceId;

  @override
  List<Object?> get props => [applicationId, counterPrice, message, serviceId];
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

/// 创建咨询
class TaskExpertStartConsultation extends TaskExpertEvent {
  const TaskExpertStartConsultation(this.serviceId);
  final int serviceId;

  @override
  List<Object?> get props => [serviceId];
}

/// 用户议价
class TaskExpertNegotiatePrice extends TaskExpertEvent {
  const TaskExpertNegotiatePrice(this.applicationId, {required this.price, this.serviceId});
  final int applicationId;
  final double price;
  final int? serviceId;

  @override
  List<Object?> get props => [applicationId, price, serviceId];
}

/// 达人报价
class TaskExpertQuotePrice extends TaskExpertEvent {
  const TaskExpertQuotePrice(this.applicationId, {required this.price, this.message, this.serviceId});
  final int applicationId;
  final double price;
  final String? message;
  final int? serviceId;

  @override
  List<Object?> get props => [applicationId, price, message, serviceId];
}

/// 回应议价/报价
class TaskExpertNegotiateResponse extends TaskExpertEvent {
  const TaskExpertNegotiateResponse(this.applicationId, {required this.action, this.counterPrice, this.serviceId});
  final int applicationId;
  final String action; // 'accept', 'reject', 'counter'
  final double? counterPrice;
  final int? serviceId;

  @override
  List<Object?> get props => [applicationId, action, counterPrice, serviceId];
}

/// 咨询转正式申请
class TaskExpertFormalApply extends TaskExpertEvent {
  const TaskExpertFormalApply(
    this.applicationId, {
    this.proposedPrice,
    this.message,
    this.timeSlotId,
    this.deadline,
    this.isFlexible = 0,
  });
  final int applicationId;
  final double? proposedPrice;
  final String? message;
  final int? timeSlotId;
  final String? deadline;
  final int isFlexible;

  @override
  List<Object?> get props => [applicationId, proposedPrice, message, timeSlotId, deadline, isFlexible];
}

/// 关闭咨询
class TaskExpertCloseConsultation extends TaskExpertEvent {
  const TaskExpertCloseConsultation(this.applicationId);
  final int applicationId;

  @override
  List<Object?> get props => [applicationId];
}

// ── Task consultation events ──────────────────────
class TaskExpertStartTaskConsultation extends TaskExpertEvent {
  const TaskExpertStartTaskConsultation(this.taskId);
  final int taskId;
  @override
  List<Object?> get props => [taskId];
}

class TaskExpertTaskNegotiate extends TaskExpertEvent {
  const TaskExpertTaskNegotiate(this.taskId, this.applicationId, {required this.price});
  final int taskId;
  final int applicationId;
  final double price;
  @override
  List<Object?> get props => [taskId, applicationId, price];
}

class TaskExpertTaskQuote extends TaskExpertEvent {
  const TaskExpertTaskQuote(this.taskId, this.applicationId, {required this.price, this.message});
  final int taskId;
  final int applicationId;
  final double price;
  final String? message;
  @override
  List<Object?> get props => [taskId, applicationId, price, message];
}

class TaskExpertTaskNegotiateResponse extends TaskExpertEvent {
  const TaskExpertTaskNegotiateResponse(this.taskId, this.applicationId, {required this.action, this.counterPrice});
  final int taskId;
  final int applicationId;
  final String action;
  final double? counterPrice;
  @override
  List<Object?> get props => [taskId, applicationId, action, counterPrice];
}

class TaskExpertTaskFormalApply extends TaskExpertEvent {
  const TaskExpertTaskFormalApply(this.taskId, this.applicationId, {this.proposedPrice, this.message});
  final int taskId;
  final int applicationId;
  final double? proposedPrice;
  final String? message;
  @override
  List<Object?> get props => [taskId, applicationId, proposedPrice, message];
}

class TaskExpertCloseTaskConsultation extends TaskExpertEvent {
  const TaskExpertCloseTaskConsultation(this.taskId, this.applicationId);
  final int taskId;
  final int applicationId;
  @override
  List<Object?> get props => [taskId, applicationId];
}

// ── Flea market consultation events ───────────────
class TaskExpertStartFleaMarketConsultation extends TaskExpertEvent {
  const TaskExpertStartFleaMarketConsultation(this.itemId);
  final String itemId;
  @override
  List<Object?> get props => [itemId];
}

class TaskExpertFleaMarketNegotiate extends TaskExpertEvent {
  const TaskExpertFleaMarketNegotiate(this.requestId, {required this.price});
  final int requestId;
  final double price;
  @override
  List<Object?> get props => [requestId, price];
}

class TaskExpertFleaMarketQuote extends TaskExpertEvent {
  const TaskExpertFleaMarketQuote(this.requestId, {required this.price, this.message});
  final int requestId;
  final double price;
  final String? message;
  @override
  List<Object?> get props => [requestId, price, message];
}

class TaskExpertFleaMarketNegotiateResponse extends TaskExpertEvent {
  const TaskExpertFleaMarketNegotiateResponse(this.requestId, {required this.action, this.counterPrice});
  final int requestId;
  final String action;
  final double? counterPrice;
  @override
  List<Object?> get props => [requestId, action, counterPrice];
}

class TaskExpertFleaMarketFormalBuy extends TaskExpertEvent {
  const TaskExpertFleaMarketFormalBuy(this.requestId);
  final int requestId;
  @override
  List<Object?> get props => [requestId];
}

class TaskExpertApproveFleaMarketPurchase extends TaskExpertEvent {
  const TaskExpertApproveFleaMarketPurchase(this.requestId);
  final int requestId;
  @override
  List<Object?> get props => [requestId];
}

class TaskExpertCloseFleaMarketConsultation extends TaskExpertEvent {
  const TaskExpertCloseFleaMarketConsultation(this.requestId);
  final int requestId;
  @override
  List<Object?> get props => [requestId];
}

/// 加载我的达人申请状态 — 对标 iOS getMyExpertApplication
class TaskExpertLoadMyExpertApplicationStatus extends TaskExpertEvent {
  const TaskExpertLoadMyExpertApplicationStatus();
}

/// 申请成为任务达人 — 对标 iOS TaskExpertApplyView.submitApplication
class TaskExpertApplyToBeExpert extends TaskExpertEvent {
  const TaskExpertApplyToBeExpert({this.message});

  final String? message;

  @override
  List<Object?> get props => [message];
}

class TaskExpertLoadServiceApplications extends TaskExpertEvent {
  const TaskExpertLoadServiceApplications(this.serviceId);
  final int serviceId;
  @override
  List<Object?> get props => [serviceId];
}

class TaskExpertReplyServiceApplication extends TaskExpertEvent {
  const TaskExpertReplyServiceApplication(
    this.serviceId,
    this.applicationId,
    this.message,
  );
  final int serviceId;
  final int applicationId;
  final String message;
  @override
  List<Object?> get props => [serviceId, applicationId, message];
}

class TaskExpertLoadServiceQuestions extends TaskExpertEvent {
  const TaskExpertLoadServiceQuestions(this.serviceId, {this.page = 1});
  final int serviceId;
  final int page;
  @override
  List<Object?> get props => [serviceId, page];
}

class TaskExpertAskServiceQuestion extends TaskExpertEvent {
  const TaskExpertAskServiceQuestion({required this.serviceId, required this.content});
  final int serviceId;
  final String content;
  @override
  List<Object?> get props => [serviceId, content];
}

class TaskExpertReplyServiceQuestion extends TaskExpertEvent {
  const TaskExpertReplyServiceQuestion({required this.questionId, required this.content});
  final int questionId;
  final String content;
  @override
  List<Object?> get props => [questionId, content];
}

class TaskExpertDeleteServiceQuestion extends TaskExpertEvent {
  const TaskExpertDeleteServiceQuestion(this.questionId);
  final int questionId;
  @override
  List<Object?> get props => [questionId];
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
    this.selectedSort = 'rating_desc',
    this.searchKeyword,
    this.myExpertApplicationStatus,
    this.serviceApplications = const [],
    this.isLoadingServiceApplications = false,
    this.serviceQuestions = const [],
    this.isLoadingServiceQuestions = false,
    this.serviceQuestionsTotalCount = 0,
    this.serviceQuestionsCurrentPage = 1,
    this.consultationData,
    this.payAndFinalizeData,
    this.errorCode,
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

  /// 选中的排序方式，'rating_desc' / 'completed_desc' / 'newest'
  final String selectedSort;

  /// 当前搜索关键词
  final String? searchKeyword;

  /// 我的达人申请状态 (pending/approved/rejected/null=未申请)
  final Map<String, dynamic>? myExpertApplicationStatus;

  /// 服务的公开申请列表（留言墙）
  final List<Map<String, dynamic>> serviceApplications;
  final bool isLoadingServiceApplications;

  /// 服务 Q&A
  final List<TaskQuestion> serviceQuestions;
  final bool isLoadingServiceQuestions;
  final int serviceQuestionsTotalCount;
  final int serviceQuestionsCurrentPage;

  /// 咨询创建后返回的数据
  final Map<String, dynamic>? consultationData;

  /// pay-and-finalize 成功后端返回的支付信息(client_secret/customer_id/ephemeral_key_secret/amount)
  /// View 监听此字段 → 跳转 ApprovalPaymentPage → 清除
  final Map<String, dynamic>? payAndFinalizeData;

  /// 后端稳定错误码（例: CONSULTATION_ALREADY_EXISTS, SERVICE_INACTIVE 等），
  /// 用于 UI 按错误码映射 l10n 文案。配合 [errorMessage] 使用。
  final String? errorCode;

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
    String? selectedSort,
    String? searchKeyword,
    Map<String, dynamic>? myExpertApplicationStatus,
    bool clearMyExpertApplicationStatus = false,
    List<Map<String, dynamic>>? serviceApplications,
    bool? isLoadingServiceApplications,
    List<TaskQuestion>? serviceQuestions,
    bool? isLoadingServiceQuestions,
    int? serviceQuestionsTotalCount,
    int? serviceQuestionsCurrentPage,
    Map<String, dynamic>? consultationData,
    bool clearConsultationData = false,
    Map<String, dynamic>? payAndFinalizeData,
    bool clearPayAndFinalizeData = false,
    String? errorCode,
    bool clearErrorCode = false,
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
      selectedSort: selectedSort ?? this.selectedSort,
      searchKeyword: searchKeyword ?? this.searchKeyword,
      myExpertApplicationStatus: clearMyExpertApplicationStatus
          ? null
          : (myExpertApplicationStatus ?? this.myExpertApplicationStatus),
      serviceApplications: serviceApplications ?? this.serviceApplications,
      isLoadingServiceApplications: isLoadingServiceApplications ?? this.isLoadingServiceApplications,
      serviceQuestions: serviceQuestions ?? this.serviceQuestions,
      isLoadingServiceQuestions: isLoadingServiceQuestions ?? this.isLoadingServiceQuestions,
      serviceQuestionsTotalCount: serviceQuestionsTotalCount ?? this.serviceQuestionsTotalCount,
      serviceQuestionsCurrentPage: serviceQuestionsCurrentPage ?? this.serviceQuestionsCurrentPage,
      consultationData: clearConsultationData
          ? null
          : (consultationData ?? this.consultationData),
      payAndFinalizeData: clearPayAndFinalizeData
          ? null
          : (payAndFinalizeData ?? this.payAndFinalizeData),
      errorCode: clearErrorCode ? null : (errorCode ?? this.errorCode),
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
        selectedSort,
        searchKeyword,
        myExpertApplicationStatus,
        serviceApplications,
        isLoadingServiceApplications,
        serviceQuestions,
        isLoadingServiceQuestions,
        serviceQuestionsTotalCount,
        serviceQuestionsCurrentPage,
        consultationData,
        payAndFinalizeData,
        errorCode,
      ];
}

// ==================== Bloc ====================

class TaskExpertBloc extends Bloc<TaskExpertEvent, TaskExpertState> {
  TaskExpertBloc({
    required TaskExpertRepository taskExpertRepository,
    ActivityRepository? activityRepository,
    required QuestionRepository questionRepository,
    this.expertId,
  })  : _taskExpertRepository = taskExpertRepository,
        _activityRepository = activityRepository,
        _questionRepository = questionRepository,
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
    on<TaskExpertOwnerApproveApplication>(_onOwnerApproveApplication);
    on<TaskExpertPayAndFinalize>(_onPayAndFinalize);
    on<TaskExpertClearPayAndFinalizeData>(
      (event, emit) => emit(state.copyWith(clearPayAndFinalizeData: true)),
    );
    on<TaskExpertRejectApplication>(_onRejectApplication);
    on<TaskExpertCounterOffer>(_onCounterOffer);
    on<TaskExpertLoadMyExpertApplicationStatus>(_onLoadMyExpertApplicationStatus);
    on<TaskExpertApplyToBeExpert>(_onApplyToBeExpert);
    on<TaskExpertLoadServiceApplications>(_onLoadServiceApplications);
    on<TaskExpertReplyServiceApplication>(_onReplyServiceApplication);
    on<TaskExpertLoadServiceQuestions>(_onLoadServiceQuestions);
    on<TaskExpertAskServiceQuestion>(_onAskServiceQuestion);
    on<TaskExpertReplyServiceQuestion>(_onReplyServiceQuestion);
    on<TaskExpertDeleteServiceQuestion>(_onDeleteServiceQuestion);
    on<TaskExpertStartConsultation>(_onStartConsultation);
    on<TaskExpertNegotiatePrice>(_onNegotiatePrice);
    on<TaskExpertQuotePrice>(_onQuotePrice);
    on<TaskExpertNegotiateResponse>(_onNegotiateResponse);
    on<TaskExpertFormalApply>(_onFormalApply);
    on<TaskExpertCloseConsultation>(_onCloseConsultation);
    // Task consultation
    on<TaskExpertStartTaskConsultation>(_onStartTaskConsultation);
    on<TaskExpertTaskNegotiate>(_onTaskNegotiate);
    on<TaskExpertTaskQuote>(_onTaskQuote);
    on<TaskExpertTaskNegotiateResponse>(_onTaskNegotiateResponse);
    on<TaskExpertTaskFormalApply>(_onTaskFormalApply);
    on<TaskExpertCloseTaskConsultation>(_onCloseTaskConsultation);
    // Flea market consultation
    on<TaskExpertStartFleaMarketConsultation>(_onStartFleaMarketConsultation);
    on<TaskExpertFleaMarketNegotiate>(_onFleaMarketNegotiate);
    on<TaskExpertFleaMarketQuote>(_onFleaMarketQuote);
    on<TaskExpertFleaMarketNegotiateResponse>(_onFleaMarketNegotiateResponse);
    on<TaskExpertFleaMarketFormalBuy>(_onFleaMarketFormalBuy);
    on<TaskExpertApproveFleaMarketPurchase>(_onApproveFleaMarketPurchase);
    on<TaskExpertCloseFleaMarketConsultation>(_onCloseFleaMarketConsultation);
  }

  final TaskExpertRepository _taskExpertRepository;
  final ActivityRepository? _activityRepository;
  final QuestionRepository _questionRepository;
  final String? expertId;

  /// 获取城市筛选参数，'all' 时返回 null
  String? _cityParam(String city) => city == 'all' ? null : city;

  /// 获取类型筛选参数，'all' 时返回 null
  String? _categoryParam(String cat) => cat == 'all' ? null : cat;

  /// 获取排序参数 — 将 UI 状态值映射为新 `/api/experts` 后端接受的枚举。
  /// 后端 (expert_routes.py:382) 只接受: rating / created_at / completed_tasks / display_order / random
  String? _sortParam(String sort) {
    switch (sort) {
      case 'rating_desc':
        return 'rating';
      case 'completed_desc':
        return 'completed_tasks';
      case 'newest':
        return 'created_at';
      default:
        return null; // 未知值不传，让后端走默认 display_order
    }
  }

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
        sort: _sortParam(state.selectedSort),
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
        sort: _sortParam(state.selectedSort),
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
        sort: _sortParam(state.selectedSort),
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
    final newSort = event.sort ?? state.selectedSort;

    emit(state.copyWith(
      selectedCategory: newCategory,
      selectedCity: newCity,
      selectedSort: newSort,
      status: TaskExpertStatus.loading,
    ));

    try {
      final response = await _taskExpertRepository.getExperts(
        keyword: (state.searchKeyword?.isNotEmpty ?? false) ? state.searchKeyword : null,
        category: _categoryParam(newCategory),
        location: _cityParam(newCity),
        sort: _sortParam(newSort),
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
          await _taskExpertRepository.getExpertById(event.expertId, forceRefresh: true);
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
    if (state.isSubmitting) return;
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
    if (event.loadMore && !state.hasMoreReviews) return;

    emit(state.copyWith(isLoadingReviews: true));
    try {
      final offset = event.loadMore ? state.reviews.length : 0;
      final result = await _taskExpertRepository.getServiceReviews(
        event.serviceId,
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
    if (state.isSubmitting) return;
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
      final expertApplications = expertId != null
          ? await _taskExpertRepository.getExpertApplications(expertId!)
          : <Map<String, dynamic>>[];

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
        clearErrorCode: true,
      ));

      add(const TaskExpertLoadExpertApplications());
    } on TaskExpertException catch (e) {
      AppLogger.error('Failed to approve application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      AppLogger.error('Failed to approve application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onOwnerApproveApplication(
    TaskExpertOwnerApproveApplication event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskExpertRepository.ownerApproveApplication(event.applicationId);

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_approved',
        clearErrorCode: true,
      ));

      add(const TaskExpertLoadExpertApplications());
    } on TaskExpertException catch (e) {
      AppLogger.error('Failed to owner-approve application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      AppLogger.error('Failed to owner-approve application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onPayAndFinalize(
    TaskExpertPayAndFinalize event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));

    try {
      final result = await _taskExpertRepository.payAndFinalizeApplication(
        event.applicationId,
        deadline: event.deadline,
        isFlexible: event.isFlexible,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'order_created_pending_payment',
        payAndFinalizeData: result,
        clearErrorCode: true,
      ));

      add(const TaskExpertLoadExpertApplications());
    } on TaskExpertException catch (e) {
      AppLogger.error('Failed to pay-and-finalize', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      AppLogger.error('Failed to pay-and-finalize', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
        clearErrorCode: true,
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
        clearErrorCode: true,
      ));

      add(const TaskExpertLoadExpertApplications());
    } on TaskExpertException catch (e) {
      AppLogger.error('Failed to reject application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      AppLogger.error('Failed to reject application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
        clearErrorCode: true,
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
        serviceId: event.serviceId,
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'counter_offer_sent',
        clearErrorCode: true,
      ));

      add(const TaskExpertLoadExpertApplications());
    } on TaskExpertException catch (e) {
      AppLogger.error('Failed to send counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      AppLogger.error('Failed to send counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
        clearErrorCode: true,
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

  /// 申请成为任务达人 — 对标 iOS TaskExpertApplyView.submitApplication
  Future<void> _onApplyToBeExpert(
    TaskExpertApplyToBeExpert event,
    Emitter<TaskExpertState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));

    try {
      await _taskExpertRepository.applyToBeExpert(
        applicationData: {
          if (event.message != null && event.message!.isNotEmpty)
            'application_message': event.message,
        },
      );

      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'expert_application_submitted',
      ));

      // 自动刷新申请状态
      add(const TaskExpertLoadMyExpertApplicationStatus());
    } catch (e) {
      AppLogger.error('Failed to apply to be expert', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'expert_application_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadServiceApplications(
    TaskExpertLoadServiceApplications event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isLoadingServiceApplications: true));
    try {
      final apps = await _taskExpertRepository.getServiceApplications(event.serviceId);
      emit(state.copyWith(
        isLoadingServiceApplications: false,
        serviceApplications: apps,
      ));
    } catch (e) {
      AppLogger.error('Failed to load service applications', e);
      emit(state.copyWith(isLoadingServiceApplications: false));
    }
  }

  Future<void> _onReplyServiceApplication(
    TaskExpertReplyServiceApplication event,
    Emitter<TaskExpertState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.replyServiceApplication(
        event.serviceId,
        event.applicationId,
        event.message,
      );
      final updated = state.serviceApplications.map((app) {
        if (app['id'] == event.applicationId) {
          return {
            ...app,
            'owner_reply': result['owner_reply'],
            'owner_reply_at': result['owner_reply_at'],
          };
        }
        return app;
      }).toList();
      emit(state.copyWith(
        isSubmitting: false,
        serviceApplications: updated,
        actionMessage: 'service_reply_submitted',
      ));
    } catch (e) {
      AppLogger.error('Failed to reply service application', e);
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadServiceQuestions(
    TaskExpertLoadServiceQuestions event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isLoadingServiceQuestions: true));
    try {
      final result = await _questionRepository.getQuestions(
        targetType: 'service',
        targetId: event.serviceId,
        page: event.page,
      );
      final items = result['items'] as List<TaskQuestion>;
      final allQuestions = event.page == 1
          ? items
          : [...state.serviceQuestions, ...items];
      emit(state.copyWith(
        serviceQuestions: allQuestions,
        isLoadingServiceQuestions: false,
        serviceQuestionsTotalCount: result['total'] as int,
        serviceQuestionsCurrentPage: event.page,
      ));
    } catch (e) {
      AppLogger.error('Failed to load service questions', e);
      emit(state.copyWith(isLoadingServiceQuestions: false));
    }
  }

  Future<void> _onAskServiceQuestion(
    TaskExpertAskServiceQuestion event,
    Emitter<TaskExpertState> emit,
  ) async {
    try {
      final question = await _questionRepository.askQuestion(
        targetType: 'service',
        targetId: event.serviceId,
        content: event.content,
      );
      emit(state.copyWith(
        serviceQuestions: [question, ...state.serviceQuestions],
        serviceQuestionsTotalCount: state.serviceQuestionsTotalCount + 1,
        actionMessage: 'qa_ask_success',
      ));
    } catch (e) {
      AppLogger.error('Failed to ask service question', e);
      emit(state.copyWith(actionMessage: _mapQaError(e, 'qa_ask_failed')));
    }
  }

  Future<void> _onReplyServiceQuestion(
    TaskExpertReplyServiceQuestion event,
    Emitter<TaskExpertState> emit,
  ) async {
    try {
      final updated = await _questionRepository.replyQuestion(
        questionId: event.questionId,
        content: event.content,
      );
      final updatedList = state.serviceQuestions.map((q) =>
        q.id == updated.id ? updated : q
      ).toList();
      emit(state.copyWith(
        serviceQuestions: updatedList,
        actionMessage: 'qa_reply_success',
      ));
    } catch (e) {
      AppLogger.error('Failed to reply service question', e);
      emit(state.copyWith(actionMessage: _mapQaError(e, 'qa_reply_failed')));
    }
  }

  Future<void> _onDeleteServiceQuestion(
    TaskExpertDeleteServiceQuestion event,
    Emitter<TaskExpertState> emit,
  ) async {
    try {
      await _questionRepository.deleteQuestion(event.questionId);
      final updatedList = state.serviceQuestions.where((q) => q.id != event.questionId).toList();
      emit(state.copyWith(
        serviceQuestions: updatedList,
        serviceQuestionsTotalCount: state.serviceQuestionsTotalCount - 1,
        actionMessage: 'qa_delete_success',
      ));
    } catch (e) {
      AppLogger.error('Failed to delete service question', e);
      emit(state.copyWith(actionMessage: _mapQaError(e, 'qa_delete_failed')));
    }
  }

  Future<void> _onStartConsultation(
    TaskExpertStartConsultation event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.createConsultation(event.serviceId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'consultation_started',
        consultationData: result,
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
        actionMessage: 'consultation_failed',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
        actionMessage: 'consultation_failed',
      ));
    }
  }

  Future<void> _onNegotiatePrice(
    TaskExpertNegotiatePrice event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.negotiatePrice(
        event.applicationId,
        proposedPrice: event.price,
        serviceId: event.serviceId,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'negotiation_sent',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onQuotePrice(
    TaskExpertQuotePrice event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.quotePrice(
        event.applicationId,
        quotedPrice: event.price,
        message: event.message,
        serviceId: event.serviceId,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'quote_sent',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onNegotiateResponse(
    TaskExpertNegotiateResponse event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.respondToNegotiation(
        event.applicationId,
        action: event.action,
        counterPrice: event.counterPrice,
        serviceId: event.serviceId,
      );
      final status = result['status'] as String? ?? '';
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'negotiate_response_$status',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onFormalApply(
    TaskExpertFormalApply event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.formalApply(
        event.applicationId,
        proposedPrice: event.proposedPrice,
        message: event.message,
        timeSlotId: event.timeSlotId,
        deadline: event.deadline,
        isFlexible: event.isFlexible,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'formal_apply_submitted',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onCloseConsultation(
    TaskExpertCloseConsultation event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.closeConsultation(event.applicationId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'consultation_closed',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  // ==================== Task consultation handlers ====================

  Future<void> _onStartTaskConsultation(
    TaskExpertStartTaskConsultation event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.createTaskConsultation(event.taskId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'consultation_started',
        consultationData: result,
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
        actionMessage: 'consultation_failed',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
        actionMessage: 'consultation_failed',
      ));
    }
  }

  Future<void> _onTaskNegotiate(
    TaskExpertTaskNegotiate event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.negotiateTaskConsultation(event.taskId, event.applicationId, proposedPrice: event.price);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'negotiation_sent',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onTaskQuote(
    TaskExpertTaskQuote event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.quoteTaskConsultation(event.taskId, event.applicationId, quotedPrice: event.price, message: event.message);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'quote_sent',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onTaskNegotiateResponse(
    TaskExpertTaskNegotiateResponse event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.respondTaskNegotiation(
        event.taskId, event.applicationId,
        action: event.action,
        counterPrice: event.counterPrice,
      );
      final status = result['status'] as String? ?? '';
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'negotiate_response_$status',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onTaskFormalApply(
    TaskExpertTaskFormalApply event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.formalApplyTaskConsultation(
        event.taskId, event.applicationId,
        proposedPrice: event.proposedPrice,
        message: event.message,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'formal_apply_submitted',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onCloseTaskConsultation(
    TaskExpertCloseTaskConsultation event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.closeTaskConsultation(event.taskId, event.applicationId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'consultation_closed',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  // ==================== Flea market consultation handlers ====================

  Future<void> _onStartFleaMarketConsultation(
    TaskExpertStartFleaMarketConsultation event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.createFleaMarketConsultation(event.itemId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'consultation_started',
        consultationData: result,
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
        actionMessage: 'consultation_failed',
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
        actionMessage: 'consultation_failed',
      ));
    }
  }

  Future<void> _onFleaMarketNegotiate(
    TaskExpertFleaMarketNegotiate event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.negotiateFleaMarketConsultation(event.requestId, proposedPrice: event.price);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'negotiation_sent',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onFleaMarketQuote(
    TaskExpertFleaMarketQuote event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.quoteFleaMarketConsultation(event.requestId, quotedPrice: event.price, message: event.message);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'quote_sent',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onFleaMarketNegotiateResponse(
    TaskExpertFleaMarketNegotiateResponse event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _taskExpertRepository.respondFleaMarketNegotiation(
        event.requestId,
        action: event.action,
        counterPrice: event.counterPrice,
      );
      final status = result['status'] as String? ?? '';
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'negotiate_response_$status',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onFleaMarketFormalBuy(
    TaskExpertFleaMarketFormalBuy event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.formalBuyFleaMarket(event.requestId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'formal_apply_submitted',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onApproveFleaMarketPurchase(
    TaskExpertApproveFleaMarketPurchase event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.approveFleaMarketPurchase(event.requestId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_approved',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  Future<void> _onCloseFleaMarketConsultation(
    TaskExpertCloseFleaMarketConsultation event,
    Emitter<TaskExpertState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _taskExpertRepository.closeFleaMarketConsultation(event.requestId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'consultation_closed',
        clearErrorCode: true,
      ));
    } on TaskExpertException catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.message,
        errorCode: e.errorCode,
      ));
    } catch (e) {
      emit(state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString(),
        clearErrorCode: true,
      ));
    }
  }

  /// Map backend Q&A error detail to specific error codes
  static String _mapQaError(Object e, String fallback) {
    final msg = e.toString();
    if (msg.contains('Cannot ask on your own post')) return 'qa_cannot_ask_own';
    if (msg.contains('Already replied')) return 'qa_already_replied';
    if (msg.contains('Content too short')) return 'qa_content_too_short';
    if (msg.contains('Only the owner can reply') ||
        msg.contains('Only the asker can delete')) {
      return 'qa_no_permission';
    }
    if (msg.contains('not found')) return 'qa_not_found';
    return fallback;
  }
}
