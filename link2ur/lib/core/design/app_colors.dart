import 'package:flutter/material.dart';

/// 应用颜色系统
/// 参考iOS DesignSystem.swift - AppColors
class AppColors {
  AppColors._();

  // ==================== 主色调 ====================
  /// 主色 - 系统蓝色
  static const Color primary = Color(0xFF007AFF);

  /// 主色变体
  static const Color primaryLight = Color(0xFF4DA3FF);
  static const Color primaryDark = Color(0xFF0055CC);

  /// 渐变主色
  static const List<Color> gradientPrimary = [
    Color(0xFF007AFF),
    Color(0xFF0055CC),
  ];

  // ==================== 辅助色 ====================
  /// 橙色 - 强调色
  static const Color accent = Color(0xFFFF9500);
  static const Color accentLight = Color(0xFFFFB84D);

  /// 金色 - VIP/特殊
  static const Color gold = Color(0xFFFFD700);

  /// 粉色 - 点赞/喜欢
  static const Color accentPink = Color(0xFFFF2D55);

  /// 青色 - 消息/在线
  static const Color teal = Color(0xFF5AC8FA);

  /// 紫色 - 特殊标签
  static const Color purple = Color(0xFFAF52DE);

  // ==================== 语义化颜色 ====================
  /// 成功
  static const Color success = Color(0xFF34C759);
  static const Color successLight = Color(0xFFE8F8EC);

  /// 警告
  static const Color warning = Color(0xFFFF9500);
  static const Color warningLight = Color(0xFFFFF4E5);

  /// 错误
  static const Color error = Color(0xFFFF3B30);
  static const Color errorLight = Color(0xFFFFE5E5);

  /// 信息
  static const Color info = Color(0xFF007AFF);
  static const Color infoLight = Color(0xFFE5F2FF);

  // ==================== 背景色 ====================
  /// 主背景色（浅色模式）
  static const Color backgroundLight = Color(0xFFF2F2F7);

  /// 主背景色（深色模式）
  static const Color backgroundDark = Color(0xFF000000);

  /// 卡片背景（浅色）
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);

  /// 卡片背景（深色）
  static const Color cardBackgroundDark = Color(0xFF1C1C1E);

  /// 二级背景
  static const Color secondaryBackgroundLight = Color(0xFFFFFFFF);
  static const Color secondaryBackgroundDark = Color(0xFF2C2C2E);

  /// 提升背景（模态框等）
  static const Color elevatedBackgroundLight = Color(0xFFFFFFFF);
  static const Color elevatedBackgroundDark = Color(0xFF2C2C2E);

  // ==================== 文字颜色 ====================
  /// 主要文字
  static const Color textPrimaryLight = Color(0xFF000000);
  static const Color textPrimaryDark = Color(0xFFFFFFFF);

  /// 次要文字
  static const Color textSecondaryLight = Color(0xFF8E8E93);
  static const Color textSecondaryDark = Color(0xFF8E8E93);

  /// 三级文字
  static const Color textTertiaryLight = Color(0xFFC7C7CC);
  static const Color textTertiaryDark = Color(0xFF48484A);

  /// 占位符文字
  static const Color textPlaceholderLight = Color(0xFFC7C7CC);
  static const Color textPlaceholderDark = Color(0xFF636366);

  // ==================== 分隔线 ====================
  /// 分隔线
  static const Color separatorLight = Color(0xFFC6C6C8);
  static const Color separatorDark = Color(0xFF38383A);

  /// 细分隔线
  static const Color dividerLight = Color(0xFFE5E5EA);
  static const Color dividerDark = Color(0xFF38383A);

  // ==================== 特殊颜色 ====================
  /// 遮罩层
  static const Color overlay = Color(0x80000000);

  /// 阴影
  static const Color shadowLight = Color(0x1A000000);
  static const Color shadowDark = Color(0x40000000);

  /// 骨架屏
  static const Color skeletonBase = Color(0xFFE0E0E0);
  static const Color skeletonHighlight = Color(0xFFF5F5F5);

  // ==================== 状态颜色 ====================
  /// 在线状态
  static const Color online = Color(0xFF34C759);

  /// 离线状态
  static const Color offline = Color(0xFF8E8E93);

  /// 忙碌状态
  static const Color busy = Color(0xFFFF9500);

  // ==================== 任务状态颜色 ====================
  static Color taskStatusColor(String status) {
    switch (status) {
      case 'open':
        return success;
      case 'in_progress':
        return primary;
      case 'pending_confirmation':
        return warning;
      case 'completed':
        return const Color(0xFF8E8E93);
      case 'cancelled':
        return error;
      case 'disputed':
        return accentPink;
      default:
        return textSecondaryLight;
    }
  }

  // ==================== 便捷颜色（默认浅色模式） ====================
  /// 主背景色
  static const Color background = backgroundLight;

  /// 卡片背景色
  static const Color cardBackground = cardBackgroundLight;

  /// 文字主色
  static const Color textPrimary = textPrimaryLight;

  /// 文字次色
  static const Color textSecondary = textSecondaryLight;

  /// 文字三级色
  static const Color textTertiary = textTertiaryLight;

  /// 分隔线色
  static const Color separator = separatorLight;

  // ==================== 工具方法 ====================
  /// 根据亮度获取背景色
  static Color backgroundFor(Brightness brightness) {
    return brightness == Brightness.light ? backgroundLight : backgroundDark;
  }

  /// 根据亮度获取卡片背景色
  static Color cardBackgroundFor(Brightness brightness) {
    return brightness == Brightness.light ? cardBackgroundLight : cardBackgroundDark;
  }

  /// 根据亮度获取文字主色
  static Color textPrimaryFor(Brightness brightness) {
    return brightness == Brightness.light ? textPrimaryLight : textPrimaryDark;
  }

  /// 根据亮度获取文字次色
  static Color textSecondaryFor(Brightness brightness) {
    return brightness == Brightness.light ? textSecondaryLight : textSecondaryDark;
  }
}
