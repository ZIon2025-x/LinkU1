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

  final int id;
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
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      bio: json['bio'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      userLevel: _parseUserLevel(json['user_level']),
      isExpert: json['is_expert'] as bool? ?? false,
      isStudentVerified: json['is_student_verified'] as bool? ?? false,
      taskCount: json['task_count'] as int? ?? 0,
      completedTaskCount: json['completed_task_count'] as int? ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      residenceCity: json['residence_city'] as String?,
      languagePreference: json['language_preference'] as String?,
      isAdmin: json['is_admin'] as bool? ?? false,
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at']) 
          : null,
    );
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
    int? id,
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
  static const empty = User(id: 0, name: '');

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
    return LoginResponse(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String?,
      user: User.fromJson(json['user'] as Map<String, dynamic>),
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

  final int id;
  final String name;
  final String? avatar;
  final bool isVerified;

  factory UserBrief.fromJson(Map<String, dynamic> json) {
    return UserBrief(
      id: json['id'] as int,
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
