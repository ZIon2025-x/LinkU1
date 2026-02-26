import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/native_share.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/scroll_safe_tap.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import 'activity_price_widget.dart';
import '../bloc/task_expert_bloc.dart';

/// 任务达人详情页
/// 对标 iOS link2ur/TaskExpertDetailView.swift — 顶部渐变背景 + 浮动卡片
class TaskExpertDetailView extends StatelessWidget {
  const TaskExpertDetailView({
    super.key,
    required this.expertId,
  });

  final String expertId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
        activityRepository: context.read<ActivityRepository>(),
      )
        ..add(TaskExpertLoadDetail(expertId))
        ..add(TaskExpertLoadExpertReviews(expertId)),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: Colors.white,
          actions: [
            BlocBuilder<TaskExpertBloc, TaskExpertState>(
              buildWhen: (previous, current) =>
                  previous.selectedExpert != current.selectedExpert,
              builder: (context, state) {
                return IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () async {
                    final expert = state.selectedExpert;
                    if (expert != null) {
                      final name = expert.displayNameWith(context.l10n);
                      final imageUrl = expert.avatar;
                      final shareFiles = await NativeShare.fileFromFirstImageUrl(imageUrl);
                      await NativeShare.share(
                        title: context.l10n.taskExpertShareTitle(name),
                        description: context.l10n.taskExpertShareText(name),
                        url: 'https://link2ur.com/task-experts/${expert.id}',
                        files: shareFiles,
                      );
                    }
                  },
                );
              },
            ),
          ],
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: ResponsiveUtils.detailMaxWidth(context)),
            child: BlocBuilder<TaskExpertBloc, TaskExpertState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.selectedExpert != current.selectedExpert ||
                  previous.reviews != current.reviews ||
                  previous.isLoadingReviews != current.isLoadingReviews ||
                  previous.services != current.services ||
                  previous.expertActivities != current.expertActivities ||
                  previous.isLoadingExpertActivities != current.isLoadingExpertActivities,
              builder: (context, state) {
                if (state.status == TaskExpertStatus.loading &&
                    state.selectedExpert == null) {
                  return const LoadingView();
                }

                if (state.status == TaskExpertStatus.error &&
                    state.selectedExpert == null) {
                  return ErrorStateView.loadFailed(
                    message: state.errorMessage ??
                        context.l10n.taskExpertLoadFailed,
                    onRetry: () {
                      context
                          .read<TaskExpertBloc>()
                          .add(TaskExpertLoadDetail(expertId));
                    },
                  );
                }

                final expert = state.selectedExpert;
                if (expert == null) {
                  return EmptyStateView.noData(
                    context,
                    title: context.l10n.taskExpertExpertNotExist,
                    description: context.l10n.taskExpertExpertNotExistDesc,
                  );
                }

                return _DetailBody(
                  expert: expert,
                  reviews: state.reviews,
                  isLoadingReviews: state.isLoadingReviews,
                  services: state.services,
                  expertActivities: state.expertActivities,
                  isLoadingExpertActivities: state.isLoadingExpertActivities,
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================
// Body — ScrollView with header background + floating card
// =============================================================

class _DetailBody extends StatelessWidget {
  const _DetailBody({
    required this.expert,
    required this.reviews,
    required this.isLoadingReviews,
    required this.services,
    required this.expertActivities,
    required this.isLoadingExpertActivities,
  });

  final TaskExpert expert;
  final List<Map<String, dynamic>> reviews;
  final bool isLoadingReviews;
  final List<TaskExpertService> services;
  final List<Activity> expertActivities;
  final bool isLoadingExpertActivities;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. 顶部渐变背景（对标iOS topHeaderBackground）
          const _TopHeaderBackground(),

          // 2. 浮动个人信息卡片（对标iOS expertProfileCard, padding.top = -60）
          Transform.translate(
            offset: const Offset(0, -60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: _ProfileCard(expert: expert),
            ),
          ),

          // 以下内容上移 -60 的间距补偿
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 3. 专业领域标签
                if (expert.displaySpecialties(locale).isNotEmpty) ...[
                  _SpecialtiesSection(
                      specialties: expert.displaySpecialties(locale)),
                  const SizedBox(height: 24),
                ],

                // 4. 达人活动（方案 A：仅显示开放中，无则隐藏）
                if (!(expertActivities.isEmpty && !isLoadingExpertActivities))
                  _ExpertActivitiesSection(
                    activities: expertActivities,
                    isLoading: isLoadingExpertActivities,
                  ),
                if (!(expertActivities.isEmpty && !isLoadingExpertActivities))
                  const SizedBox(height: 24),

                // 5. 评价
                _ReviewsSection(
                  reviews: reviews,
                  isLoading: isLoadingReviews,
                ),
                const SizedBox(height: 24),

                // 6. 服务菜单（方案B：服务卡片内显示活动关联提示）
                _ServicesSection(
                  services: services,
                  expertActivities: expertActivities,
                ),

                SizedBox(height: MediaQuery.paddingOf(context).bottom + 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Top Header Background — 对标iOS topHeaderBackground()
// 180px primary渐变 + 两个装饰圆
// =============================================================

class _TopHeaderBackground extends StatelessWidget {
  const _TopHeaderBackground();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 180 + MediaQuery.paddingOf(context).top,
      width: double.infinity,
      child: Stack(
        children: [
          // 渐变背景
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // 装饰圆 1（右上）
          Positioned(
            right: -25,
            top: -25,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
          ),
          // 装饰圆 2（左下）
          Positioned(
            left: -60,
            bottom: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// Profile Card — 对标iOS expertProfileCard
// 白色卡片，头像带白色边框+阴影，名称+认证+简介+统计
// =============================================================

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.expert});

  final TaskExpert expert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // 头像（对标iOS: 90 size, white stroke, shadow）
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: AvatarView(
              imageUrl: expert.avatar,
              name: expert.displayNameWith(context.l10n),
              size: 90,
            ),
          ),
          const SizedBox(height: 20),

          // 名字 + 认证徽章（对标iOS: checkmark.seal.fill）
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  expert.displayNameWith(context.l10n),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.verified,
                size: 18,
                color: AppColors.primary,
              ),
            ],
          ),

          // 简介（对标iOS: font 14, textSecondary, centered, lineLimit 3）
          if (expert.displayBio(locale)?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                expert.displayBio(locale)!,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          // 统计网格（对标iOS: HStack(spacing:0) + divider）
          const SizedBox(height: 16),
          IntrinsicHeight(
            child: Row(
              children: [
                Expanded(
                  child: _StatItem(
                    icon: Icons.star,
                    iconColor: Colors.orange,
                    value: expert.ratingDisplay,
                    label: context.l10n.taskExpertRating,
                  ),
                ),
                _verticalDivider(isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons.check_circle,
                    iconColor: AppColors.primary,
                    value: '${expert.completedTasks}',
                    label: context.l10n.taskExpertCompletedOrders,
                  ),
                ),
                _verticalDivider(isDark),
                Expanded(
                  child: _StatItem(
                    icon: Icons.bar_chart,
                    iconColor: Colors.green,
                    value: '${expert.totalServices}',
                    label: context.l10n.taskExpertServices,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider(bool isDark) {
    return Container(
      width: 1,
      height: 24,
      color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
    );
  }
}

/// 统计项（对标iOS statItem: icon + value + label）
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// Specialties — 胶囊标签（对标iOS infoSection + FlowLayout）
// =============================================================

class _SpecialtiesSection extends StatelessWidget {
  const _SpecialtiesSection({required this.specialties});

  final List<String> specialties;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(title: context.l10n.taskExpertSpecialties),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: specialties
              .map((s) => Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.primary
                          .withValues(alpha: isDark ? 0.15 : 0.12),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ))
              .toList(),
        ),
      ],
    );
  }
}

// =============================================================
// 达人活动 — 方案 A：独立活动卡片区域
// =============================================================

class _ExpertActivitiesSection extends StatelessWidget {
  const _ExpertActivitiesSection({
    required this.activities,
    required this.isLoading,
  });

  final List<Activity> activities;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
            title: context.l10n.taskSourceExpertActivity),
        const SizedBox(height: AppSpacing.md),
        if (isLoading && activities.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppColors.primary,
                ),
              ),
            ),
          )
        else if (activities.isEmpty)
          const SizedBox.shrink()
        else
          ...activities.map(
            (activity) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _ExpertActivityCard(activity: activity),
            ),
          ),
      ],
    );
  }
}

/// 达人活动卡片：封面 + 标题 + 时间/人数/价格，点击进入活动详情
class _ExpertActivityCard extends StatelessWidget {
  const _ExpertActivityCard({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ScrollSafeTap(
      onTap: () {
        AppHaptics.selection();
        context.push('/activities/${activity.id}');
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
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
            if (activity.firstImage != null)
              AsyncImageView(
                imageUrl: activity.firstImage!,
                width: double.infinity,
                height: 160,
              )
            else
              Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.12),
                      AppColors.primary.withValues(alpha: 0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  Icons.photo_library_outlined,
                  size: 40,
                  color: AppColors.primary.withValues(alpha: 0.4),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.displayTitle(Localizations.localeOf(context)),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (activity.hasTimeSlots)
                        Text(
                          context.l10n.activityMultipleTimeSlots,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        )
                      else if (activity.deadline != null)
                        Text(
                          DateFormat('MM/dd HH:mm')
                              .format(activity.deadline!.toLocal()),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.people_outlined,
                        size: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const Spacer(),
                      ActivityPriceWidget(activity: activity),
                      Icon(
                        Icons.chevron_right,
                        size: 20,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
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
}

// =============================================================
// Reviews — 卡片列表（对标iOS reviewsCard）
// =============================================================

class _ReviewsSection extends StatelessWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.isLoading,
  });

  final List<Map<String, dynamic>> reviews;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SectionHeader(title: context.l10n.taskExpertReviews),
              const Spacer(),
              if (reviews.isNotEmpty)
                Text(
                  context.l10n.taskExpertReviewsCount(reviews.length),
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading && reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: LoadingView(),
              ),
            )
          else if (reviews.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  context.l10n.taskExpertNoReviews,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          else
            ...reviews.map((review) => _ReviewRow(review: review)),
        ],
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.grey.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 星级 + 日期
          Row(
            children: [
              ...List.generate(5, (i) {
                final star = i + 1;
                final fullStars = rating.floor();
                final hasHalf = rating - fullStars >= 0.5;
                IconData icon;
                Color color;
                if (star <= fullStars) {
                  icon = Icons.star;
                  color = AppColors.gold;
                } else if (star == fullStars + 1 && hasHalf) {
                  icon = Icons.star_half;
                  color = AppColors.gold;
                } else {
                  icon = Icons.star_border;
                  color = isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight;
                }
                return Icon(icon, size: 14, color: color);
              }),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _formatTime(createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd').format(date);
    } catch (_) {
      return dateStr;
    }
  }
}

// =============================================================
// Services — 对标iOS ServiceCard (100x100)
// =============================================================

class _ServicesSection extends StatelessWidget {
  const _ServicesSection({
    required this.services,
    required this.expertActivities,
  });

  final List<TaskExpertService> services;
  final List<Activity> expertActivities;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _SectionHeader(title: context.l10n.taskExpertServiceMenu),
            const Spacer(),
            Text(
              context.l10n.taskExpertServicesCount(services.length),
              style: TextStyle(
                fontSize: 13,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        if (services.isEmpty)
          _buildEmptyServices(context, isDark)
        else
          ...services.map(
            (service) {
              final relatedCount = expertActivities
                  .where((a) => a.expertServiceId == service.id)
                  .length;
              return _ServiceCard(
                service: service,
                relatedActivityCount: relatedCount,
                onTap: () => context.goToServiceDetail(service.id),
              );
            },
          ),
      ],
    );
  }

  Widget _buildEmptyServices(BuildContext context, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 48,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(height: 12),
          Text(
            context.l10n.taskExpertNoServices,
            style: TextStyle(
              fontSize: 14,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// 服务卡片（对标iOS ServiceCard: 100x100图 + semibold title + caption + price + chevron）
/// 方案B：若有关联活动，显示「N 个相关活动可报名」提示
class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.relatedActivityCount,
    required this.onTap,
  });

  final TaskExpertService service;
  final int relatedActivityCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 100x100 圆角图片（对标iOS: 100x100）
              if (service.firstImage != null)
                ClipRRect(
                  borderRadius: AppRadius.allMedium,
                  child: AsyncImageView(
                    imageUrl: service.firstImage,
                    width: 100,
                    height: 100,
                    errorWidget: _buildPlaceholder(isDark),
                  ),
                )
              else
                _buildPlaceholder(isDark),
              const SizedBox(width: 16),
              // 服务信息
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题（对标iOS: .semibold, size 16, lineLimit 2）
                    Text(
                      service.serviceName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (service.description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        service.description,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    // 方案B：关联活动提示
                    if (relatedActivityCount > 0) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_available,
                              size: 14,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              context.l10n
                                  .taskExpertRelatedActivitiesAvailable(
                                      relatedActivityCount),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Spacer(),
                    // 价格 + chevron（对标iOS: size 18, bold, primary）
                    Row(
                      children: [
                        Text(
                          service.priceDisplay,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right,
                          size: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder(bool isDark) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.primary.withValues(alpha: 0.06),
        borderRadius: AppRadius.allMedium,
      ),
      child: Icon(
        Icons.photo,
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
        size: 24,
      ),
    );
  }
}

// =============================================================
// Shared: Section Header — 对标iOS竖线 + 标题
// =============================================================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
      ],
    );
  }
}
