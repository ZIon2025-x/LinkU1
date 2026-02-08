import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';

/// 基础卡片
/// 参考iOS cardStyle modifier
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.hasShadow = true,
    this.hasBorder = false,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final bool hasShadow;
  final bool hasBorder;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ?? 
        (isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight);
    final effectiveBorderRadius = borderRadius ?? AppRadius.card;

    // 与iOS cardBackground()对齐：默认添加微妙边框 separator.opacity(0.3), 0.5pt
    final defaultBorder = Border.all(
      color: (isDark ? AppColors.separatorDark : AppColors.separatorLight).withValues(alpha: 0.3),
      width: 0.5,
    );

    // 对齐iOS: 双层阴影 - 一层柔和扩散 + 一层紧密底部
    final effectiveShadow = hasShadow
        ? [
            ...AppShadows.smallForBrightness(isDark ? Brightness.dark : Brightness.light),
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.06 : 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ]
        : null;

    Widget card = Container(
      margin: margin,
      padding: padding ?? AppSpacing.allMd,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: effectiveBorderRadius,
        boxShadow: effectiveShadow,
        border: hasBorder 
            ? Border.all(
                color: borderColor ?? (isDark ? AppColors.dividerDark : AppColors.dividerLight),
              )
            : defaultBorder,
      ),
      child: child,
    );

    if (onTap != null) {
      card = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: effectiveBorderRadius,
          child: card,
        ),
      );
    }

    return card;
  }
}

/// 列表项卡片
class ListItemCard extends StatelessWidget {
  const ListItemCard({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.padding,
    this.showArrow = false,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final EdgeInsets? padding;
  final bool showArrow;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: padding ?? AppSpacing.listItem,
      onTap: onTap,
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            AppSpacing.hMd,
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (showArrow && trailing == null)
            Icon(
              Icons.chevron_right,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
        ],
      ),
    );
  }
}

/// 分组卡片
class GroupedCard extends StatelessWidget {
  const GroupedCard({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.backgroundColor,
  });

  final List<Widget> children;
  final Widget? header;
  final Widget? footer;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = backgroundColor ??
        (isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          header!,
          AppSpacing.vSm,
        ],
        Container(
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.card,
            border: Border.all(
              color: (isDark ? AppColors.separatorDark : AppColors.separatorLight).withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Column(
            children: List.generate(children.length * 2 - 1, (index) {
              if (index.isOdd) {
                return Divider(
                  height: 1,
                  indent: 16,
                  color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
                );
              }
              return children[index ~/ 2];
            }),
          ),
        ),
        if (footer != null) ...[
          AppSpacing.vSm,
          footer!,
        ],
      ],
    );
  }
}

/// 统计卡片
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.iconColor,
    this.onTap,
  });

  final String value;
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 32,
              color: iconColor ?? AppColors.primary,
            ),
            AppSpacing.vSm,
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
