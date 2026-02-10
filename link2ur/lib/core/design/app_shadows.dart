import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 应用阴影系统
/// 参考iOS DesignSystem.swift - AppShadow
class AppShadows {
  AppShadows._();

  // ==================== 基础阴影 ====================
  /// 超小阴影 - 轻微提升
  static List<BoxShadow> get tiny => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.04),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// 小阴影 - 卡片默认（与iOS对齐offset改为(0,4)）
  static List<BoxShadow> get small => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.06),
          blurRadius: 8,
          offset: const Offset(0, 4),
        ),
      ];

  /// 中阴影 - 浮动卡片 (与iOS对齐 y-offset: 6)
  static List<BoxShadow> get medium => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 6),
        ),
      ];

  /// 大阴影 - 模态框/弹窗
  static List<BoxShadow> get large => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.12),
          blurRadius: 15,
          offset: const Offset(0, 8),
        ),
      ];

  /// 特大阴影 - 浮动元素 (与iOS floating对齐 y-offset: 12)
  static List<BoxShadow> get xlarge => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.15),
          blurRadius: 25,
          offset: const Offset(0, 12),
        ),
      ];

  // ==================== 彩色阴影 ====================
  /// 主色阴影 (与iOS对齐 opacity: 0.25)
  static List<BoxShadow> primary({double opacity = 0.25}) => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// 成功色阴影
  static List<BoxShadow> success({double opacity = 0.3}) => [
        BoxShadow(
          color: AppColors.success.withValues(alpha: opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  /// 错误色阴影
  static List<BoxShadow> error({double opacity = 0.3}) => [
        BoxShadow(
          color: AppColors.error.withValues(alpha: opacity),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ==================== 卡片双阴影 ====================
  /// 卡片双阴影 - 与iOS对齐: 主色阴影 + 黑色轻阴影
  static List<BoxShadow> get cardDual => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.08),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.02),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// 深色模式卡片双阴影
  static List<BoxShadow> get cardDualDark => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];

  /// 根据亮度获取卡片双阴影
  static List<BoxShadow> cardDualForBrightness(Brightness brightness) {
    return brightness == Brightness.light ? cardDual : cardDualDark;
  }

  // ==================== 特殊阴影 ====================
  /// 底部导航栏阴影
  static List<BoxShadow> get bottomNav => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, -2),
        ),
      ];

  /// 顶部AppBar阴影
  static List<BoxShadow> get appBar => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.05),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  /// 浮动按钮阴影
  static List<BoxShadow> get fab => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 15,
          offset: const Offset(0, 6),
        ),
      ];

  /// 输入框聚焦阴影
  static List<BoxShadow> get inputFocus => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.15),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  // ==================== 深色模式阴影 ====================
  /// 深色模式小阴影
  static List<BoxShadow> get smallDark => [
        BoxShadow(
          color: AppColors.shadowDark.withValues(alpha: 0.2),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];

  /// 深色模式中阴影
  static List<BoxShadow> get mediumDark => [
        BoxShadow(
          color: AppColors.shadowDark.withValues(alpha: 0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  // ==================== 工具方法 ====================
  /// 根据亮度获取小阴影
  static List<BoxShadow> smallForBrightness(Brightness brightness) {
    return brightness == Brightness.light ? small : smallDark;
  }

  /// 根据亮度获取中阴影
  static List<BoxShadow> mediumForBrightness(Brightness brightness) {
    return brightness == Brightness.light ? medium : mediumDark;
  }
}
