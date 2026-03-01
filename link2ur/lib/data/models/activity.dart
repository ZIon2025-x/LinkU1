import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/localized_string.dart';

/// 活动模型
/// 参考后端 ActivityOut（含 title_en/title_zh/description_en/description_zh）
class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.title,
    this.titleEn,
    this.titleZh,
    this.description = '',
    this.descriptionEn,
    this.descriptionZh,
    required this.expertId,
    required this.expertServiceId,
    this.location = '',
    this.taskType = '',
    this.rewardType = 'cash',
    this.originalPricePerParticipant,
    this.discountPercentage,
    this.discountedPricePerParticipant,
    this.currency = 'GBP',
    this.pointsReward,
    this.maxParticipants = 0,
    this.minParticipants = 0,
    this.currentParticipants,
    this.completionRule = 'all',
    this.rewardDistribution = 'equal',
    this.status = 'open',
    this.isPublic = true,
    this.visibility = 'public',
    this.deadline,
    this.activityEndDate,
    this.images,
    this.serviceImages,
    this.hasTimeSlots = false,
    this.rewardApplicants = false,
    this.applicantRewardAmount,
    this.applicantPointsReward,
    this.reservedPointsTotal,
    this.distributedPointsTotal,
    this.hasApplied,
    this.userTaskId,
    this.userTaskStatus,
    this.userTaskIsPaid,
    this.userTaskHasNegotiation,
    this.type, // "applied", "favorited", "both" — 我的活动列表用
    this.participantStatus, // 参与状态
    this.createdAt,
    this.updatedAt,
    this.activityType = 'standard',
    this.prizeType,
    this.prizeDescription,
    this.prizeDescriptionEn,
    this.prizeCount,
    this.drawMode,
    this.drawAt,
    this.drawnAt,
    this.winners,
    this.isDrawn = false,
    this.isOfficial = false,
    this.currentApplicants,
  });

  final int id;
  final String title;
  final String? titleEn;
  final String? titleZh;
  final String description;
  final String? descriptionEn;
  final String? descriptionZh;
  final String expertId;
  final int expertServiceId;
  final String location;
  final String taskType;
  final String rewardType; // cash, points, both
  final double? originalPricePerParticipant;
  final double? discountPercentage;
  final double? discountedPricePerParticipant;
  final String currency;
  final int? pointsReward;
  final int maxParticipants;
  final int minParticipants;
  final int? currentParticipants;
  final String completionRule; // all, min
  final String rewardDistribution; // equal, custom
  final String status;
  final bool isPublic;
  final String visibility;
  final DateTime? deadline;
  final DateTime? activityEndDate;
  final List<String>? images;
  final List<String>? serviceImages;
  final bool hasTimeSlots;
  final bool rewardApplicants;
  final double? applicantRewardAmount;
  final int? applicantPointsReward;
  final int? reservedPointsTotal;
  final int? distributedPointsTotal;

  // 用户状态
  final bool? hasApplied;
  final int? userTaskId;
  final String? userTaskStatus;
  final bool? userTaskIsPaid;
  final bool? userTaskHasNegotiation;

  /// 活动类型标记（我的活动列表）: "applied", "favorited", "both"
  final String? type;

  /// 参与状态（已申请时的状态）
  final String? participantStatus;

  final DateTime? createdAt;
  final DateTime? updatedAt;
  // 活动类型与抽奖字段
  final String activityType;      // 'standard' | 'lottery' | 'first_come'
  final String? prizeType;
  final String? prizeDescription;
  final String? prizeDescriptionEn;
  final int? prizeCount;
  final String? drawMode;
  final DateTime? drawAt;
  final DateTime? drawnAt;
  final List<ActivityWinner>? winners;
  final bool isDrawn;
  final bool isOfficial;
  final int? currentApplicants;

  /// 是否抽奖活动
  bool get isLottery => activityType == 'lottery';

  /// 是否先到先得活动
  bool get isFirstCome => activityType == 'first_come';

  /// 是否官方活动（非 standard）
  bool get isOfficialActivity => activityType != 'standard';

  /// 第一张图片
  String? get firstImage {
    if (images != null && images!.isNotEmpty) return images!.first;
    if (serviceImages != null && serviceImages!.isNotEmpty) {
      return serviceImages!.first;
    }
    return null;
  }

  /// 是否已结束（对标 iOS activity.isEnded）
  bool get isEnded {
    const endedStatuses = ['ended', 'cancelled', 'completed', 'closed'];
    if (endedStatuses.contains(status.toLowerCase())) return true;
    if (deadline != null && DateTime.now().isAfter(deadline!)) return true;
    if (activityEndDate != null && DateTime.now().isAfter(activityEndDate!)) {
      return true;
    }
    return false;
  }

  /// 是否待审核
  bool get isPendingReview => status == 'pending_review';

  /// 是否已拒绝
  bool get isRejected => status == 'rejected';

  /// 是否已满员
  bool get isFull =>
      currentParticipants != null &&
      currentParticipants! >= maxParticipants;

  /// 参与进度
  double get participationProgress {
    if (maxParticipants == 0) return 0;
    return (currentParticipants ?? 0) / maxParticipants;
  }

  /// 是否有折扣
  bool get hasDiscount =>
      discountPercentage != null && discountPercentage! > 0;

  /// 按 locale 显示标题（优先 zh/en 列，缺则 fallback 到 title）
  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, title, locale);

  /// 按 locale 显示描述
  String displayDescription(Locale locale) =>
      localizedString(descriptionZh, descriptionEn, description, locale);

  /// 显示价格
  String get priceDisplay {
    if (discountedPricePerParticipant != null) {
      return '£${discountedPricePerParticipant!.toStringAsFixed(2)}';
    }
    if (originalPricePerParticipant != null) {
      return '£${originalPricePerParticipant!.toStringAsFixed(2)}';
    }
    return '免费';
  }

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      titleEn: json['title_en'] as String?,
      titleZh: json['title_zh'] as String?,
      description: json['description'] as String? ?? '',
      descriptionEn: json['description_en'] as String?,
      descriptionZh: json['description_zh'] as String?,
      expertId: json['expert_id']?.toString() ?? '',
      expertServiceId: json['expert_service_id'] as int? ?? 0,
      location: json['location'] as String? ?? '',
      taskType: json['task_type'] as String? ?? '',
      rewardType: json['reward_type'] as String? ?? 'cash',
      originalPricePerParticipant:
          (json['original_price_per_participant'] as num?)?.toDouble(),
      discountPercentage:
          (json['discount_percentage'] as num?)?.toDouble(),
      discountedPricePerParticipant:
          (json['discounted_price_per_participant'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'GBP',
      pointsReward: json['points_reward'] as int?,
      maxParticipants: json['max_participants'] as int? ?? 0,
      minParticipants: json['min_participants'] as int? ?? 0,
      currentParticipants: json['current_participants'] as int?,
      completionRule: json['completion_rule'] as String? ?? 'all',
      rewardDistribution: json['reward_distribution'] as String? ?? 'equal',
      status: json['status'] as String? ?? 'open',
      isPublic: json['is_public'] as bool? ?? true,
      visibility: json['visibility'] as String? ?? 'public',
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'])
          : null,
      activityEndDate: json['activity_end_date'] != null
          ? DateTime.tryParse(json['activity_end_date'])
          : null,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      serviceImages: (json['service_images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      hasTimeSlots: json['has_time_slots'] as bool? ?? false,
      rewardApplicants: json['reward_applicants'] as bool? ?? false,
      applicantRewardAmount:
          (json['applicant_reward_amount'] as num?)?.toDouble(),
      applicantPointsReward: json['applicant_points_reward'] as int?,
      reservedPointsTotal: json['reserved_points_total'] as int?,
      distributedPointsTotal: json['distributed_points_total'] as int?,
      hasApplied: json['has_applied'] as bool?,
      userTaskId: json['user_task_id'] as int?,
      userTaskStatus: json['user_task_status'] as String?,
      userTaskIsPaid: json['user_task_is_paid'] as bool?,
      userTaskHasNegotiation: json['user_task_has_negotiation'] as bool?,
      type: json['type'] as String?,
      participantStatus: json['participant_status'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
      // 活动类型与抽奖字段
      activityType: json['activity_type'] as String? ?? 'standard',
      prizeType: json['prize_type'] as String?,
      prizeDescription: json['prize_description'] as String?,
      prizeDescriptionEn: json['prize_description_en'] as String?,
      prizeCount: json['prize_count'] as int?,
      drawMode: json['draw_mode'] as String?,
      drawAt: json['draw_at'] != null
          ? DateTime.tryParse(json['draw_at'] as String)
          : null,
      drawnAt: json['drawn_at'] != null
          ? DateTime.tryParse(json['drawn_at'] as String)
          : null,
      winners: json['winners'] != null
          ? (json['winners'] as List)
              .map((w) => ActivityWinner.fromJson(w as Map<String, dynamic>))
              .toList()
          : null,
      isDrawn: json['is_drawn'] as bool? ?? false,
      isOfficial: json['is_official'] as bool? ?? false,
      currentApplicants: json['current_applicants'] as int?,
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
      'expert_id': expertId,
      'expert_service_id': expertServiceId,
      'location': location,
      'task_type': taskType,
      'reward_type': rewardType,
      'original_price_per_participant': originalPricePerParticipant,
      'discount_percentage': discountPercentage,
      'discounted_price_per_participant': discountedPricePerParticipant,
      'currency': currency,
      'points_reward': pointsReward,
      'max_participants': maxParticipants,
      'min_participants': minParticipants,
      'current_participants': currentParticipants,
      'status': status,
      'is_public': isPublic,
      'visibility': visibility,
      'deadline': deadline?.toIso8601String(),
      'activity_end_date': activityEndDate?.toIso8601String(),
      'images': images,
      'service_images': serviceImages,
      'has_time_slots': hasTimeSlots,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'activity_type': activityType,
      'prize_type': prizeType,
      'prize_description': prizeDescription,
      'prize_description_en': prizeDescriptionEn,
      'prize_count': prizeCount,
      'draw_mode': drawMode,
      'draw_at': drawAt?.toIso8601String(),
      'drawn_at': drawnAt?.toIso8601String(),
      'winners': winners?.map((w) => w.toJson()).toList(),
      'is_drawn': isDrawn,
      'is_official': isOfficial,
      'current_applicants': currentApplicants,
    };
  }

  Activity copyWith({
    int? id,
    String? title,
    String? titleEn,
    String? titleZh,
    String? description,
    String? descriptionEn,
    String? descriptionZh,
    String? expertId,
    int? expertServiceId,
    String? location,
    String? taskType,
    String? rewardType,
    double? originalPricePerParticipant,
    double? discountPercentage,
    double? discountedPricePerParticipant,
    String? currency,
    int? pointsReward,
    int? maxParticipants,
    int? minParticipants,
    int? currentParticipants,
    String? completionRule,
    String? rewardDistribution,
    String? status,
    bool? isPublic,
    String? visibility,
    DateTime? deadline,
    DateTime? activityEndDate,
    List<String>? images,
    List<String>? serviceImages,
    bool? hasTimeSlots,
    bool? rewardApplicants,
    double? applicantRewardAmount,
    int? applicantPointsReward,
    int? reservedPointsTotal,
    int? distributedPointsTotal,
    bool? hasApplied,
    int? userTaskId,
    String? userTaskStatus,
    bool? userTaskIsPaid,
    bool? userTaskHasNegotiation,
    String? type,
    String? participantStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? activityType,
    String? prizeType,
    String? prizeDescription,
    String? prizeDescriptionEn,
    int? prizeCount,
    String? drawMode,
    DateTime? drawAt,
    DateTime? drawnAt,
    List<ActivityWinner>? winners,
    bool? isDrawn,
    bool? isOfficial,
    int? currentApplicants,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      titleEn: titleEn ?? this.titleEn,
      titleZh: titleZh ?? this.titleZh,
      description: description ?? this.description,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      descriptionZh: descriptionZh ?? this.descriptionZh,
      expertId: expertId ?? this.expertId,
      expertServiceId: expertServiceId ?? this.expertServiceId,
      location: location ?? this.location,
      taskType: taskType ?? this.taskType,
      rewardType: rewardType ?? this.rewardType,
      originalPricePerParticipant: originalPricePerParticipant ?? this.originalPricePerParticipant,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      discountedPricePerParticipant: discountedPricePerParticipant ?? this.discountedPricePerParticipant,
      currency: currency ?? this.currency,
      pointsReward: pointsReward ?? this.pointsReward,
      maxParticipants: maxParticipants ?? this.maxParticipants,
      minParticipants: minParticipants ?? this.minParticipants,
      currentParticipants: currentParticipants ?? this.currentParticipants,
      completionRule: completionRule ?? this.completionRule,
      rewardDistribution: rewardDistribution ?? this.rewardDistribution,
      status: status ?? this.status,
      isPublic: isPublic ?? this.isPublic,
      visibility: visibility ?? this.visibility,
      deadline: deadline ?? this.deadline,
      activityEndDate: activityEndDate ?? this.activityEndDate,
      images: images ?? this.images,
      serviceImages: serviceImages ?? this.serviceImages,
      hasTimeSlots: hasTimeSlots ?? this.hasTimeSlots,
      rewardApplicants: rewardApplicants ?? this.rewardApplicants,
      applicantRewardAmount: applicantRewardAmount ?? this.applicantRewardAmount,
      applicantPointsReward: applicantPointsReward ?? this.applicantPointsReward,
      reservedPointsTotal: reservedPointsTotal ?? this.reservedPointsTotal,
      distributedPointsTotal: distributedPointsTotal ?? this.distributedPointsTotal,
      hasApplied: hasApplied ?? this.hasApplied,
      userTaskId: userTaskId ?? this.userTaskId,
      userTaskStatus: userTaskStatus ?? this.userTaskStatus,
      userTaskIsPaid: userTaskIsPaid ?? this.userTaskIsPaid,
      userTaskHasNegotiation: userTaskHasNegotiation ?? this.userTaskHasNegotiation,
      type: type ?? this.type,
      participantStatus: participantStatus ?? this.participantStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      activityType: activityType ?? this.activityType,
      prizeType: prizeType ?? this.prizeType,
      prizeDescription: prizeDescription ?? this.prizeDescription,
      prizeDescriptionEn: prizeDescriptionEn ?? this.prizeDescriptionEn,
      prizeCount: prizeCount ?? this.prizeCount,
      drawMode: drawMode ?? this.drawMode,
      drawAt: drawAt ?? this.drawAt,
      drawnAt: drawnAt ?? this.drawnAt,
      winners: winners ?? this.winners,
      isDrawn: isDrawn ?? this.isDrawn,
      isOfficial: isOfficial ?? this.isOfficial,
      currentApplicants: currentApplicants ?? this.currentApplicants,
    );
  }

  @override
  List<Object?> get props => [id, title, status, updatedAt, activityType, isDrawn, isOfficial];
}

/// 活动列表响应
class ActivityListResponse {
  const ActivityListResponse({
    required this.activities,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<Activity> activities;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => activities.length >= pageSize;

  /// 从分页 JSON 对象解析（兼容后端分页格式）
  factory ActivityListResponse.fromJson(
    Map<String, dynamic> json, {
    int page = 1,
    int pageSize = 20,
  }) {
    final list = (json['items'] ?? json['activities']) as List<dynamic>?;
    final activities = list
            ?.map((e) => Activity.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return ActivityListResponse(
      activities: activities,
      total: json['total'] as int? ?? activities.length,
      page: json['page'] as int? ?? page,
      pageSize: json['page_size'] as int? ?? pageSize,
    );
  }

  /// 从 JSON 数组解析（后端 /api/activities 返回 List<ActivityOut>）
  factory ActivityListResponse.fromList(
    List<dynamic> list, {
    int page = 1,
    int pageSize = 20,
  }) {
    final activities = list
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
    return ActivityListResponse(
      activities: activities,
      total: activities.length,
      page: page,
      pageSize: pageSize,
    );
  }
}

/// 活动获奖者模型
class ActivityWinner extends Equatable {
  final String userId;
  final String name;
  final String? avatarUrl;
  final int? prizeIndex;

  const ActivityWinner({
    required this.userId,
    required this.name,
    this.avatarUrl,
    this.prizeIndex,
  });

  factory ActivityWinner.fromJson(Map<String, dynamic> json) => ActivityWinner(
        userId: json['user_id'] as String,
        name: json['name'] as String,
        avatarUrl: json['avatar_url'] as String?,
        prizeIndex: json['prize_index'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'name': name,
        'avatar_url': avatarUrl,
        'prize_index': prizeIndex,
      };

  @override
  List<Object?> get props => [userId, name, avatarUrl, prizeIndex];
}

/// 官方活动抽奖/申请结果
class OfficialActivityResult extends Equatable {
  final bool isDrawn;
  final DateTime? drawnAt;
  final List<ActivityWinner> winners;
  final String? myStatus;
  final String? myVoucherCode;

  const OfficialActivityResult({
    required this.isDrawn,
    this.drawnAt,
    this.winners = const [],
    this.myStatus,
    this.myVoucherCode,
  });

  factory OfficialActivityResult.fromJson(Map<String, dynamic> json) =>
      OfficialActivityResult(
        isDrawn: json['is_drawn'] as bool? ?? false,
        drawnAt: json['drawn_at'] != null
            ? DateTime.tryParse(json['drawn_at'] as String)
            : null,
        winners: json['winners'] != null
            ? (json['winners'] as List)
                .map((w) => ActivityWinner.fromJson(w as Map<String, dynamic>))
                .toList()
            : const [],
        myStatus: json['my_status'] as String?,
        myVoucherCode: json['my_voucher_code'] as String?,
      );

  @override
  List<Object?> get props => [isDrawn, drawnAt, winners, myStatus, myVoucherCode];
}
