import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 应用阴影系统
/// 采用双层阴影 (Double Shadow) 提升层次感
class AppShadows {
  AppShadows._();

  /// 基础卡片阴影 (浅色)
  static final List<BoxShadow> cardLight = [
    // 轮廓阴影
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    // 浮动阴影
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 12,
      offset: const Offset(0, 8),
    ),
  ];

  /// 基础卡片阴影 (深色)
  static final List<BoxShadow> cardDark = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.2),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 12,
      offset: const Offset(0, 8),
    ),
  ];

  /// 悬浮按钮阴影 (浅色)
  static final List<BoxShadow> floatingLight = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.2),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.15),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// 悬浮按钮阴影 (深色)
  static final List<BoxShadow> floatingDark = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.4),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// 获取卡片阴影
  static List<BoxShadow> card(bool isDark) => isDark ? cardDark : cardLight;

  /// 获取悬浮阴影
  static List<BoxShadow> floating(bool isDark) => isDark ? floatingDark : floatingLight;

  /// 主色调阴影（用于激活状态的按钮等）
  static List<BoxShadow> primary({double opacity = 0.2}) => [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: opacity),
      blurRadius: 8,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: opacity * 0.6),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// FAB 悬浮按钮阴影
  static final List<BoxShadow> fab = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.25),
      blurRadius: 12,
      offset: const Offset(0, 6),
    ),
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.15),
      blurRadius: 24,
      offset: const Offset(0, 12),
    ),
  ];

  /// 根据亮度获取双层卡片阴影
  static List<BoxShadow> cardDualForBrightness(Brightness brightness) =>
      brightness == Brightness.dark ? cardDark : cardLight;
}
