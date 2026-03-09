import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../data/models/newbie_task.dart';

/// Reusable widget for a single newbie task item.
/// Shows task title, description, reward preview, status badge, and claim button.
class TaskItemWidget extends StatelessWidget {
  const TaskItemWidget({
    super.key,
    required this.task,
    this.isClaiming = false,
    this.onClaim,
  });

  final NewbieTaskProgress task;
  final bool isClaiming;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = task.config;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
      child: Row(
        children: [
          // Task icon
          _buildTaskIcon(),
          AppSpacing.hMd,
          // Title + description + reward
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.titleZh,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (config.descriptionZh.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    config.descriptionZh,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 4),
                _buildRewardPreview(config),
              ],
            ),
          ),
          AppSpacing.hSm,
          // Status badge / claim button
          _buildTrailing(context),
        ],
      ),
    );
  }

  Widget _buildTaskIcon() {
    final Color bgColor;
    final IconData icon;

    if (task.isClaimed) {
      bgColor = AppColors.successLight;
      icon = Icons.check_circle_rounded;
    } else if (task.isCompleted) {
      bgColor = AppColors.warningLight;
      icon = Icons.star_rounded;
    } else {
      bgColor = AppColors.infoLight;
      icon = Icons.radio_button_unchecked_rounded;
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: task.isClaimed
            ? AppColors.success
            : task.isCompleted
                ? AppColors.warning
                : AppColors.primary,
        size: 20,
      ),
    );
  }

  Widget _buildRewardPreview(NewbieTaskConfig config) {
    final rewardText = config.rewardType == 'points'
        ? '${config.rewardAmount} 积分'
        : config.rewardType == 'coupon'
            ? '优惠券奖励'
            : '${config.rewardAmount} 奖励';

    return Row(
      children: [
        const Icon(
          Icons.card_giftcard_rounded,
          size: 14,
          color: AppColors.accent,
        ),
        const SizedBox(width: 4),
        Text(
          rewardText,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.accent,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailing(BuildContext context) {
    // Claimed — blue checkmark badge
    if (task.isClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: AppRadius.allPill,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: AppColors.primary),
            SizedBox(width: 2),
            Text(
              '已领取',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    // Completed — green "可领取" + claim button
    if (task.isCompleted) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: isClaiming ? null : onClaim,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            shape: RoundedRectangleBorder(
              borderRadius: AppRadius.allPill,
            ),
            elevation: 0,
          ),
          child: isClaiming
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  '可领取',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    // Pending — grey badge
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: AppRadius.allPill,
      ),
      child: const Text(
        '未完成',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
