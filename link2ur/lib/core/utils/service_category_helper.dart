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

  /// 类别 → 渐变色映射（达人卡片/详情页封面兜底）
  static const List<Color> _fallbackGradient = [
    Color(0xFFE5E7EB), Color(0xFFCBD5E1),
  ];
  static const Map<String, List<Color>> _gradientMap = {
    'programming':          [Color(0xFFC7CEEA), Color(0xFF8E9AEA)],
    'translation':          [Color(0xFFFFE8D6), Color(0xFFFFB5A7)],
    'tutoring':             [Color(0xFFBEE3DB), Color(0xFF7FD1B9)],
    'food':                 [Color(0xFFFFD6A5), Color(0xFFFF9F68)],
    'beverage':             [Color(0xFFFEE2E2), Color(0xFFFCA5A5)],
    'cake':                 [Color(0xFFFCE7F3), Color(0xFFF9A8D4)],
    'errand_transport':     [Color(0xFFD1E4FF), Color(0xFF89B4FF)],
    'social_entertainment': [Color(0xFFEDE9FE), Color(0xFFA78BFA)],
    'beauty_skincare':      [Color(0xFFFBC2EB), Color(0xFFA18CD1)],
    'handicraft':           [Color(0xFFE2D1F9), Color(0xFFB8A1D9)],
    'gaming':               [Color(0xFFCFFAFE), Color(0xFF67E8F9)],
    'photography':          [Color(0xFFFFE29F), Color(0xFFFFA99F)],
    'housekeeping':         [Color(0xFFB5EAD7), Color(0xFF7FD1B9)],
  };

  static List<Color> getGradient(String? category) {
    if (category == null || category.isEmpty) return _fallbackGradient;
    return _gradientMap[category.toLowerCase()] ?? _fallbackGradient;
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
