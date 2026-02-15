import 'package:equatable/equatable.dart';

/// 用户模型
/// 参考iOS User.swift
class User extends Equatable {
  const User({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.avatar,
    this.bio,
    this.isVerified = false,
    this.userLevel,
    this.isExpert = false,
    this.isStudentVerified = false,
    this.taskCount = 0,
    this.completedTaskCount = 0,
    this.avgRating,
    this.residenceCity,
    this.languagePreference,
    this.isAdmin = false,
    this.createdAt,
  });

  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? avatar;
  final String? bio;
  final bool isVerified;
  final String? userLevel; // 后端返回字符串: "normal", "vip", "super"
  final bool isExpert;
  final bool isStudentVerified;
  final int taskCount;
  final int completedTaskCount;
  final double? avgRating;
  final String? residenceCity;
  final String? languagePreference;
  final bool isAdmin;
  final DateTime? createdAt;

  /// 头像URL
  String? get avatarUrl => avatar;

  /// 显示名称
  String get displayName => name.isNotEmpty ? name : '用户$id';

  /// 评分显示
  String get ratingDisplay => avgRating != null 
      ? avgRating!.toStringAsFixed(1) 
      : '-';

  /// 完成率
  double get completionRate {
    if (taskCount == 0) return 0;
    return completedTaskCount / taskCount;
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      isVerified: _parseBool(json['is_verified']),
      userLevel: _parseUserLevel(json['user_level']),
      isExpert: _parseBool(json['is_expert']),
      isStudentVerified: _parseBool(json['is_student_verified']),
      taskCount: json['task_count'] as int? ?? 0,
      completedTaskCount: json['completed_task_count'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      residenceCity: json['residence_city'] as String?,
      languagePreference: json['language_preference'] as String?,
      isAdmin: _parseBool(json['is_admin']),
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'].toString()) 
          : null,
    );
  }

  /// 兼容后端返回的 bool 可能是 bool、int(0/1) 或 null
  static bool _parseBool(dynamic value) {
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) return value == 'true' || value == '1';
    return false;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'avatar': avatar,
      'bio': bio,
      'is_verified': isVerified,
      'user_level': userLevel,
      'is_expert': isExpert,
      'is_student_verified': isStudentVerified,
      'task_count': taskCount,
      'completed_task_count': completedTaskCount,
      'avg_rating': avgRating,
      'residence_city': residenceCity,
      'language_preference': languagePreference,
      'is_admin': isAdmin,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? phone,
    String? avatar,
    String? bio,
    bool? isVerified,
    String? userLevel,
    bool? isExpert,
    bool? isStudentVerified,
    int? taskCount,
    int? completedTaskCount,
    double? avgRating,
    String? residenceCity,
    String? languagePreference,
    bool? isAdmin,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      avatar: avatar ?? this.avatar,
      bio: bio ?? this.bio,
      isVerified: isVerified ?? this.isVerified,
      userLevel: userLevel ?? this.userLevel,
      isExpert: isExpert ?? this.isExpert,
      isStudentVerified: isStudentVerified ?? this.isStudentVerified,
      taskCount: taskCount ?? this.taskCount,
      completedTaskCount: completedTaskCount ?? this.completedTaskCount,
      avgRating: avgRating ?? this.avgRating,
      residenceCity: residenceCity ?? this.residenceCity,
      languagePreference: languagePreference ?? this.languagePreference,
      isAdmin: isAdmin ?? this.isAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        phone,
        avatar,
        bio,
        isVerified,
        userLevel,
        isExpert,
        isStudentVerified,
        taskCount,
        completedTaskCount,
        avgRating,
        residenceCity,
        languagePreference,
        isAdmin,
        createdAt,
      ];

  /// 信用分（百分制，由avgRating转换）
  String get creditScoreDisplay {
    if (avgRating == null || avgRating! <= 0) return '--';
    final creditScore = (avgRating! / 5.0) * 100.0;
    return '${creditScore.toInt()}';
  }

  /// 解析 user_level 字段（后端可能返回 int 或 String）
  static String? _parseUserLevel(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) {
      switch (value) {
        case 2:
          return 'vip';
        case 3:
          return 'super';
        default:
          return 'normal';
      }
    }
    return value.toString();
  }

  /// 空用户
  static const empty = User(id: '', name: '');

  /// 是否为空用户
  bool get isEmpty => this == empty;

  /// 是否不为空用户
  bool get isNotEmpty => this != empty;
}

/// 登录响应
class LoginResponse {
  const LoginResponse({
    required this.accessToken,
    this.refreshToken,
    required this.user,
  });

  final String accessToken;
  final String? refreshToken;
  final User user;

  factory LoginResponse.fromJson(Map<String, dynamic> json) {
    // 后端返回 session_id 作为认证凭证（兼容旧版 access_token）
    final accessToken = json['session_id'] as String?
        ?? json['access_token'] as String?;
    if (accessToken == null || accessToken.isEmpty) {
      throw FormatException(
        'Login response missing session_id/access_token. Keys: ${json.keys.toList()}',
      );
    }

    final userJson = json['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw FormatException(
        'Login response missing user data. Keys: ${json.keys.toList()}',
      );
    }

    return LoginResponse(
      accessToken: accessToken,
      refreshToken: json['refresh_token'] as String?,
      user: User.fromJson(userJson),
    );
  }
}

/// 用户资料详情（含统计、近期任务、收到的评价）
class UserProfileDetail {
  const UserProfileDetail({
    required this.user,
    required this.stats,
    this.recentTasks = const [],
    this.reviews = const [],
    this.recentForumPosts = const [],
    this.soldFleaItems = const [],
  });

  final User user;
  final UserProfileStats stats;
  final List<UserProfileTask> recentTasks;
  final List<UserProfileReview> reviews;
  final List<UserProfileForumPost> recentForumPosts;
  final List<UserProfileFleaItem> soldFleaItems;

  factory UserProfileDetail.fromJson(Map<String, dynamic> json) {
    final userJson = json['user'] as Map<String, dynamic>?;
    if (userJson == null) {
      throw FormatException(
        'Profile response missing user. Keys: ${json.keys.toList()}',
      );
    }
    final statsJson = json['stats'] as Map<String, dynamic>? ?? {};
    final recentTasksRaw =
        json['recent_tasks'] as List<dynamic>? ?? [];
    final reviewsRaw = json['reviews'] as List<dynamic>? ?? [];
    final forumPostsRaw =
        json['recent_forum_posts'] as List<dynamic>? ?? [];
    final fleaItemsRaw =
        json['sold_flea_items'] as List<dynamic>? ?? [];

    return UserProfileDetail(
      user: User.fromJson(userJson),
      stats: UserProfileStats.fromJson(
        Map<String, dynamic>.from(statsJson),
      ),
      recentTasks: recentTasksRaw
          .map((e) => UserProfileTask.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      reviews: reviewsRaw
          .map((e) => UserProfileReview.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      recentForumPosts: forumPostsRaw
          .map((e) => UserProfileForumPost.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
      soldFleaItems: fleaItemsRaw
          .map((e) => UserProfileFleaItem.fromJson(
                Map<String, dynamic>.from(e as Map),
              ))
          .toList(),
    );
  }
}

class UserProfileStats {
  const UserProfileStats({
    this.totalTasks = 0,
    this.postedTasks = 0,
    this.takenTasks = 0,
    this.completedTasks = 0,
    this.totalReviews = 0,
    this.completionRate,
  });

  final int totalTasks;
  final int postedTasks;
  final int takenTasks;
  final int completedTasks;
  final int totalReviews;
  final double? completionRate;

  factory UserProfileStats.fromJson(Map<String, dynamic> json) {
    return UserProfileStats(
      totalTasks: json['total_tasks'] as int? ?? 0,
      postedTasks: json['posted_tasks'] as int? ?? 0,
      takenTasks: json['taken_tasks'] as int? ?? 0,
      completedTasks: json['completed_tasks'] as int? ?? 0,
      totalReviews: json['total_reviews'] as int? ?? 0,
      completionRate: (json['completion_rate'] as num?)?.toDouble(),
    );
  }
}

class UserProfileTask {
  const UserProfileTask({
    required this.id,
    required this.title,
    required this.status,
    required this.reward,
    this.createdAt,
    this.taskType,
  });

  final int id;
  final String title;
  final String status;
  final double reward;
  final String? createdAt;
  final String? taskType;

  factory UserProfileTask.fromJson(Map<String, dynamic> json) {
    return UserProfileTask(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      status: json['status'] as String? ?? '',
      reward: (json['reward'] as num?)?.toDouble() ?? 0,
      createdAt: json['created_at']?.toString(),
      taskType: json['task_type'] as String?,
    );
  }
}

/// 用户收到的评价（用于个人主页展示）
class UserProfileReview {
  const UserProfileReview({
    required this.id,
    required this.rating,
    this.comment,
    required this.createdAt,
    required this.taskId,
    this.isAnonymous = false,
    this.reviewerName,
    this.reviewerAvatar,
  });

  final int id;
  final double rating;
  final String? comment;
  final String createdAt;
  final int taskId;
  final bool isAnonymous;
  final String? reviewerName;
  final String? reviewerAvatar;

  factory UserProfileReview.fromJson(Map<String, dynamic> json) {
    return UserProfileReview(
      id: json['id'] as int,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
      createdAt: json['created_at']?.toString() ?? '',
      taskId: json['task_id'] as int? ?? 0,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
      reviewerName: json['reviewer_name'] as String?,
      reviewerAvatar: json['reviewer_avatar'] as String?,
    );
  }
}

/// 用户近期论坛帖子（用于个人主页展示）
class UserProfileForumPost {
  const UserProfileForumPost({
    required this.id,
    required this.title,
    this.contentPreview,
    this.images = const [],
    this.likeCount = 0,
    this.replyCount = 0,
    this.viewCount = 0,
    this.createdAt,
  });

  final int id;
  final String title;
  final String? contentPreview;
  final List<String> images;
  final int likeCount;
  final int replyCount;
  final int viewCount;
  final String? createdAt;

  factory UserProfileForumPost.fromJson(Map<String, dynamic> json) {
    return UserProfileForumPost(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      contentPreview: json['content_preview'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// 用户已售闲置物品（用于个人主页展示）
class UserProfileFleaItem {
  const UserProfileFleaItem({
    required this.id,
    required this.title,
    required this.price,
    this.images = const [],
    this.status = 'sold',
    this.viewCount = 0,
    this.createdAt,
  });

  final int id;
  final String title;
  final double price;
  final List<String> images;
  final String status;
  final int viewCount;
  final String? createdAt;

  factory UserProfileFleaItem.fromJson(Map<String, dynamic> json) {
    return UserProfileFleaItem(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      status: json['status'] as String? ?? 'sold',
      viewCount: json['view_count'] as int? ?? 0,
      createdAt: json['created_at']?.toString(),
    );
  }
}

/// 用户简要信息（用于列表显示）
class UserBrief {
  const UserBrief({
    required this.id,
    required this.name,
    this.avatar,
    this.isVerified = false,
  });

  final String id;
  final String name;
  final String? avatar;
  final bool isVerified;

  factory UserBrief.fromJson(Map<String, dynamic> json) {
    return UserBrief(
      id: json['id']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
    );
  }

  factory UserBrief.fromUser(User user) {
    return UserBrief(
      id: user.id,
      name: user.name,
      avatar: user.avatar,
      isVerified: user.isVerified,
    );
  }
}
