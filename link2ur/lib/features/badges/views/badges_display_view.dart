import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/badge.dart';
import '../../../data/repositories/badges_repository.dart';
import '../bloc/badges_bloc.dart';
import 'badge_selector_dialog.dart';

/// Badges display section for user profile page.
///
/// Can be embedded as a widget section within the profile page.
/// When [userId] is null, loads the current user's badges.
class BadgesDisplayView extends StatelessWidget {
  const BadgesDisplayView({
    super.key,
    this.userId,
    this.onBadgeTap,
  });

  /// If null, loads current user's badges via [BadgesLoadRequested].
  final String? userId;

  /// Called when a badge is tapped (e.g. to open badge selector dialog).
  final VoidCallback? onBadgeTap;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BadgesBloc(
        badgesRepository: context.read<BadgesRepository>(),
      )..add(const BadgesLoadRequested()),
      child: _BadgesDisplayBody(onBadgeTap: onBadgeTap),
    );
  }
}

class _BadgesDisplayBody extends StatelessWidget {
  const _BadgesDisplayBody({this.onBadgeTap});

  final VoidCallback? onBadgeTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BadgesBloc, BadgesState>(
      builder: (context, state) {
        if (state.status == BadgesStatus.loading && state.badges.isEmpty) {
          return const SizedBox(
            height: 80,
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        if (state.status == BadgesStatus.error && state.badges.isEmpty) {
          return Padding(
            padding: AppSpacing.horizontalMd,
            child: Text(
              context.localizeError(state.errorMessage),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.error,
                  ),
            ),
          );
        }

        if (state.badges.isEmpty) {
          return _buildEmptyBadges(context);
        }

        return _buildBadgesGrid(context, state.badges);
      },
    );
  }

  Widget _buildEmptyBadges(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: AppSpacing.horizontalMd,
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(13) : Colors.grey.withAlpha(20),
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Icon(
            Icons.military_tech_outlined,
            size: 32,
            color: theme.colorScheme.onSurface.withAlpha(100),
          ),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              context.l10n.badgesEmptyState,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(140),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openBadgeSelector(BuildContext context) {
    BadgeSelectorDialog.show(context, context.read<BadgesBloc>());
  }

  Widget _buildBadgesGrid(BuildContext context, List<UserBadge> badges) {
    return Padding(
      padding: AppSpacing.horizontalMd,
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.sm,
        children: badges.map((badge) {
          return Semantics(
            button: true,
            label: context.l10n.badgeViewDetails,
            child: GestureDetector(
              onTap: onBadgeTap ?? () => _openBadgeSelector(context),
              child: _BadgeChip(badge: badge),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// A single badge chip display
class _BadgeChip extends StatelessWidget {
  const _BadgeChip({required this.badge});

  final UserBadge badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color badgeColor = _getBadgeColor(badge.rank);
    final bool isDisplayed = badge.isDisplayed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDisplayed
            ? badgeColor.withAlpha(isDark ? 50 : 30)
            : isDark
                ? Colors.white.withAlpha(13)
                : Colors.grey.withAlpha(25),
        borderRadius: AppRadius.allPill,
        border: isDisplayed
            ? Border.all(color: badgeColor.withAlpha(120), width: 1.5)
            : Border.all(
                color: isDark
                    ? Colors.white.withAlpha(20)
                    : Colors.black.withAlpha(13),
              ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.military_tech,
            size: 18,
            color: badgeColor,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              buildBadgeLabel(context, badge),
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: isDisplayed
                    ? badgeColor
                    : theme.colorScheme.onSurface.withAlpha(180),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor(String? rank) {
    if (rank == null) return AppColors.primary;
    final lower = rank.toLowerCase();
    if (lower.contains('1') || lower.contains('gold') || lower == 'top 1') {
      return const Color(0xFFFFD700);
    }
    if (lower.contains('2') ||
        lower.contains('silver') ||
        lower == 'top 2') {
      return const Color(0xFFC0C0C0);
    }
    if (lower.contains('3') ||
        lower.contains('bronze') ||
        lower == 'top 3') {
      return const Color(0xFFCD7F32);
    }
    return AppColors.primary;
  }
}
