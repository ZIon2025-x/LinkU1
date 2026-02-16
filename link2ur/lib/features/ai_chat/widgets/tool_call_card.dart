import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';

/// 工具调用指示卡片
class ToolCallCard extends StatelessWidget {
  const ToolCallCard({
    super.key,
    required this.toolName,
    this.isLoading = true,
  });

  final String toolName;
  final bool isLoading;

  String get _displayName {
    switch (toolName) {
      case 'query_my_tasks':
        return '查询我的任务';
      case 'get_task_detail':
        return '获取任务详情';
      case 'search_tasks':
        return '搜索任务';
      case 'get_my_profile':
        return '获取个人资料';
      case 'get_platform_faq':
        return '查询常见问题';
      default:
        return toolName;
    }
  }

  IconData get _icon {
    switch (toolName) {
      case 'query_my_tasks':
        return Icons.task_alt;
      case 'get_task_detail':
        return Icons.description;
      case 'search_tasks':
        return Icons.search;
      case 'get_my_profile':
        return Icons.person;
      case 'get_platform_faq':
        return Icons.help_outline;
      default:
        return Icons.build;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 40, // AI avatar + spacing
        vertical: AppSpacing.xs,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 4,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1C1C1E)
              : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isDark
                ? Colors.white12
                : Colors.black.withAlpha(15),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _icon,
              size: 16,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              _displayName,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            if (isLoading) ...[
              const SizedBox(width: AppSpacing.sm),
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.primary,
                ),
              ),
            ] else ...[
              const SizedBox(width: AppSpacing.sm),
              const Icon(
                Icons.check_circle,
                size: 14,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
