import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 自适应颜色 ThemeExtension
///
/// 通过 `Theme.of(context).extension<AppColorsExtension>()!` 获取，
/// 颜色自动适配深浅色模式，消除 view 层的 `isDark ? X : Y` 三元判断。
///
/// 用法:
/// ```dart
/// final colors = Theme.of(context).extension<AppColorsExtension>()!;
/// Container(color: colors.cardBackground);
/// Text('Hello', style: TextStyle(color: colors.textPrimary));
/// ```
class AppColorsExtension extends ThemeExtension<AppColorsExtension> {
  const AppColorsExtension({
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textPlaceholder,
    required this.background,
    required this.cardBackground,
    required this.secondaryBackground,
    required this.elevatedBackground,
    required this.separator,
    required this.divider,
    required this.surface1,
    required this.surface2,
    required this.surface3,
    required this.shimmerBase,
    required this.shimmerHighlight,
  });

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;
  final Color textPlaceholder;
  final Color background;
  final Color cardBackground;
  final Color secondaryBackground;
  final Color elevatedBackground;
  final Color separator;
  final Color divider;
  final Color surface1;
  final Color surface2;
  final Color surface3;
  final Color shimmerBase;
  final Color shimmerHighlight;

  static const light = AppColorsExtension(
    textPrimary: AppColors.textPrimaryLight,
    textSecondary: AppColors.textSecondaryLight,
    textTertiary: AppColors.textTertiaryLight,
    textPlaceholder: AppColors.textPlaceholderLight,
    background: AppColors.backgroundLight,
    cardBackground: AppColors.cardBackgroundLight,
    secondaryBackground: AppColors.secondaryBackgroundLight,
    elevatedBackground: AppColors.elevatedBackgroundLight,
    separator: AppColors.separatorLight,
    divider: AppColors.dividerLight,
    surface1: Color(0x08007AFF),
    surface2: Color(0x0D007AFF),
    surface3: Color(0x14007AFF),
    shimmerBase: AppColors.skeletonBase,
    shimmerHighlight: AppColors.skeletonHighlight,
  );

  static const dark = AppColorsExtension(
    textPrimary: AppColors.textPrimaryDark,
    textSecondary: AppColors.textSecondaryDark,
    textTertiary: AppColors.textTertiaryDark,
    textPlaceholder: AppColors.textPlaceholderDark,
    background: AppColors.backgroundDark,
    cardBackground: AppColors.cardBackgroundDark,
    secondaryBackground: AppColors.secondaryBackgroundDark,
    elevatedBackground: AppColors.elevatedBackgroundDark,
    separator: AppColors.separatorDark,
    divider: AppColors.dividerDark,
    surface1: Color(0x0D007AFF),
    surface2: Color(0x14007AFF),
    surface3: Color(0x1F007AFF),
    shimmerBase: Color(0xFF424242),
    shimmerHighlight: Color(0xFF616161),
  );

  @override
  AppColorsExtension copyWith({
    Color? textPrimary,
    Color? textSecondary,
    Color? textTertiary,
    Color? textPlaceholder,
    Color? background,
    Color? cardBackground,
    Color? secondaryBackground,
    Color? elevatedBackground,
    Color? separator,
    Color? divider,
    Color? surface1,
    Color? surface2,
    Color? surface3,
    Color? shimmerBase,
    Color? shimmerHighlight,
  }) {
    return AppColorsExtension(
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textTertiary: textTertiary ?? this.textTertiary,
      textPlaceholder: textPlaceholder ?? this.textPlaceholder,
      background: background ?? this.background,
      cardBackground: cardBackground ?? this.cardBackground,
      secondaryBackground: secondaryBackground ?? this.secondaryBackground,
      elevatedBackground: elevatedBackground ?? this.elevatedBackground,
      separator: separator ?? this.separator,
      divider: divider ?? this.divider,
      surface1: surface1 ?? this.surface1,
      surface2: surface2 ?? this.surface2,
      surface3: surface3 ?? this.surface3,
      shimmerBase: shimmerBase ?? this.shimmerBase,
      shimmerHighlight: shimmerHighlight ?? this.shimmerHighlight,
    );
  }

  @override
  AppColorsExtension lerp(AppColorsExtension? other, double t) {
    if (other is! AppColorsExtension) return this;
    return AppColorsExtension(
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textTertiary: Color.lerp(textTertiary, other.textTertiary, t)!,
      textPlaceholder: Color.lerp(textPlaceholder, other.textPlaceholder, t)!,
      background: Color.lerp(background, other.background, t)!,
      cardBackground: Color.lerp(cardBackground, other.cardBackground, t)!,
      secondaryBackground: Color.lerp(secondaryBackground, other.secondaryBackground, t)!,
      elevatedBackground: Color.lerp(elevatedBackground, other.elevatedBackground, t)!,
      separator: Color.lerp(separator, other.separator, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      surface1: Color.lerp(surface1, other.surface1, t)!,
      surface2: Color.lerp(surface2, other.surface2, t)!,
      surface3: Color.lerp(surface3, other.surface3, t)!,
      shimmerBase: Color.lerp(shimmerBase, other.shimmerBase, t)!,
      shimmerHighlight: Color.lerp(shimmerHighlight, other.shimmerHighlight, t)!,
    );
  }
}

/// BuildContext 快捷扩展
extension AppColorsExtensionContext on BuildContext {
  AppColorsExtension get appColors =>
      Theme.of(this).extension<AppColorsExtension>()!;
}
