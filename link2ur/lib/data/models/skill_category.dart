import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';

/// Skill category model
class SkillCategory extends Equatable {
  final int id;
  final String nameZh;
  final String nameEn;
  final String? icon;
  final int displayOrder;
  final bool isActive;

  const SkillCategory({
    required this.id,
    required this.nameZh,
    required this.nameEn,
    this.icon,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory SkillCategory.fromJson(Map<String, dynamic> json) {
    return SkillCategory(
      id: json['id'] as int? ?? 0,
      nameZh: json['name_zh'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
      icon: json['icon'] as String?,
      displayOrder: json['display_order'] as int? ?? 0,
      isActive: parseBool(json['is_active'], true),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_zh': nameZh,
        'name_en': nameEn,
        'icon': icon,
        'display_order': displayOrder,
        'is_active': isActive,
      };

  SkillCategory copyWith({
    int? id,
    String? nameZh,
    String? nameEn,
    String? icon,
    int? displayOrder,
    bool? isActive,
  }) {
    return SkillCategory(
      id: id ?? this.id,
      nameZh: nameZh ?? this.nameZh,
      nameEn: nameEn ?? this.nameEn,
      icon: icon ?? this.icon,
      displayOrder: displayOrder ?? this.displayOrder,
      isActive: isActive ?? this.isActive,
    );
  }

  @override
  List<Object?> get props => [id, nameZh, nameEn, icon, displayOrder, isActive];
}
