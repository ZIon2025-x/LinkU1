import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
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
          title: const Text('活动'),
        ),
        body: BlocBuilder<ActivityBloc, ActivityState>(
          builder: (context, state) {
            if (state.status == ActivityStatus.loading &&
                state.activities.isEmpty) {
              return const LoadingView();
            }

            if (state.status == ActivityStatus.error &&
                state.activities.isEmpty) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '加载失败',
                onRetry: () {
                  context.read<ActivityBloc>().add(
                        const ActivityLoadRequested(),
                      );
                },
              );
            }

            if (state.activities.isEmpty) {
              return EmptyStateView.noData(
                title: '暂无活动',
                description: '还没有可用的活动',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ActivityBloc>().add(
                      const ActivityRefreshRequested(),
                    );
                // Wait for state update
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.separated(
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
                  return _ActivityCard(activity: state.activities[index]);
                },
              ),
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
              ClipRRect(
                borderRadius: AppRadius.allMedium,
                child: Image.network(
                  activity.firstImage!,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 200,
                    color: AppColors.skeletonBase,
                    child: const Icon(Icons.image_not_supported),
                  ),
                ),
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
                style: TextStyle(color: AppColors.textSecondaryLight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            AppSpacing.vMd,

            // 位置
            if (activity.location.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 16,
                    color: AppColors.textTertiaryLight,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      activity.location,
                      style: TextStyle(
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
                    style: TextStyle(
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
                    Icon(
                      Icons.people_outline,
                      size: 16,
                      color: AppColors.textTertiaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            // 进度条
            if (activity.maxParticipants > 0) ...[
              AppSpacing.vSm,
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: activity.participationProgress,
                  backgroundColor: AppColors.skeletonBase,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 4,
                ),
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
                    _getStatusText(activity.status),
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
                      style: TextStyle(
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
}
