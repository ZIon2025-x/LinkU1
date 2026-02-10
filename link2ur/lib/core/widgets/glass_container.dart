import 'dart:ui';
import 'package:flutter/material.dart';

/// 毛玻璃容器组件
/// 参考 iOS .ultraThinMaterial + 白色边框叠加 (GlassStyle modifier)
/// 提供 iOS 风格的磨砂玻璃效果
class GlassContainer extends StatelessWidget {
  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius,
    this.padding,
    this.blurSigma = 20.0,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth = 0.5,
    this.opacity = 0.7,
  });

  final Widget child;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final double blurSigma;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderWidth;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorderRadius = borderRadius ?? BorderRadius.circular(16);
    final effectiveBackground = backgroundColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: opacity));
    final effectiveBorder = borderColor ??
        (isDark
            ? Colors.white.withValues(alpha: 0.15)
            : Colors.white.withValues(alpha: 0.2));

    return ClipRRect(
      borderRadius: effectiveBorderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: effectiveBackground,
            borderRadius: effectiveBorderRadius,
            border: Border.all(
              color: effectiveBorder,
              width: borderWidth,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// 毛玻璃卡片 - 预设常用参数的便捷版本
class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.blurSigma = 15.0,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      borderRadius: borderRadius ?? BorderRadius.circular(16),
      padding: padding,
      blurSigma: blurSigma,
      child: child,
    );
  }
}

/// 毛玻璃底部栏 - 用于底部操作栏、TabBar 等
class GlassBottomBar extends StatelessWidget {
  const GlassBottomBar({
    super.key,
    required this.child,
    this.padding,
    this.blurSigma = 25.0,
  });

  final Widget child;
  final EdgeInsets? padding;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return GlassContainer(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(20),
        topRight: Radius.circular(20),
      ),
      blurSigma: blurSigma,
      padding: padding ??
          EdgeInsets.only(
            left: 16,
            right: 16,
            top: 12,
            bottom: 12 + bottomPadding,
          ),
      child: child,
    );
  }
}
