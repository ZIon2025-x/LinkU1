import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/models/activity.dart';
import '../bloc/activity_bloc.dart';

/// 活动列表页
class ActivityView extends StatelessWidget {
  const ActivityView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActivityBloc(
        activityRepository: context.read<ActivityRepository>(),
      )..add(const ActivityLoadRequested()),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('校园活动'),
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
              return const EmptyStateView(
                icon: Icons.event_outlined,
                title: '暂无活动',
                description: '稍后再来看看吧',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<ActivityBloc>().add(
                      const ActivityRefreshRequested(),
                    );
                await Future.delayed(const Duration(milliseconds: 500));
              },
              child: ListView.separated(
                padding: AppSpacing.allMd,
                itemCount: state.activities.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => AppSpacing.vMd,
                itemBuilder: (context, index) {
                  if (index == state.activities.length) {
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

  String _formatTime(Activity a) {
    final dt = a.deadline ?? a.activityEndDate ?? a.createdAt;
    if (dt == null) return '';
    return '${dt.month}月${dt.day}日 ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return '立即报名';
      case 'completed':
        return '已结束';
      case 'cancelled':
        return '已取消';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      onTap: () {
        context.push('/activities/${activity.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面图
          if (activity.firstImage != null)
            ClipRRect(
              borderRadius: AppRadius.allMedium,
              child: Image.network(
                activity.firstImage!,
                height: 150,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.7),
                        AppColors.primary,
                      ],
                    ),
                    borderRadius: AppRadius.allMedium,
                  ),
                  child: Center(
                    child: Icon(
                      Icons.event,
                      color: Colors.white.withValues(alpha: 0.5),
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          if (activity.firstImage == null)
            Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.7),
                    AppColors.primary,
                  ],
                ),
                borderRadius: AppRadius.allMedium,
              ),
              child: Center(
                child: Icon(
                  Icons.event,
                  color: Colors.white.withValues(alpha: 0.5),
                  size: 48,
                ),
              ),
            ),
          AppSpacing.vMd,

          // 标题
          Text(
            activity.title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vSm,

          // 描述
          if (activity.description.isNotEmpty)
            Text(
              activity.description,
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (activity.description.isNotEmpty) AppSpacing.vSm,

          // 时间和地点
          Row(
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: AppColors.textTertiaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                _formatTime(activity),
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              if (activity.location.isNotEmpty) ...[
                const SizedBox(width: 16),
                const Icon(
                  Icons.location_on_outlined,
                  size: 16,
                  color: AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    activity.location,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          AppSpacing.vMd,

          // 底部：参与人数和状态
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${activity.currentParticipants ?? 0}/${activity.maxParticipants}人',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              GestureDetector(
                onTap: () {
                  if (activity.status == 'active' &&
                      !activity.isFull &&
                      activity.hasApplied != true) {
                    context.read<ActivityBloc>().add(
                          ActivityApply(activity.id),
                        );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: activity.status == 'active' &&
                            !activity.isFull &&
                            activity.hasApplied != true
                        ? AppColors.primary
                        : AppColors.textTertiaryLight.withValues(alpha: 0.3),
                    borderRadius: AppRadius.allPill,
                  ),
                  child: Text(
                    activity.hasApplied == true
                        ? '已报名'
                        : activity.isFull
                            ? '已满员'
                            : _getStatusText(activity.status),
                    style: TextStyle(
                      color: activity.status == 'active' &&
                              !activity.isFull &&
                              activity.hasApplied != true
                          ? Colors.white
                          : AppColors.textSecondaryLight,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
