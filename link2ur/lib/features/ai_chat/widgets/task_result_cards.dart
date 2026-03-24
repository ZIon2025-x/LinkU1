import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/go_router_extensions.dart';
import '../../../core/utils/l10n_extension.dart';

/// 任务搜索/推荐结果的水平滚动卡片列表
class TaskResultCards extends StatelessWidget {
  const TaskResultCards({
    super.key,
    required this.toolResult,
  });

  final Map<String, dynamic> toolResult;

  @override
  Widget build(BuildContext context) {
    final tasks = toolResult['tasks'] as List<dynamic>?;
    if (tasks == null || tasks.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(
        left: AppSpacing.md + 40, // align with AI bubble (avatar + gap)
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: SizedBox(
        height: 128,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: tasks.length,
          separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
          itemBuilder: (context, index) {
            final task = tasks[index] as Map<String, dynamic>;
            return _TaskCard(task: task, isDark: isDark);
          },
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.isDark});

  final Map<String, dynamic> task;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final title = task['title'] as String? ?? '';
    final reward = task['reward'];
    final currency = task['currency'] as String? ?? 'GBP';
    final taskType = task['task_type'] as String? ?? '';
    final location = task['location'] as String? ?? '';
    final currencySymbol = currency == 'GBP' ? '£' : currency;
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () {
        final id = task['id'];
        if (id is int) {
          context.goToTaskDetail(id);
        }
      },
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
                height: 1.3,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),

            // Reward
            if (reward != null)
              Text(
                '$currencySymbol${reward is num ? reward.toStringAsFixed(2) : reward}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),

            const Spacer(),

            // Type + Location row
            Row(
              children: [
                if (taskType.isNotEmpty) ...[
                  Icon(
                    Icons.category_outlined,
                    size: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      taskType,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                ],
                if (taskType.isNotEmpty && location.isNotEmpty)
                  const SizedBox(width: AppSpacing.xs),
                if (location.isNotEmpty) ...[
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            const SizedBox(height: 4),

            // View detail hint
            Text(
              l10n.aiTaskCardViewDetail,
              style: TextStyle(
                fontSize: 11,
                color: AppColors.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
