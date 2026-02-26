import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';

/// AI 生成的任务草稿卡片 — 用户点击确认后跳转到发布页预填
class TaskDraftCard extends StatelessWidget {
  const TaskDraftCard({
    super.key,
    required this.draft,
    required this.onConfirm,
  });

  final Map<String, dynamic> draft;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    final title = draft['title'] as String? ?? '';
    final description = draft['description'] as String? ?? '';
    final taskType = draft['task_type'] as String? ?? '';
    final reward = draft['reward'];
    final currency = draft['currency'] as String? ?? 'GBP';
    final location = draft['location'] as String? ?? '';
    final currencySymbol = currency == 'GBP' ? '£' : currency;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md + 40,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2332) : const Color(0xFFF0F7FF),
          borderRadius: BorderRadius.circular(AppRadius.large),
          border: Border.all(
            color: AppColors.primary.withAlpha(60),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.edit_note, size: 18, color: AppColors.primary),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  l10n.aiTaskDraftTitle,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            _buildField(context, l10n.createTaskTitleField, title),
            if (description.isNotEmpty)
              _buildField(
                context,
                l10n.taskDetailTaskDescription,
                description.length > 80
                    ? '${description.substring(0, 80)}...'
                    : description,
              ),
            if (taskType.isNotEmpty)
              _buildField(context, l10n.createTaskType, taskType),
            if (reward != null)
              _buildField(
                context,
                l10n.createTaskReward,
                '$currencySymbol${(reward is num ? reward.toStringAsFixed(2) : reward)}',
              ),
            if (location.isNotEmpty)
              _buildField(context, l10n.createTaskLocation, location),

            const SizedBox(height: AppSpacing.md),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(l10n.aiTaskDraftConfirmButton),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
