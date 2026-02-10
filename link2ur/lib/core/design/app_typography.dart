import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 应用文字样式系统
/// 参考iOS DesignSystem.swift - AppTypography
/// 英文使用 Inter 品牌字体，中文自动回退系统字体
class AppTypography {
  AppTypography._();

  /// 品牌字体名称（Inter — 现代感 + 高可读性）
  /// Google Fonts 自动缓存，首次下载后不再请求网络
  /// 使用 static final 确保只解析一次字体族名称，避免每次访问 TextStyle 时重复调用
  static final String? _fontFamily = GoogleFonts.inter().fontFamily;

  // ==================== 标题样式 ====================
  /// 大标题 - 34pt Bold
  static final TextStyle largeTitle = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 34,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0.37,
  );

  /// 标题1 - 28pt Bold
  static final TextStyle title = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0.36,
  );

  /// 标题2 - 22pt Bold
  static final TextStyle title2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.bold,
    height: 1.3,
    letterSpacing: 0.35,
  );

  /// 标题3 - 20pt Semibold
  static final TextStyle title3 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0.38,
  );

  // ==================== 正文样式 ====================
  /// 正文 - 17pt Regular
  static final TextStyle body = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.41,
  );

  /// 正文加粗 - 17pt Semibold
  static final TextStyle bodyBold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.41,
  );

  /// 标注 - 16pt Regular
  static final TextStyle callout = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.32,
  );

  /// 副标题 - 15pt Regular
  static final TextStyle subheadline = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.24,
  );

  /// 副标题加粗 - 15pt Semibold
  static final TextStyle subheadlineBold = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.24,
  );

  // ==================== 辅助样式 ====================
  /// 脚注 - 13pt Regular
  static final TextStyle footnote = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 13,
    fontWeight: FontWeight.normal,
    height: 1.4,
    letterSpacing: -0.08,
  );

  /// 说明文字 - 12pt Regular
  static final TextStyle caption = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.normal,
    height: 1.3,
    letterSpacing: 0,
  );

  /// 说明文字2 - 11pt Regular
  static final TextStyle caption2 = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.normal,
    height: 1.3,
    letterSpacing: 0.07,
  );

  // ==================== 特殊样式 ====================
  /// 按钮文字 - 17pt Semibold
  static final TextStyle button = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -0.41,
  );

  /// 小按钮文字 - 15pt Medium
  static final TextStyle buttonSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 15,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: -0.24,
  );

  /// 标签文字 - 12pt Medium
  static final TextStyle tag = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0,
  );

  /// 徽章文字 - 10pt Bold
  static final TextStyle badge = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 10,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0,
  );

  /// 价格文字 - 24pt Bold + tabular figures
  static final TextStyle price = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: 0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// 小价格文字 - 17pt Semibold + tabular figures
  static final TextStyle priceSmall = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// 数字文字 - 使用等宽数字
  static final TextStyle number = TextStyle(
    fontFamily: _fontFamily,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.2,
    fontFeatures: const [FontFeature.tabularFigures()],
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
