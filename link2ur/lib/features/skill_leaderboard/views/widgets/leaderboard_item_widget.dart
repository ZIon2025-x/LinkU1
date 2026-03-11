import 'package:flutter/material.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/widgets/async_image_view.dart';
import '../../../../data/models/skill_leaderboard_entry.dart';

/// Single leaderboard entry row widget
class LeaderboardItemWidget extends StatelessWidget {
  const LeaderboardItemWidget({
    super.key,
    required this.entry,
    this.isCurrentUser = false,
  });

  final SkillLeaderboardEntry entry;
  final bool isCurrentUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.xs,
      ),
      padding: AppSpacing.listItem,
      decoration: BoxDecoration(
        color: isCurrentUser
            ? AppColors.primary.withAlpha(isDark ? 40 : 25)
            : isDark
                ? Colors.white.withAlpha(13)
                : Colors.white,
        borderRadius: AppRadius.allMedium,
        border: isCurrentUser
            ? Border.all(color: AppColors.primary.withAlpha(100), width: 1.5)
            : Border.all(
                color: isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(13),
              ),
      ),
      child: Row(
        children: [
          // Rank number
          _buildRank(theme),
          AppSpacing.hMd,

          // Avatar
          _buildAvatar(),
          AppSpacing.hSm,

          // Name & completed tasks
          Expanded(child: _buildUserInfo(theme)),

          // Rating
          _buildRating(theme),
          AppSpacing.hMd,

          // Score
          _buildScore(theme),
        ],
      ),
    );
  }

  Widget _buildRank(ThemeData theme) {
    final rank = entry.rank;
    if (rank >= 1 && rank <= 3) {
      return _buildMedalRank(rank);
    }
    return SizedBox(
      width: 32,
      child: Text(
        '$rank',
        textAlign: TextAlign.center,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withAlpha(180),
        ),
      ),
    );
  }

  Widget _buildMedalRank(int rank) {
    final Color color;
    final IconData icon;
    switch (rank) {
      case 1:
        color = const Color(0xFFFFD700); // Gold
        icon = Icons.emoji_events;
        break;
      case 2:
        color = const Color(0xFFC0C0C0); // Silver
        icon = Icons.emoji_events;
        break;
      case 3:
        color = const Color(0xFFCD7F32); // Bronze
        icon = Icons.emoji_events;
        break;
      default:
        color = Colors.grey;
        icon = Icons.emoji_events;
    }

    return SizedBox(
      width: 32,
      child: Icon(icon, color: color, size: 28),
    );
  }

  Widget _buildAvatar() {
    return AvatarView(
      imageUrl: entry.userAvatar,
      name: entry.userName,
    );
  }

  Widget _buildUserInfo(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          entry.userName,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isCurrentUser ? FontWeight.w700 : FontWeight.w600,
            color: isCurrentUser ? AppColors.primary : null,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '${entry.completedTasks} tasks',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withAlpha(140),
          ),
        ),
      ],
    );
  }

  Widget _buildRating(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.star_rounded,
          size: 16,
          color: entry.avgRating > 0
              ? const Color(0xFFFFB800)
              : theme.colorScheme.onSurface.withAlpha(80),
        ),
        const SizedBox(width: 2),
        Text(
          entry.ratingDisplay,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: entry.avgRating > 0
                ? theme.colorScheme.onSurface
                : theme.colorScheme.onSurface.withAlpha(80),
          ),
        ),
      ],
    );
  }

  Widget _buildScore(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(25),
        borderRadius: AppRadius.allPill,
      ),
      child: Text(
        entry.score.toStringAsFixed(0),
        style: theme.textTheme.bodySmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}
