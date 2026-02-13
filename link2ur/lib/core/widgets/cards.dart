import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../design/app_shadows.dart';
import '../design/app_spacing.dart';
import '../utils/haptic_feedback.dart';

/// 基础卡片 — 带按压缩放反馈 + 增强阴影
/// 移动端：iOS 风格按压缩放反馈
/// Web 桌面端：hover 上浮 + 阴影增强（对齐 frontend translateY(-2px) 效果）
class AppCard extends StatefulWidget {
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
    this.enableScaleTap = true,
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
  /// 是否启用按压缩放反馈（默认开启，onTap 非空时生效）
  final bool enableScaleTap;

  @override
  State<AppCard> createState() => _AppCardState();
}

class _AppCardState extends State<AppCard>
    with SingleTickerProviderStateMixin {
  // 懒创建：仅当 onTap 非空且启用缩放反馈时才分配 AnimationController
  // 列表中大量纯展示 AppCard 不会产生额外开销
  AnimationController? _scaleController;
  Animation<double>? _scaleAnimation;

  /// Web 桌面端 hover 状态
  bool _isHovered = false;

  bool get _needsAnimation =>
      widget.onTap != null && widget.enableScaleTap;

  void _ensureController() {
    if (_scaleController != null) return;
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(
        parent: _scaleController!,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.elasticOut,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController?.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails _) {
    _ensureController();
    _scaleController!.forward();
  }

  void _onTapUp(TapUpDetails _) => _scaleController?.reverse();
  void _onTapCancel() => _scaleController?.reverse();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = widget.backgroundColor ??
        (isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight);
    final effectiveBorderRadius = widget.borderRadius ?? AppRadius.card;

    // Web 桌面端 hover 时使用增强阴影
    final useHoverShadow = kIsWeb && _isHovered && widget.hasShadow;

    final defaultBorder = Border.all(
      color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
          .withValues(alpha: _isHovered ? 0.15 : 0.3),
      width: 0.5,
    );

    final effectiveShadow = widget.hasShadow
        ? (useHoverShadow
            ? AppShadows.cardHover(isDark)
            : AppShadows.cardDualForBrightness(
                isDark ? Brightness.dark : Brightness.light))
        : null;

    // 使用静态 Container 避免 AnimatedContainer 在 hover 时做 boxShadow 插值
    // （GPU 每帧重算模糊非常昂贵）。hover 上浮效果用 AnimatedSlide 代替。
    Widget card = Container(
      margin: widget.margin,
      padding: widget.padding ?? AppSpacing.allMd,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: effectiveBorderRadius,
        boxShadow: effectiveShadow,
        border: widget.hasBorder
            ? Border.all(
                color: widget.borderColor ??
                    (isDark ? AppColors.dividerDark : AppColors.dividerLight),
              )
            : defaultBorder,
      ),
      child: widget.child,
    );

    // Web 桌面端 hover 上移 2px（对齐 frontend translateY(-2px)）
    if (kIsWeb) {
      card = AnimatedSlide(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        offset: _isHovered ? const Offset(0, -0.01) : Offset.zero,
        child: card,
      );
    }

    // Web 桌面端：添加 MouseRegion hover 效果 + 鼠标指针
    if (kIsWeb && widget.onTap != null) {
      card = MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: card,
      );
    }

    if (widget.onTap != null) {
      if (!kIsWeb && _needsAnimation) {
        // 移动端：按压缩放反馈
        _ensureController();
        card = GestureDetector(
          onTapDown: _onTapDown,
          onTapUp: _onTapUp,
          onTapCancel: _onTapCancel,
          onTap: () {
            AppHaptics.selection();
            widget.onTap?.call();
          },
          child: AnimatedBuilder(
            animation: _scaleAnimation!,
            builder: (context, child) => Transform.scale(
              scale: _scaleAnimation!.value,
              child: child,
            ),
            child: card,
          ),
        );
      } else {
        card = GestureDetector(
          onTap: () {
            if (!kIsWeb) AppHaptics.selection();
            widget.onTap?.call();
          },
          child: card,
        );
      }
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
