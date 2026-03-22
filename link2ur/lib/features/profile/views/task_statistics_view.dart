import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/profile_bloc.dart';

/// Task Statistics detail page — shown to VIP users.
/// Displays task counts, completion rate, and upgrade progress.
class TaskStatisticsView extends StatelessWidget {
  const TaskStatisticsView({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthBloc>().state.user?.id ?? '';
    if (userId.isEmpty) return const SizedBox.shrink();

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      )..add(ProfileLoadTaskStatistics(userId)),
      child: _TaskStatisticsContent(userId: userId),
    );
  }
}

class _TaskStatisticsContent extends StatelessWidget {
  const _TaskStatisticsContent({required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskStatisticsTitle),
      ),
      body: BlocBuilder<ProfileBloc, ProfileState>(
        buildWhen: (prev, curr) =>
            prev.isLoadingStatistics != curr.isLoadingStatistics ||
            prev.taskStatistics != curr.taskStatistics ||
            prev.errorMessage != curr.errorMessage,
        builder: (context, state) {
          if (state.isLoadingStatistics) {
            return const Center(child: LoadingView());
          }

          if (state.errorMessage != null && state.taskStatistics == null) {
            return Center(
              child: Padding(
                padding: AppSpacing.allMd,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.textSecondary,
                    ),
                    AppSpacing.vMd,
                    Text(
                      state.errorMessage!,
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    AppSpacing.vLg,
                    ElevatedButton.icon(
                      onPressed: () {
                        context.read<ProfileBloc>().add(
                              ProfileLoadTaskStatistics(userId),
                            );
                      },
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.taskStatisticsTitle),
                    ),
                  ],
                ),
              ),
            );
          }

          final stats = state.taskStatistics;
          if (stats == null) {
            return const Center(child: LoadingView());
          }

          final statistics =
              stats['statistics'] as Map<String, dynamic>? ?? {};
          final upgradeConditions =
              stats['upgrade_conditions'] as Map<String, dynamic>? ?? {};
          final currentLevel = stats['current_level'] as String? ?? 'normal';

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ProfileBloc>().add(
                    ProfileLoadTaskStatistics(userId),
                  );
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: AppSpacing.screen,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _StatsCard(statistics: statistics),
                  AppSpacing.vMd,
                  _UpgradeCard(
                    upgradeConditions: upgradeConditions,
                    statistics: statistics,
                    currentLevel: currentLevel,
                  ),
                  AppSpacing.vXl,
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==================== Stats Card ====================

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.statistics});

  final Map<String, dynamic> statistics;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final postedTasks = statistics['posted_tasks'] as int? ?? 0;
    final acceptedTasks = statistics['accepted_tasks'] as int? ?? 0;
    final completedTasks = statistics['completed_tasks'] as int? ?? 0;
    final totalTasks = statistics['total_tasks'] as int? ?? 0;
    final completionRate =
        (statistics['completion_rate'] as num?)?.toDouble() ?? 0.0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4-column stat row
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  label: l10n.taskStatisticsPosted,
                  value: '$postedTasks',
                  color: AppColors.primary,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatColumn(
                  label: l10n.taskStatisticsAccepted,
                  value: '$acceptedTasks',
                  color: AppColors.accent,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatColumn(
                  label: l10n.taskStatisticsCompleted,
                  value: '$completedTasks',
                  color: AppColors.success,
                ),
              ),
              _VerticalDivider(),
              Expanded(
                child: _StatColumn(
                  label: l10n.taskStatisticsTotal,
                  value: '$totalTasks',
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.lg),
          const Divider(height: 1),
          const SizedBox(height: AppSpacing.lg),

          // Completion rate progress bar
          Text(
            l10n.taskStatisticsCompletionRate,
            style: AppTypography.footnote.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _ProgressBar(
                  value: completionRate.clamp(0.0, 1.0),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '${(completionRate * 100).toStringAsFixed(0)}%',
                style: AppTypography.subheadlineBold.copyWith(
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ==================== Upgrade Card ====================

class _UpgradeCard extends StatelessWidget {
  const _UpgradeCard({
    required this.upgradeConditions,
    required this.statistics,
    required this.currentLevel,
  });

  final Map<String, dynamic> upgradeConditions;
  final Map<String, dynamic> statistics;
  final String currentLevel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final upgradeEnabled =
        upgradeConditions['upgrade_enabled'] as bool? ?? false;
    final taskCountThreshold =
        (upgradeConditions['task_count_threshold'] as num?)?.toInt() ?? 50;
    final ratingThreshold =
        (upgradeConditions['rating_threshold'] as num?)?.toDouble() ?? 4.5;
    final completionRateThreshold =
        (upgradeConditions['completion_rate_threshold'] as num?)?.toDouble() ??
            0.8;

    final totalTasks = statistics['total_tasks'] as int? ?? 0;
    final completionRate =
        (statistics['completion_rate'] as num?)?.toDouble() ?? 0.0;

    // Rating is not directly in statistics — use 0 as placeholder; backend
    // may include it in future iterations or the user's profile field.
    // We show a progress bar capped at threshold for now.
    const double currentRating = 0.0;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: title + current level badge
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.taskStatisticsUpgradeProgress,
                  style: AppTypography.bodyBold,
                ),
              ),
              _LevelBadge(level: currentLevel),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${l10n.taskStatisticsCurrentLevel}: ${_levelLabel(context, currentLevel)}',
            style: AppTypography.footnote.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (!upgradeEnabled) ...[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.warningLight,
                borderRadius: BorderRadius.circular(AppRadius.small),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppColors.warning,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.taskStatisticsUpgradeDisabled,
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],

          // Progress bars
          _UpgradeProgressItem(
            label: l10n.taskStatisticsTaskCount,
            current: totalTasks.toDouble(),
            threshold: taskCountThreshold.toDouble(),
            unit: '',
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          _UpgradeProgressItem(
            label: l10n.taskStatisticsRating,
            current: currentRating,
            threshold: ratingThreshold,
            unit: '',
            color: AppColors.gold,
            decimals: 1,
          ),
          const SizedBox(height: AppSpacing.md),
          _UpgradeProgressItem(
            label: l10n.taskStatisticsCompletionRate,
            current: completionRate * 100,
            threshold: completionRateThreshold * 100,
            unit: '%',
            color: AppColors.success,
            decimals: 0,
          ),
        ],
      ),
    );
  }

  String _levelLabel(BuildContext context, String level) {
    final l10n = context.l10n;
    switch (level) {
      case 'vip':
        return l10n.taskStatisticsLevelVip;
      case 'super':
        return l10n.taskStatisticsLevelSuper;
      default:
        return l10n.taskStatisticsLevelNormal;
    }
  }
}

// ==================== Shared Widgets ====================

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: AppSpacing.card,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: AppTypography.title3.copyWith(color: color),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: AppColors.dividerLight,
      margin: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.pill),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 8,
        backgroundColor:
            Theme.of(context).brightness == Brightness.dark
                ? Colors.white12
                : Colors.black.withValues(alpha: 0.07),
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

class _UpgradeProgressItem extends StatelessWidget {
  const _UpgradeProgressItem({
    required this.label,
    required this.current,
    required this.threshold,
    required this.unit,
    required this.color,
    this.decimals = 0,
  });

  final String label;
  final double current;
  final double threshold;
  final String unit;
  final Color color;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final progress = threshold > 0
        ? (current / threshold).clamp(0.0, 1.0)
        : 0.0;
    final currentStr = decimals > 0
        ? current.toStringAsFixed(decimals)
        : current.toStringAsFixed(0);
    final thresholdStr = decimals > 0
        ? threshold.toStringAsFixed(decimals)
        : threshold.toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.footnote.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            Text(
              '$currentStr$unit / $thresholdStr$unit',
              style: AppTypography.footnote.copyWith(
                color: progress >= 1.0 ? AppColors.success : color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        _ProgressBar(value: progress, color: color),
      ],
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level});

  final String level;

  @override
  Widget build(BuildContext context) {
    final List<Color> gradient;
    final IconData icon;

    switch (level) {
      case 'vip':
        gradient = AppColors.gradientGold;
        icon = Icons.workspace_premium;
        break;
      case 'super':
        gradient = AppColors.gradientPinkPurple;
        icon = Icons.local_fire_department;
        break;
      default:
        gradient = [AppColors.textSecondary, AppColors.textTertiary];
        icon = Icons.person;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradient),
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            _levelLabel(context, level),
            style: AppTypography.badge.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  String _levelLabel(BuildContext context, String level) {
    final l10n = context.l10n;
    switch (level) {
      case 'vip':
        return l10n.taskStatisticsLevelVip;
      case 'super':
        return l10n.taskStatisticsLevelSuper;
      default:
        return l10n.taskStatisticsLevelNormal;
    }
  }
}
