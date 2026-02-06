import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';

/// 徽章视图
/// 参考iOS BadgeView.swift
class BadgeView extends StatelessWidget {
  const BadgeView({
    super.key,
    required this.count,
    this.maxCount = 99,
    this.size = 18,
    this.backgroundColor = AppColors.error,
    this.textColor = Colors.white,
    this.showZero = false,
  });

  final int count;
  final int maxCount;
  final double size;
  final Color backgroundColor;
  final Color textColor;
  final bool showZero;

  @override
  Widget build(BuildContext context) {
    if (count <= 0 && !showZero) {
      return const SizedBox.shrink();
    }

    final displayText = count > maxCount ? '$maxCount+' : count.toString();
    final isWide = displayText.length > 1;

    return Container(
      height: size,
      constraints: BoxConstraints(
        minWidth: size,
        maxWidth: isWide ? size * 1.8 : size,
      ),
      padding: EdgeInsets.symmetric(horizontal: isWide ? 4 : 0),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Center(
        child: Text(
          displayText,
          style: AppTypography.badge.copyWith(color: textColor),
        ),
      ),
    );
  }
}

/// 带徽章的图标
class IconWithBadge extends StatelessWidget {
  const IconWithBadge({
    super.key,
    required this.icon,
    this.count = 0,
    this.iconSize = 24,
    this.iconColor,
    this.badgeColor = AppColors.error,
    this.showBadge = true,
  });

  final IconData icon;
  final int count;
  final double iconSize;
  final Color? iconColor;
  final Color badgeColor;
  final bool showBadge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: iconSize,
          color: iconColor,
        ),
        if (showBadge && count > 0)
          Positioned(
            right: -6,
            top: -6,
            child: BadgeView(
              count: count,
              backgroundColor: badgeColor,
              size: 16,
            ),
          ),
      ],
    );
  }
}

/// 小红点
class RedDot extends StatelessWidget {
  const RedDot({
    super.key,
    this.size = 8,
    this.color = AppColors.error,
    this.show = true,
  });

  final double size;
  final Color color;
  final bool show;

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// 状态标签
class StatusTag extends StatelessWidget {
  const StatusTag({
    super.key,
    required this.text,
    this.color = AppColors.primary,
    this.backgroundColor,
    this.outlined = false,
    this.size = TagSize.medium,
  });

  final String text;
  final Color color;
  final Color? backgroundColor;
  final bool outlined;
  final TagSize size;

  /// 成功状态
  factory StatusTag.success(String text, {TagSize size = TagSize.medium}) {
    return StatusTag(
      text: text,
      color: AppColors.success,
      backgroundColor: AppColors.successLight,
      size: size,
    );
  }

  /// 警告状态
  factory StatusTag.warning(String text, {TagSize size = TagSize.medium}) {
    return StatusTag(
      text: text,
      color: AppColors.warning,
      backgroundColor: AppColors.warningLight,
      size: size,
    );
  }

  /// 错误状态
  factory StatusTag.error(String text, {TagSize size = TagSize.medium}) {
    return StatusTag(
      text: text,
      color: AppColors.error,
      backgroundColor: AppColors.errorLight,
      size: size,
    );
  }

  /// 信息状态
  factory StatusTag.info(String text, {TagSize size = TagSize.medium}) {
    return StatusTag(
      text: text,
      color: AppColors.primary,
      backgroundColor: AppColors.infoLight,
      size: size,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = outlined 
        ? Colors.transparent 
        : (backgroundColor ?? color.withValues(alpha: 0.1));

    double paddingH;
    double paddingV;
    double fontSize;

    switch (size) {
      case TagSize.small:
        paddingH = 6;
        paddingV = 2;
        fontSize = 10;
        break;
      case TagSize.medium:
        paddingH = 8;
        paddingV = 4;
        fontSize = 12;
        break;
      case TagSize.large:
        paddingH = 12;
        paddingV = 6;
        fontSize = 14;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: paddingH, vertical: paddingV),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.allTiny,
        border: outlined ? Border.all(color: color) : null,
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

enum TagSize { small, medium, large }
