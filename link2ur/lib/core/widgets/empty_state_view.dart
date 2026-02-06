import 'package:flutter/material.dart';
import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../design/app_radius.dart';

/// 空状态视图
/// 参考iOS EmptyStateView.swift
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionText,
    this.onAction,
    this.iconSize = 80,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? description;
  final String? actionText;
  final VoidCallback? onAction;
  final double iconSize;
  final Color? iconColor;

  /// 无数据
  factory EmptyStateView.noData({
    String title = '暂无数据',
    String? description,
    String? actionText,
    VoidCallback? onAction,
  }) {
    return EmptyStateView(
      icon: Icons.inbox_outlined,
      title: title,
      description: description,
      actionText: actionText,
      onAction: onAction,
    );
  }

  /// 无任务
  factory EmptyStateView.noTasks({
    String? actionText,
    VoidCallback? onAction,
  }) {
    return EmptyStateView(
      icon: Icons.task_alt_outlined,
      title: '暂无任务',
      description: '还没有相关任务，点击下方按钮发布新任务',
      actionText: actionText,
      onAction: onAction,
    );
  }

  /// 无消息
  factory EmptyStateView.noMessages() {
    return const EmptyStateView(
      icon: Icons.chat_bubble_outline,
      title: '暂无消息',
      description: '还没有收到任何消息',
    );
  }

  /// 无搜索结果
  factory EmptyStateView.noSearchResults({String? keyword}) {
    return EmptyStateView(
      icon: Icons.search_off,
      title: '未找到结果',
      description: keyword != null ? '没有找到与"$keyword"相关的内容' : '没有找到相关内容',
    );
  }

  /// 无收藏
  factory EmptyStateView.noFavorites() {
    return const EmptyStateView(
      icon: Icons.favorite_outline,
      title: '暂无收藏',
      description: '收藏的内容将显示在这里',
    );
  }

  /// 无通知
  factory EmptyStateView.noNotifications() {
    return const EmptyStateView(
      icon: Icons.notifications_none_outlined,
      title: '暂无通知',
      description: '您的通知将显示在这里',
    );
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
            // 图标
            Container(
              width: iconSize + 40,
              height: iconSize + 40,
              decoration: BoxDecoration(
                color: (iconColor ?? AppColors.textSecondaryLight).withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
            AppSpacing.vLg,
            // 标题
            Text(
              title,
              style: AppTypography.title3.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              AppSpacing.vSm,
              // 描述
              Text(
                description!,
                style: AppTypography.subheadline.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionText != null && onAction != null) ...[
              AppSpacing.vLg,
              // 操作按钮
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppRadius.button,
                  ),
                ),
                child: Text(actionText!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
