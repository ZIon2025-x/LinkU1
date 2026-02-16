import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/localized_string.dart';
import '../../l10n/app_localizations.dart';

/// 任务达人模型
/// 后端实际返回格式参考 React 前端 TaskExperts.tsx 的 interface TaskExpert
/// 双语模式与 ForumCategory / LeaderboardItem 一致：
///   display* getter 优先 zh → en → 默认字段（后端已根据语言选择默认字段值）
class TaskExpert extends Equatable {
  const TaskExpert({
    required this.id,
    this.expertName,
    this.bio,
    this.bioEn,
    this.bioZh,
    this.avatar,
    this.status = 'active',
    this.rating = 0.0,
    this.totalServices = 0,
    this.completedTasks = 0,
    this.specialties,
    this.specialtiesEn,
    this.specialtiesZh,
    this.featuredSkills,
    this.featuredSkillsEn,
    this.featuredSkillsZh,
    this.achievements,
    this.achievementsEn,
    this.achievementsZh,
    this.responseTime,
    this.responseTimeEn,
    this.responseTimeZh,
    this.location,
    this.isVerified = false,
    this.userLevel,
    this.completionRate,
    this.successRate,
    this.category,
    this.totalTasks = 0,
    this.createdAt,
  });

  final String id;
  final String? expertName;
  // 双语：bio
  final String? bio;       // 后端根据语言选择的显示值
  final String? bioEn;
  final String? bioZh;
  final String? avatar;
  final String status;
  final double rating;     // 兼容 rating 和 avg_rating
  final int totalServices;
  final int completedTasks;
  // 双语：specialties / expertise_areas（专业领域）
  final List<String>? specialties;    // 后端根据语言选择的显示值
  final List<String>? specialtiesEn;
  final List<String>? specialtiesZh;
  // 双语：featured_skills（特色技能）
  final List<String>? featuredSkills;  // 后端根据语言选择的显示值
  final List<String>? featuredSkillsEn;
  final List<String>? featuredSkillsZh;
  // 双语：achievements（成就）
  final List<String>? achievements;    // 后端根据语言选择的显示值
  final List<String>? achievementsEn;
  final List<String>? achievementsZh;
  // 双语：response_time
  final String? responseTime;          // 后端根据语言选择的显示值
  final String? responseTimeEn;
  final String? responseTimeZh;
  // 扩展字段
  final String? location;
  final bool isVerified;
  final String? userLevel;
  final double? completionRate;
  final double? successRate;
  final String? category;
  final int totalTasks;
  final DateTime? createdAt;

  // ==================== 双语 display 访问器 ====================
  // 模式：zh → en → 默认字段（与 ForumCategory.displayName 一致）
  // 默认字段已由后端根据 Accept-Language 选择，作为最终回退

  /// 显示名称（硬编码回退，国际化请使用 displayNameWith(l10n)）
  String get displayName => expertName ?? '达人$id';

  /// 显示名称（国际化，expertName 为空时使用 l10n.taskExpertWithId）
  String displayNameWith(AppLocalizations l10n) =>
      (expertName != null && expertName!.isNotEmpty)
          ? expertName!
          : l10n.taskExpertWithId(id);

  /// name 别名（兼容视图层）
  String get name => displayName;

  /// 显示简介（根据 locale 选择 zh/en）
  String? displayBio(Locale locale) =>
      localizedStringOrNull(bioZh, bioEn, bio, locale);

  /// 显示专业领域（根据 locale 选择 zh/en）
  List<String> displaySpecialties(Locale locale) =>
      localizedList(specialtiesZh, specialtiesEn, specialties, locale);

  /// 显示特色技能（根据 locale 选择 zh/en）
  List<String> displayFeaturedSkills(Locale locale) =>
      localizedList(featuredSkillsZh, featuredSkillsEn, featuredSkills, locale);

  /// 显示成就（根据 locale 选择 zh/en）
  List<String> displayAchievements(Locale locale) =>
      localizedList(achievementsZh, achievementsEn, achievements, locale);

  /// 显示响应时间（根据 locale 选择 zh/en）
  String? displayResponseTime(Locale locale) =>
      localizedStringOrNull(responseTimeZh, responseTimeEn, responseTime, locale);

  /// 平均评分（可空版本，兼容视图层）
  double? get avgRating => rating > 0 ? rating : null;

  /// 评分显示
  String get ratingDisplay => rating > 0 ? rating.toStringAsFixed(1) : '-';

  factory TaskExpert.fromJson(Map<String, dynamic> json) {
    return TaskExpert(
      id: json['id']?.toString() ?? '',
      // 后端实际返回 name（FeaturedTaskExpert），兼容 expert_name（TaskExpertOut）
      expertName: json['name'] as String? ?? json['expert_name'] as String?,
      // 双语 bio
      bio: json['bio'] as String?,
      bioEn: json['bio_en'] as String?,
      bioZh: json['bio_zh'] as String?,
      avatar: json['avatar'] as String?,
      status: json['status'] as String? ?? 'active',
      // 后端实际返回 avg_rating（FeaturedTaskExpert），兼容 rating（TaskExpertOut）
      rating: (json['avg_rating'] as num?)?.toDouble() ??
          (json['rating'] as num?)?.toDouble() ??
          0.0,
      totalServices: json['total_services'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
      // 双语 specialties / expertise_areas（专业领域）
      specialties: _parseStringList(json['expertise_areas']) ??
          _parseStringList(json['specialties']),
      specialtiesEn: _parseStringList(json['expertise_areas_en']) ??
          _parseStringList(json['specialties_en']),
      specialtiesZh: _parseStringList(json['specialties_zh']),
      // 双语 featured_skills
      featuredSkills: _parseStringList(json['featured_skills']),
      featuredSkillsEn: _parseStringList(json['featured_skills_en']),
      featuredSkillsZh: _parseStringList(json['featured_skills_zh']),
      // 双语 achievements
      achievements: _parseStringList(json['achievements']),
      achievementsEn: _parseStringList(json['achievements_en']),
      achievementsZh: _parseStringList(json['achievements_zh']),
      // 双语 response_time
      responseTime: json['response_time'] as String?,
      responseTimeEn: json['response_time_en'] as String?,
      responseTimeZh: json['response_time_zh'] as String?,
      // 扩展字段（与 React 前端 TaskExpert interface 一致）
      location: json['location'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      userLevel: json['user_level'] as String?,
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
      successRate: (json['success_rate'] as num?)?.toDouble(),
      category: json['category'] as String?,
      totalTasks: json['total_tasks'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  /// 安全解析字符串列表（兼容 null 和非列表类型）
  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': expertName,
      'bio': bio,
      'bio_en': bioEn,
      'bio_zh': bioZh,
      'avatar': avatar,
      'status': status,
      'avg_rating': rating,
      'total_services': totalServices,
      'completed_tasks': completedTasks,
      'expertise_areas': specialties,
      'expertise_areas_en': specialtiesEn,
      'specialties_zh': specialtiesZh,
      'featured_skills': featuredSkills,
      'featured_skills_en': featuredSkillsEn,
      'featured_skills_zh': featuredSkillsZh,
      'achievements': achievements,
      'achievements_en': achievementsEn,
      'achievements_zh': achievementsZh,
      'response_time': responseTime,
      'response_time_en': responseTimeEn,
      'response_time_zh': responseTimeZh,
      'location': location,
      'is_verified': isVerified,
      'user_level': userLevel,
      'completion_rate': completionRate,
      'success_rate': successRate,
      'category': category,
      'total_tasks': totalTasks,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, expertName, rating, status, bio, specialties];
}

/// 任务达人服务模型
/// 参考后端 TaskExpertServiceOut
class TaskExpertService extends Equatable {
  const TaskExpertService({
    required this.id,
    required this.expertId,
    required this.serviceName,
    this.description = '',
    this.images,
    required this.basePrice,
    this.currency = 'GBP',
    this.status = 'active',
    this.displayOrder = 0,
    this.viewCount = 0,
    this.applicationCount = 0,
    this.createdAt,
    this.hasTimeSlots = false,
    this.timeSlotDurationMinutes,
    this.timeSlotStartTime,
    this.timeSlotEndTime,
    this.participantsPerSlot,
    this.userApplicationId,
    this.userApplicationStatus,
    this.userTaskId,
    this.userTaskStatus,
    this.userTaskIsPaid,
    this.userApplicationHasNegotiation,
  });

  final int id;
  final String expertId;
  final String serviceName;
  final String description;
  final List<String>? images;
  final double basePrice;
  final String currency;
  final String status;
  final int displayOrder;
  final int viewCount;
  final int applicationCount;
  final DateTime? createdAt;

  // 时间段相关
  final bool hasTimeSlots;
  final int? timeSlotDurationMinutes;
  final String? timeSlotStartTime;
  final String? timeSlotEndTime;
  final int? participantsPerSlot;

  // 用户申请状态
  final int? userApplicationId;
  final String? userApplicationStatus;
  final int? userTaskId;
  final String? userTaskStatus;
  final bool? userTaskIsPaid;
  final bool? userApplicationHasNegotiation;

  /// 价格显示
  String get priceDisplay => '£${basePrice.toStringAsFixed(2)}';

  /// 第一张图片
  String? get firstImage =>
      images != null && images!.isNotEmpty ? images!.first : null;

  /// 是否已申请
  bool get hasApplied => userApplicationId != null;

  factory TaskExpertService.fromJson(Map<String, dynamic> json) {
    return TaskExpertService(
      id: json['id'] as int,
      expertId: json['expert_id']?.toString() ?? '',
      serviceName: json['service_name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      basePrice: (json['base_price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      status: json['status'] as String? ?? 'active',
      displayOrder: json['display_order'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      applicationCount: json['application_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      hasTimeSlots: json['has_time_slots'] as bool? ?? false,
      timeSlotDurationMinutes: json['time_slot_duration_minutes'] as int?,
      timeSlotStartTime: json['time_slot_start_time'] as String?,
      timeSlotEndTime: json['time_slot_end_time'] as String?,
      participantsPerSlot: json['participants_per_slot'] as int?,
      userApplicationId: json['user_application_id'] as int?,
      userApplicationStatus: json['user_application_status'] as String?,
      userTaskId: json['user_task_id'] as int?,
      userTaskStatus: json['user_task_status'] as String?,
      userTaskIsPaid: json['user_task_is_paid'] as bool?,
      userApplicationHasNegotiation:
          json['user_application_has_negotiation'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'expert_id': expertId,
      'service_name': serviceName,
      'description': description,
      'images': images,
      'base_price': basePrice,
      'currency': currency,
      'status': status,
      'display_order': displayOrder,
      'view_count': viewCount,
      'application_count': applicationCount,
      'has_time_slots': hasTimeSlots,
      'time_slot_duration_minutes': timeSlotDurationMinutes,
      'time_slot_start_time': timeSlotStartTime,
      'time_slot_end_time': timeSlotEndTime,
      'participants_per_slot': participantsPerSlot,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [id, expertId, serviceName, basePrice, status];
}

/// 任务达人列表响应
class TaskExpertListResponse {
  const TaskExpertListResponse({
    required this.experts,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<TaskExpert> experts;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => experts.length >= pageSize;

  factory TaskExpertListResponse.fromJson(Map<String, dynamic> json) {
    // 兼容后端返回的不同 key（后端实际返回 task_experts）
    final rawList = (json['task_experts'] as List<dynamic>?) ??
        (json['items'] as List<dynamic>?) ??
        (json['experts'] as List<dynamic>?) ??
        [];
    return TaskExpertListResponse(
      experts: rawList
          .map((e) => TaskExpert.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? json['limit'] as int? ?? 20,
    );
  }

  /// 从原始列表构造（后端 GET /api/task-experts 返回的是数组）
  factory TaskExpertListResponse.fromList(
    List<dynamic> list, {
    int page = 1,
    int pageSize = 50,
  }) {
    final experts = list
        .map((e) => TaskExpert.fromJson(e as Map<String, dynamic>))
        .toList();
    return TaskExpertListResponse(
      experts: experts,
      total: experts.length,
      page: page,
      pageSize: pageSize,
    );
  }
}

/// 服务时间段模型
/// 对标iOS ServiceTimeSlot
class ServiceTimeSlot extends Equatable {
  const ServiceTimeSlot({
    required this.id,
    required this.serviceId,
    required this.slotStartDatetime,
    required this.slotEndDatetime,
    required this.currentParticipants,
    required this.maxParticipants,
    this.isAvailable = true,
    this.activityId,
    this.hasActivity,
    this.activityPrice,
    this.pricePerParticipant,
    this.isExpired,
    this.userHasApplied = false,
  });

  final int id;
  final int serviceId;
  final String slotStartDatetime;
  final String slotEndDatetime;
  final int currentParticipants;
  final int maxParticipants;
  final bool isAvailable;
  final int? activityId;
  final bool? hasActivity;
  final double? activityPrice;
  final double? pricePerParticipant;
  final bool? isExpired;
  final bool userHasApplied;

  /// 是否可选：未过期 + 未满员 + 可用 + 用户未申请过
  bool get canSelect =>
      isExpired != true &&
      currentParticipants < maxParticipants &&
      isAvailable &&
      !userHasApplied;

  /// 显示价格（优先活动价格）
  double? get displayPrice => activityPrice ?? pricePerParticipant;

  factory ServiceTimeSlot.fromJson(Map<String, dynamic> json) {
    return ServiceTimeSlot(
      id: json['id'] as int,
      serviceId: json['service_id'] as int? ?? 0,
      slotStartDatetime: json['slot_start_datetime'] as String? ?? '',
      slotEndDatetime: json['slot_end_datetime'] as String? ?? '',
      currentParticipants: json['current_participants'] as int? ?? 0,
      maxParticipants: json['max_participants'] as int? ?? 1,
      isAvailable: json['is_available'] as bool? ?? true,
      activityId: json['activity_id'] as int?,
      hasActivity: json['has_activity'] as bool?,
      activityPrice: (json['activity_price'] as num?)?.toDouble(),
      pricePerParticipant:
          (json['price_per_participant'] as num?)?.toDouble(),
      isExpired: json['is_expired'] as bool?,
      userHasApplied: json['user_has_applied'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props =>
      [id, serviceId, isExpired, currentParticipants, userHasApplied];
}
