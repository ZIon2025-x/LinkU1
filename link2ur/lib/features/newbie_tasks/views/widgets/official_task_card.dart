import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../data/models/official_task.dart';

/// Card for official tasks with "官方" badge.
class OfficialTaskCard extends StatelessWidget {
  const OfficialTaskCard({
    super.key,
    required this.task,
    this.onTap,
  });

  final OfficialTask task;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row with "官方" badge
            Row(
              children: [
                // 官方 badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradientIndigo,
                    ),
                    borderRadius: AppRadius.allTiny,
                  ),
                  child: const Text(
                    '官方',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                AppSpacing.hSm,
                // Topic tag (if present)
                if (task.topicTag != null && task.topicTag!.isNotEmpty) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight.withValues(alpha: 0.15),
                      borderRadius: AppRadius.allTiny,
                    ),
                    child: Text(
                      '#${task.topicTag}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Submission status
                if (task.hasReachedLimit)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.successLight,
                      borderRadius: AppRadius.allTiny,
                    ),
                    child: const Text(
                      '已完成',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: AppColors.success,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.vSm,
            // Title
            Text(
              task.titleZh,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (task.descriptionZh.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                task.descriptionZh,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            AppSpacing.vSm,
            // Bottom row: reward + deadline
            Row(
              children: [
                // Reward
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.warningLight,
                    borderRadius: AppRadius.allTiny,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.card_giftcard_rounded,
                        size: 14,
                        color: AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _rewardText,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warning,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Validity period
                if (task.validUntil != null)
                  Text(
                    '截止 ${_formatDate(task.validUntil!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                // Max per user
                if (task.maxPerUser > 1) ...[
                  AppSpacing.hSm,
                  Text(
                    '${task.userSubmissionCount}/${task.maxPerUser} 次',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String get _rewardText {
    if (task.rewardType == 'points') {
      return '${task.rewardAmount} 积分';
    } else if (task.rewardType == 'coupon') {
      return '优惠券奖励';
    }
    return '${task.rewardAmount} 奖励';
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}';
  }
}
