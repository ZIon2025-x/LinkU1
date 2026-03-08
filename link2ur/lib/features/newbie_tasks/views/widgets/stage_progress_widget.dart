import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../data/models/newbie_task.dart';

/// Stage header with progress indicator (e.g., "2/4 完成").
class StageProgressWidget extends StatelessWidget {
  const StageProgressWidget({
    super.key,
    required this.stageNumber,
    required this.title,
    required this.tasks,
    this.stageProgress,
    this.isClaiming = false,
    this.onClaimBonus,
  });

  final int stageNumber;
  final String title;
  final List<NewbieTaskProgress> tasks;
  final StageProgress? stageProgress;
  final bool isClaiming;
  final VoidCallback? onClaimBonus;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final claimedCount = tasks.where((t) => t.isClaimed).length;
    final totalCount = tasks.length;
    final progress = totalCount > 0 ? claimedCount / totalCount : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stage header row
        Row(
          children: [
            // Stage number badge
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientPrimary,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  '$stageNumber',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            AppSpacing.hSm,
            // Title
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            // Progress indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: claimedCount == totalCount && totalCount > 0
                    ? AppColors.successLight
                    : AppColors.surface2(Theme.of(context).brightness),
                borderRadius: AppRadius.allPill,
              ),
              child: Text(
                '$claimedCount/$totalCount 完成',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: claimedCount == totalCount && totalCount > 0
                      ? AppColors.success
                      : AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        AppSpacing.vSm,
        // Progress bar
        ClipRRect(
          borderRadius: AppRadius.allPill,
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: isDark
                ? AppColors.secondaryBackgroundDark
                : AppColors.backgroundLight,
            valueColor: AlwaysStoppedAnimation<Color>(
              claimedCount == totalCount && totalCount > 0
                  ? AppColors.success
                  : AppColors.primary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stage bonus card — shows "阶段完成奖励" with reward info.
/// Can claim when all tasks in the stage are claimed.
class StageBonusCard extends StatelessWidget {
  const StageBonusCard({
    super.key,
    required this.stageProgress,
    required this.tasks,
    this.isClaiming = false,
    this.onClaim,
  });

  final StageProgress stageProgress;
  final List<NewbieTaskProgress> tasks;
  final bool isClaiming;
  final VoidCallback? onClaim;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final config = stageProgress.config;
    final allClaimed = tasks.isNotEmpty && tasks.every((t) => t.isClaimed);

    final rewardText = config.rewardType == 'points'
        ? '${config.rewardAmount} 积分'
        : config.rewardType == 'coupon'
            ? '优惠券奖励'
            : '${config.rewardAmount} 奖励';

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        gradient: stageProgress.isClaimed
            ? null
            : allClaimed
                ? const LinearGradient(
                    colors: AppColors.gradientGold,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
        color: stageProgress.isClaimed
            ? (isDark
                ? AppColors.secondaryBackgroundDark
                : AppColors.backgroundLight)
            : allClaimed
                ? null
                : (isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight),
        borderRadius: AppRadius.allMedium,
        border: !allClaimed && !stageProgress.isClaimed
            ? Border.all(
                color:
                    isDark ? AppColors.dividerDark : AppColors.dividerLight,
                width: 0.5,
              )
            : null,
      ),
      child: Row(
        children: [
          // Trophy icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: stageProgress.isClaimed
                  ? AppColors.successLight
                  : allClaimed
                      ? Colors.white.withValues(alpha: 0.25)
                      : AppColors.warningLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              stageProgress.isClaimed
                  ? Icons.emoji_events_rounded
                  : Icons.emoji_events_outlined,
              color: stageProgress.isClaimed
                  ? AppColors.success
                  : allClaimed
                      ? Colors.white
                      : AppColors.warning,
              size: 22,
            ),
          ),
          AppSpacing.hMd,
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '阶段完成奖励',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: allClaimed && !stageProgress.isClaimed
                        ? Colors.white
                        : isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.card_giftcard_rounded,
                      size: 14,
                      color: allClaimed && !stageProgress.isClaimed
                          ? Colors.white.withValues(alpha: 0.8)
                          : AppColors.accent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      rewardText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: allClaimed && !stageProgress.isClaimed
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status / Claim button
          _buildTrailing(context, allClaimed),
        ],
      ),
    );
  }

  Widget _buildTrailing(BuildContext context, bool allClaimed) {
    if (stageProgress.isClaimed) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.successLight,
          borderRadius: AppRadius.allPill,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check, size: 14, color: AppColors.success),
            SizedBox(width: 2),
            Text(
              '已领取',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
            ),
          ],
        ),
      );
    }

    if (allClaimed && stageProgress.isCompleted) {
      return SizedBox(
        height: 32,
        child: ElevatedButton(
          onPressed: isClaiming ? null : onClaim,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: AppColors.accent,
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
                    color: AppColors.accent,
                  ),
                )
              : const Text(
                  '领取奖励',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      );
    }

    // Not all tasks completed yet — show lock
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        borderRadius: AppRadius.allPill,
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 14, color: AppColors.textSecondaryLight),
          SizedBox(width: 2),
          Text(
            '未解锁',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
