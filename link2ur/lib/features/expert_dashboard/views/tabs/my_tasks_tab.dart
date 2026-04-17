import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/design/app_colors.dart';
import '../../../../core/design/app_radius.dart';
import '../../../../core/design/app_spacing.dart';
import '../../../../core/router/go_router_extensions.dart';
import '../../../../core/utils/error_localizer.dart';
import '../../../../core/utils/l10n_extension.dart';
import '../../../../core/widgets/error_state_view.dart';
import '../../bloc/expert_dashboard_bloc.dart';

/// My Tasks tab — shows tasks the current user participates in.
class MyTasksTab extends StatelessWidget {
  const MyTasksTab({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpertDashboardBloc, ExpertDashboardState>(
      buildWhen: (prev, curr) =>
          prev.myTasks != curr.myTasks || prev.status != curr.status,
      builder: (context, state) {
        if ((state.status == ExpertDashboardStatus.initial ||
                state.status == ExpertDashboardStatus.loading) &&
            state.myTasks.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state.status == ExpertDashboardStatus.error &&
            state.myTasks.isEmpty) {
          return ErrorStateView(
            message: context.localizeError(
                state.errorMessage ?? 'expert_dashboard_load_my_tasks_failed'),
            onRetry: () => context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadMyTasks()),
          );
        }

        if (state.myTasks.isEmpty) {
          return _EmptyMyTasksView();
        }

        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<ExpertDashboardBloc>()
                .add(const ExpertDashboardLoadMyTasks());
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: state.myTasks.length,
            itemBuilder: (context, index) {
              final task = state.myTasks[index];
              return Padding(
                key: ValueKey(task['id']),
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: _TaskCard(
                  task: task,
                  onTap: () {
                    final taskId = task['id'];
                    if (taskId is int) {
                      context.goToTaskChat(taskId);
                    } else {
                      final parsed = int.tryParse(taskId.toString());
                      if (parsed != null) context.goToTaskChat(parsed);
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyMyTasksView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_outlined,
              size: 64,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.l10n.expertMyTasksEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.l10n.expertMyTasksEmptyMessage,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task, required this.onTap});

  final Map<String, dynamic> task;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final title = (task['title'] as String?) ?? '';
    final posterName = (task['poster_name'] as String?) ?? '';
    final posterAvatar = task['poster_avatar'] as String?;
    final status = (task['status'] as String?) ?? '';
    final reward = task['reward'];
    final currency = (task['currency'] as String?) ?? 'GBP';
    final joinedAt = task['joined_at'] as String?;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.allMedium,
        side: BorderSide(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allMedium,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundImage:
                    posterAvatar != null ? NetworkImage(posterAvatar) : null,
                child: posterAvatar == null
                    ? Text(
                        posterName.isNotEmpty
                            ? posterName[0].toUpperCase()
                            : '?',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      )
                    : null,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          posterName,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                        ),
                        if (reward != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          Text(
                            '$currency ${(reward as num).toStringAsFixed(2)}',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                        ],
                      ],
                    ),
                    if (joinedAt != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        joinedAt.substring(0, 10),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                              fontSize: 11,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusChip(status: status),
              const SizedBox(width: 4),
              Icon(
                Icons.chat_outlined,
                size: 20,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (color, label) = switch (status) {
      'pending_payment' => (Colors.orange, l10n.taskStatusPendingPayment),
      'in_progress' => (AppColors.primary, l10n.taskStatusInProgress),
      'completed' => (Colors.green, l10n.taskStatusCompleted),
      'pending' => (Colors.orange, l10n.taskStatusPendingPayment),
      _ => (Colors.grey, status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}
