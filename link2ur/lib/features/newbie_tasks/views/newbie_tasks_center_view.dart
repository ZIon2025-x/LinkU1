import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/newbie_tasks_repository.dart';
import '../../../data/repositories/official_tasks_repository.dart';
import '../bloc/newbie_tasks_bloc.dart';
import 'widgets/official_task_bottom_sheet.dart';
import 'widgets/official_task_card.dart';
import 'widgets/stage_progress_widget.dart';
import 'widgets/task_item_widget.dart';

/// task_key → 跳转路由映射。
/// pending 状态的任务点击后引导用户去对应页面完成操作。
const _taskRoutes = <String, String>{
  'upload_avatar': AppRoutes.editProfile,
  'fill_bio': AppRoutes.editProfile,
  'add_skills': AppRoutes.editProfile,
  'student_verify': AppRoutes.studentVerification,
  'first_post': AppRoutes.createPost,
  'first_flea_item': AppRoutes.createFleaMarketItem,
  'join_activity': AppRoutes.activities,
  'posts_5': AppRoutes.createPost,
  'posts_20': AppRoutes.createPost,
  'first_assigned_task': AppRoutes.tasks,
  'complete_5_tasks': AppRoutes.tasks,
};

/// 任务中心页面
/// 显示新手任务（按阶段分组）+ 官方任务
class NewbieTasksCenterView extends StatelessWidget {
  const NewbieTasksCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NewbieTasksBloc(
        newbieTasksRepository: context.read<NewbieTasksRepository>(),
        officialTasksRepository: context.read<OfficialTasksRepository>(),
      )..add(const NewbieTasksLoadRequested()),
      child: const _TaskCenterContent(),
    );
  }
}

class _TaskCenterContent extends StatelessWidget {
  const _TaskCenterContent();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocListener<NewbieTasksBloc, NewbieTasksState>(
      listenWhen: (prev, curr) =>
          prev.errorMessage != curr.errorMessage &&
          curr.errorMessage != null &&
          curr.status == NewbieTasksStatus.loaded,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.localizeError(state.errorMessage))),
        );
      },
      child: BlocBuilder<NewbieTasksBloc, NewbieTasksState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.newbieTaskCenter),
            ),
            body: state.isLoading && state.tasks.isEmpty
                ? const LoadingView()
                : state.status == NewbieTasksStatus.error && state.tasks.isEmpty
                    ? ErrorStateView(
                        message:
                            context.localizeError(state.errorMessage),
                        onRetry: () => context
                            .read<NewbieTasksBloc>()
                            .add(const NewbieTasksLoadRequested()),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          final bloc = context.read<NewbieTasksBloc>();
                          bloc.add(const NewbieTasksLoadRequested());
                          await bloc.stream
                              .firstWhere((s) => !s.isLoading)
                              .timeout(
                                const Duration(seconds: 10),
                                onTimeout: () => bloc.state,
                              );
                        },
                        child: _buildBody(context, state),
                      ),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, NewbieTasksState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // Welcome hint for new users
        SliverToBoxAdapter(
          child: _WelcomeHint(allCompleted: state.completedCount == state.totalCount && state.totalCount > 0),
        ),

        // Overall progress header
        SliverToBoxAdapter(
          child: _OverallProgressCard(state: state),
        ),

        // Stage 1
        ..._buildStageSection(
            context, state, 1, l10n.newbieTaskStage1, isDark),

        // Stage 2
        ..._buildStageSection(
            context, state, 2, l10n.newbieTaskStage2, isDark),

        // Stage 3
        ..._buildStageSection(
            context, state, 3, l10n.newbieTaskStage3, isDark),

        // Official Tasks section
        if (state.officialTasks.isNotEmpty) ...[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradientIndigo,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.flag_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  AppSpacing.hSm,
                  Text(
                    l10n.newbieOfficialTasksTitle,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: AppSpacing.horizontalMd,
            sliver: SliverList.separated(
              itemCount: state.officialTasks.length,
              separatorBuilder: (_, __) => AppSpacing.vSm,
              itemBuilder: (context, index) {
                final task = state.officialTasks[index];
                return OfficialTaskCard(
                  key: ValueKey('official_${task.id}'),
                  task: task,
                  onTap: () async {
                    final shouldNavigate = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => OfficialTaskBottomSheet(task: task),
                    );
                    if (!context.mounted) return;
                    // If user tapped "Go Post", navigate and wait for return
                    if (shouldNavigate == true) {
                      final locale = Localizations.localeOf(context);
                      await OfficialTaskBottomSheet.navigateToCreatePost(
                        context, task, locale,
                      );
                    }
                    // Refresh after CreatePostView returns (or sheet dismissed)
                    if (context.mounted) {
                      context
                          .read<NewbieTasksBloc>()
                          .add(const NewbieTasksLoadRequested());
                    }
                  },
                );
              },
            ),
          ),
        ],

        // Bottom spacing
        const SliverToBoxAdapter(
          child: SizedBox(height: 32),
        ),
      ],
    );
  }

  List<Widget> _buildStageSection(
    BuildContext context,
    NewbieTasksState state,
    int stageNumber,
    String title,
    bool isDark,
  ) {
    final stageTasks = state.getTasksByStage(stageNumber);
    final stageProgress = state.stages
        .where((s) => s.stage == stageNumber)
        .firstOrNull;

    // Don't show empty stages
    if (stageTasks.isEmpty && stageProgress == null) {
      return [];
    }

    return [
      // Stage header
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
          child: StageProgressWidget(
            stageNumber: stageNumber,
            title: title,
            tasks: stageTasks,
            stageProgress: stageProgress,
          ),
        ),
      ),
      // Task items
      if (stageTasks.isNotEmpty)
        SliverPadding(
          padding: AppSpacing.horizontalMd,
          sliver: SliverList.separated(
            itemCount: stageTasks.length,
            separatorBuilder: (_, __) => AppSpacing.vSm,
            itemBuilder: (context, index) {
              final task = stageTasks[index];
              final isClaiming = state.claimingTaskKey == task.taskKey;
              final route = _taskRoutes[task.taskKey];
              return TaskItemWidget(
                key: ValueKey('task_${task.taskKey}'),
                task: task,
                isClaiming: isClaiming,
                onClaim: () => context
                    .read<NewbieTasksBloc>()
                    .add(NewbieTaskClaimRequested(task.taskKey)),
                onTap: route != null
                    ? () async {
                        await context.push(route);
                        if (context.mounted) {
                          context
                              .read<NewbieTasksBloc>()
                              .add(const NewbieTasksLoadRequested());
                        }
                      }
                    : null,
              );
            },
          ),
        ),
      // Stage bonus card
      if (stageProgress != null)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: StageBonusCard(
              stageProgress: stageProgress,
              tasks: stageTasks,
              isClaiming: state.claimingStage == stageNumber,
              onClaim: () => context
                  .read<NewbieTasksBloc>()
                  .add(NewbieStageBonusClaimRequested(stageNumber)),
            ),
          ),
        ),
    ];
  }
}

/// 欢迎引导提示 — 告诉用户该怎么做。
class _WelcomeHint extends StatelessWidget {
  const _WelcomeHint({required this.allCompleted});

  final bool allCompleted;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            allCompleted ? '🎉' : '👋',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              allCompleted
                  ? l10n.newbieAllDoneHint
                  : l10n.newbieWelcomeHint,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Overall progress card at the top of the page.
class _OverallProgressCard extends StatelessWidget {
  const _OverallProgressCard({required this.state});

  final NewbieTasksState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final completedCount = state.completedCount;
    final totalCount = state.totalCount;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientPrimary,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.rocket_launch_rounded,
                  color: Colors.white,
                  size: 24,
                ),
                AppSpacing.hSm,
                Text(
                  l10n.newbieTaskProgressTitle,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
                const Spacer(),
                Text(
                  '$completedCount/$totalCount',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
            AppSpacing.vMd,
            // Progress bar
            ClipRRect(
              borderRadius: AppRadius.allPill,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            AppSpacing.vSm,
            Text(
              totalCount > 0
                  ? completedCount == totalCount
                      ? l10n.newbieTaskAllCompleted
                      : l10n.newbieTaskGetRewardsHint
                  : l10n.newbieTaskNoTasks,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
