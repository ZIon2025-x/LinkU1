import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/repositories/activity_repository.dart';
import '../bloc/activity_bloc.dart';

/// 活动详情视图
/// 参考iOS ActivityDetailView.swift
class ActivityDetailView extends StatelessWidget {
  const ActivityDetailView({
    super.key,
    required this.activityId,
  });

  final int activityId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActivityBloc(
        activityRepository: context.read<ActivityRepository>(),
      )..add(ActivityLoadDetail(activityId)),
      child: _ActivityDetailViewContent(activityId: activityId),
    );
  }
}

class _ActivityDetailViewContent extends StatelessWidget {
  const _ActivityDetailViewContent({required this.activityId});

  final int activityId;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ActivityBloc, ActivityState>(
      listener: (context, state) {
        if (state.actionMessage == '报名成功') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('报名成功'),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state.actionMessage != null &&
            state.actionMessage!.startsWith('报名失败')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionMessage!),
              backgroundColor: AppColors.error,
            ),
          );
        }
      },
      child: BlocBuilder<ActivityBloc, ActivityState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('活动详情'),
            ),
            body: _buildBody(context, state),
            bottomNavigationBar: _buildBottomBar(context, state),
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, ActivityState state) {
    if (state.isDetailLoading && state.activityDetail == null) {
      return const LoadingView();
    }

    if (state.detailStatus == ActivityStatus.error &&
        state.activityDetail == null) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage ?? '加载失败',
        onRetry: () {
          context.read<ActivityBloc>().add(ActivityLoadDetail(activityId));
        },
      );
    }

    if (state.activityDetail == null) {
      return ErrorStateView.notFound();
    }

    final activity = state.activityDetail!;

    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片轮播
          if (activity.images != null && activity.images!.isNotEmpty)
            SizedBox(
              height: 250,
              child: PageView.builder(
                itemCount: activity.images!.length,
                itemBuilder: (context, index) {
                  return ClipRRect(
                    borderRadius: AppRadius.allMedium,
                    child: Image.network(
                      activity.images![index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: AppColors.skeletonBase,
                        child: const Icon(Icons.image_not_supported),
                      ),
                    ),
                  );
                },
              ),
            ),
          if (activity.images != null && activity.images!.isNotEmpty)
            AppSpacing.vLg,

          // 标题
          Text(
            activity.title,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          AppSpacing.vMd,

          // 价格和状态
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allTiny,
                ),
                child: Text(
                  activity.priceDisplay,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
              if (activity.hasDiscount) ...[
                AppSpacing.hMd,
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: AppRadius.allTiny,
                  ),
                  child: Text(
                    '${activity.discountPercentage!.toStringAsFixed(0)}% OFF',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(activity.status)
                      .withValues(alpha: 0.1),
                  borderRadius: AppRadius.allTiny,
                ),
                child: Text(
                  _getStatusText(activity.status),
                  style: TextStyle(
                    fontSize: 14,
                    color: _getStatusColor(activity.status),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vLg,

          // 参与进度
          Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 20,
                color: AppColors.textSecondaryLight,
              ),
              AppSpacing.hSm,
              Text(
                '参与人数: ${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                style: const TextStyle(
                  fontSize: 16,
                  color: AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
          AppSpacing.vSm,
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: activity.participationProgress,
              backgroundColor: AppColors.skeletonBase,
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
              minHeight: 8,
            ),
          ),
          AppSpacing.vLg,

          // 位置
          if (activity.location.isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.location_on_outlined,
                  size: 20,
                  color: AppColors.textSecondaryLight,
                ),
                AppSpacing.hSm,
                Expanded(
                  child: Text(
                    activity.location,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              ],
            ),
            AppSpacing.vLg,
          ],

          // 描述
          if (activity.description.isNotEmpty) ...[
            const Text(
              '活动详情',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vMd,
            Text(
              activity.description,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondaryLight,
                height: 1.6,
              ),
            ),
            AppSpacing.vLg,
          ],

          // 截止时间
          if (activity.deadline != null) ...[
            Row(
              children: [
                const Icon(
                  Icons.access_time_outlined,
                  size: 20,
                  color: AppColors.textSecondaryLight,
                ),
                AppSpacing.hSm,
                Text(
                  '截止时间: ${_formatDateTime(activity.deadline)}',
                  style: const TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget? _buildBottomBar(BuildContext context, ActivityState state) {
    if (state.activityDetail == null) return null;

    final activity = state.activityDetail!;
    final canApply = activity.status == 'active' &&
        !activity.isFull &&
        (activity.hasApplied != true);

    if (!canApply) return null;

    return Container(
      padding: AppSpacing.allMd,
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
        child: PrimaryButton(
          text: '立即报名',
          onPressed: state.isSubmitting
              ? null
              : () {
                  context.read<ActivityBloc>().add(
                        ActivityApply(activityId),
                      );
                },
          isLoading: state.isSubmitting,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return AppColors.textSecondaryLight;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiaryLight;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '进行中';
      case 'completed':
        return '已结束';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
