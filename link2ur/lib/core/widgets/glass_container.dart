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
/// 支持渐变边框、按压缩放反馈
class GlassCard extends StatefulWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius,
    this.blurSigma = 15.0,
    this.onTap,
    this.useGradientBorder = false,
    this.gradientColors,
  });

  final Widget child;
  final EdgeInsets padding;
  final BorderRadius? borderRadius;
  final double blurSigma;
  final VoidCallback? onTap;
  /// 是否使用渐变边框
  final bool useGradientBorder;
  /// 渐变边框颜色（默认使用 primary 渐变）
  final List<Color>? gradientColors;

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = widget.borderRadius ?? BorderRadius.circular(16);

    Widget card;
    if (widget.useGradientBorder) {
      // 渐变边框效果：用 DecoratedBox 渐变背景 + ClipRRect + 内部 GlassContainer
      card = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: widget.gradientColors ?? const [Color(0xFF2659F2), Color(0xFF4088FF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(1.5), // 渐变边框宽度
          child: GlassContainer(
            borderRadius: radius,
            padding: widget.padding,
            blurSigma: widget.blurSigma,
            borderWidth: 0, // 内部不再需要边框
            child: widget.child,
          ),
        ),
      );
    } else {
      card = GlassContainer(
        borderRadius: radius,
        padding: widget.padding,
        blurSigma: widget.blurSigma,
        child: widget.child,
      );
    }

    if (widget.onTap != null) {
      card = GestureDetector(
        onTapDown: (_) => _scaleController.forward(),
        onTapUp: (_) => _scaleController.reverse(),
        onTapCancel: () => _scaleController.reverse(),
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) => Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          ),
          child: card,
        ),
      );
    }

    return card;
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
