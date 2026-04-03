import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
import '../../core/utils/localized_string.dart';

/// User badge model
class UserBadge extends Equatable {
  final int id;
  final String badgeType;
  final String? skillCategory;
  final String? skillNameZh;
  final String? skillNameEn;
  final String? city;
  final String? rank;
  final bool isDisplayed;
  final DateTime? grantedAt;

  const UserBadge({
    required this.id,
    required this.badgeType,
    this.skillCategory,
    this.skillNameZh,
    this.skillNameEn,
    this.city,
    this.rank,
    this.isDisplayed = false,
    this.grantedAt,
  });

  /// 根据 locale 返回技能分类名称
  String? displaySkillName(Locale locale) {
    return localizedStringOrNull(skillNameZh, skillNameEn, skillCategory, locale);
  }

  factory UserBadge.fromJson(Map<String, dynamic> json) {
    return UserBadge(
      id: json['id'] as int? ?? 0,
      badgeType: json['badge_type'] as String? ?? '',
      skillCategory: json['skill_category'] as String?,
      skillNameZh: json['skill_name_zh'] as String?,
      skillNameEn: json['skill_name_en'] as String?,
      city: json['city'] as String?,
      rank: json['rank']?.toString(),
      isDisplayed: parseBool(json['is_displayed']),
      grantedAt: json['granted_at'] != null
          ? DateTime.tryParse(json['granted_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'badge_type': badgeType,
        'skill_category': skillCategory,
        'skill_name_zh': skillNameZh,
        'skill_name_en': skillNameEn,
        'city': city,
        'rank': rank,
        'is_displayed': isDisplayed,
        'granted_at': grantedAt?.toIso8601String(),
      };

  UserBadge copyWith({
    int? id,
    String? badgeType,
    String? skillCategory,
    String? skillNameZh,
    String? skillNameEn,
    String? city,
    String? rank,
    bool? isDisplayed,
    DateTime? grantedAt,
  }) {
    return UserBadge(
      id: id ?? this.id,
      badgeType: badgeType ?? this.badgeType,
      skillCategory: skillCategory ?? this.skillCategory,
      skillNameZh: skillNameZh ?? this.skillNameZh,
      skillNameEn: skillNameEn ?? this.skillNameEn,
      city: city ?? this.city,
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
        skillNameZh,
        skillNameEn,
        city,
        rank,
        isDisplayed,
        grantedAt,
      ];
}
