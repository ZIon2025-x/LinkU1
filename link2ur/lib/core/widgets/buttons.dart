import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';
import 'loading_view.dart';

/// 按压缩放动画包装器
/// 参考iOS PrimaryButtonStyle的按压效果
/// scale: 按压时缩放比例 (默认0.96)
/// duration: 动画时长
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
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: widget.scaleDown,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
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
        HapticFeedback.lightImpact();
        onPressed?.call();
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: isActive ? effectiveGradient : null,
          color: isActive ? null : AppColors.textTertiaryLight,
          borderRadius: AppRadius.button,
          boxShadow: isActive ? AppShadows.primary(opacity: 0.2) : null,
        ),
        child: Center(
          child: isLoading
              ? const ButtonLoadingIndicator()
              : Row(
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
    );
  }
}

/// 次要按钮
/// 参考iOS SecondaryButtonStyle - 边框 + 按压缩放(0.96) + 触觉反馈
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
        HapticFeedback.lightImpact();
        onPressed?.call();
      },
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: effectiveColor, width: 1.5),
          borderRadius: AppRadius.button,
        ),
        child: Center(
          child: isLoading
              ? ButtonLoadingIndicator(color: effectiveColor)
              : Row(
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
    );
  }
}

/// 文字按钮
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
    return GestureDetector(
      onTap: onPressed,
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: fontWeight,
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
        HapticFeedback.mediumImpact();
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

/// 小型操作按钮
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
    return GestureDetector(
      onTap: onPressed,
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
