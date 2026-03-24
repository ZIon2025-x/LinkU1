import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';

/// 服务分类 → icon & 本地化名称映射
class ServiceCategoryHelper {
  ServiceCategoryHelper._();

  static IconData getIcon(String? category) {
    if (category == null) return Icons.build_outlined;
    return _iconMap[category] ?? Icons.build_outlined;
  }

  static String getLocalizedLabel(String category, AppLocalizations l10n) {
    final fn = _labelMap[category];
    if (fn != null) return fn(l10n);
    return category;
  }

  static const Map<String, IconData> _iconMap = {
    'programming': Icons.code,
    'translation': Icons.translate,
    'tutoring': Icons.school_outlined,
    'food': Icons.restaurant_outlined,
    'beverage': Icons.local_cafe_outlined,
    'cake': Icons.cake_outlined,
    'errand_transport': Icons.directions_run,
    'social_entertainment': Icons.people_outlined,
    'beauty_skincare': Icons.face_retouching_natural,
    'handicraft': Icons.handyman_outlined,
    'gaming': Icons.sports_esports_outlined,
    'photography': Icons.camera_alt_outlined,
    'housekeeping': Icons.home_outlined,
  };

  static final Map<String, String Function(AppLocalizations)> _labelMap = {
    'programming': (l) => l.expertCategoryProgramming,
    'translation': (l) => l.expertCategoryTranslation,
    'tutoring': (l) => l.expertCategoryTutoring,
    'food': (l) => l.expertCategoryFood,
    'beverage': (l) => l.expertCategoryBeverage,
    'cake': (l) => l.expertCategoryCake,
    'errand_transport': (l) => l.expertCategoryErrandTransport,
    'social_entertainment': (l) => l.expertCategorySocialEntertainment,
    'beauty_skincare': (l) => l.expertCategoryBeautySkincare,
    'handicraft': (l) => l.expertCategoryHandicraft,
    'gaming': (l) => l.expertCategoryGaming,
    'photography': (l) => l.expertCategoryPhotography,
    'housekeeping': (l) => l.expertCategoryHousekeeping,
  };
}
