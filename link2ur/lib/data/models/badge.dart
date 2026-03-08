import 'package:equatable/equatable.dart';

/// User badge model
class UserBadge extends Equatable {
  final int id;
  final String badgeType;
  final String? skillCategory;
  final String? rank;
  final bool isDisplayed;
  final DateTime? grantedAt;

  const UserBadge({
    required this.id,
    required this.badgeType,
    this.skillCategory,
    this.rank,
    this.isDisplayed = false,
    this.grantedAt,
  });

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'] as int? ?? 0,
      badgeType: json['badge_type'] as String? ?? '',
      skillCategory: json['skill_category'] as String?,
      rank: json['rank'] as String?,
      isDisplayed: json['is_displayed'] as bool? ?? false,
      grantedAt: json['granted_at'] != null
          ? DateTime.tryParse(json['granted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'badge_type': badgeType,
        'skill_category': skillCategory,
        'rank': rank,
        'is_displayed': isDisplayed,
        'granted_at': grantedAt?.toIso8601String(),
      };

  UserBadge copyWith({
    int? id,
    String? badgeType,
    String? skillCategory,
    String? rank,
    bool? isDisplayed,
    DateTime? grantedAt,
  }) {
    return UserBadge(
      id: id ?? this.id,
      badgeType: badgeType ?? this.badgeType,
      skillCategory: skillCategory ?? this.skillCategory,
      rank: rank ?? this.rank,
      isDisplayed: isDisplayed ?? this.isDisplayed,
      grantedAt: grantedAt ?? this.grantedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        badgeType,
        skillCategory,
        rank,
        isDisplayed,
        grantedAt,
      ];
}
