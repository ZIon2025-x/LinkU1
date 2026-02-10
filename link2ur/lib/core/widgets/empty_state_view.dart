import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';
import '../utils/l10n_extension.dart';

/// 空状态视图 — 图标带轻微浮动动画
/// 参考iOS EmptyStateView.swift
class EmptyStateView extends StatefulWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.message,
    this.actionText,
    this.onAction,
    this.iconSize = 80,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? message; // alias for description
  final String? actionText;
  final VoidCallback? onAction;
  final double iconSize;
  final Color? iconColor;

  /// 无数据 (localized)
  static EmptyStateView noData(BuildContext context, {
    String? title,
    String? description,
    String? actionText,
    VoidCallback? onAction,
  }) {
    final l10n = context.l10n;
    return EmptyStateView(
      icon: Icons.inbox_outlined,
      title: title ?? l10n.emptyNoData,
      description: description,
      actionText: actionText,
      onAction: onAction,
    );
  }

  /// 无任务 (localized)
  static EmptyStateView noTasks(BuildContext context, {
    String? title,
    String? description,
    String? actionText,
    VoidCallback? onAction,
  }) {
    final l10n = context.l10n;
    return EmptyStateView(
      icon: Icons.task_alt_outlined,
      title: title ?? l10n.emptyNoTasks,
      description: description ?? l10n.emptyNoTasksDescription,
      actionText: actionText,
      onAction: onAction,
    );
  }

  /// 无消息 (localized)
  static EmptyStateView noMessages(BuildContext context, {
    String? title,
    String? description,
  }) {
    final l10n = context.l10n;
    return EmptyStateView(
      icon: Icons.chat_bubble_outline,
      title: title ?? l10n.emptyNoMessages,
      description: description ?? l10n.emptyNoMessagesDescription,
    );
  }

  /// 无搜索结果 (localized)
  static EmptyStateView noSearchResults(BuildContext context, {
    String? title,
    String? description,
    String? keyword,
  }) {
    final l10n = context.l10n;
    return EmptyStateView(
      icon: Icons.search_off,
      title: title ?? l10n.emptyNoSearchResultsTitle,
      description: description ?? l10n.emptyNoSearchResultsDescription,
    );
  }

  /// 无收藏 (localized)
  static EmptyStateView noFavorites(BuildContext context, {
    String? title,
    String? description,
  }) {
    final l10n = context.l10n;
    return EmptyStateView(
      icon: Icons.favorite_outline,
      title: title ?? l10n.emptyNoData,
      description: description ?? l10n.emptyNoFavoritesDescription,
    );
  }

  /// 无通知 (localized)
  static EmptyStateView noNotifications(BuildContext context, {
    String? title,
    String? description,
  }) {
    final l10n = context.l10n;
    return EmptyStateView(
      icon: Icons.notifications_none_outlined,
      title: title ?? l10n.emptyNoNotifications,
      description: description ?? l10n.emptyNoNotificationsDescription,
    );
  }

  @override
  State<EmptyStateView> createState() => _EmptyStateViewState();
}

class _EmptyStateViewState extends State<EmptyStateView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    // 缓慢浮动：3 秒一个周期，低帧率开销
    _floatController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: AppSpacing.allXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 图标 — 轻微浮动动画（上下 6px）
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                final offset = math.sin(_floatController.value * math.pi) * 6;
                return Transform.translate(
                  offset: Offset(0, -offset),
                  child: child,
                );
              },
              child: Container(
                width: widget.iconSize + 40,
                height: widget.iconSize + 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (widget.iconColor ?? AppColors.primary).withValues(alpha: 0.12),
                      (widget.iconColor ?? AppColors.primary).withValues(alpha: 0.06),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.iconSize,
                  color: widget.iconColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ),
            ),
            AppSpacing.vLg,
            // 标题
            Text(
              widget.title,
              style: AppTypography.title3.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (widget.description != null || widget.message != null) ...[
              AppSpacing.vSm,
              // 描述
              Text(
                widget.description ?? widget.message!,
                style: AppTypography.subheadline.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (widget.actionText != null && widget.onAction != null) ...[
              AppSpacing.vLg,
              // 操作按钮
              ElevatedButton(
                onPressed: widget.onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.button,
                  ),
                ),
                child: Text(widget.actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
