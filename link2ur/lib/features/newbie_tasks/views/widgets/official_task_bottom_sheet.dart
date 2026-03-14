import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../data/models/official_task.dart';

/// Bottom sheet showing official task details and "Go Post" action.
class OfficialTaskBottomSheet extends StatelessWidget {
  const OfficialTaskBottomSheet({super.key, required this.task});

  final OfficialTask task;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Badge row: "Official" + topic tag
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: AppColors.gradientIndigo,
                  ),
                  borderRadius: AppRadius.allTiny,
                ),
                child: Text(
                  l10n.officialTask,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
              if (task.topicTag != null && task.topicTag!.isNotEmpty) ...[
                AppSpacing.hSm,
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.15),
                    borderRadius: AppRadius.allTiny,
                  ),
                  child: Text(
                    '#${task.topicTag}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.vMd,

          // Title
          Text(
            task.displayTitle(locale),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vSm,

          // Description (scrollable if long)
          if (task.displayDescription(locale).isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 160),
              child: SingleChildScrollView(
                child: Text(
                  task.displayDescription(locale),
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          AppSpacing.vMd,

          // Info row: reward + deadline + submission count
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              // Reward
              _InfoChip(
                icon: Icons.card_giftcard_rounded,
                iconColor: AppColors.warning,
                bgColor: AppColors.warningLight,
                text: task.rewardType == 'points'
                    ? l10n.newbieTaskPoints('${task.rewardAmount}')
                    : '${task.rewardAmount}',
              ),
              // Deadline
              if (task.validUntil != null)
                _InfoChip(
                  icon: Icons.schedule_rounded,
                  iconColor: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  bgColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  text: l10n.officialTaskDeadline(
                    '${task.validUntil!.month}/${task.validUntil!.day}',
                  ),
                ),
              // Submission count
              if (task.maxPerUser > 1)
                _InfoChip(
                  icon: Icons.repeat_rounded,
                  iconColor: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  bgColor: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.04),
                  text: l10n.officialTaskSubmissionCount(
                    '${task.userSubmissionCount}',
                    '${task.maxPerUser}',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: _buildActionButton(context, isDark, l10n, locale),
          ),

          // Bottom safe area
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    bool isDark,
    dynamic l10n,
    Locale locale,
  ) {
    // Completed
    if (task.hasReachedLimit) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(l10n.officialTaskCompleted),
      );
    }

    // Expired
    if (!task.isCurrentlyValid) {
      return ElevatedButton(
        onPressed: null,
        style: ElevatedButton.styleFrom(
          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade200,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Text(l10n.officialTaskExpired),
      );
    }

    // Active — Go Post
    return ElevatedButton(
      onPressed: () => _goPost(context, locale),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      child: Text(
        l10n.officialTaskGoPost,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _goPost(BuildContext context, Locale locale) async {
    // Close bottom sheet, returning true to signal navigation
    Navigator.of(context).pop(true);
  }

  /// Called from the parent after bottom sheet closes with result=true.
  /// Navigates to CreatePostView and waits for it to return.
  static Future<void> navigateToCreatePost(
    BuildContext context,
    OfficialTask task,
    Locale locale,
  ) async {
    final title = Uri.encodeComponent(task.displayTitle(locale));
    await context.push(
      '${AppRoutes.createPost}?officialTaskId=${task.id}&officialTaskTitle=$title',
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.text,
  });

  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AppRadius.allTiny,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: iconColor,
            ),
          ),
        ],
      ),
    );
  }
}
