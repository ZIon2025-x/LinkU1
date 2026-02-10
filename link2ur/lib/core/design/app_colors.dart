import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

/// 应用颜色系统
/// 参考iOS DesignSystem.swift - AppColors
class AppColors {
  AppColors._();

  // ==================== 主色调 ====================
  /// 主色 - 与iOS DesignSystem对齐 (#2659F2)
  static const Color primary = Color(0xFF2659F2);

  /// 主色变体
  static const Color primaryLight = Color(0xFF4088FF);
  static const Color primaryDark = Color(0xFF1A3FBF);

  /// 渐变主色 - 与iOS对齐 [#2659F2, #4088FF]
  static const List<Color> gradientPrimary = [
    Color(0xFF2659F2),
    Color(0xFF4088FF),
  ];

  // ==================== 辅助色 ====================
  /// 橙色 - 强调色 (与iOS accentOrange对齐)
  static const Color accent = Color(0xFFFF8033);
  static const Color accentLight = Color(0xFFFFB84D);

  /// 金色 - VIP/特殊
  static const Color gold = Color(0xFFFFD700);

  /// 粉色 - 点赞/喜欢 (与iOS accentPink对齐)
  static const Color accentPink = Color(0xFFFF4D80);

  /// 青色 - 消息/在线
  static const Color teal = Color(0xFF5AC8FA);

  /// 紫色 - 特殊标签 (与iOS accentPurple对齐)
  static const Color purple = Color(0xFF7359F2);

  // ==================== 语义化颜色 ====================
  /// 成功 (与iOS对齐 #26BF73)
  static const Color success = Color(0xFF26BF73);
  static const Color successLight = Color(0xFFE5F8EE);

  /// 警告 (与iOS对齐 #FFA600)
  static const Color warning = Color(0xFFFFA600);
  static const Color warningLight = Color(0xFFFFF4E5);

  /// 错误 (与iOS对齐 #F24D4D)
  static const Color error = Color(0xFFF24D4D);
  static const Color errorLight = Color(0xFFFFE5E5);

  /// 信息
  static const Color info = Color(0xFF2659F2);
  static const Color infoLight = Color(0xFFE5EDFF);

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

  // ==================== 桌面端 Notion/Linear 风格 ====================
  /// 桌面端文字色（浅色模式）
  static const Color desktopTextLight = Color(0xFF37352F);

  /// 桌面端输入框/悬浮背景（浅色模式）
  static const Color desktopHoverLight = Color(0xFFF0F0EE);

  /// 桌面端边框/分隔线（浅色模式）
  static const Color desktopBorderLight = Color(0xFFE8E8E5);

  /// 桌面端占位文字（浅色模式）
  static const Color desktopPlaceholderLight = Color(0xFF9B9A97);

  /// 通知红点
  static const Color badgeRed = Color(0xFFEB5757);

  /// 价格红色
  static const Color priceRed = Color(0xFFE64D4D);

  /// VIP 金色渐变
  static const List<Color> gradientGold = [
    Color(0xFFFFD700),
    Color(0xFFFF8C00),
  ];

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
      case AppConstants.taskStatusOpen:
        return success;
      case AppConstants.taskStatusInProgress:
        return primary;
      case AppConstants.taskStatusPendingConfirmation:
        return warning;
      case AppConstants.taskStatusPendingPayment:
        return const Color(0xFF8B5CF6); // 紫色 - 待支付
      case AppConstants.taskStatusCompleted:
        return const Color(0xFF8E8E93);
      case AppConstants.taskStatusCancelled:
        return error;
      case AppConstants.taskStatusDisputed:
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
