import 'package:flutter/material.dart';

/// 应用圆角系统
/// 参考iOS DesignSystem.swift - AppCornerRadius
class AppRadius {
  AppRadius._();

  // ==================== 基础圆角值 ====================
  /// 4pt - 超小圆角
  static const double tiny = 4.0;

  /// 8pt - 小圆角
  static const double small = 8.0;

  /// 12pt - 中圆角（默认）
  static const double medium = 12.0;

  /// 16pt - 大圆角
  static const double large = 16.0;

  /// 20pt - 超大圆角
  static const double xlarge = 20.0;

  /// 24pt - 特大圆角
  static const double xxlarge = 24.0;

  /// 999pt - 胶囊/圆形
  static const double pill = 999.0;

  // ==================== BorderRadius快捷方式 ====================
  /// 无圆角
  static const BorderRadius zero = BorderRadius.zero;

  /// 超小圆角
  static final BorderRadius allTiny = BorderRadius.circular(tiny);

  /// 小圆角
  static final BorderRadius allSmall = BorderRadius.circular(small);

  /// 中圆角
  static final BorderRadius allMedium = BorderRadius.circular(medium);

  /// 大圆角
  static final BorderRadius allLarge = BorderRadius.circular(large);

  /// 超大圆角
  static final BorderRadius allXlarge = BorderRadius.circular(xlarge);

  /// 特大圆角
  static final BorderRadius allXxlarge = BorderRadius.circular(xxlarge);

  /// 胶囊圆角
  static final BorderRadius allPill = BorderRadius.circular(pill);

  // ==================== 特殊圆角 ====================
  /// 顶部圆角（底部Sheet）
  static final BorderRadius topLarge = BorderRadius.only(
    topLeft: Radius.circular(large),
    topRight: Radius.circular(large),
  );

  /// 顶部圆角（模态框）
  static final BorderRadius topXlarge = BorderRadius.only(
    topLeft: Radius.circular(xlarge),
    topRight: Radius.circular(xlarge),
  );

  /// 底部圆角
  static final BorderRadius bottomMedium = BorderRadius.only(
    bottomLeft: Radius.circular(medium),
    bottomRight: Radius.circular(medium),
  );

  /// 左侧圆角
  static final BorderRadius leftMedium = BorderRadius.only(
    topLeft: Radius.circular(medium),
    bottomLeft: Radius.circular(medium),
  );

  /// 右侧圆角
  static final BorderRadius rightMedium = BorderRadius.only(
    topRight: Radius.circular(medium),
    bottomRight: Radius.circular(medium),
  );

  // ==================== 卡片圆角 ====================
  /// 卡片默认圆角
  static final BorderRadius card = allMedium;

  /// 按钮圆角
  static final BorderRadius button = allSmall;

  /// 输入框圆角
  static final BorderRadius input = allSmall;

  /// 图片圆角
  static final BorderRadius image = allMedium;

  /// 头像圆角
  static final BorderRadius avatar = allPill;

  /// 标签圆角
  static final BorderRadius tag = allTiny;

  /// 模态框圆角
  static final BorderRadius modal = topXlarge;

  // ==================== Radius快捷方式 ====================
  /// 圆形Radius
  static final Radius circularTiny = Radius.circular(tiny);
  static final Radius circularSmall = Radius.circular(small);
  static final Radius circularMedium = Radius.circular(medium);
  static final Radius circularLarge = Radius.circular(large);
  static final Radius circularXlarge = Radius.circular(xlarge);
}
