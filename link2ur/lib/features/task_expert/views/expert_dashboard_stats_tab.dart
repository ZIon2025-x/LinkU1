import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/error_state_view.dart';
import '../bloc/expert_dashboard_bloc.dart';

/// Stats tab for the Expert Dashboard — shows 5 stat cards.
class ExpertDashboardStatsTab extends StatelessWidget {
  const ExpertDashboardStatsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) =>
          prev.stats != curr.stats || prev.status != curr.status,
      builder: (context, state) {
        if ((state.status == ExpertDashboardStatus.initial ||
                state.status == ExpertDashboardStatus.loading) &&
            state.stats.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ExpertDashboardStatus.error &&
            state.stats.isEmpty) {
          return ErrorStateView(
            message: context.localizeError(
                state.errorMessage ?? 'expert_dashboard_load_stats_failed'),
            onRetry: () => context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadStats()),
          );
        }

        final stats = state.stats;
        final totalServices = (stats['total_services'] as num?)?.toInt() ?? 0;
        final activeServices = (stats['active_services'] as num?)?.toInt() ?? 0;
        final totalApplications =
            (stats['total_applications'] as num?)?.toInt() ?? 0;
        final pendingApplications =
            (stats['pending_applications'] as num?)?.toInt() ?? 0;
        final upcomingSlots =
            (stats['upcoming_time_slots'] as num?)?.toInt() ?? 0;

        return ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            // 2-column grid for first 4 cards
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: context.l10n.expertDashboardTotalServices,
                    value: totalServices,
                    icon: Icons.design_services,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    title: context.l10n.expertDashboardActiveServices,
                    value: activeServices,
                    icon: Icons.check_circle,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _StatCard(
                    title: context.l10n.expertDashboardTotalApplications,
                    value: totalApplications,
                    icon: Icons.assignment,
                    color: AppColors.purple,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _StatCard(
                    title: context.l10n.expertDashboardPendingApplications,
                    value: pendingApplications,
                    icon: Icons.pending_actions,
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            // Full-width card for upcoming slots
            _StatCard(
              title: context.l10n.expertDashboardUpcomingSlots,
              value: upcomingSlots,
              icon: Icons.schedule,
              color: AppColors.teal,
              fullWidth: true,
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.fullWidth = false,
  });

  final String title;
  final int value;
  final IconData icon;
  final Color color;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: isDark ? 0.25 : 0.12),
            color.withValues(alpha: isDark ? 0.12 : 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: color.withValues(alpha: isDark ? 0.3 : 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: fullWidth
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: AppRadius.allSmall,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              if (fullWidth)
                Text(
                  value.toString(),
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (!fullWidth)
            Text(
              value.toString(),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
                height: 1,
              ),
            ),
          if (!fullWidth) const SizedBox(height: AppSpacing.xs),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
