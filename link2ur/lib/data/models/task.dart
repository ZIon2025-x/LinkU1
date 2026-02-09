import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';
import 'user.dart';

/// 任务模型
/// 参考iOS Task.swift
class Task extends Equatable {
  const Task({
    required this.id,
    required this.title,
    this.titleEn,
    this.titleZh,
    this.description,
    this.descriptionEn,
    this.descriptionZh,
    required this.taskType,
    this.location,
    this.latitude,
    this.longitude,
    required this.reward,
    this.currency = 'USD',
    required this.status,
    this.images = const [],
    this.deadline,
    required this.posterId,
    this.poster,
    this.takerId,
    this.taker,
    this.isMultiParticipant = false,
    this.maxParticipants = 1,
    this.currentParticipants = 0,
    this.taskSource,
    this.taskLevel,
    this.hasApplied = false,
    this.userApplicationStatus,
    this.completionEvidence,
    this.paymentExpiresAt,
    this.confirmationDeadline,
    this.agreedReward,
    this.baseReward,
    this.originatingUserId,
    this.expertCreatorId,
    this.hasReviewed = false,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String? titleEn;
  final String? titleZh;
  final String? description;
  final String? descriptionEn;
  final String? descriptionZh;
  final String taskType;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double reward;
  final String currency;
  final String status;
  final List<String> images;
  final DateTime? deadline;
  final String posterId;
  final UserBrief? poster;
  final String? takerId;
  final UserBrief? taker;
  final bool isMultiParticipant;
  final int maxParticipants;
  final int currentParticipants;
  final String? taskSource;
  final String? taskLevel; // normal, vip, super
  final bool hasApplied;
  final String? userApplicationStatus;
  final String? completionEvidence;
  final String? paymentExpiresAt;
  final String? confirmationDeadline;
  final double? agreedReward;
  final double? baseReward;
  final String? originatingUserId;
  final String? expertCreatorId;
  final bool hasReviewed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 显示标题（根据语言）
  String get displayTitle => titleZh ?? titleEn ?? title;

  /// 显示描述（根据语言）
  String? get displayDescription => descriptionZh ?? descriptionEn ?? description;

  /// 是否是线上任务
  bool get isOnline => location == null || location == 'online';

  /// 是否已截止
  bool get isExpired => deadline != null && deadline!.isBefore(DateTime.now());

  /// 是否可以申请
  bool get canApply => 
      status == AppConstants.taskStatusOpen && 
      !hasApplied && 
      !isExpired && 
      currentParticipants < maxParticipants;

  // ==================== 任务来源判断 ====================

  /// 是否跳蚤市场任务
  bool get isFleaMarketTask =>
      taskSource == AppConstants.taskSourceFleaMarket;

  /// 是否达人服务任务
  bool get isExpertServiceTask =>
      taskSource == AppConstants.taskSourceExpertService;

  /// 是否达人活动任务
  bool get isExpertActivityTask =>
      taskSource == AppConstants.taskSourceExpertActivity;

  /// 是否有特殊来源 (非普通任务)
  bool get hasSpecialSource =>
      isFleaMarketTask || isExpertServiceTask || isExpertActivityTask;

  // ==================== 任务等级 ====================

  /// 是否 VIP 任务
  bool get isVipTask => taskLevel == 'vip';

  /// 是否超级任务
  bool get isSuperTask => taskLevel == 'super';

  /// 是否有特殊等级
  bool get hasSpecialLevel =>
      taskLevel != null && taskLevel != 'normal';

  // ==================== 实际金额 ====================

  /// 实际显示金额 (协商价 > 基础价 > 奖励)
  double get displayReward => agreedReward ?? baseReward ?? reward;

  // ==================== 支付到期 ====================

  /// 支付是否已过期
  bool get isPaymentExpired {
    if (paymentExpiresAt == null || paymentExpiresAt!.isEmpty) return false;
    try {
      final expiry = DateTime.parse(paymentExpiresAt!);
      return DateTime.now().isAfter(expiry);
    } catch (_) {
      return false;
    }
  }

  // ==================== 跳蚤市场分类提取 ====================

  /// 从描述中提取跳蚤市场商品分类
  /// 后端创建任务时在描述末尾追加 "Category: {分类}"
  String? get fleaMarketCategory {
    if (!isFleaMarketTask) return null;
    final desc = displayDescription ?? '';
    const prefix = 'Category: ';
    final idx = desc.lastIndexOf(prefix);
    if (idx < 0) return null;
    final cat = desc.substring(idx + prefix.length).trim();
    return cat.isEmpty ? null : cat;
  }

  /// Header 中显示的分类文本 (跳蚤市场用商品分类，其他用 taskType)
  String get displayCategoryText =>
      (isFleaMarketTask ? fleaMarketCategory : null) ?? taskTypeText;

  /// 状态显示文本
  String get statusText {
    switch (status) {
      case AppConstants.taskStatusOpen:
        return '招募中';
      case AppConstants.taskStatusInProgress:
        return '进行中';
      case AppConstants.taskStatusPendingConfirmation:
        return '待确认';
      case AppConstants.taskStatusPendingPayment:
        return '待支付';
      case AppConstants.taskStatusCompleted:
        return '已完成';
      case AppConstants.taskStatusCancelled:
        return '已取消';
      case AppConstants.taskStatusDisputed:
        return '争议中';
      default:
        return status;
    }
  }

  /// 任务类型显示文本
  String get taskTypeText {
    switch (taskType) {
      case 'delivery':
        return '代取代送';
      case 'shopping':
        return '代购';
      case 'tutoring':
        return '辅导';
      case 'translation':
        return '翻译';
      case 'design':
        return '设计';
      case 'programming':
        return '编程';
      case 'writing':
        return '写作';
      case 'photography':
        return '摄影';
      case 'moving':
        return '搬家';
      case 'cleaning':
        return '清洁';
      case 'repair':
        return '维修';
      case 'other':
        return '其他';
      default:
        return taskType;
    }
  }

  /// 第一张图片
  String? get firstImage => images.isNotEmpty ? images.first : null;

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      titleEn: json['title_en'] as String?,
      titleZh: json['title_zh'] as String?,
      description: json['description'] as String?,
      descriptionEn: json['description_en'] as String?,
      descriptionZh: json['description_zh'] as String?,
      taskType: json['task_type'] as String? ?? 'other',
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      reward: (json['reward'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      status: json['status'] as String? ?? AppConstants.taskStatusOpen,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      posterId: json['poster_id']?.toString() ?? '',
      poster: json['poster'] != null
          ? UserBrief.fromJson(json['poster'] as Map<String, dynamic>)
          : null,
      takerId: json['taker_id']?.toString(),
      taker: json['taker'] != null
          ? UserBrief.fromJson(json['taker'] as Map<String, dynamic>)
          : null,
      isMultiParticipant: json['is_multi_participant'] as bool? ?? false,
      maxParticipants: json['max_participants'] as int? ?? 1,
      currentParticipants: json['current_participants'] as int? ?? 0,
      taskSource: json['task_source'] as String?,
      taskLevel: json['task_level'] as String?,
      hasApplied: json['has_applied'] as bool? ?? false,
      userApplicationStatus: json['user_application_status'] as String?,
      completionEvidence: json['completion_evidence'] as String?,
      paymentExpiresAt: json['payment_expires_at'] as String?,
      confirmationDeadline: json['confirmation_deadline'] as String?,
      agreedReward: (json['agreed_reward'] as num?)?.toDouble(),
      baseReward: (json['base_reward'] as num?)?.toDouble(),
      originatingUserId: json['originating_user_id']?.toString(),
      expertCreatorId: json['expert_creator_id']?.toString(),
      hasReviewed: json['has_reviewed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'title_en': titleEn,
      'title_zh': titleZh,
      'description': description,
      'description_en': descriptionEn,
      'description_zh': descriptionZh,
      'task_type': taskType,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'reward': reward,
      'currency': currency,
      'status': status,
      'images': images,
      'deadline': deadline?.toIso8601String(),
      'poster_id': posterId,
      'taker_id': takerId,
      'is_multi_participant': isMultiParticipant,
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'task_source': taskSource,
      'task_level': taskLevel,
      'has_applied': hasApplied,
      'user_application_status': userApplicationStatus,
      'completion_evidence': completionEvidence,
      'payment_expires_at': paymentExpiresAt,
      'confirmation_deadline': confirmationDeadline,
      'agreed_reward': agreedReward,
      'base_reward': baseReward,
      'originating_user_id': originatingUserId,
      'expert_creator_id': expertCreatorId,
      'has_reviewed': hasReviewed,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  Task copyWith({
    int? id,
    String? title,
    String? titleEn,
    String? titleZh,
    String? description,
    String? descriptionEn,
    String? descriptionZh,
    String? taskType,
    String? location,
    double? latitude,
    double? longitude,
    double? reward,
    String? currency,
    String? status,
    List<String>? images,
    DateTime? deadline,
    String? posterId,
    UserBrief? poster,
    String? takerId,
    UserBrief? taker,
    bool? isMultiParticipant,
    int? maxParticipants,
    int? currentParticipants,
    String? taskSource,
    String? taskLevel,
    bool? hasApplied,
    String? userApplicationStatus,
    String? completionEvidence,
    String? paymentExpiresAt,
    String? confirmationDeadline,
    double? agreedReward,
    double? baseReward,
    String? originatingUserId,
    String? expertCreatorId,
    bool? hasReviewed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      titleEn: titleEn ?? this.titleEn,
      titleZh: titleZh ?? this.titleZh,
      description: description ?? this.description,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionZh: descriptionZh ?? this.descriptionZh,
      taskType: taskType ?? this.taskType,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      reward: reward ?? this.reward,
      currency: currency ?? this.currency,
      status: status ?? this.status,
      images: images ?? this.images,
      deadline: deadline ?? this.deadline,
      posterId: posterId ?? this.posterId,
      poster: poster ?? this.poster,
      takerId: takerId ?? this.takerId,
      taker: taker ?? this.taker,
      isMultiParticipant: isMultiParticipant ?? this.isMultiParticipant,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      taskSource: taskSource ?? this.taskSource,
      taskLevel: taskLevel ?? this.taskLevel,
      hasApplied: hasApplied ?? this.hasApplied,
      userApplicationStatus: userApplicationStatus ?? this.userApplicationStatus,
      completionEvidence: completionEvidence ?? this.completionEvidence,
      paymentExpiresAt: paymentExpiresAt ?? this.paymentExpiresAt,
      confirmationDeadline: confirmationDeadline ?? this.confirmationDeadline,
      agreedReward: agreedReward ?? this.agreedReward,
      baseReward: baseReward ?? this.baseReward,
      originatingUserId: originatingUserId ?? this.originatingUserId,
      expertCreatorId: expertCreatorId ?? this.expertCreatorId,
      hasReviewed: hasReviewed ?? this.hasReviewed,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, status, updatedAt];
}

/// 任务列表响应
class TaskListResponse {
  const TaskListResponse({
    required this.tasks,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<Task> tasks;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => tasks.length >= pageSize;

  factory TaskListResponse.fromJson(Map<String, dynamic> json) {
    // 后端不同接口返回不同的键名：
    //   /api/tasks → 'tasks' 或 'items'
    //   /api/recommendations → 'recommendations'
    final taskList = (json['tasks'] ?? json['items'] ?? json['recommendations'])
        as List<dynamic>?;
    return TaskListResponse(
      tasks: taskList
              ?.map((e) => Task.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}

/// 创建任务请求
class CreateTaskRequest {
  const CreateTaskRequest({
    required this.title,
    this.description,
    required this.taskType,
    this.location,
    this.latitude,
    this.longitude,
    required this.reward,
    this.currency = 'USD',
    this.images = const [],
    this.deadline,
    this.isMultiParticipant = false,
    this.maxParticipants = 1,
  });

  final String title;
  final String? description;
  final String taskType;
  final String? location;
  final double? latitude;
  final double? longitude;
  final double reward;
  final String currency;
  final List<String> images;
  final DateTime? deadline;
  final bool isMultiParticipant;
  final int maxParticipants;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      if (description != null) 'description': description,
      'task_type': taskType,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'reward': reward,
      'currency': currency,
      'images': images,
      if (deadline != null) 'deadline': deadline!.toIso8601String(),
      'is_multi_participant': isMultiParticipant,
      'max_participants': maxParticipants,
    };
  }
}
