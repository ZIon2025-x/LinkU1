import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/custom_share_panel.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
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
        taskExpertRepository:
            context.read<TaskExpertRepository>(),
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
        if (state.actionMessage == context.l10n.activityRegisterSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.activityRegisterSuccess),
              backgroundColor: AppColors.success,
            ),
          );
        } else if (state.actionMessage != null &&
            state.actionMessage!.startsWith(context.l10n.activityRegisterFailed)) {
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
            body: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: ResponsiveUtils.detailMaxWidth(context)),
                child: _buildBody(context, state),
              ),
            ),
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
              final activity = state.activityDetail!;
              CustomSharePanel.show(
                context,
                title: activity.title,
                description: activity.description,
                url: 'https://link2ur.com/activities/${activity.id}',
              );
            },
          ),
          // 达人头像按钮 - 对标iOS expert avatar NavigationLink
          if (state.activityDetail!.expertId.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () {
                  context.push('/task-experts/${state.activityDetail!.expertId}');
                },
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withValues(alpha: 0.15),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(Icons.person,
                      size: 14, color: AppColors.primary),
                ),
              ),
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
        message: state.errorMessage ?? context.l10n.activityLoadFailed,
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
                      context.l10n.activityFavorite,
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

  /// CTA 按钮 - 对标iOS ActivityBottomBar 的完整状态机
  /// 状态优先级：已结束 > 已申请(含议价/支付子状态) > 已满 > 可申请
  Widget _buildCTAButton(
      BuildContext context, ActivityState state, Activity activity) {
    // 1. 活动已结束/取消 - 对标iOS activity.isEnded
    if (activity.status != 'active') {
      return _buildDisabledButton(_getStatusText(activity.status, context));
    }

    // 2. 已申请且有任务ID - 对标iOS hasApplied == true, let taskId = activity.userTaskId
    if (activity.hasApplied == true && activity.userTaskId != null) {
      // 2a. 有议价 + 待支付 → 等待达人回应 (灰色不可点击)
      if (activity.userTaskHasNegotiation == true &&
          activity.userTaskStatus == 'pending_payment') {
        return _buildDisabledButton(context.l10n.activityWaitingExpertResponse);
      }

      // 2b. 待支付 + 未支付 → 继续支付 (可点击)
      if (activity.userTaskStatus == 'pending_payment' &&
          activity.userTaskIsPaid != true) {
        return _buildPrimaryButton(
          context,
          text: context.l10n.activityContinuePayment,
          isLoading: state.isSubmitting,
          onTap: () {
            HapticFeedback.selectionClick();
            // TODO: 跳转支付页面
          },
        );
      }

      // 2c. 有议价但非待支付 → 等待达人回应
      if (activity.userTaskHasNegotiation == true) {
        return _buildDisabledButton(context.l10n.activityWaitingExpertResponse);
      }

      // 2d. 其他已申请状态 → 已申请 (灰色)
      return _buildDisabledButton(context.l10n.activityApplied);
    }

    // 3. 已申请但无任务ID → 已申请 (灰色)
    if (activity.hasApplied == true) {
      return _buildDisabledButton(context.l10n.activityApplied);
    }

    // 4. 已满员
    if (activity.isFull) {
      return _buildDisabledButton(context.l10n.activityFullSlots);
    }

    // 5. 可申请 → 弹出申请弹窗 - 对标iOS showPurchaseSheet / ActivityApplyView
    return _buildPrimaryButton(
      context,
      text: context.l10n.activityRegisterNow,
      isLoading: state.isSubmitting,
      onTap: () {
        HapticFeedback.selectionClick();
        ActivityApplySheet.show(
          context,
          activityId: activityId,
          activity: activity,
        );
      },
    );
  }

  /// 禁用状态按钮 (灰色)
  Widget _buildDisabledButton(String text) {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.textTertiaryLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          text,
          style: AppTypography.bodyBold.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  /// 主操作按钮 (渐变色)
  Widget _buildPrimaryButton(
    BuildContext context, {
    required String text,
    required bool isLoading,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
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
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(
                  text,
                  style: AppTypography.bodyBold.copyWith(color: Colors.white),
                ),
        ),
      ),
    );
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
            context.l10n.fleaMarketNoImage,
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
                    text: context.l10n.activityByAppointment,
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
        context.l10n.activityFree,
        style: const TextStyle(
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
            const Text(
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
              style: const TextStyle(
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
            style: const TextStyle(
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
                  label: context.l10n.activityParticipantsCount,
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
                  label: context.l10n.activityRemainingSlots,
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
                  value: _getStatusText(activity.status, context),
                  label: context.l10n.activityStatusLabel,
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

  String _getStatusText(String status, BuildContext context) {
    if (status == 'active' && activity.isFull) return context.l10n.activityFullSlots;
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
              title: context.l10n.activityDetailTitle,
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
              title: context.l10n.activityInfo,
            ),
            const SizedBox(height: AppSpacing.md),

            // 位置
            if (activity.location.isNotEmpty)
              _InfoRow(
                icon: activity.location.toLowerCase().contains('online')
                    ? Icons.public
                    : Icons.location_on,
                label: context.l10n.activityLocation,
                value: activity.location,
              ),

            // 类型
            if (activity.taskType.isNotEmpty)
              _InfoRow(
                icon: Icons.category,
                label: context.l10n.activityType,
                value: activity.taskType,
              ),

            // 时间安排 - 对标iOS hasTimeSlots条件
            if (activity.hasTimeSlots)
              _InfoRow(
                icon: Icons.calendar_month,
                label: context.l10n.activityTimeArrangement,
                value: context.l10n.activityMultipleTimeSlots,
              )
            else if (activity.deadline != null)
              _InfoRow(
                icon: Icons.calendar_today,
                label: context.l10n.activityDeadline,
                value: _formatDateTime(activity.deadline),
              ),

            // 折扣
            if (activity.hasDiscount)
              _InfoRow(
                icon: Icons.local_offer,
                label: context.l10n.activityDiscount,
                value:
                    '${activity.discountPercentage!.toStringAsFixed(0)}% OFF',
                valueColor: AppColors.error,
              ),

            // 奖励类型
            _InfoRow(
              icon: Icons.monetization_on,
              label: context.l10n.activityRewardType,
              value: _getRewardTypeText(activity.rewardType, context),
            ),
          ],
        ),
      ),
    );
  }

  String _getRewardTypeText(String type, BuildContext context) {
    switch (type) {
      case 'cash':
        return context.l10n.activityCash;
      case 'points':
        return context.l10n.activityPointsReward;
      case 'both':
        return context.l10n.activityCashAndPoints;
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
                      context.l10n.activityPublisher,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.activityViewExpertProfileShort,
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

// ============================================================
// 活动申请弹窗 - 对标iOS ActivityApplyView
// hasTimeSlots → 时间段选择视图
// !hasTimeSlots → 灵活时间 / 日期选择视图
// ============================================================

class ActivityApplySheet extends StatefulWidget {
  const ActivityApplySheet({
    super.key,
    required this.activityId,
    required this.activity,
  });

  final int activityId;
  final Activity activity;

  /// 弹出申请弹窗
  static Future<void> show(
    BuildContext context, {
    required int activityId,
    required Activity activity,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: context.read<ActivityBloc>(),
        child: ActivityApplySheet(
          activityId: activityId,
          activity: activity,
        ),
      ),
    );
  }

  @override
  State<ActivityApplySheet> createState() => _ActivityApplySheetState();
}

class _ActivityApplySheetState extends State<ActivityApplySheet> {
  int? _selectedTimeSlotId;
  bool _isFlexibleTime = false;
  DateTime _preferredDate = DateTime.now().add(const Duration(days: 1));

  bool get _hasTimeSlots => widget.activity.hasTimeSlots;

  @override
  void initState() {
    super.initState();
    // 有时间段时自动加载 - 对标iOS onAppear
    if (_hasTimeSlots) {
      context.read<ActivityBloc>().add(ActivityLoadTimeSlots(
            serviceId: widget.activity.expertServiceId,
            activityId: widget.activityId,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<ActivityBloc, ActivityState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null &&
          prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          Navigator.of(context).pop(); // 关闭弹窗
          // snackbar 由外层 listener 处理
        }
      },
      builder: (context, state) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // 拖动手柄
                  _buildHandle(),
                  // 标题栏
                  _buildTitleBar(context),
                  const Divider(height: 1),
                  // 内容区域
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.all(AppSpacing.md),
                      children: [
                        if (_hasTimeSlots)
                          _buildTimeSlotSelection(context, state, isDark)
                        else
                          _buildFlexibleTimeSelection(context, isDark),
                        const SizedBox(height: AppSpacing.lg),
                      ],
                    ),
                  ),
                  // 底部按钮
                  _buildApplyButton(context, state, isDark),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 10, bottom: 6),
        width: 36,
        height: 5,
        decoration: BoxDecoration(
          color: AppColors.textTertiaryLight.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.commonCancel,
              style: AppTypography.body.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          const Spacer(),
          Text(
            context.l10n.activityApplyToJoin,
            style: AppTypography.title3,
          ),
          const Spacer(),
          const SizedBox(width: 50), // 平衡间距
        ],
      ),
    );
  }

  // ==================== 时间段选择视图 ====================

  Widget _buildTimeSlotSelection(
      BuildContext context, ActivityState state, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        _buildSectionHeader(
          icon: Icons.schedule,
          title: context.l10n.activitySelectTimeSlot,
        ),
        const SizedBox(height: AppSpacing.md),

        if (state.isLoadingTimeSlots)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: CircularProgressIndicator(),
            ),
          )
        else if (state.timeSlots.isEmpty)
          _buildEmptyTimeSlots(context, isDark)
        else
          _buildTimeSlotsGrouped(state.timeSlots, isDark),
      ],
    );
  }

  Widget _buildEmptyTimeSlots(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        borderRadius: AppRadius.allLarge,
      ),
      child: Column(
        children: [
          Icon(Icons.event_busy,
              size: 48,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.activityNoAvailableTime,
            style: AppTypography.bodyBold.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.activityNoAvailableTimeMessage,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// 按日期分组显示时间段 - 对标iOS groupedTimeSlots + timeSlotsList
  Widget _buildTimeSlotsGrouped(List<ServiceTimeSlot> slots, bool isDark) {
    // 按日期分组
    final grouped = <String, List<ServiceTimeSlot>>{};
    for (final slot in slots) {
      final dateKey = _parseSlotDateKey(slot.slotStartDatetime);
      grouped.putIfAbsent(dateKey, () => []).add(slot);
    }
    final sortedKeys = grouped.keys.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedKeys.map((dateKey) {
        final daySlots = grouped[dateKey]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期标题 - 对标iOS formatDate
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: AppSpacing.sm),
              child: Text(
                _formatDateHeader(dateKey),
                style: AppTypography.bodyBold,
              ),
            ),
            // 时间段网格 - 对标iOS LazyVGrid
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: daySlots
                  .map((slot) => _ActivityTimeSlotCard(
                        slot: slot,
                        isSelected: _selectedTimeSlotId == slot.id,
                        isDark: isDark,
                        onSelect: () {
                          if (slot.canSelect) {
                            setState(() => _selectedTimeSlotId = slot.id);
                            HapticFeedback.selectionClick();
                          }
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        );
      }).toList(),
    );
  }

  // ==================== 灵活时间选择视图 ====================

  Widget _buildFlexibleTimeSelection(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(
          icon: Icons.calendar_today,
          title: context.l10n.activityParticipateTime,
        ),
        const SizedBox(height: AppSpacing.md),

        // 灵活时间开关 - 对标iOS Toggle
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.backgroundDark
                : AppColors.backgroundLight,
            borderRadius: AppRadius.allLarge,
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.activityTimeFlexible,
                          style: AppTypography.bodyBold.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.l10n.activityTimeFlexibleMessage,
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    value: _isFlexibleTime,
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) =>
                        setState(() => _isFlexibleTime = val),
                  ),
                ],
              ),

              // 日期选择器 - 对标iOS DatePicker
              if (!_isFlexibleTime) ...[
                const Divider(height: 24),
                GestureDetector(
                  onTap: () => _showDatePicker(context),
                  child: Row(
                    children: [
                      const Icon(Icons.event, size: 20, color: AppColors.primary),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        context.l10n.activityPreferredDate,
                        style: AppTypography.body.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        DateFormat('yyyy-MM-dd').format(_preferredDate),
                        style: AppTypography.bodyBold.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.chevron_right,
                          size: 18, color: AppColors.textTertiaryLight),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _preferredDate = picked);
    }
  }

  // ==================== 底部申请按钮 ====================

  Widget _buildApplyButton(
      BuildContext context, ActivityState state, bool isDark) {
    final canApply = _hasTimeSlots
        ? _selectedTimeSlotId != null
        : true; // 非时间段模式总是可以申请

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
              horizontal: AppSpacing.md, vertical: 12),
          child: GestureDetector(
            onTap: (state.isSubmitting || !canApply) ? null : _onApply,
            child: AnimatedOpacity(
              opacity: canApply ? 1.0 : 0.5,
              duration: const Duration(milliseconds: 200),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  gradient: canApply
                      ? const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF0059B3)])
                      : null,
                  color: canApply ? null : AppColors.textTertiaryLight,
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
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.send,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.activityConfirmApply,
                              style: AppTypography.bodyBold
                                  .copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onApply() {
    HapticFeedback.selectionClick();

    if (_hasTimeSlots) {
      // 时间段模式 - 传 timeSlotId
      context.read<ActivityBloc>().add(ActivityApply(
            widget.activityId,
            timeSlotId: _selectedTimeSlotId,
          ));
    } else {
      // 灵活时间/日期模式
      context.read<ActivityBloc>().add(ActivityApply(
            widget.activityId,
            preferredDeadline: _isFlexibleTime
                ? null
                : _preferredDate.toUtc().toIso8601String(),
            isFlexibleTime: _isFlexibleTime,
          ));
    }
  }

  // ==================== 工具方法 ====================

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppSpacing.sm),
        Text(title, style: AppTypography.title3),
      ],
    );
  }

  /// 解析ISO 8601时间戳为本地日期key (yyyy-MM-dd)
  String _parseSlotDateKey(String isoDatetime) {
    try {
      final date = DateTime.parse(isoDatetime).toLocal();
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return isoDatetime.substring(0, 10);
    }
  }

  /// 格式化日期标题 - 对标iOS formatDate
  String _formatDateHeader(String dateKey) {
    try {
      final date = DateFormat('yyyy-MM-dd').parse(dateKey);
      final locale = Localizations.localeOf(context).languageCode;
      if (locale == 'zh') {
        return DateFormat('MM月dd日 EEE', 'zh_CN').format(date);
      }
      return DateFormat('MMM dd, EEE', 'en').format(date);
    } catch (_) {
      return dateKey;
    }
  }
}

// ==================== 时间段卡片 ====================
// 对标iOS ActivityTimeSlotCard

class _ActivityTimeSlotCard extends StatelessWidget {
  const _ActivityTimeSlotCard({
    required this.slot,
    required this.isSelected,
    required this.isDark,
    required this.onSelect,
  });

  final ServiceTimeSlot slot;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final canSelect = slot.canSelect;
    final opacity = canSelect ? 1.0 : 0.5;

    return GestureDetector(
      onTap: canSelect ? onSelect : null,
      child: AnimatedOpacity(
        opacity: opacity,
        duration: const Duration(milliseconds: 200),
        child: Container(
          width: (MediaQuery.of(context).size.width - 48 - AppSpacing.sm) / 2,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : slot.userHasApplied
                    ? (isDark
                        ? AppColors.textTertiaryDark.withValues(alpha: 0.1)
                        : AppColors.textTertiaryLight.withValues(alpha: 0.08))
                    : (isDark
                        ? AppColors.cardBackgroundDark
                        : AppColors.cardBackgroundLight),
            borderRadius: AppRadius.allMedium,
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : slot.userHasApplied
                      ? (isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight).withValues(alpha: 0.3)
                      : (isDark
                              ? AppColors.separatorDark
                              : AppColors.separatorLight)
                          .withValues(alpha: 0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 已申请标签
              if (slot.userHasApplied) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.textTertiaryDark.withValues(alpha: 0.2)
                        : AppColors.textTertiaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.serviceApplied,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              // 时间范围 - 对标iOS formatTimeRange
              Text(
                _formatTimeRange(slot.slotStartDatetime, slot.slotEndDatetime),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? AppColors.primary
                      : slot.userHasApplied
                          ? (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight)
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                ),
              ),
              const SizedBox(height: 4),
              // 人数 - 对标iOS currentParticipants/maxParticipants
              Text(
                context.l10n.activityPersonCount(
                    slot.currentParticipants, slot.maxParticipants),
                style: TextStyle(
                  fontSize: 11,
                  color: isSelected
                      ? AppColors.primary
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
              ),
              // 价格
              if (slot.displayPrice != null) ...[
                const SizedBox(height: 4),
                Text(
                  '£${slot.displayPrice!.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: slot.userHasApplied
                        ? AppColors.textTertiaryLight
                        : AppColors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// 格式化时间范围 HH:mm-HH:mm - 对标iOS formatTimeRange
  String _formatTimeRange(String startIso, String endIso) {
    try {
      final start = DateTime.parse(startIso).toLocal();
      final end = DateTime.parse(endIso).toLocal();
      final fmt = DateFormat('HH:mm');
      return '${fmt.format(start)}-${fmt.format(end)}';
    } catch (_) {
      return '';
    }
  }
}
