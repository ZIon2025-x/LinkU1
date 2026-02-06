import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';
import 'loading_view.dart';

/// 主要按钮
/// 参考iOS PrimaryButtonStyle
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

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: (isDisabled || isLoading) ? null : effectiveGradient,
        color: (isDisabled || isLoading) ? AppColors.textTertiaryLight : null,
        borderRadius: AppRadius.button,
        boxShadow: (isDisabled || isLoading) ? null : AppShadows.primary(opacity: 0.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isDisabled || isLoading) ? null : onPressed,
          borderRadius: AppRadius.button,
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
      ),
    );
  }
}

/// 次要按钮
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

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: effectiveColor, width: 1.5),
        borderRadius: AppRadius.button,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: (isDisabled || isLoading) ? null : onPressed,
          borderRadius: AppRadius.button,
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
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: backgroundColor ?? Colors.transparent,
        borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
        child: InkWell(
          onTap: onPressed,
          borderRadius: borderRadius ?? BorderRadius.circular(size / 2),
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
class FloatingButton extends StatelessWidget {
  const FloatingButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 56,
    this.backgroundColor = AppColors.primary,
    this.iconColor = Colors.white,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color backgroundColor;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: AppShadows.fab,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(size / 2),
          child: Center(
            child: Icon(
              icon,
              color: iconColor,
              size: size * 0.5,
            ),
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
