import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/utils/l10n_extension.dart';
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
    final locale = Localizations.localeOf(context);

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
                  config.displayTitle(locale),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (config.displayDescription(locale).isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    config.displayDescription(locale),
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
                _buildRewardPreview(context, config),
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

  Widget _buildRewardPreview(BuildContext context, NewbieTaskConfig config) {
    final l10n = context.l10n;
    final rewardText = config.rewardType == 'points'
        ? l10n.newbieTaskPoints('${config.rewardAmount}')
        : config.rewardType == 'coupon'
            ? l10n.newbieTaskCouponReward
            : l10n.newbieTaskReward('${config.rewardAmount}');

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    // Claimed — blue checkmark badge
    if (task.isClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: AppRadius.allPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check, size: 14, color: AppColors.primary),
            const SizedBox(width: 2),
            Text(
              l10n.newbieTaskClaimed,
              style: const TextStyle(
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
              : Text(
                  l10n.newbieTaskCompleted,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      );
    }

    // Pending — grey badge (dark mode aware)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.secondaryBackgroundDark
            : AppColors.backgroundLight,
        borderRadius: AppRadius.allPill,
      ),
      child: Text(
        l10n.newbieTaskPending,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
        ),
      ),
    );
  }
}
