import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// 学生认证模型
/// 参考后端 StudentVerification status response
class StudentVerification extends Equatable {
  const StudentVerification({
    this.isVerified = false,
    this.status,
    this.university,
    this.email,
    this.verifiedAt,
    this.expiresAt,
    this.daysRemaining,
    this.canRenew = false,
    this.renewableFrom,
    this.emailLocked = false,
    this.tokenExpired = false,
  });

  final bool isVerified;
  final String? status; // pending, verified, expired, revoked
  final University? university;
  final String? email;
  final DateTime? verifiedAt;
  final DateTime? expiresAt;
  final int? daysRemaining;
  final bool canRenew;
  final DateTime? renewableFrom;
  final bool emailLocked;
  final bool tokenExpired;

  /// 是否正在审核中
  bool get isPending => status == AppConstants.verificationStatusPending;

  /// 是否已过期
  bool get isExpired => status == AppConstants.verificationStatusExpired;

  /// 是否已被撤销
  bool get isRevoked => status == AppConstants.verificationStatusRevoked;

  /// 是否即将过期（30天内）
  bool get isExpiringSoon =>
      daysRemaining != null && daysRemaining! <= 30 && daysRemaining! > 0;

  /// 状态显示文本
  String get statusText {
    switch (status) {
      case AppConstants.verificationStatusPending:
        return '审核中';
      case 'verified':
        return '已认证';
      case AppConstants.verificationStatusExpired:
        return '已过期';
      case AppConstants.verificationStatusRevoked:
        return '已撤销';
      default:
        return '未认证';
    }
  }

  factory StudentVerification.fromJson(Map<String, dynamic> json) {
    return StudentVerification(
      isVerified: json['is_verified'] as bool? ?? false,
      status: json['status'] as String?,
      university: json['university'] != null
          ? University.fromJson(json['university'] as Map<String, dynamic>)
          : null,
      email: json['email'] as String?,
      verifiedAt: json['verified_at'] != null
          ? DateTime.parse(json['verified_at'])
          : null,
      expiresAt: json['expires_at'] != null
          ? DateTime.parse(json['expires_at'])
          : null,
      daysRemaining: json['days_remaining'] as int?,
      canRenew: json['can_renew'] as bool? ?? false,
      renewableFrom: json['renewable_from'] != null
          ? DateTime.parse(json['renewable_from'])
          : null,
      emailLocked: json['email_locked'] as bool? ?? false,
      tokenExpired: json['token_expired'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_verified': isVerified,
      'status': status,
      'university': university?.toJson(),
      'email': email,
      'verified_at': verifiedAt?.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'days_remaining': daysRemaining,
      'can_renew': canRenew,
      'renewable_from': renewableFrom?.toIso8601String(),
      'email_locked': emailLocked,
      'token_expired': tokenExpired,
    };
  }

  @override
  List<Object?> get props => [isVerified, status, email];
}

/// 大学模型
class University extends Equatable {
  const University({
    required this.id,
    required this.name,
    this.nameCn,
  });

  final int id;
  final String name;
  final String? nameCn;

  /// 显示名称
  String get displayName => nameCn ?? name;

  factory University.fromJson(Map<String, dynamic> json) {
    return University(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameCn: json['name_cn'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'name_cn': nameCn,
    };
  }

  @override
  List<Object?> get props => [id, name];
}

/// 提交学生认证请求
class SubmitStudentVerificationRequest {
  const SubmitStudentVerificationRequest({
    required this.universityId,
    required this.email,
  });

  final int universityId;
  final String email;

  Map<String, dynamic> toJson() {
    return {
      'university_id': universityId,
      'email': email,
    };
  }
}
