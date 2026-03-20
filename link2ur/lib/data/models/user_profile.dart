import 'package:equatable/equatable.dart';

/// 能力画像
class UserCapability extends Equatable {
  final int id;
  final int categoryId;
  final String? categoryNameZh;
  final String? categoryNameEn;
  final String skillName;
  final String proficiency;
  final String verificationSource;
  final int verifiedTaskCount;

  const UserCapability({
    required this.id,
    required this.categoryId,
    this.categoryNameZh,
    this.categoryNameEn,
    required this.skillName,
    required this.proficiency,
    required this.verificationSource,
    this.verifiedTaskCount = 0,
  });

  factory UserCapability.fromJson(Map<String, dynamic> json) {
    return UserCapability(
      id: json['id'] as int,
      categoryId: json['category_id'] as int,
      categoryNameZh: json['category_name_zh'] as String?,
      categoryNameEn: json['category_name_en'] as String?,
      skillName: json['skill_name'] as String,
      proficiency: json['proficiency'] as String? ?? 'beginner',
      verificationSource: json['verification_source'] as String? ?? 'self_declared',
      verifiedTaskCount: json['verified_task_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'category_id': categoryId,
    'skill_name': skillName,
    'proficiency': proficiency,
  };

  String displayCategoryName(String locale) {
    if (locale.startsWith('en')) return categoryNameEn ?? categoryNameZh ?? '';
    return categoryNameZh ?? categoryNameEn ?? '';
  }

  @override
  List<Object?> get props => [id, categoryId, skillName, proficiency, verificationSource, verifiedTaskCount];
}

/// 偏好画像
class UserProfilePreference extends Equatable {
  final String mode;
  final String durationType;
  final String rewardPreference;
  final List<String> preferredTimeSlots;
  final List<int> preferredCategories;
  final List<String> preferredHelperTypes;

  const UserProfilePreference({
    this.mode = 'both',
    this.durationType = 'both',
    this.rewardPreference = 'no_preference',
    this.preferredTimeSlots = const [],
    this.preferredCategories = const [],
    this.preferredHelperTypes = const [],
  });

  factory UserProfilePreference.fromJson(Map<String, dynamic> json) {
    return UserProfilePreference(
      mode: json['mode'] as String? ?? 'both',
      durationType: json['duration_type'] as String? ?? 'both',
      rewardPreference: json['reward_preference'] as String? ?? 'no_preference',
      preferredTimeSlots: (json['preferred_time_slots'] as List?)?.cast<String>() ?? [],
      preferredCategories: (json['preferred_categories'] as List?)?.cast<int>() ?? [],
      preferredHelperTypes: (json['preferred_helper_types'] as List?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'mode': mode,
    'duration_type': durationType,
    'reward_preference': rewardPreference,
    'preferred_time_slots': preferredTimeSlots,
    'preferred_categories': preferredCategories,
    'preferred_helper_types': preferredHelperTypes,
  };

  UserProfilePreference copyWith({
    String? mode,
    String? durationType,
    String? rewardPreference,
    List<String>? preferredTimeSlots,
    List<int>? preferredCategories,
    List<String>? preferredHelperTypes,
  }) {
    return UserProfilePreference(
      mode: mode ?? this.mode,
      durationType: durationType ?? this.durationType,
      rewardPreference: rewardPreference ?? this.rewardPreference,
      preferredTimeSlots: preferredTimeSlots ?? this.preferredTimeSlots,
      preferredCategories: preferredCategories ?? this.preferredCategories,
      preferredHelperTypes: preferredHelperTypes ?? this.preferredHelperTypes,
    );
  }

  @override
  List<Object?> get props => [mode, durationType, rewardPreference, preferredTimeSlots, preferredCategories, preferredHelperTypes];
}

/// 可靠度画像
class UserReliability extends Equatable {
  final double responseSpeedAvg;
  final double completionRate;
  final double onTimeRate;
  final double complaintRate;
  final double communicationScore;
  final double repeatRate;
  final double cancellationRate;
  final double? reliabilityScore;
  final int totalTasksTaken;
  final bool insufficientData;

  const UserReliability({
    this.responseSpeedAvg = 0,
    this.completionRate = 0,
    this.onTimeRate = 0,
    this.complaintRate = 0,
    this.communicationScore = 0,
    this.repeatRate = 0,
    this.cancellationRate = 0,
    this.reliabilityScore,
    this.totalTasksTaken = 0,
    this.insufficientData = true,
  });

  factory UserReliability.fromJson(Map<String, dynamic> json) {
    return UserReliability(
      responseSpeedAvg: (json['response_speed_avg'] as num?)?.toDouble() ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0,
      onTimeRate: (json['on_time_rate'] as num?)?.toDouble() ?? 0,
      complaintRate: (json['complaint_rate'] as num?)?.toDouble() ?? 0,
      communicationScore: (json['communication_score'] as num?)?.toDouble() ?? 0,
      repeatRate: (json['repeat_rate'] as num?)?.toDouble() ?? 0,
      cancellationRate: (json['cancellation_rate'] as num?)?.toDouble() ?? 0,
      reliabilityScore: (json['reliability_score'] as num?)?.toDouble(),
      totalTasksTaken: json['total_tasks_taken'] as int? ?? 0,
      insufficientData: json['insufficient_data'] as bool? ?? true,
    );
  }

  @override
  List<Object?> get props => [responseSpeedAvg, completionRate, onTimeRate, complaintRate,
    communicationScore, repeatRate, cancellationRate, reliabilityScore, totalTasksTaken];
}

/// 需求画像
class UserDemand extends Equatable {
  final String userStage;
  final List<PredictedNeed> predictedNeeds;
  final Map<String, dynamic> recentInterests;
  final String? lastInferredAt;

  const UserDemand({
    this.userStage = 'new_arrival',
    this.predictedNeeds = const [],
    this.recentInterests = const {},
    this.lastInferredAt,
  });

  factory UserDemand.fromJson(Map<String, dynamic> json) {
    return UserDemand(
      userStage: json['user_stage'] as String? ?? 'new_arrival',
      predictedNeeds: (json['predicted_needs'] as List?)
          ?.map((e) => PredictedNeed.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      recentInterests: json['recent_interests'] as Map<String, dynamic>? ?? {},
      lastInferredAt: json['last_inferred_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [userStage, predictedNeeds, recentInterests, lastInferredAt];
}

class PredictedNeed extends Equatable {
  final String category;
  final double confidence;
  final List<String> items;
  final String reason;

  const PredictedNeed({
    required this.category,
    required this.confidence,
    this.items = const [],
    this.reason = '',
  });

  factory PredictedNeed.fromJson(Map<String, dynamic> json) {
    return PredictedNeed(
      category: json['category'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      items: (json['items'] as List?)?.cast<String>() ?? [],
      reason: json['reason'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [category, confidence, items, reason];
}

/// 四维画像汇总
class UserProfileSummary extends Equatable {
  final List<UserCapability> capabilities;
  final UserProfilePreference preference;
  final UserReliability reliability;
  final UserDemand demand;

  const UserProfileSummary({
    this.capabilities = const [],
    this.preference = const UserProfilePreference(),
    this.reliability = const UserReliability(),
    this.demand = const UserDemand(),
  });

  factory UserProfileSummary.fromJson(Map<String, dynamic> json) {
    return UserProfileSummary(
      capabilities: (json['capabilities'] as List?)
          ?.map((e) => UserCapability.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      preference: json['preference'] != null
          ? UserProfilePreference.fromJson(json['preference'] as Map<String, dynamic>)
          : const UserProfilePreference(),
      reliability: json['reliability'] != null
          ? UserReliability.fromJson(json['reliability'] as Map<String, dynamic>)
          : const UserReliability(),
      demand: json['demand'] != null
          ? UserDemand.fromJson(json['demand'] as Map<String, dynamic>)
          : const UserDemand(),
    );
  }

  @override
  List<Object?> get props => [capabilities, preference, reliability, demand];
}
