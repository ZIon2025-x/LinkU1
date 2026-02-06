import 'package:flutter/material.dart';

/// 应用间距系统
/// 参考iOS DesignSystem.swift - AppSpacing
/// 使用8pt网格系统
class AppSpacing {
  AppSpacing._();

  // ==================== 基础间距 ====================
  /// 4pt - 超小间距
  static const double xs = 4.0;

  /// 8pt - 小间距
  static const double sm = 8.0;

  /// 16pt - 中间距（默认）
  static const double md = 16.0;

  /// 20pt - 大间距
  static const double lg = 20.0;

  /// 24pt - 超大间距
  static const double xl = 24.0;

  /// 32pt - 特大间距
  static const double xxl = 32.0;

  /// 40pt - 区块间距
  static const double section = 40.0;

  // ==================== 特殊间距 ====================
  /// 屏幕水平内边距
  static const double screenHorizontal = 16.0;

  /// 屏幕垂直内边距
  static const double screenVertical = 16.0;

  /// 卡片内边距
  static const double cardPadding = 16.0;

  /// 列表项垂直间距
  static const double listItemVertical = 12.0;

  /// 列表项水平间距
  static const double listItemHorizontal = 16.0;

  /// 按钮内边距
  static const double buttonPaddingVertical = 14.0;
  static const double buttonPaddingHorizontal = 24.0;

  /// 输入框内边距
  static const double inputPadding = 12.0;

  /// 图标与文字间距
  static const double iconTextGap = 8.0;

  /// 标签间距
  static const double tagGap = 8.0;

  /// 网格间距
  static const double gridGap = 12.0;

  // ==================== EdgeInsets快捷方式 ====================
  /// 无间距
  static const EdgeInsets zero = EdgeInsets.zero;

  /// 全部xs间距
  static const EdgeInsets allXs = EdgeInsets.all(xs);

  /// 全部sm间距
  static const EdgeInsets allSm = EdgeInsets.all(sm);

  /// 全部md间距
  static const EdgeInsets allMd = EdgeInsets.all(md);

  /// 全部lg间距
  static const EdgeInsets allLg = EdgeInsets.all(lg);

  /// 全部xl间距
  static const EdgeInsets allXl = EdgeInsets.all(xl);

  /// 水平md间距
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);

  /// 水平lg间距
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);

  /// 垂直sm间距
  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);

  /// 垂直md间距
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);

  /// 屏幕内边距
  static const EdgeInsets screen = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );

  /// 卡片内边距
  static const EdgeInsets card = EdgeInsets.all(cardPadding);

  /// 列表项内边距
  static const EdgeInsets listItem = EdgeInsets.symmetric(
    horizontal: listItemHorizontal,
    vertical: listItemVertical,
  );

  /// 按钮内边距
  static const EdgeInsets button = EdgeInsets.symmetric(
    horizontal: buttonPaddingHorizontal,
    vertical: buttonPaddingVertical,
  );

  // ==================== SizedBox快捷方式 ====================
  /// 水平间距
  static const SizedBox hXs = SizedBox(width: xs);
  static const SizedBox hSm = SizedBox(width: sm);
  static const SizedBox hMd = SizedBox(width: md);
  static const SizedBox hLg = SizedBox(width: lg);
  static const SizedBox hXl = SizedBox(width: xl);

  /// 垂直间距
  static const SizedBox vXs = SizedBox(height: xs);
  static const SizedBox vSm = SizedBox(height: sm);
  static const SizedBox vMd = SizedBox(height: md);
  static const SizedBox vLg = SizedBox(height: lg);
  static const SizedBox vXl = SizedBox(height: xl);
  static const SizedBox vXxl = SizedBox(height: xxl);
  static const SizedBox vSection = SizedBox(height: section);
}
