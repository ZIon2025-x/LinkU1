import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/badge.dart';
import '../bloc/badges_bloc.dart';

/// Dialog for selecting which badge to display on the user's avatar.
///
/// Must be shown within a context that has [BadgesBloc] provided.
/// Example:
/// ```dart
/// showDialog(
///   context: context,
///   builder: (_) => BlocProvider.value(
///     value: context.read<BadgesBloc>(),
///     child: const BadgeSelectorDialog(),
///   ),
/// );
/// ```
class BadgeSelectorDialog extends StatelessWidget {
  const BadgeSelectorDialog({super.key, required this.badgesBloc});

  final BadgesBloc badgesBloc;

  /// Show the badge selector dialog.
  ///
  /// [badgesBloc] must be provided so the dialog can read and dispatch events.
  static Future<void> show(BuildContext context, BadgesBloc badgesBloc) {
    return showDialog(
      context: context,
      builder: (_) => BadgeSelectorDialog(badgesBloc: badgesBloc),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: AppRadius.allLarge),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.badgeSelector,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Badge list
            Flexible(
              child: BlocBuilder<BadgesBloc, BadgesState>(
                bloc: badgesBloc,
                builder: (context, state) {
                  if (state.badges.isEmpty) {
                    return Padding(
                      padding: AppSpacing.allLg,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.military_tech_outlined,
                              size: 48,
                              color: theme.colorScheme.onSurface
                                  .withAlpha(100),
                            ),
                            AppSpacing.vSm,
                            Text(
                              context.l10n.badgeSelectorEmpty,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withAlpha(140),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  // Error snackbar
                  if (state.errorMessage != null) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.localizeError(state.errorMessage),
                            ),
                          ),
                        );
                      }
                    });
                  }

                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.sm,
                    ),
                    itemCount: state.badges.length + 1, // +1 for "Clear" option
                    itemBuilder: (context, index) {
                      // First item: "Clear" / "No badge" option
                      if (index == 0) {
                        final hasDisplayed =
                            state.badges.any((b) => b.isDisplayed);
                        return _ClearBadgeItem(
                          isSelected: !hasDisplayed,
                          onTap: hasDisplayed
                              ? () => _clearDisplayedBadges(context, state)
                              : null,
                        );
                      }

                      final badge = state.badges[index - 1];
                      return _BadgeSelectionItem(
                        badge: badge,
                        onTap: () {
                          badgesBloc.add(BadgeDisplayToggled(badge.id));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearDisplayedBadges(BuildContext context, BadgesState state) {
    // Toggle off all displayed badges
    final displayedBadges = state.badges.where((b) => b.isDisplayed);
    for (final badge in displayedBadges) {
      badgesBloc.add(BadgeDisplayToggled(badge.id));
    }
  }
}

/// "No badge / Clear" option at top of the list
class _ClearBadgeItem extends StatelessWidget {
  const _ClearBadgeItem({
    required this.isSelected,
    this.onTap,
  });

  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withAlpha(13)
              : Colors.grey.withAlpha(25),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.block,
          size: 20,
          color: theme.colorScheme.onSurface.withAlpha(100),
        ),
      ),
      title: Text(
        context.l10n.badgeNone,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: Text(
        context.l10n.badgeNoClearDescription,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withAlpha(120),
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 24)
          : Icon(
              Icons.radio_button_unchecked,
              color: theme.colorScheme.onSurface.withAlpha(60),
              size: 24,
            ),
      onTap: onTap,
    );
  }
}

/// A single badge selection row
class _BadgeSelectionItem extends StatelessWidget {
  const _BadgeSelectionItem({
    required this.badge,
    required this.onTap,
  });

  final UserBadge badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final badgeColor = _getBadgeColor(badge.rank);

    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: badgeColor.withAlpha(isDark ? 40 : 25),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.military_tech,
          size: 22,
          color: badgeColor,
        ),
      ),
      title: Text(
        badge.skillCategory ?? badge.badgeType,
        style: theme.textTheme.bodyMedium?.copyWith(
          fontWeight: badge.isDisplayed ? FontWeight.w700 : FontWeight.w500,
        ),
      ),
      subtitle: badge.rank != null
          ? Text(
              badge.rank!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withAlpha(120),
              ),
            )
          : null,
      trailing: badge.isDisplayed
          ? const Icon(Icons.check_circle, color: AppColors.primary, size: 24)
          : Icon(
              Icons.radio_button_unchecked,
              color: theme.colorScheme.onSurface.withAlpha(60),
              size: 24,
            ),
      onTap: onTap,
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
