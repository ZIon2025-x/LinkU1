import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import '../../core/utils/localized_string.dart';

/// Newbie task configuration
class NewbieTaskConfig extends Equatable {
  final String taskKey;
  final int stage;
  final String titleZh;
  final String titleEn;
  final String descriptionZh;
  final String descriptionEn;
  final String rewardType;
  final int rewardAmount;
  final int? couponId;
  final int displayOrder;
  final bool isActive;

  const NewbieTaskConfig({
    required this.taskKey,
    required this.stage,
    required this.titleZh,
    required this.titleEn,
    this.descriptionZh = '',
    this.descriptionEn = '',
    required this.rewardType,
    required this.rewardAmount,
    this.couponId,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory NewbieTaskConfig.fromJson(Map<String, dynamic> json) {
    return NewbieTaskConfig(
      taskKey: json['task_key'] as String? ?? '',
      stage: json['stage'] as int? ?? 0,
      titleZh: json['title_zh'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      descriptionZh: json['description_zh'] as String? ?? '',
      descriptionEn: json['description_en'] as String? ?? '',
      rewardType: json['reward_type'] as String? ?? 'points',
      rewardAmount: json['reward_amount'] as int? ?? 0,
      couponId: json['coupon_id'] as int?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: parseBool(json['is_active'], true),
    );
  }

  Map<String, dynamic> toJson() => {
        'task_key': taskKey,
        'stage': stage,
        'title_zh': titleZh,
        'title_en': titleEn,
        'description_zh': descriptionZh,
        'description_en': descriptionEn,
        'reward_type': rewardType,
        'reward_amount': rewardAmount,
        'coupon_id': couponId,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, titleZh, locale);

  String displayDescription(Locale locale) =>
      localizedString(descriptionZh, descriptionEn, descriptionZh, locale);

  NewbieTaskConfig copyWith({
    String? taskKey,
    int? stage,
    String? titleZh,
    String? titleEn,
    String? descriptionZh,
    String? descriptionEn,
    String? rewardType,
    int? rewardAmount,
    int? couponId,
    int? displayOrder,
    bool? isActive,
  }) {
    return NewbieTaskConfig(
      taskKey: taskKey ?? this.taskKey,
      stage: stage ?? this.stage,
      titleZh: titleZh ?? this.titleZh,
      titleEn: titleEn ?? this.titleEn,
      descriptionZh: descriptionZh ?? this.descriptionZh,
      descriptionEn: descriptionEn ?? this.descriptionEn,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      couponId: couponId ?? this.couponId,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        taskKey,
        stage,
        titleZh,
        titleEn,
        descriptionZh,
        descriptionEn,
        rewardType,
        rewardAmount,
        couponId,
        displayOrder,
        isActive,
      ];
}

/// Newbie task progress (user-specific)
class NewbieTaskProgress extends Equatable {
  final String taskKey;
  final String status; // pending / completed / claimed
  final DateTime? completedAt;
  final DateTime? claimedAt;
  final NewbieTaskConfig config;

  const NewbieTaskProgress({
    required this.taskKey,
    required this.status,
    this.completedAt,
    this.claimedAt,
    required this.config,
  });

  factory NewbieTaskProgress.fromJson(Map<String, dynamic> json) {
    return NewbieTaskProgress(
      taskKey: json['task_key'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'].toString())
          : null,
      claimedAt: json['claimed_at'] != null
          ? DateTime.tryParse(json['claimed_at'].toString())
          : null,
      config: NewbieTaskConfig.fromJson(
        json['config'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'task_key': taskKey,
        'status': status,
        'completed_at': completedAt?.toIso8601String(),
        'claimed_at': claimedAt?.toIso8601String(),
        'config': config.toJson(),
      };

  NewbieTaskProgress copyWith({
    String? taskKey,
    String? status,
    DateTime? completedAt,
    DateTime? claimedAt,
    NewbieTaskConfig? config,
  }) {
    return NewbieTaskProgress(
      taskKey: taskKey ?? this.taskKey,
      status: status ?? this.status,
      completedAt: completedAt ?? this.completedAt,
      claimedAt: claimedAt ?? this.claimedAt,
      config: config ?? this.config,
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isClaimed => status == 'claimed';

  @override
  List<Object?> get props => [taskKey, status, completedAt, claimedAt, config];
}

/// Stage bonus configuration
class StageBonusConfig extends Equatable {
  final int stage;
  final String titleZh;
  final String titleEn;
  final String rewardType;
  final int rewardAmount;
  final int? couponId;
  final bool isActive;

  const StageBonusConfig({
    required this.stage,
    required this.titleZh,
    required this.titleEn,
    required this.rewardType,
    required this.rewardAmount,
    this.couponId,
    this.isActive = true,
  });

  factory StageBonusConfig.fromJson(Map<String, dynamic> json) {
    return StageBonusConfig(
      stage: json['stage'] as int? ?? 0,
      titleZh: json['title_zh'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      rewardType: json['reward_type'] as String? ?? 'points',
      rewardAmount: json['reward_amount'] as int? ?? 0,
      couponId: json['coupon_id'] as int?,
      isActive: parseBool(json['is_active'], true),
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'title_zh': titleZh,
        'title_en': titleEn,
        'reward_type': rewardType,
        'reward_amount': rewardAmount,
        'coupon_id': couponId,
        'is_active': isActive,
      };

  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, titleZh, locale);

  StageBonusConfig copyWith({
    int? stage,
    String? titleZh,
    String? titleEn,
    String? rewardType,
    int? rewardAmount,
    int? couponId,
    bool? isActive,
  }) {
    return StageBonusConfig(
      stage: stage ?? this.stage,
      titleZh: titleZh ?? this.titleZh,
      titleEn: titleEn ?? this.titleEn,
      rewardType: rewardType ?? this.rewardType,
      rewardAmount: rewardAmount ?? this.rewardAmount,
      couponId: couponId ?? this.couponId,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [
        stage,
        titleZh,
        titleEn,
        rewardType,
        rewardAmount,
        couponId,
        isActive,
      ];
}

/// Stage progress (user-specific)
class StageProgress extends Equatable {
  final int stage;
  final String status; // pending / completed / claimed
  final DateTime? claimedAt;
  final StageBonusConfig config;

  const StageProgress({
    required this.stage,
    required this.status,
    this.claimedAt,
    required this.config,
  });

  factory StageProgress.fromJson(Map<String, dynamic> json) {
    return StageProgress(
      stage: json['stage'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      claimedAt: json['claimed_at'] != null
          ? DateTime.tryParse(json['claimed_at'].toString())
          : null,
      config: StageBonusConfig.fromJson(
        json['config'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() => {
        'stage': stage,
        'status': status,
        'claimed_at': claimedAt?.toIso8601String(),
        'config': config.toJson(),
      };

  StageProgress copyWith({
    int? stage,
    String? status,
    DateTime? claimedAt,
    StageBonusConfig? config,
  }) {
    return StageProgress(
      stage: stage ?? this.stage,
      status: status ?? this.status,
      claimedAt: claimedAt ?? this.claimedAt,
      config: config ?? this.config,
    );
  }

  bool get isPending => status == 'pending';
  bool get isCompleted => status == 'completed';
  bool get isClaimed => status == 'claimed';

  @override
  List<Object?> get props => [stage, status, claimedAt, config];
}
