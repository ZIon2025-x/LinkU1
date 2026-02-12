import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 应用阴影系统
/// 采用双层阴影 (Double Shadow) 提升层次感
/// 对齐 frontend 阴影参数：sm/md/lg/xl
class AppShadows {
  AppShadows._();

  /// 基础卡片阴影 (浅色) — 对齐 frontend md: 0 2px 8px rgba(0,0,0,0.1)
  static final List<BoxShadow> cardLight = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
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

  // ==================== 桌面端 Hover 阴影 ====================
  // 对齐 frontend hover 效果：translateY(-2px) + 增强阴影

  /// 桌面端卡片 hover 阴影 (浅色) — 对齐 frontend lg
  static final List<BoxShadow> cardHoverLight = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.08),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  /// 桌面端卡片 hover 阴影 (深色)
  static final List<BoxShadow> cardHoverDark = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.35),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  /// 获取卡片 hover 阴影
  static List<BoxShadow> cardHover(bool isDark) =>
      isDark ? cardHoverDark : cardHoverLight;
}
