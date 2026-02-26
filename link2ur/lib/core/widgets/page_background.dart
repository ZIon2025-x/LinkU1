import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// 与 iOS AppColors.background (systemGroupedBackground) 对齐的页面背景组件
///
/// 支持两种渐变模式（二选一）：
/// - [hasTopGradient]：顶部 300px 主色→透明叠加（个人中心页）
/// - [gradientToBackground]：整页主色→背景色渐变（社区等页），可复用
///
/// 用法示例：
/// ```dart
/// // 纯色背景
/// PageBackground(child: yourContent)
///
/// // 顶部 300px 渐变（个人中心）
/// PageBackground(hasTopGradient: true, child: yourContent)
///
/// // 整页主色→背景色渐变（社区）
/// PageBackground(gradientToBackground: true, child: yourContent)
/// ```
class PageBackground extends StatelessWidget {
  const PageBackground({
    super.key,
    required this.child,
    this.hasTopGradient = false,
    this.gradientToBackground = false,
    this.gradientStops,
    this.topOpacityDark,
    this.topOpacityLight,
  });

  /// 子组件
  final Widget child;

  /// 是否叠加顶部 300px 渐变（个人中心页）
  /// 对齐 iOS ProfileView：primary.opacity(0.15) → transparent
  final bool hasTopGradient;

  /// 是否使用整页「主色→背景色」渐变（社区等页可复用）
  /// 顶部主色半透明，向下过渡到 [AppColors.backgroundDark/Light]
  final bool gradientToBackground;

  /// [gradientToBackground] 为 true 时的渐变 stops，默认 [0.0, 0.35]
  final List<double>? gradientStops;

  /// 深色模式下顶部主色透明度，默认 0.12
  final double? topOpacityDark;

  /// 浅色模式下顶部主色透明度，默认 0.06
  final double? topOpacityLight;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (gradientToBackground) {
      final stops = gradientStops ?? [0.0, 0.35];
      final topDark = topOpacityDark ?? 0.12;
      final topLight = topOpacityLight ?? 0.06;
      return Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          AppColors.primary.withValues(alpha: topDark),
                          AppColors.backgroundDark,
                        ]
                      : [
                          AppColors.primary.withValues(alpha: topLight),
                          AppColors.backgroundLight,
                        ],
                  stops: stops,
                ),
              ),
            ),
          ),
          child,
        ],
      );
    }

    if (hasTopGradient) {
      return Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 300,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      );
    }

    return child;
  }
}
