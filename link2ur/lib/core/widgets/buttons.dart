import 'package:flutter/material.dart';
import '../utils/haptic_feedback.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';
import 'loading_view.dart';

/// iOS 风格弹簧曲线
/// 模拟 SwiftUI spring(response: 0.3, dampingFraction: 0.6)
class _SpringCurve extends Curve {
  const _SpringCurve({this.damping = 0.6, this.response = 0.3});

  final double damping;
  final double response;

  @override
  double transformInternal(double t) {
    final omega = 2 * 3.14159 / response;
    final decay = -omega * damping;
    final value = 1 - (1 + decay * t) * (1 - t) * (1 - t) *
        _expApprox(decay * t);
    // clamp 到 [0, 1]，防止弹簧过冲导致 scale 超过原始大小
    return value.clamp(0.0, 1.0);
  }

  double _expApprox(double x) {
    // Fast exp approximation for animation
    if (x > 0) return 1.0;
    return 1 + x + x * x / 2 + x * x * x / 6;
  }
}

/// 按压缩放动画包装器
/// 参考iOS BouncyButtonStyle的按压效果 (scale: 0.96, spring animation)
/// scale: 按压时缩放比例 (默认0.96)
/// 可在其他Widget中复用此组件实现iOS风格的按压反馈
class ScaleTapWrapper extends StatefulWidget {
  const ScaleTapWrapper({
    super.key,
    required this.child,
    required this.onTap,
    this.enabled = true,
    this.scaleDown = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double scaleDown;

  @override
  State<ScaleTapWrapper> createState() => ScaleTapWrapperState();
}

class ScaleTapWrapperState extends State<ScaleTapWrapper>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 350),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      // iOS BouncyButtonStyle 弹簧回弹效果
      reverseCurve: const _SpringCurve(damping: 0.6, response: 0.3),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    if (!widget.enabled) return;
    _controller.forward();
  }

  void _onTapUp(TapUpDetails _) {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  void _onTapCancel() {
    if (!widget.enabled) return;
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      onTap: widget.enabled ? widget.onTap : null,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) => Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        ),
        child: widget.child,
      ),
    );
  }
}

/// 主要按钮
/// 参考iOS PrimaryButtonStyle - 渐变背景 + 按压缩放(0.96) + 触觉反馈
/// 加载态动画：按钮宽度收缩为圆形 → loading 旋转 → 展开回全宽
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
    this.height = 50,
    this.gradient,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;
  final double height;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final effectiveGradient = gradient ?? const LinearGradient(
      colors: AppColors.gradientPrimary,
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
    );

    final isActive = !isDisabled && !isLoading;

    return ScaleTapWrapper(
      enabled: isActive,
      onTap: () {
        AppHaptics.buttonTap();
        onPressed?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
        width: isLoading ? height : width, // 收缩为圆形
        height: height,
        decoration: BoxDecoration(
          gradient: isActive || isLoading ? effectiveGradient : null,
          color: isActive || isLoading ? null : AppColors.textTertiaryLight,
          borderRadius: isLoading
              ? BorderRadius.circular(height / 2) // 圆形
              : AppRadius.button,
          boxShadow: isActive || isLoading
              ? AppShadows.primary(opacity: 0.2)
              : null,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: isLoading
                ? const ButtonLoadingIndicator(key: ValueKey('loading'))
                : Row(
                    key: const ValueKey('content'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: Colors.white, size: 20),
                        AppSpacing.hSm,
                      ],
                      Text(
                        text,
                        style: AppTypography.button.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 次要按钮
/// 参考iOS SecondaryButtonStyle - 边框 + 按压缩放(0.96) + 触觉反馈
/// 加载态切换：文字/图标 ↔ loading 指示器平滑 crossfade
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isDisabled = false,
    this.icon,
    this.width,
    this.height = 50,
    this.color = AppColors.primary,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isDisabled;
  final IconData? icon;
  final double? width;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = isDisabled ? AppColors.textTertiaryLight : color;
    final isActive = !isDisabled && !isLoading;

    return ScaleTapWrapper(
      enabled: isActive,
      onTap: () {
        AppHaptics.buttonTap();
        onPressed?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: effectiveColor, width: 1.5),
          borderRadius: AppRadius.button,
        ),
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: isLoading
                ? ButtonLoadingIndicator(
                    key: const ValueKey('loading'),
                    color: effectiveColor,
                  )
                : Row(
                    key: const ValueKey('content'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (icon != null) ...[
                        Icon(icon, color: effectiveColor, size: 20),
                        AppSpacing.hSm,
                      ],
                      Text(
                        text,
                        style: AppTypography.button.copyWith(color: effectiveColor),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// 文字按钮（带缩放反馈 + 触觉反馈）
class TextActionButton extends StatelessWidget {
  const TextActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color = AppColors.primary,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w500,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final double fontSize;
  final FontWeight fontWeight;

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      scaleDown: 0.97,
      onTap: () {
        AppHaptics.selection();
        onPressed?.call();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
        ),
      ),
    );
  }
}

/// 图标按钮
/// 参考iOS IconButtonStyle - 44pt触摸区域 + 按压缩放(0.9)
class IconActionButton extends StatelessWidget {
  const IconActionButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 44,
    this.iconSize = 24,
    this.color,
    this.backgroundColor,
    this.borderRadius,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;
  final Color? color;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      scaleDown: 0.9,
      onTap: onPressed,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.transparent,
            borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
          ),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: color ?? Theme.of(context).iconTheme.color,
            ),
          ),
        ),
      ),
    );
  }
}

/// 浮动操作按钮
/// 参考iOS FloatingButtonStyle - 渐变 + 按压缩放(0.9) + 触觉反馈(medium)
class FloatingButton extends StatelessWidget {
  const FloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 56,
    this.backgroundColor = AppColors.primary,
    this.iconColor = Colors.white,
    this.useGradient = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color backgroundColor;
  final Color iconColor;
  final bool useGradient;

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      scaleDown: 0.9,
      onTap: () {
        AppHaptics.medium();
        onPressed?.call();
      },
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: useGradient ? const LinearGradient(
            colors: AppColors.gradientPrimary,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ) : null,
          color: useGradient ? null : backgroundColor,
          shape: BoxShape.circle,
          boxShadow: AppShadows.fab,
        ),
        child: Center(
          child: Icon(
            icon,
            color: iconColor,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

/// 小型操作按钮（带缩放反馈 + 触觉反馈）
class SmallActionButton extends StatelessWidget {
  const SmallActionButton({
    super.key,
    required this.text,
    this.onPressed,
    this.color = AppColors.primary,
    this.filled = false,
  });

  final String text;
  final VoidCallback? onPressed;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      scaleDown: 0.95,
      onTap: () {
        AppHaptics.selection();
        onPressed?.call();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: filled ? color : Colors.transparent,
          borderRadius: AppRadius.allTiny,
          border: filled ? null : Border.all(color: color),
        ),
        child: Text(
          text,
          style: AppTypography.buttonSmall.copyWith(
            color: filled ? Colors.white : color,
          ),
        ),
      ),
    );
  }
}
