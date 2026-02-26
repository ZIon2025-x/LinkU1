import 'package:flutter/material.dart';
import '../design/app_colors.dart';

/// 首页同款背景：品牌渐变 + 装饰径向圆，可复用于社区等页
///
/// 用法：Scaffold.body 内 Stack 首子组件
/// ```dart
/// Scaffold(
///   body: Stack(
///     children: [
///       const RepaintBoundary(child: DecorativeBackground()),
///       SafeArea(child: yourContent),
///     ],
///   ),
/// )
/// ```
class DecorativeBackground extends StatelessWidget {
  const DecorativeBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return IgnorePointer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [AppColors.backgroundDark, AppColors.authDark]
                : [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.primary.withValues(alpha: 0.06),
                    AppColors.primary.withValues(alpha: 0.02),
                    AppColors.backgroundLight,
                  ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // 左上装饰圆
            Positioned(
              left: -160,
              top: -320,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.08),
                      AppColors.primary.withValues(alpha: 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 右下装饰圆（更淡）
            Positioned(
              right: -60,
              bottom: -80,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: isDark ? 0.01 : 0.015),
                      AppColors.primary.withValues(alpha: 0.004),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            // 右上一点粉/紫点缀（与主色区分）
            Positioned(
              right: 20,
              top: 80,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.accentPink.withValues(alpha: isDark ? 0.04 : 0.06),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
