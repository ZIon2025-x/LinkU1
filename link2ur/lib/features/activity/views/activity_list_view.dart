import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/scroll_safe_tap.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/models/activity.dart';
import '../bloc/activity_bloc.dart';

/// 活动列表视图（对齐iOS ActivityListView.swift）
/// 顶部分段筛选器：单人活动 / 多人活动
class ActivityListView extends StatelessWidget {
  const ActivityListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ActivityBloc(
        activityRepository: context.read<ActivityRepository>(),
      )..add(const ActivityLoadRequested(status: 'open')),
      child: const _ActivityListContent(),
    );
  }
}

/// 活动筛选类型（对齐iOS ActivityFilterOption）
enum _FilterOption { single, multi }

class _ActivityListContent extends StatefulWidget {
  const _ActivityListContent();

  @override
  State<_ActivityListContent> createState() => _ActivityListContentState();
}

class _ActivityListContentState extends State<_ActivityListContent> {
  _FilterOption _filterOption = _FilterOption.single;

  /// 按 hasTimeSlots 筛选（对齐iOS filteredActivities）
  List<Activity> _filteredActivities(List<Activity> all) {
    switch (_filterOption) {
      case _FilterOption.single:
        return all.where((a) => !a.hasTimeSlots).toList();
      case _FilterOption.multi:
        return all.where((a) => a.hasTimeSlots).toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.activityActivities),
      ),
      body: Column(
        children: [
          // 分段筛选器（对齐iOS SegmentedPickerStyle）
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: _SegmentedFilter(
              selected: _filterOption,
              onChanged: (option) {
                AppHaptics.selection();
                setState(() => _filterOption = option);
              },
              isDark: isDark,
            ),
          ),

          // 活动列表
          Expanded(
            child: BlocBuilder<ActivityBloc, ActivityState>(
              buildWhen: (prev, curr) =>
                  prev.activities != curr.activities ||
                  prev.status != curr.status ||
                  prev.hasMore != curr.hasMore,
              builder: (context, state) {
                final filtered = _filteredActivities(state.activities);

                // 判断当前处于哪种状态，用于 AnimatedSwitcher 的 key
                // 只在 skeleton/error/empty/loaded 之间切换时才触发动画
                // 筛选切换不会改变 stateKey，避免闪烁
                final String stateKey;
                if (state.status == ActivityStatus.loading &&
                    state.activities.isEmpty) {
                  stateKey = 'skeleton';
                } else if (state.status == ActivityStatus.error &&
                    state.activities.isEmpty) {
                  stateKey = 'error';
                } else if (state.activities.isEmpty) {
                  stateKey = 'empty';
                } else {
                  stateKey = 'loaded';
                }

                Widget content;

                if (stateKey == 'skeleton') {
                  content = const SkeletonTopImageCardList(
                    key: ValueKey('skeleton'),
                    itemCount: 3,
                    imageHeight: 160,
                  );
                } else if (stateKey == 'error') {
                  content = KeyedSubtree(
                    key: const ValueKey('error'),
                    child: ErrorStateView.loadFailed(
                      message:
                          state.errorMessage ?? l10n.activityLoadFailed,
                      onRetry: () {
                        context.read<ActivityBloc>().add(
                              const ActivityLoadRequested(status: 'open'),
                            );
                      },
                    ),
                  );
                } else if (filtered.isEmpty) {
                  // 数据已加载但当前筛选无结果
                  content = KeyedSubtree(
                    key: const ValueKey('empty'),
                    child: EmptyStateView(
                      icon: Icons.event_busy,
                      title: l10n.activityNoActivities,
                      message: l10n.activityNoAvailableActivities,
                    ),
                  );
                } else {
                  content = RefreshIndicator(
                    key: const ValueKey('loaded'),
                    onRefresh: () async {
                      context.read<ActivityBloc>().add(
                            const ActivityRefreshRequested(),
                          );
                      await Future.delayed(
                          const Duration(milliseconds: 500));
                    },
                    child: ListView.separated(
                      clipBehavior: Clip.none,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      itemCount:
                          filtered.length + (state.hasMore ? 1 : 0),
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        if (index == filtered.length) {
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
                          child: ActivityCardView(
                            activity: filtered[index],
                            onTap: () => context.push(
                                '/activities/${filtered[index].id}'),
                          ),
                        );
                      },
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: AppConstants.animationDuration,
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: content,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// 分段筛选器（对齐iOS SegmentedPickerStyle）
class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({
    required this.selected,
    required this.onChanged,
    required this.isDark,
  });

  final _FilterOption selected;
  final ValueChanged<_FilterOption> onChanged;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _buildSegment(
            label: l10n.activitySingle,
            isSelected: selected == _FilterOption.single,
            onTap: () => onChanged(_FilterOption.single),
          ),
          _buildSegment(
            label: l10n.activityMulti,
            isSelected: selected == _FilterOption.multi,
            onTap: () => onChanged(_FilterOption.multi),
          ),
        ],
      ),
    );
  }

  Widget _buildSegment({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.grey[700] : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? (isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight)
                  : (isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }
}

/// 活动卡片（对齐iOS ActivityCardView）
/// 可在活动列表、我的活动等多处复用
class ActivityCardView extends StatelessWidget {
  const ActivityCardView({
    super.key,
    required this.activity,
    required this.onTap,
    this.showEndedBadge = false,
    this.isFavorited = false,
    this.activityType,
  });

  final Activity activity;
  final VoidCallback onTap;
  final bool showEndedBadge;
  final bool isFavorited;

  /// 活动类型标记（我的活动页面用）: "applied", "favorited", "both"
  /// 为 null 时不显示类型标签
  final String? activityType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return ScrollSafeTap(
      onTap: onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: (isDark ? Colors.white : Colors.black)
                .withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域 + 状态标签（对齐iOS ZStack）
            Stack(
              children: [
                // 图片或占位
                activity.firstImage != null
                    ? AsyncImageView(
                        imageUrl: activity.firstImage!,
                        width: double.infinity,
                        height: 160,
                      )
                    : _buildPlaceholder(),

                // 右上角收藏红心（对齐iOS isFavorited）
                if (isFavorited)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 3,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.favorite,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),

                // 类型标签：已申请 / 已收藏（我的活动页面）
                if (activityType != null)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _buildTypeBadges(l10n),
                  ),

                // 状态标签：已满 / 已结束（对齐iOS）
                if (activity.isFull || showEndedBadge)
                  Positioned(
                    top: 8,
                    left: (isFavorited || activityType != null) ? 8 : null,
                    right: (isFavorited || activityType != null) ? null : 8,
                    child: _buildStatusBadge(l10n),
                  ),
              ],
            ),

            // 内容区域（对齐iOS VStack内容）
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题（对齐iOS单行）
                  Text(
                    activity.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 价格 + 参与人数（对齐iOS HStack）
                  Row(
                    children: [
                      // 价格（对齐iOS: 货币符号 + 金额 bold）
                      _buildPriceDisplay(activity),
                      const Spacer(),
                      // 参与人数
                      Icon(
                        Icons.people,
                        size: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // 位置 + 预约制标签（对齐iOS底部行）
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        size: 13,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          activity.location.isNotEmpty
                              ? activity.location
                              : '-',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (activity.hasTimeSlots) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color:
                                AppColors.warning.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            l10n.activityByAppointment,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppColors.warning,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 价格显示（对齐iOS: 货币符号小字 + 金额大字 bold）
  Widget _buildPriceDisplay(Activity activity) {
    final price = activity.discountedPricePerParticipant ??
        activity.originalPricePerParticipant;
    final symbol = activity.currency == 'GBP' ? '£' : '¥';

    if (price == null || price == 0) {
      return const Text(
        'Free',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          symbol,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 2),
        Text(
          price.toStringAsFixed(0),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
      ],
    );
  }

  /// 类型标签（我的活动页面: applied绿色 + favorited红心，对齐iOS）
  Widget _buildTypeBadges(dynamic l10n) {
    final type = activityType ?? activity.type;
    if (type == null) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (type == 'applied' || type == 'both')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.success,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              l10n.taskExpertApplied,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        if (type == 'both') const SizedBox(width: 4),
        if (type == 'favorited' || type == 'both')
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.favorite,
              size: 10,
              color: Colors.white,
            ),
          ),
      ],
    );
  }

  /// 状态标签（对齐iOS: ended / fullCapacity）
  Widget _buildStatusBadge(dynamic l10n) {
    if (activity.isFull) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.activityFullCapacity,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    if (showEndedBadge) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          l10n.activityEnded,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  /// 渐变占位图（对齐iOS placeholderBackground）
  Widget _buildPlaceholder() {
    return Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.calendar_month,
        size: 40,
        color: AppColors.primary.withValues(alpha: 0.3),
      ),
    );
  }
}
