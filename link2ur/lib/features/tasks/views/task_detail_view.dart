import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../bloc/task_detail_bloc.dart';

/// 任务详情页
/// 参考iOS TaskDetailView.swift
class TaskDetailView extends StatelessWidget {
  const TaskDetailView({super.key, required this.taskId});

  final int taskId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskDetailBloc(
        taskRepository: context.read<TaskRepository>(),
      )..add(TaskDetailLoadRequested(taskId)),
      child: const _TaskDetailContent(),
    );
  }
}

class _TaskDetailContent extends StatelessWidget {
  const _TaskDetailContent();

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskDetailBloc, TaskDetailState>(
      listenWhen: (prev, curr) => curr.actionMessage != null && prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('任务详情'),
            actions: [
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: () {},
              ),
              IconButton(
                icon: const Icon(Icons.more_horiz),
                onPressed: () {},
              ),
            ],
          ),
          body: _buildBody(context, state),
          bottomNavigationBar: state.isLoaded && state.task != null
              ? _buildBottomBar(context, state)
              : null,
        );
      },
    );
  }

  Widget _buildBody(BuildContext context, TaskDetailState state) {
    if (state.isLoading) {
      return const SkeletonDetail();
    }

    if (state.status == TaskDetailStatus.error) {
      return ErrorStateView(
        message: state.errorMessage ?? '加载失败',
        onRetry: () {
          final bloc = context.read<TaskDetailBloc>();
          if (state.task != null) {
            bloc.add(TaskDetailLoadRequested(state.task!.id));
          }
        },
      );
    }

    final task = state.task;
    if (task == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片轮播
          if (task.images.isNotEmpty) _buildImageCarousel(task),

          Padding(
            padding: AppSpacing.allMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 标题和状态
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        task.displayTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: AppRadius.allTiny,
                      ),
                      child: Text(
                        task.statusText,
                        style: const TextStyle(color: AppColors.success),
                      ),
                    ),
                  ],
                ),
                AppSpacing.vMd,

                // 价格
                Text(
                  '${task.currency == 'GBP' ? '£' : '\$'}${task.reward.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                AppSpacing.vLg,

                // 任务信息卡片
                _buildInfoCard(task),
                AppSpacing.vMd,

                // 任务描述
                if (task.displayDescription != null)
                  _buildDescriptionCard(task),
                if (task.displayDescription != null) AppSpacing.vMd,

                // 发布者信息
                _buildPosterCard(context, task),
                AppSpacing.vXxl,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageCarousel(Task task) {
    return SizedBox(
      height: 250,
      child: PageView.builder(
        itemCount: task.images.length,
        itemBuilder: (context, index) {
          return AsyncImageView(
            imageUrl: task.images[index],
            width: double.infinity,
            height: 250,
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(Task task) {
    return AppCard(
      child: Column(
        children: [
          _InfoRow(
            icon: Icons.category_outlined,
            label: '任务类型',
            value: task.taskTypeText,
          ),
          const Divider(height: 24),
          _InfoRow(
            icon: Icons.location_on_outlined,
            label: '任务地点',
            value: task.location ?? '线上',
          ),
          if (task.deadline != null) ...[
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.access_time,
              label: '截止时间',
              value:
                  '${task.deadline!.year}-${task.deadline!.month.toString().padLeft(2, '0')}-${task.deadline!.day.toString().padLeft(2, '0')}',
            ),
          ],
          if (task.isMultiParticipant) ...[
            const Divider(height: 24),
            _InfoRow(
              icon: Icons.people_outline,
              label: '参与人数',
              value: '${task.currentParticipants}/${task.maxParticipants}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(Task task) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '任务描述',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          AppSpacing.vMd,
          Text(
            task.displayDescription!,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPosterCard(BuildContext context, Task task) {
    return AppCard(
      onTap: task.poster != null
          ? () => context.push('/chat/${task.posterId}')
          : null,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary,
            child: task.poster?.avatar != null
                ? ClipOval(
                    child: Image.network(
                      task.poster!.avatar!,
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, color: Colors.white),
                    ),
                  )
                : const Icon(Icons.person, color: Colors.white),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.poster?.name ?? '发布者',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (task.poster?.isVerified == true)
                  Row(
                    children: [
                      Icon(Icons.verified, size: 14, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        '已认证',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, TaskDetailState state) {
    final task = state.task!;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconActionButton(
              icon: Icons.chat_bubble_outline,
              onPressed: () {
                context.push('/chat/${task.posterId}');
              },
              backgroundColor: AppColors.skeletonBase,
            ),
            AppSpacing.hMd,
            Expanded(
              child: _buildActionButton(context, state),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(BuildContext context, TaskDetailState state) {
    final task = state.task!;

    if (state.isSubmitting) {
      return const PrimaryButton(
        text: '处理中...',
        onPressed: null,
        isLoading: true,
      );
    }

    if (task.canApply) {
      return PrimaryButton(
        text: '申请接单',
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailApplyRequested());
        },
      );
    }

    if (task.hasApplied) {
      return PrimaryButton(
        text: '取消申请',
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailCancelApplicationRequested());
        },
      );
    }

    if (task.status == 'in_progress') {
      return PrimaryButton(
        text: '完成任务',
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailCompleteRequested());
        },
      );
    }

    if (task.status == 'pending_confirmation') {
      return PrimaryButton(
        text: '确认完成',
        onPressed: () {
          context
              .read<TaskDetailBloc>()
              .add(const TaskDetailConfirmCompletionRequested());
        },
      );
    }

    return PrimaryButton(
      text: task.statusText,
      onPressed: null,
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.textSecondaryLight),
        AppSpacing.hMd,
        Text(
          label,
          style: TextStyle(color: AppColors.textSecondaryLight),
        ),
        const Spacer(),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
