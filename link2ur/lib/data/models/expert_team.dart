import 'package:equatable/equatable.dart';

/// 达人团队
class ExpertTeam extends Equatable {
  final String id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String? bio;
  final String? bioEn;
  final String? bioZh;
  final String? avatar;
  final String status;
  final bool allowApplications;
  final int memberCount;
  final double rating;
  final int totalServices;
  final int completedTasks;
  final double completionRate;
  final bool isOfficial;
  final String? officialBadge;
  final bool stripeOnboardingComplete;
  final DateTime? createdAt;
  final bool isFollowing;
  final String? myRole;
  final int? forumCategoryId;
  final List<ExpertMember>? members;
  final bool? isFeatured;
  final String? location;
  final double? latitude;
  final double? longitude;
  final int? serviceRadiusKm;
  // 达人画像字段 (migration 188)
  final String? category;
  final bool isVerified;
  final List<String>? expertiseAreas;
  final List<String>? expertiseAreasEn;
  final List<String>? featuredSkills;
  final List<String>? featuredSkillsEn;
  final List<String>? achievements;
  final List<String>? achievementsEn;
  final String? responseTime;
  final String? responseTimeEn;
  final String userLevel;
  /// 每周营业时间: {"mon": {"open": "09:00", "close": "18:00"}, "sun": null, ...}
  final Map<String, dynamic>? businessHours;

  const ExpertTeam({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    this.bio,
    this.bioEn,
    this.bioZh,
    this.avatar,
    this.status = 'active',
    this.allowApplications = false,
    this.memberCount = 1,
    this.rating = 0.0,
    this.totalServices = 0,
    this.completedTasks = 0,
    this.completionRate = 0.0,
    this.isOfficial = false,
    this.officialBadge,
    this.stripeOnboardingComplete = false,
    this.createdAt,
    this.isFollowing = false,
    this.myRole,
    this.forumCategoryId,
    this.members,
    this.isFeatured,
    this.location,
    this.latitude,
    this.longitude,
    this.serviceRadiusKm,
    this.category,
    this.isVerified = false,
    this.expertiseAreas,
    this.expertiseAreasEn,
    this.featuredSkills,
    this.featuredSkillsEn,
    this.achievements,
    this.achievementsEn,
    this.responseTime,
    this.responseTimeEn,
    this.userLevel = 'normal',
    this.businessHours,
  });

  factory ExpertTeam.fromJson(Map<String, dynamic> json) {
    return ExpertTeam(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      bio: json['bio'] as String?,
      bioEn: json['bio_en'] as String?,
      bioZh: json['bio_zh'] as String?,
      avatar: json['avatar'] as String?,
      status: json['status'] as String? ?? 'active',
      allowApplications: json['allow_applications'] as bool? ?? false,
      memberCount: json['member_count'] as int? ?? 1,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      totalServices: json['total_services'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble() ?? 0.0,
      isOfficial: json['is_official'] as bool? ?? false,
      officialBadge: json['official_badge'] as String?,
      stripeOnboardingComplete: json['stripe_onboarding_complete'] as bool? ?? false,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      isFollowing: json['is_following'] as bool? ?? false,
      myRole: json['my_role'] as String?,
      forumCategoryId: json['forum_category_id'] as int?,
      members: json['members'] != null
          ? (json['members'] as List).map((e) => ExpertMember.fromJson(e as Map<String, dynamic>)).toList()
          : null,
      isFeatured: json['is_featured'] as bool?,
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      serviceRadiusKm: json['service_radius_km'] as int?,
      category: json['category'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      expertiseAreas: (json['expertise_areas'] as List?)?.cast<String>(),
      expertiseAreasEn: (json['expertise_areas_en'] as List?)?.cast<String>(),
      featuredSkills: (json['featured_skills'] as List?)?.cast<String>(),
      featuredSkillsEn: (json['featured_skills_en'] as List?)?.cast<String>(),
      achievements: (json['achievements'] as List?)?.cast<String>(),
      achievementsEn: (json['achievements_en'] as List?)?.cast<String>(),
      responseTime: json['response_time'] as String?,
      responseTimeEn: json['response_time_en'] as String?,
      userLevel: json['user_level'] as String? ?? 'normal',
      businessHours: json['business_hours'] as Map<String, dynamic>?,
    );
  }

  String displayName(String locale) {
    if (locale.startsWith('zh')) return nameZh ?? name;
    return nameEn ?? name;
  }

  String? displayBio(String locale) {
    if (locale.startsWith('zh')) return bioZh ?? bio;
    return bioEn ?? bio;
  }

  List<String> displayExpertiseAreas(String locale) {
    if (locale.startsWith('zh')) return expertiseAreas ?? [];
    return expertiseAreasEn ?? expertiseAreas ?? [];
  }

  List<String> displayFeaturedSkills(String locale) {
    if (locale.startsWith('zh')) return featuredSkills ?? [];
    return featuredSkillsEn ?? featuredSkills ?? [];
  }

  List<String> displayAchievements(String locale) {
    if (locale.startsWith('zh')) return achievements ?? [];
    return achievementsEn ?? achievements ?? [];
  }

  String? displayResponseTime(String locale) {
    if (locale.startsWith('zh')) return responseTime;
    return responseTimeEn ?? responseTime;
  }

  @override
  List<Object?> get props => [
        id, name, nameEn, nameZh, bio, bioEn, bioZh, avatar,
        status, allowApplications, memberCount, rating,
        totalServices, completedTasks, completionRate,
        isOfficial, officialBadge, stripeOnboardingComplete,
        createdAt, isFollowing, myRole, forumCategoryId, members, isFeatured,
        location, latitude, longitude, serviceRadiusKm,
        category, isVerified, expertiseAreas, expertiseAreasEn,
        featuredSkills, featuredSkillsEn, achievements, achievementsEn,
        responseTime, responseTimeEn, userLevel, businessHours,
      ];
}

/// 达人团队成员
class ExpertMember extends Equatable {
  final int id;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String role;
  final String status;
  final DateTime? joinedAt;

  const ExpertMember({
    required this.id,
    required this.userId,
    this.userName,
    this.userAvatar,
    required this.role,
    this.status = 'active',
    this.joinedAt,
  });

  factory ExpertMember.fromJson(Map<String, dynamic> json) {
    return ExpertMember(
      id: json['id'] as int,
      userId: json['user_id'] as String? ?? '',
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      role: json['role'] as String,
      status: json['status'] as String? ?? 'active',
      joinedAt: json['joined_at'] != null ? DateTime.tryParse(json['joined_at'].toString()) : null,
    );
  }

  bool get isOwner => role == 'owner';
  bool get isAdmin => role == 'admin';
  bool get isMember => role == 'member';
  bool get canManage => role == 'owner' || role == 'admin';

  @override
  List<Object?> get props => [id, userId, role, status];
}

/// 达人创建申请
class ExpertTeamApplication extends Equatable {
  final int id;
  final String userId;
  final String expertName;
  final String? bio;
  final String? avatar;
  final String? applicationMessage;
  final String status;
  final String? reviewComment;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const ExpertTeamApplication({
    required this.id,
    required this.userId,
    required this.expertName,
    this.bio,
    this.avatar,
    this.applicationMessage,
    this.status = 'pending',
    this.reviewComment,
    this.createdAt,
    this.reviewedAt,
  });

  factory ExpertTeamApplication.fromJson(Map<String, dynamic> json) {
    return ExpertTeamApplication(
      id: json['id'] as int,
      userId: json['user_id'] as String,
      expertName: json['expert_name'] as String,
      bio: json['bio'] as String?,
      avatar: json['avatar'] as String?,
      applicationMessage: json['application_message'] as String?,
      status: json['status'] as String? ?? 'pending',
      reviewComment: json['review_comment'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  @override
  List<Object?> get props => [id, userId, status];
}

/// 加入团队请求
class ExpertJoinRequest extends Equatable {
  final int id;
  final String expertId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String? message;
  final String status;
  final DateTime? createdAt;
  final DateTime? reviewedAt;

  const ExpertJoinRequest({
    required this.id,
    required this.expertId,
    required this.userId,
    this.userName,
    this.userAvatar,
    this.message,
    this.status = 'pending',
    this.createdAt,
    this.reviewedAt,
  });

  factory ExpertJoinRequest.fromJson(Map<String, dynamic> json) {
    return ExpertJoinRequest(
      id: json['id'] as int,
      expertId: json['expert_id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      reviewedAt: json['reviewed_at'] != null ? DateTime.tryParse(json['reviewed_at'].toString()) : null,
    );
  }

  @override
  List<Object?> get props => [id, expertId, userId, status];
}

/// 团队邀请
class ExpertInvitation extends Equatable {
  final int id;
  final String expertId;
  final String inviterId;
  final String inviteeId;
  final String? inviteeName;
  final String? inviteeAvatar;
  final String status;
  final DateTime? createdAt;
  final DateTime? respondedAt;
  final String? expertName;
  final String? expertAvatar;

  const ExpertInvitation({
    required this.id,
    required this.expertId,
    required this.inviterId,
    required this.inviteeId,
    this.inviteeName,
    this.inviteeAvatar,
    this.status = 'pending',
    this.createdAt,
    this.respondedAt,
    this.expertName,
    this.expertAvatar,
  });

  factory ExpertInvitation.fromJson(Map<String, dynamic> json) {
    return ExpertInvitation(
      id: json['id'] as int,
      expertId: json['expert_id'] as String,
      inviterId: json['inviter_id'] as String,
      inviteeId: json['invitee_id'] as String,
      inviteeName: json['invitee_name'] as String?,
      inviteeAvatar: json['invitee_avatar'] as String?,
      status: json['status'] as String? ?? 'pending',
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'].toString()) : null,
      respondedAt: json['responded_at'] != null ? DateTime.tryParse(json['responded_at'].toString()) : null,
      expertName: json['expert_name'] as String?,
      expertAvatar: json['expert_avatar'] as String?,
    );
  }

  bool get isPending => status == 'pending';

  @override
  List<Object?> get props => [id, expertId, inviteeId, status];
}
