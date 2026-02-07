import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';

/// 通用统计项组件 - 用于个人主页、任务详情等展示数值统计
/// 参考iOS StatItem.swift
class StatItem extends StatelessWidget {
  const StatItem({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveColor = color ?? AppColors.primary;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon!, size: 20, color: effectiveColor),
          AppSpacing.vXs,
        ],
        Text(
          value,
          style: AppTypography.title3.copyWith(
            color: effectiveColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        AppSpacing.vXs,
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }
}

/// 紧凑统计项组件 - 用于卡片底部显示浏览量、回复数等
/// 参考iOS CompactStatItem.swift
class CompactStatItem extends StatelessWidget {
  const CompactStatItem({
    super.key,
    required this.icon,
    required this.count,
    this.color,
    this.isActive = false,
    this.activeColor,
    this.onTap,
  });

  final IconData icon;
  final int count;
  final Color? color;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    final effectiveActiveColor = activeColor ?? AppColors.primary;
    final effectiveColor = isActive ? effectiveActiveColor : (color ?? defaultColor);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: effectiveColor,
        ),
        const SizedBox(width: 4),
        Text(
          _formatCount(count),
          style: AppTypography.caption2.copyWith(
            color: effectiveColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: content,
      );
    }

    return content;
  }

  String _formatCount(int count) {
    if (count >= 10000) {
      return '${(count / 10000).toStringAsFixed(1)}w';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}k';
    }
    return count.toString();
  }
}
