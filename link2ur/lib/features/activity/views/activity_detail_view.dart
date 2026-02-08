import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../data/models/activity.dart';
import '../../../data/repositories/activity_repository.dart';
import '../bloc/activity_bloc.dart';

/// 活动详情视图 - 对标iOS ActivityDetailView.swift
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
          final hasImages = state.activityDetail?.images?.isNotEmpty == true ||
              state.activityDetail?.serviceImages?.isNotEmpty == true;

          return Scaffold(
            extendBodyBehindAppBar: true,
            appBar: _buildAppBar(context, state, hasImages),
            body: _buildBody(context, state),
            bottomNavigationBar: _buildBottomBar(context, state),
          );
        },
      ),
    );
  }

  /// 透明AppBar - 始终透明
  PreferredSizeWidget _buildAppBar(
      BuildContext context, ActivityState state, bool hasImages) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      leading: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.white),
          ),
        ),
      ),
      actions: [
        if (state.activityDetail != null) ...[
          _buildAppBarButton(
            icon: Icons.share_outlined,
            onPressed: () {
              HapticFeedback.selectionClick();
            },
          ),
        ],
      ],
    );
  }

  Widget _buildAppBarButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.white),
        ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片轮播区域 - 对标iOS ActivityImageCarousel (height: 240)
          _ActivityImageCarousel(activity: activity),

          // 内容区域 - 上移重叠图片 - 对标iOS offset(y: -30)
          Transform.translate(
            offset: const Offset(0, -30),
            child: Column(
              children: [
                // Header 卡片 - 对标iOS ActivityHeaderCard (标题 + 价格 + 标签)
                _ActivityHeaderCard(activity: activity, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // Stats 条 - 对标iOS ActivityStatsBar (参与人数/剩余名额/状态)
                _ActivityStatsBar(activity: activity, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // 描述卡片 - 对标iOS ActivityDescriptionCard
                if (activity.description.isNotEmpty)
                  _ActivityDescriptionCard(
                      activity: activity, isDark: isDark),
                if (activity.description.isNotEmpty)
                  const SizedBox(height: AppSpacing.md),

                // 信息网格卡片 - 对标iOS ActivityInfoGrid
                _ActivityInfoGrid(activity: activity, isDark: isDark),
                const SizedBox(height: AppSpacing.md),

                // 发布者信息行 - 对标iOS PosterInfoRow
                _PosterInfoRow(activity: activity, isDark: isDark),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildBottomBar(BuildContext context, ActivityState state) {
    if (state.activityDetail == null) return null;
    final activity = state.activityDetail!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              // 收藏按钮 - 对标iOS favorite button
              SizedBox(
                width: 50,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 20,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '收藏',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              // 主按钮
              Expanded(child: _buildCTAButton(context, state, activity)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCTAButton(
      BuildContext context, ActivityState state, Activity activity) {
    if (activity.status != 'active') {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.textTertiaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            _getStatusText(activity.status),
            style: AppTypography.bodyBold.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (activity.hasApplied == true) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.textTertiaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '已报名',
            style: AppTypography.bodyBold.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    if (activity.isFull) {
      return Container(
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.textTertiaryLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '已满员',
            style: AppTypography.bodyBold.copyWith(color: Colors.white),
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: state.isSubmitting
          ? null
          : () {
              HapticFeedback.selectionClick();
              context
                  .read<ActivityBloc>()
                  .add(ActivityApply(activityId));
            },
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, Color(0xFF0059B3)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: state.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  '立即报名',
                  style: AppTypography.bodyBold.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
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

// ==================== 图片轮播 ====================

class _ActivityImageCarousel extends StatefulWidget {
  const _ActivityImageCarousel({required this.activity});
  final Activity activity;

  @override
  State<_ActivityImageCarousel> createState() =>
      _ActivityImageCarouselState();
}

class _ActivityImageCarouselState extends State<_ActivityImageCarousel> {
  int _currentPage = 0;

  List<String> get _allImages {
    final images = <String>[];
    if (widget.activity.images != null) images.addAll(widget.activity.images!);
    if (widget.activity.serviceImages != null) {
      images.addAll(widget.activity.serviceImages!);
    }
    return images;
  }

  @override
  Widget build(BuildContext context) {
    final images = _allImages;

    if (images.isEmpty) {
      return _buildEmptyState();
    }

    return SizedBox(
      height: 300,
      child: Stack(
        children: [
          // 图片 PageView
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (index) =>
                setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => FullScreenImageView(
                      images: images,
                      initialIndex: index,
                    ),
                  ));
                },
                child: AsyncImageView(
                  imageUrl: images[index],
                  width: double.infinity,
                  height: 300,
                  fit: BoxFit.cover,
                ),
              );
            },
          ),

          // 底部渐变 - 对标iOS LinearGradient transparent → background
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 80,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Theme.of(context)
                        .scaffoldBackgroundColor
                        .withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),

          // 页面指示器 - 对标iOS capsule dots with ultraThinMaterial
          if (images.length > 1)
            Positioned(
              left: 0,
              right: 0,
              bottom: 45,
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(images.length, (index) {
                          final isSelected = _currentPage == index;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: isSelected ? 16 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Colors.white
                                  : Colors.white.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.15),
            AppColors.primary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event,
            size: 60,
            color: AppColors.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '暂无图片',
            style: AppTypography.caption.copyWith(
              color: AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Header 卡片 ====================

class _ActivityHeaderCard extends StatelessWidget {
  const _ActivityHeaderCard({
    required this.activity,
    required this.isDark,
  });

  final Activity activity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 第一行：标题 + 价格
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                _PriceView(activity: activity),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // 第二行：标签
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // 任务类型
                if (activity.taskType.isNotEmpty)
                  _BadgeView(
                    text: activity.taskType,
                    color: AppColors.primary,
                    withIcon: true,
                    icon: Icons.category,
                  ),
                // 预约制
                if (activity.hasTimeSlots)
                  _BadgeView(
                    text: '预约制',
                    color: Colors.orange,
                    withIcon: true,
                    icon: Icons.schedule,
                  ),
                // 位置
                if (activity.location.isNotEmpty)
                  _BadgeView(
                    text: activity.location,
                    color: AppColors.error,
                    withIcon: true,
                    icon: activity.location.toLowerCase().contains('online')
                        ? Icons.public
                        : Icons.location_on,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 价格视图 ====================

class _PriceView extends StatelessWidget {
  const _PriceView({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final price = activity.discountedPricePerParticipant ??
        activity.originalPricePerParticipant;

    if (price == null || price == 0) {
      return Text(
        '免费',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.success,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '£',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.5,
              ),
            ),
            Text(
              price.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                height: 1.1,
              ),
            ),
          ],
        ),
        if (activity.hasDiscount &&
            activity.originalPricePerParticipant != null)
          Text(
            '£${activity.originalPricePerParticipant!.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              decoration: TextDecoration.lineThrough,
              color: AppColors.textTertiaryLight,
            ),
          ),
      ],
    );
  }
}

// ==================== Badge 视图 ====================

class _BadgeView extends StatelessWidget {
  const _BadgeView({
    required this.text,
    required this.color,
    this.withIcon = false,
    this.icon,
  });

  final String text;
  final Color color;
  final bool withIcon;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    if (withIcon && icon != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 9, color: Colors.white),
            const SizedBox(width: 3),
            Text(
              text,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}

// ==================== Stats 条 ====================

class _ActivityStatsBar extends StatelessWidget {
  const _ActivityStatsBar({
    required this.activity,
    required this.isDark,
  });

  final Activity activity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final remaining =
        activity.maxParticipants - (activity.currentParticipants ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // 参与人数
              Expanded(
                child: _StatItem(
                  value:
                      '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                  label: '参与人数',
                  color: AppColors.primary,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: (isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight)
                    .withValues(alpha: 0.3),
              ),
              // 剩余名额
              Expanded(
                child: _StatItem(
                  value: '$remaining',
                  label: '剩余名额',
                  color: AppColors.success,
                ),
              ),
              VerticalDivider(
                width: 1,
                thickness: 1,
                color: (isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight)
                    .withValues(alpha: 0.3),
              ),
              // 状态
              Expanded(
                child: _StatItem(
                  value: _getStatusText(activity.status),
                  label: '状态',
                  color: _getStatusColor(activity.status),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
        return activity.isFull ? AppColors.error : Colors.orange;
      case 'completed':
        return AppColors.textSecondaryLight;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textTertiaryLight;
    }
  }

  String _getStatusText(String status) {
    if (status == 'active' && activity.isFull) return '已满员';
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

class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.value,
    required this.label,
    required this.color,
  });

  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          label,
          style: AppTypography.caption.copyWith(
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}

// ==================== 描述卡片 ====================

class _ActivityDescriptionCard extends StatelessWidget {
  const _ActivityDescriptionCard({
    required this.activity,
    required this.isDark,
  });

  final Activity activity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header - 对标iOS SectionHeader
            _SectionHeader(
              icon: Icons.description,
              title: '活动详情',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              activity.description,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 信息网格卡片 ====================

class _ActivityInfoGrid extends StatelessWidget {
  const _ActivityInfoGrid({
    required this.activity,
    required this.isDark,
  });

  final Activity activity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(
              icon: Icons.info_outline,
              title: '活动信息',
            ),
            const SizedBox(height: AppSpacing.md),

            // 位置
            if (activity.location.isNotEmpty)
              _InfoRow(
                icon: activity.location.toLowerCase().contains('online')
                    ? Icons.public
                    : Icons.location_on,
                label: '地点',
                value: activity.location,
              ),

            // 类型
            if (activity.taskType.isNotEmpty)
              _InfoRow(
                icon: Icons.category,
                label: '类型',
                value: activity.taskType,
              ),

            // 截止时间
            if (activity.deadline != null)
              _InfoRow(
                icon: Icons.calendar_today,
                label: '截止时间',
                value: _formatDateTime(activity.deadline),
              ),

            // 折扣
            if (activity.hasDiscount)
              _InfoRow(
                icon: Icons.local_offer,
                label: '折扣',
                value:
                    '${activity.discountPercentage!.toStringAsFixed(0)}% OFF',
                valueColor: AppColors.error,
              ),

            // 奖励类型
            _InfoRow(
              icon: Icons.monetization_on,
              label: '奖励类型',
              value: _getRewardTypeText(activity.rewardType),
            ),
          ],
        ),
      ),
    );
  }

  String _getRewardTypeText(String type) {
    switch (type) {
      case 'cash':
        return '现金';
      case 'points':
        return '积分';
      case 'both':
        return '现金 + 积分';
      default:
        return type;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return '';
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}

// ==================== 信息行 ====================

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Icon(
              icon,
              size: 16,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            label,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondaryLight,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              style: AppTypography.body.copyWith(
                fontWeight: FontWeight.w500,
                color: valueColor ?? AppColors.textPrimaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Section Header ====================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
  });

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

// ==================== 发布者信息行 ====================

class _PosterInfoRow extends StatelessWidget {
  const _PosterInfoRow({
    required this.activity,
    required this.isDark,
  });

  final Activity activity;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          if (activity.expertId.isNotEmpty) {
            context.push('/task-experts/${activity.expertId}');
          }
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // 头像
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF0059B3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, size: 22, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.md),
              // 文字
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '发布者',
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '查看达人资料',
                      style: AppTypography.bodyBold.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              // 箭头
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.backgroundDark
                      : AppColors.backgroundLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.chevron_right,
                  size: 14,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
