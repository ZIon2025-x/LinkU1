import 'package:flutter/material.dart';

/// 应用文字样式系统
/// 参考iOS DesignSystem.swift - AppTypography
class AppTypography {
  AppTypography._();

  /// 字体家族
  static const String fontFamily = 'PingFang';

  // ==================== 标题样式 ====================
  /// 大标题 - 34pt Bold
  static const TextStyle largeTitle = TextStyle(
    fontSize: 34,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0.37,
  );

  /// 标题1 - 28pt Bold
  static const TextStyle title = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0.36,
  );

  /// 标题2 - 22pt Bold
  static const TextStyle title2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.3,
    letterSpacing: 0.35,
  );

  /// 标题3 - 20pt Semibold
  static const TextStyle title3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.38,
  );

  // ==================== 正文样式 ====================
  /// 正文 - 17pt Regular
  static const TextStyle body = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.41,
  );

  /// 正文加粗 - 17pt Semibold
  static const TextStyle bodyBold = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.41,
  );

  /// 标注 - 16pt Regular
  static const TextStyle callout = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.32,
  );

  /// 副标题 - 15pt Regular
  static const TextStyle subheadline = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.24,
  );

  /// 副标题加粗 - 15pt Semibold
  static const TextStyle subheadlineBold = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.24,
  );

  // ==================== 辅助样式 ====================
  /// 脚注 - 13pt Regular
  static const TextStyle footnote = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.08,
  );

  /// 说明文字 - 12pt Regular
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.3,
    letterSpacing: 0,
  );

  /// 说明文字2 - 11pt Regular
  static const TextStyle caption2 = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.normal,
    height: 1.3,
    letterSpacing: 0.07,
  );

  // ==================== 特殊样式 ====================
  /// 按钮文字 - 17pt Semibold
  static const TextStyle button = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.41,
  );

  /// 小按钮文字 - 15pt Medium
  static const TextStyle buttonSmall = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.24,
  );

  /// 标签文字 - 12pt Medium
  static const TextStyle tag = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0,
  );

  /// 徽章文字 - 10pt Bold
  static const TextStyle badge = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0,
  );

  /// 价格文字 - 24pt Bold
  static const TextStyle price = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0,
  );

  /// 小价格文字 - 17pt Semibold
  static const TextStyle priceSmall = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
  );

  /// 数字文字 - 使用等宽数字
  static const TextStyle number = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: [FontFeature.tabularFigures()],
  );

  // ==================== 工具方法 ====================
  /// 带颜色的样式
  static TextStyle withColor(TextStyle style, Color color) {
    return style.copyWith(color: color);
  }

  /// 带最大行数的样式
  static TextStyle withMaxLines(TextStyle style, int maxLines) {
    return style.copyWith(overflow: TextOverflow.ellipsis);
  }
}
