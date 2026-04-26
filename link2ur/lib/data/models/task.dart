import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/constants/app_constants.dart';
import '../../core/utils/json_utils.dart';
import '../../core/utils/localized_string.dart';
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
    this.currency = 'GBP',
    required this.status,
    this.images = const [],
    this.deadline,
    required this.posterId,
    this.poster,
    this.takerId,
    this.taker,
    this.takerDisplay,
    this.isMultiParticipant = false,
    this.maxParticipants = 1,
    this.currentParticipants = 0,
    this.taskSource,
    this.taskLevel,
    this.hasApplied = false,
    this.userApplicationStatus,
    this.userApplicationId,
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
    this.distance,
    this.isFlexible = false,
    this.acceptedAt,
    this.completedAt,
    this.confirmedAt,
    this.autoConfirmed = false,
    this.confirmationRemainingSeconds,
    this.pointsReward,
    this.minParticipants,
    this.platformFeeRate,
    this.platformFeeAmount,
    this.rewardToBeQuoted = false,
    this.counterOfferPrice,
    this.counterOfferStatus,
    this.counterOfferUserId,
    this.isPublic = 1,
    this.takerPublic = 1,
    this.pricingType = 'fixed',
    this.taskMode = 'online',
    this.requiredSkills = const [],
    this.isConsultationPlaceholder = false,
    this.isPaid = false,
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

  /// 统一的"接单方"显示信息（spec §4.6 U2 方案）。
  ///
  /// - 团队接单(后端 `task.taker_expert_id` 非空)：`type='expert'`，
  ///   `entityId` 是 `experts.id`，`name`/`avatar` 是团队的名称和 logo
  /// - 个人接单：`type='user'`，`entityId` 是 `users.id`
  /// - 任务尚无接单方：`null`
  ///
  /// 渲染接单方信息时优先用此字段；旧的 `taker` (UserBrief) 仅作为个人接单
  /// 时的兜底，且不携带团队语义。
  final TakerDisplay? takerDisplay;

  final bool isMultiParticipant;
  final int maxParticipants;
  final int currentParticipants;
  final String? taskSource;
  final String? taskLevel; // normal, vip, super
  final bool hasApplied;
  final String? userApplicationStatus;
  final int? userApplicationId;
  final List<Map<String, dynamic>>? completionEvidence;
  final String? paymentExpiresAt;
  final String? confirmationDeadline;
  final double? agreedReward;
  final double? baseReward;
  final String? originatingUserId;
  final String? expertCreatorId;
  final bool hasReviewed;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 与用户的距离（米），由前端计算
  final double? distance;

  final bool isFlexible;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final DateTime? confirmedAt;
  final bool autoConfirmed;
  final int? confirmationRemainingSeconds;
  final int? pointsReward;
  final int? minParticipants;
  /// 平台服务费比例（如 0.08 表示 8%），由详情接口返回
  final double? platformFeeRate;
  /// 平台服务费金额（英镑），由详情接口返回
  final double? platformFeeAmount;
  /// 是否待报价（发布时未填金额，由接单者报价）
  final bool rewardToBeQuoted;
  final double? counterOfferPrice;
  final String? counterOfferStatus;
  final String? counterOfferUserId;
  final int isPublic;
  final int takerPublic;
  final String pricingType;
  final String taskMode;
  final List<String> requiredSkills;

  /// 是否为咨询占位任务（后端 is_consultation_placeholder，spec §F.1.2）
  final bool isConsultationPlaceholder;

  /// 是否已托管支付。后端 `Task.is_paid` (Integer 0/1) 经 schema 转 bool。
  /// 前端在 status==in_progress 时用此字段判断是否允许接单方点"标记完成":
  /// 后端 `POST /tasks/{id}/complete` 会校验 is_paid=true，否则拒 400 TASK_NOT_PAID。
  final bool isPaid;

  /// 模糊距离（500m 为一个区间）
  /// 返回区间上限值（用于排序），如 500, 1000, 1500, ...
  int? get blurredDistanceBucket {
    if (distance == null) return null;
    // 向上取整到最近的 500m
    return ((distance! / 500).ceil() * 500).toInt();
  }

  /// 模糊距离显示文本
  /// <500m → "<500m", 500-1000m → "<1km", 1-1.5km → "<1.5km", ...
  String? get blurredDistanceText {
    final bucket = blurredDistanceBucket;
    if (bucket == null) return null;
    if (bucket <= 500) return '<500m';
    if (bucket < 1000) return '<${bucket}m';
    final km = bucket / 1000;
    // 整数公里不显示小数点
    if (km == km.roundToDouble()) return '<${km.toInt()}km';
    return '<${km.toStringAsFixed(1)}km';
  }

  /// 显示标题（根据 locale 选择 zh/en）
  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, title, locale);

  /// 显示描述（根据 locale 选择 zh/en）
  String? displayDescription(Locale locale) =>
      localizedStringOrNull(descriptionZh, descriptionEn, description, locale);

  /// 是否是线上任务
  bool get isOnline => location == null || location == 'online';

  /// 模糊地址（隐藏详细街道信息，只保留区域级别）
  /// 例如 "London, Westminster, 10 Downing St" → "London, Westminster"
  /// 例如 "北京市朝阳区建国路88号" → "北京市朝阳区"
  String? get blurredLocation {
    if (location == null || isOnline) return location;
    final loc = location!.trim();

    // 尝试按逗号分割（英文地址格式: "City, Area, Street..."）
    final commaParts = loc.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (commaParts.length >= 2) {
      // 只保留前两段（通常是城市+区域）
      return commaParts.take(2).join(', ');
    }

    // 中文地址格式：尝试截取到"区/县/市"
    final zhMatch = RegExp(r'^(.+?[市省州])?(.+?[区县镇])').firstMatch(loc);
    if (zhMatch != null) {
      return zhMatch.group(0);
    }

    // 兜底：如果地址较长，只显示前半部分 + "附近"
    if (loc.length > 6) {
      return '${loc.substring(0, (loc.length * 0.5).ceil())}***';
    }

    return loc;
  }

  /// 判断指定用户是否可以查看完整地址
  /// 任务发布者和已接单者可以看到完整地址
  bool canViewFullAddress(String? userId) {
    if (userId == null) return false;
    if (userId == posterId) return true; // 发布者
    if (takerId != null && userId == takerId) return true; // 接单者
    // 已申请且被接受的用户
    if (userApplicationStatus == 'accepted') return true;
    return false;
  }

  /// 根据用户身份返回应该显示的地址
  String? displayLocation(String? currentUserId) {
    if (isOnline) return location;
    if (canViewFullAddress(currentUserId)) return location;
    return blurredLocation;
  }

  /// 是否已截止
  bool get isExpired => deadline != null && deadline!.isBefore(DateTime.now());

  /// 是否可以申请
  bool get canApply =>
      (status == AppConstants.taskStatusOpen || status == AppConstants.taskStatusConsulting) &&
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

  /// 是否是指定给当前用户的任务（来自用户资料页发送）
  bool get isDesignatedTask => taskSource == 'user_profile';

  /// 是否有特殊来源 (非普通任务)
  bool get hasSpecialSource =>
      isFleaMarketTask || isExpertServiceTask || isExpertActivityTask;

  // ==================== 任务等级 ====================

  /// 是否 VIP 任务
  bool get isVipTask => taskLevel == 'vip';

  /// 是否超级任务
  bool get isSuperTask => taskLevel == 'super';

  /// 是否达人任务
  bool get isExpertTask => taskLevel == 'expert';

  /// 是否有特殊等级
  bool get hasSpecialLevel =>
      taskLevel != null && taskLevel != 'normal';

  // ==================== 实际金额 ====================

  /// 实际显示金额 (协商价 > 基础价 > 奖励)；待报价且未议定价格时为 0
  double get displayReward => agreedReward ?? baseReward ?? reward;

  bool get hasCounterOfferPending => counterOfferStatus == 'pending';

  /// 是否仍处于「待报价」状态（发布时为待报价且尚未有议定金额时为 true；批准后已有 agreedReward 则为 false）
  bool get isPriceToBeQuoted =>
      rewardToBeQuoted && (agreedReward == null || agreedReward! <= 0);

  // ==================== 支付到期 ====================

  /// 支付是否已过期
  bool get isPaymentExpired {
    if (paymentExpiresAt == null || paymentExpiresAt!.isEmpty) return false;
    try {
      final expiry = DateTime.tryParse(paymentExpiresAt!);
      if (expiry == null) return false;
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
    final desc = description ?? descriptionZh ?? descriptionEn ?? '';
    const prefix = 'Category: ';
    final idx = desc.lastIndexOf(prefix);
    if (idx < 0) return null;
    final cat = desc.substring(idx + prefix.length).trim();
    return cat.isEmpty ? null : cat;
  }

  /// Header 中显示的分类文本 (跳蚤市场用商品分类，其他用 taskType)
  String get displayCategoryText =>
      (isFleaMarketTask ? fleaMarketCategory : null) ?? taskTypeText;

  /// 任务类型显示文本（国际化请使用 TaskTypeHelper.getLocalizedLabel(taskType, l10n)）
  String get taskTypeText {
    switch (taskType) {
      case 'Housekeeping':
        return '家政服务';
      case 'Campus Life':
        return '校园生活';
      case 'Second-hand & Rental':
        return '二手与租赁';
      case 'Errand Running':
        return '跑腿代办';
      case 'Skill Service':
        return '技能服务';
      case 'Social Help':
        return '社交互助';
      case 'Transportation':
        return '交通出行';
      case 'Pet Care':
        return '宠物照料';
      case 'Life Convenience':
        return '生活便利';
      case 'Other':
        return '其他';
      // 兼容旧数据
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
      case 'other':
        return '其他';
      default:
        return taskType;
    }
  }

  /// 第一张图片
  String? get firstImage => images.isNotEmpty ? images.first : null;

  static List<Map<String, dynamic>>? _parseCompletionEvidence(dynamic raw) {
    if (raw == null) return null;
    if (raw is List) {
      return raw.map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{}).toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return [{'type': 'text', 'content': raw}];
    }
    return null;
  }

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
      currency: json['currency'] as String? ?? 'GBP',
      status: json['status'] as String? ?? AppConstants.taskStatusOpen,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'])
          : null,
      posterId: json['poster_id']?.toString() ?? '',
      poster: json['poster'] != null
          ? UserBrief.fromJson(json['poster'] as Map<String, dynamic>)
          : null,
      takerId: json['taker_id']?.toString(),
      taker: json['taker'] != null
          ? UserBrief.fromJson(json['taker'] as Map<String, dynamic>)
          : null,
      takerDisplay: json['taker_display'] != null
          ? TakerDisplay.fromJson(json['taker_display'] as Map<String, dynamic>)
          : null,
      isMultiParticipant: parseBool(json['is_multi_participant']),
      maxParticipants: json['max_participants'] as int? ?? 1,
      currentParticipants: json['current_participants'] as int? ?? 0,
      taskSource: json['task_source'] as String?,
      taskLevel: json['task_level'] as String?,
      hasApplied: parseBool(json['has_applied']),
      userApplicationStatus: json['user_application_status'] as String?,
      userApplicationId: json['user_application_id'] as int?,
      completionEvidence: _parseCompletionEvidence(json['completion_evidence']),
      paymentExpiresAt: json['payment_expires_at'] as String?,
      confirmationDeadline: json['confirmation_deadline'] as String?,
      agreedReward: (json['agreed_reward'] as num?)?.toDouble(),
      baseReward: (json['base_reward'] as num?)?.toDouble(),
      originatingUserId: json['originating_user_id']?.toString(),
      expertCreatorId: json['expert_creator_id']?.toString(),
      hasReviewed: parseBool(json['has_reviewed']),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      distance: (json['distance'] as num?)?.toDouble(),
      isFlexible: (json['is_flexible'] as int? ?? 0) == 1,
      acceptedAt: json['accepted_at'] != null ? DateTime.tryParse(json['accepted_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      confirmedAt: json['confirmed_at'] != null ? DateTime.tryParse(json['confirmed_at'].toString()) : null,
      autoConfirmed: parseBool(json['auto_confirmed']),
      confirmationRemainingSeconds: json['confirmation_remaining_seconds'] as int?,
      pointsReward: json['points_reward'] as int?,
      minParticipants: json['min_participants'] as int?,
      platformFeeRate: (json['platform_fee_rate'] as num?)?.toDouble(),
      platformFeeAmount: (json['platform_fee_amount'] as num?)?.toDouble(),
      rewardToBeQuoted: parseBool(json['reward_to_be_quoted']),
      counterOfferPrice: (json['counter_offer_price'] as num?)?.toDouble(),
      counterOfferStatus: json['counter_offer_status'] as String?,
      counterOfferUserId: json['counter_offer_user_id'] as String?,
      isPublic: json['is_public'] as int? ?? 1,
      takerPublic: json['taker_public'] as int? ?? 1,
      pricingType: json['pricing_type'] as String? ?? 'fixed',
      taskMode: json['task_mode'] as String? ?? 'online',
      requiredSkills: (json['required_skills'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isConsultationPlaceholder: json['is_consultation_placeholder'] as bool? ?? false,
      isPaid: parseBool(json['is_paid']),
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
      if (takerDisplay != null) 'taker_display': takerDisplay!.toJson(),
      'is_multi_participant': isMultiParticipant,
      'max_participants': maxParticipants,
      'current_participants': currentParticipants,
      'task_source': taskSource,
      'task_level': taskLevel,
      'has_applied': hasApplied,
      'user_application_status': userApplicationStatus,
      'user_application_id': userApplicationId,
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
      'is_flexible': isFlexible ? 1 : 0,
      'accepted_at': acceptedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'confirmed_at': confirmedAt?.toIso8601String(),
      'auto_confirmed': autoConfirmed,
      'confirmation_remaining_seconds': confirmationRemainingSeconds,
      'points_reward': pointsReward,
      'min_participants': minParticipants,
      'reward_to_be_quoted': rewardToBeQuoted,
      'is_public': isPublic,
      'taker_public': takerPublic,
      'platform_fee_rate': platformFeeRate,
      'platform_fee_amount': platformFeeAmount,
      'counter_offer_price': counterOfferPrice,
      'counter_offer_status': counterOfferStatus,
      'counter_offer_user_id': counterOfferUserId,
      'pricing_type': pricingType,
      'task_mode': taskMode,
      'required_skills': requiredSkills,
      'is_consultation_placeholder': isConsultationPlaceholder,
      'is_paid': isPaid,
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
    TakerDisplay? takerDisplay,
    bool? isMultiParticipant,
    int? maxParticipants,
    int? currentParticipants,
    String? taskSource,
    String? taskLevel,
    bool? hasApplied,
    String? userApplicationStatus,
    int? userApplicationId,
    List<Map<String, dynamic>>? completionEvidence,
    String? paymentExpiresAt,
    String? confirmationDeadline,
    double? agreedReward,
    double? baseReward,
    String? originatingUserId,
    String? expertCreatorId,
    bool? hasReviewed,
    DateTime? createdAt,
    DateTime? updatedAt,
    double? distance,
    bool? isFlexible,
    DateTime? acceptedAt,
    DateTime? completedAt,
    DateTime? confirmedAt,
    bool? autoConfirmed,
    int? confirmationRemainingSeconds,
    int? pointsReward,
    int? minParticipants,
    double? platformFeeRate,
    double? platformFeeAmount,
    bool? rewardToBeQuoted,
    double? counterOfferPrice,
    String? counterOfferStatus,
    String? counterOfferUserId,
    int? isPublic,
    int? takerPublic,
    String? pricingType,
    String? taskMode,
    List<String>? requiredSkills,
    bool? isConsultationPlaceholder,
    bool? isPaid,
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
      takerDisplay: takerDisplay ?? this.takerDisplay,
      isMultiParticipant: isMultiParticipant ?? this.isMultiParticipant,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      taskSource: taskSource ?? this.taskSource,
      taskLevel: taskLevel ?? this.taskLevel,
      hasApplied: hasApplied ?? this.hasApplied,
      userApplicationStatus: userApplicationStatus ?? this.userApplicationStatus,
      userApplicationId: userApplicationId ?? this.userApplicationId,
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
      distance: distance ?? this.distance,
      isFlexible: isFlexible ?? this.isFlexible,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
      autoConfirmed: autoConfirmed ?? this.autoConfirmed,
      confirmationRemainingSeconds: confirmationRemainingSeconds ?? this.confirmationRemainingSeconds,
      pointsReward: pointsReward ?? this.pointsReward,
      minParticipants: minParticipants ?? this.minParticipants,
      platformFeeRate: platformFeeRate ?? this.platformFeeRate,
      platformFeeAmount: platformFeeAmount ?? this.platformFeeAmount,
      rewardToBeQuoted: rewardToBeQuoted ?? this.rewardToBeQuoted,
      counterOfferPrice: counterOfferPrice ?? this.counterOfferPrice,
      counterOfferStatus: counterOfferStatus ?? this.counterOfferStatus,
      counterOfferUserId: counterOfferUserId ?? this.counterOfferUserId,
      isPublic: isPublic ?? this.isPublic,
      takerPublic: takerPublic ?? this.takerPublic,
      pricingType: pricingType ?? this.pricingType,
      taskMode: taskMode ?? this.taskMode,
      requiredSkills: requiredSkills ?? this.requiredSkills,
      isConsultationPlaceholder: isConsultationPlaceholder ?? this.isConsultationPlaceholder,
      isPaid: isPaid ?? this.isPaid,
    );
  }

  @override
  List<Object?> get props => [
        id, title, status, reward, currency, hasApplied,
        userApplicationStatus, userApplicationId, takerId, takerDisplay, hasReviewed, updatedAt,
        counterOfferPrice, counterOfferStatus, counterOfferUserId,
        isPublic, takerPublic,
        pricingType, taskMode, requiredSkills,
        isConsultationPlaceholder,
        isPaid,
      ];
}

/// 接单方统一显示信息（spec §4.6 U2 方案）。
///
/// 后端 `build_taker_display` 序列化器返回:
/// - 团队任务: `{type: 'expert', entity_id, name, avatar}`
/// - 个人任务: `{type: 'user',   entity_id, name, avatar}`
/// - 未接单:   `null`
class TakerDisplay extends Equatable {
  const TakerDisplay({
    required this.type,
    required this.entityId,
    this.name,
    this.avatar,
  });

  /// `'expert'` 表示达人团队接单，`'user'` 表示个人接单
  final String type;

  /// `experts.id`（团队）或 `users.id`（个人）
  final String entityId;

  /// 团队名称或用户昵称
  final String? name;

  /// 团队 logo 或用户头像 URL
  final String? avatar;

  bool get isTeam => type == 'expert';
  bool get isIndividual => type == 'user';

  factory TakerDisplay.fromJson(Map<String, dynamic> json) {
    return TakerDisplay(
      type: (json['type'] as String?) ?? 'user',
      entityId: json['entity_id']?.toString() ?? '',
      name: json['name'] as String?,
      avatar: json['avatar'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'entity_id': entityId,
        'name': name,
        'avatar': avatar,
      };

  @override
  List<Object?> get props => [type, entityId, name, avatar];
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

  /// 后端返回 total 时用分页计算，否则用本页条数推断
  bool get hasMore =>
      total > 0 ? (page * pageSize < total) : (tasks.length >= pageSize);

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
    this.reward,
    this.currency = 'GBP',
    this.images = const [],
    this.deadline,
    this.isMultiParticipant = false,
    this.maxParticipants = 1,
    this.isPublic = 1,
    this.taskSource = 'normal',
    this.designatedTakerId,
    this.pricingType = 'fixed',
    this.taskMode = 'online',
    this.requiredSkills = const [],
    this.isFlexible = false,
  });

  final String title;
  final String? description;
  final String taskType;
  final String? location;
  final double? latitude;
  final double? longitude;
  /// 任务金额；null 表示待报价（由接单者报价/议价）
  final double? reward;
  final String currency;
  final List<String> images;
  final DateTime? deadline;
  final bool isMultiParticipant;
  final int maxParticipants;
  final int isPublic;
  final String taskSource;
  final String? designatedTakerId;
  /// 是否灵活时间（无截止日期）
  final bool isFlexible;
  /// 定价类型: fixed(固定价), negotiable(协商)
  final String pricingType;
  /// 任务方式: online(线上), offline(线下), both(都可以)
  final String taskMode;
  /// 所需技能标签
  final List<String> requiredSkills;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description ?? '',
      'task_type': taskType,
      'location': location ?? 'Online',
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (reward != null) 'reward': reward,
      'currency': currency,
      'images': images,
      if (deadline != null) 'deadline': deadline!.toUtc().toIso8601String(),
      'is_flexible': isFlexible ? 1 : 0,
      'is_multi_participant': isMultiParticipant,
      'max_participants': maxParticipants,
      'is_public': isPublic,
      'task_source': taskSource,
      if (designatedTakerId != null) 'designated_taker_id': designatedTakerId,
      'pricing_type': pricingType,
      'task_mode': taskMode,
      if (requiredSkills.isNotEmpty) 'required_skills': requiredSkills,
    };
  }
}
