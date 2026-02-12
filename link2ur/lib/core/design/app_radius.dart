import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// 应用圆角系统
/// 参考iOS DesignSystem.swift - AppCornerRadius
/// Web 桌面端使用更紧凑的圆角以对齐 frontend React 项目
class AppRadius {
  AppRadius._();

  // ==================== 基础圆角值 ====================
  /// 4pt - 超小圆角
  static const double tiny = 4.0;

  /// 小圆角：移动端 10pt（iOS 对齐），Web 桌面端 8pt（frontend 对齐）
  static const double small = kIsWeb ? 8.0 : 10.0;

  /// 中圆角：移动端 16pt（iOS 对齐），Web 桌面端 12pt（frontend 对齐）
  static const double medium = kIsWeb ? 12.0 : 16.0;

  /// 大圆角：移动端 24pt（iOS 对齐），Web 桌面端 16pt（frontend 对齐）
  static const double large = kIsWeb ? 16.0 : 24.0;

  /// 超大圆角：移动端 32pt（iOS 对齐），Web 桌面端 20pt（frontend 对齐）
  static const double xlarge = kIsWeb ? 20.0 : 32.0;

  /// 特大圆角
  static const double xxlarge = kIsWeb ? 24.0 : 36.0;

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
  static const BorderRadius topLarge = BorderRadius.only(
    topLeft: Radius.circular(large),
    topRight: Radius.circular(large),
  );

  /// 顶部圆角（模态框）
  static const BorderRadius topXlarge = BorderRadius.only(
    topLeft: Radius.circular(xlarge),
    topRight: Radius.circular(xlarge),
  );

  /// 底部圆角
  static const BorderRadius bottomMedium = BorderRadius.only(
    bottomLeft: Radius.circular(medium),
    bottomRight: Radius.circular(medium),
  );

  /// 左侧圆角
  static const BorderRadius leftMedium = BorderRadius.only(
    topLeft: Radius.circular(medium),
    bottomLeft: Radius.circular(medium),
  );

  /// 右侧圆角
  static const BorderRadius rightMedium = BorderRadius.only(
    topRight: Radius.circular(medium),
    bottomRight: Radius.circular(medium),
  );

  // ==================== 卡片圆角 ====================
  /// 卡片默认圆角
  static final BorderRadius card = allMedium;

  /// 按钮圆角 - 与iOS对齐使用medium(12pt)
  static final BorderRadius button = allMedium;

  /// 输入框圆角 - 与iOS对齐使用medium(12pt)
  static final BorderRadius input = allMedium;

  /// 图片圆角
  static final BorderRadius image = allMedium;

  /// 头像圆角
  static final BorderRadius avatar = allPill;

  /// 标签圆角
  static final BorderRadius tag = allTiny;

  /// 模态框圆角
  static const BorderRadius modal = topXlarge;

  // ==================== Radius快捷方式 ====================
  /// 圆形Radius
  static const Radius circularTiny = Radius.circular(tiny);
  static const Radius circularSmall = Radius.circular(small);
  static const Radius circularMedium = Radius.circular(medium);
  static const Radius circularLarge = Radius.circular(large);
  static const Radius circularXlarge = Radius.circular(xlarge);
}
