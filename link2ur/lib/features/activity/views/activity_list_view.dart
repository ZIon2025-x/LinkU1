import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/animated_progress_bar.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/models/activity.dart';
import '../bloc/activity_bloc.dart';

/// 活动列表视图
/// 参考iOS ActivityListView.swift
class ActivityListView extends StatelessWidget {
  const ActivityListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActivityBloc(
        activityRepository: context.read<ActivityRepository>(),
      )..add(const ActivityLoadRequested()),
      child: Scaffold(
        appBar: AppBar(
          title: Builder(
            builder: (context) => Text(context.l10n.activityActivities),
          ),
        ),
        body: BlocBuilder<ActivityBloc, ActivityState>(
          buildWhen: (prev, curr) =>
              prev.activities != curr.activities ||
              prev.status != curr.status ||
              prev.hasMore != curr.hasMore,
          builder: (context, state) {
            // AnimatedSwitcher 实现 skeleton → 内容的平滑过渡
            Widget content;

            if (state.status == ActivityStatus.loading &&
                state.activities.isEmpty) {
              content = const SkeletonTopImageCardList(
                key: ValueKey('skeleton'),
                itemCount: 3,
                imageHeight: 200,
              );
            } else if (state.status == ActivityStatus.error &&
                state.activities.isEmpty) {
              content = ErrorStateView.loadFailed(
                message: state.errorMessage ?? context.l10n.activityLoadFailed,
                onRetry: () {
                  context.read<ActivityBloc>().add(
                        const ActivityLoadRequested(),
                      );
                },
              );
            } else if (state.activities.isEmpty) {
              content = EmptyStateView.noData(
                context,
                title: context.l10n.activityNoActivities,
                description: context.l10n.activityNoAvailableActivities,
              );
            } else {
            content = RefreshIndicator(
              onRefresh: () async {
                context.read<ActivityBloc>().add(
                      const ActivityRefreshRequested(),
                    );
                // Wait for state update
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.separated(
                clipBehavior: Clip.none,
                padding: AppSpacing.allMd,
                itemCount: state.activities.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => AppSpacing.vMd,
                itemBuilder: (context, index) {
                  if (index == state.activities.length) {
                    // Load more trigger
                    context.read<ActivityBloc>().add(
                          const ActivityLoadMore(),
                        );
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: LoadingIndicator(),
                      ),
                    );
                  }
                  return AnimatedListItem(
                    index: index,
                    child: _ActivityCard(activity: state.activities[index]),
                  );
                },
              ),
            );
            }

            return AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              child: content,
            );
          },
        ),
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/activities/${activity.id}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片
            if (activity.firstImage != null)
              AsyncImageView(
                imageUrl: activity.firstImage,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                borderRadius: AppRadius.allMedium,
              ),
            if (activity.firstImage != null) AppSpacing.vMd,

            // 标题
            Text(
              activity.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vSm,

            // 描述
            if (activity.description.isNotEmpty)
              Text(
                activity.description,
                style: const TextStyle(color: AppColors.textSecondaryLight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            AppSpacing.vMd,

            // 位置
            if (activity.location.isNotEmpty)
              Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textTertiaryLight,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity.location,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            if (activity.location.isNotEmpty) AppSpacing.vSm,

            // 价格和参与进度
            Row(
              children: [
                // 价格
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.allTiny,
                  ),
                  child: Text(
                    activity.priceDisplay,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const Spacer(),

                // 参与进度
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 16,
                      color: AppColors.textTertiaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 进度条 — 自定义动画版
            if (activity.maxParticipants > 0) ...[
              AppSpacing.vSm,
              AnimatedProgressBar(
                progress: activity.participationProgress,
                height: 5,
                showLabel: true,
                label:
                    '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                warningThreshold: 0.85,
              ),
            ],

            // 状态标签
            AppSpacing.vSm,
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(activity.status)
                        .withValues(alpha: 0.1),
                    borderRadius: AppRadius.allTiny,
                  ),
                  child: Text(
                    _getStatusText(activity.status, context),
                    style: TextStyle(
                      fontSize: 12,
                      color: _getStatusColor(activity.status),
                    ),
                  ),
                ),
                if (activity.hasDiscount) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.1),
                      borderRadius: AppRadius.allTiny,
                    ),
                    child: Text(
                      '${activity.discountPercentage!.toStringAsFixed(0)}% OFF',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.error,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
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

  String _getStatusText(String status, BuildContext context) {
    switch (status) {
      case 'active':
        return context.l10n.activityInProgress;
      case 'completed':
        return context.l10n.activityEnded;
      case 'cancelled':
        return context.l10n.activityCancelled;
      default:
        return status;
    }
  }
}
