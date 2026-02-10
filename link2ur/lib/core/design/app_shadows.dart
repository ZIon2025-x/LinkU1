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

  /// 小阴影 - 卡片默认（增强层次感）
  static List<BoxShadow> get small => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.10),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ];

  /// 中阴影 - 浮动卡片
  static List<BoxShadow> get medium => [
        BoxShadow(
          color: AppColors.shadowLight.withValues(alpha: 0.12),
          blurRadius: 16,
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
  /// 卡片双阴影 - 品牌色阴影 + 黑色基础阴影（增强层次）
  static List<BoxShadow> get cardDual => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.10),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];

  /// 深色模式卡片双阴影
  static List<BoxShadow> get cardDualDark => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.15),
          blurRadius: 14,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 2),
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

  // ==================== 交互阴影 ====================
  /// 卡片按压态阴影（缩小的阴影 → 贴近表面的感觉）
  static List<BoxShadow> get cardPressed => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.06),
          blurRadius: 6,
          offset: const Offset(0, 2),
        ),
      ];

  /// 卡片悬浮态阴影（放大的品牌色阴影）
  static List<BoxShadow> get cardHover => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.15),
          blurRadius: 20,
          offset: const Offset(0, 8),
        ),
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.04),
          blurRadius: 4,
          offset: const Offset(0, 2),
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
