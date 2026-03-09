import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Official task model (platform-created tasks with rewards)
class OfficialTask extends Equatable {
  final int id;
  final String titleZh;
  final String titleEn;
  final String descriptionZh;
  final String descriptionEn;
  final String? topicTag;
  final String taskType;
  final String rewardType;
  final int rewardAmount;
  final int? couponId;
  final int maxPerUser;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final bool isActive;
  final DateTime? createdAt;
  final int userSubmissionCount;

  const OfficialTask({
    required this.id,
    required this.titleZh,
    required this.titleEn,
    this.descriptionZh = '',
    this.descriptionEn = '',
    this.topicTag,
    required this.taskType,
    required this.rewardType,
    required this.rewardAmount,
    this.couponId,
    this.maxPerUser = 1,
    this.validFrom,
    this.validUntil,
    this.isActive = true,
    this.createdAt,
    this.userSubmissionCount = 0,
  });

  factory OfficialTask.fromJson(Map<String, dynamic> json) {
    return OfficialTask(
      id: json['id'] as int? ?? 0,
      titleZh: json['title_zh'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      descriptionZh: json['description_zh'] as String? ?? '',
      descriptionEn: json['description_en'] as String? ?? '',
      topicTag: json['topic_tag'] as String?,
      taskType: json['task_type'] as String? ?? '',
      rewardType: json['reward_type'] as String? ?? 'points',
      rewardAmount: json['reward_amount'] as int? ?? 0,
      couponId: json['coupon_id'] as int?,
      maxPerUser: json['max_per_user'] as int? ?? 1,
      validFrom: json['valid_from'] != null
          ? DateTime.tryParse(json['valid_from'].toString())
          : null,
      validUntil: json['valid_until'] != null
          ? DateTime.tryParse(json['valid_until'].toString())
          : null,
      isActive: parseBool(json['is_active'], true),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      userSubmissionCount: json['user_submission_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title_zh': titleZh,
        'title_en': titleEn,
        'description_zh': descriptionZh,
        'description_en': descriptionEn,
        'topic_tag': topicTag,
        'task_type': taskType,
        'reward_type': rewardType,
        'reward_amount': rewardAmount,
        'coupon_id': couponId,
        'max_per_user': maxPerUser,
        'valid_from': validFrom?.toIso8601String(),
        'valid_until': validUntil?.toIso8601String(),
        'is_active': isActive,
        'created_at': createdAt?.toIso8601String(),
        'user_submission_count': userSubmissionCount,
      };

  OfficialTask copyWith({
    int? id,
    String? titleZh,
    String? titleEn,
    String? descriptionZh,
    String? descriptionEn,
    String? topicTag,
    String? taskType,
    String? rewardType,
    int? rewardAmount,
    int? couponId,
    int? maxPerUser,
    DateTime? validFrom,
    DateTime? validUntil,
    bool? isActive,
    DateTime? createdAt,
    int? userSubmissionCount,
  }) {
    return OfficialTask(
      id: id ?? this.id,
      titleZh: titleZh ?? this.titleZh,
      titleEn: titleEn ?? this.titleEn,
      descriptionZh: descriptionZh ?? this.descriptionZh,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      topicTag: topicTag ?? this.topicTag,
      taskType: taskType ?? this.taskType,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      couponId: couponId ?? this.couponId,
      maxPerUser: maxPerUser ?? this.maxPerUser,
      validFrom: validFrom ?? this.validFrom,
      validUntil: validUntil ?? this.validUntil,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      userSubmissionCount: userSubmissionCount ?? this.userSubmissionCount,
    );
  }

  /// Whether the task is currently valid (within date range)
  bool get isCurrentlyValid {
    final now = DateTime.now();
    if (validFrom != null && now.isBefore(validFrom!)) return false;
    if (validUntil != null && now.isAfter(validUntil!)) return false;
    return isActive;
  }

  /// Whether the user has reached the submission limit
  bool get hasReachedLimit => userSubmissionCount >= maxPerUser;

  @override
  List<Object?> get props => [
        id,
        titleZh,
        titleEn,
        descriptionZh,
        descriptionEn,
        topicTag,
        taskType,
        rewardType,
        rewardAmount,
        couponId,
        maxPerUser,
        validFrom,
        validUntil,
        isActive,
        createdAt,
        userSubmissionCount,
      ];
}
