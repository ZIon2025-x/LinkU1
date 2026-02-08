import 'package:equatable/equatable.dart';

/// 活动模型
/// 参考后端 ActivityOut
class Activity extends Equatable {
  const Activity({
    required this.id,
    required this.title,
    this.description = '',
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
    this.status = 'active',
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
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String description;
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

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 第一张图片
  String? get firstImage {
    if (images != null && images!.isNotEmpty) return images!.first;
    if (serviceImages != null && serviceImages!.isNotEmpty) {
      return serviceImages!.first;
    }
    return null;
  }

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
      description: json['description'] as String? ?? '',
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
      status: json['status'] as String? ?? 'active',
      isPublic: json['is_public'] as bool? ?? true,
      visibility: json['visibility'] as String? ?? 'public',
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'])
          : null,
      activityEndDate: json['activity_end_date'] != null
          ? DateTime.parse(json['activity_end_date'])
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
      'description': description,
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
    };
  }

  Activity copyWith({
    int? id,
    String? title,
    String? description,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
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
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [id, title, status, updatedAt];
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

  factory ActivityListResponse.fromJson(Map<String, dynamic> json) {
    return ActivityListResponse(
      activities: (json['items'] as List<dynamic>?)
              ?.map((e) => Activity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}
