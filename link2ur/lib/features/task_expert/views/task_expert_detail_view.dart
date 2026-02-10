import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/models/task_expert.dart';
import '../bloc/task_expert_bloc.dart';

/// 任务达人详情页
/// 参考iOS TaskExpertDetailView.swift
class TaskExpertDetailView extends StatelessWidget {
  const TaskExpertDetailView({
    super.key,
    required this.expertId,
  });

  final int expertId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )
        ..add(TaskExpertLoadDetail(expertId))
        ..add(TaskExpertLoadExpertReviews(expertId.toString())),
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<TaskExpertBloc, TaskExpertState>(
            builder: (context, state) {
              return Text(
                state.selectedExpert?.displayName ?? context.l10n.taskExpertDetailTitle,
              );
            },
          ),
          actions: [
            BlocBuilder<TaskExpertBloc, TaskExpertState>(
              builder: (context, state) {
                return IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {
                    final expert = state.selectedExpert;
                    if (expert != null) {
                      SharePlus.instance.share(
                        ShareParams(
                          text: '${context.l10n.taskExpertShareText(expert.displayName)}\nhttps://link2ur.com/task-experts/${expert.id}',
                          subject: context.l10n.taskExpertShareTitle(expert.displayName),
                        ),
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
            constraints: BoxConstraints(maxWidth: ResponsiveUtils.detailMaxWidth(context)),
            child: BlocBuilder<TaskExpertBloc, TaskExpertState>(
          builder: (context, state) {
            // Loading state
            if (state.status == TaskExpertStatus.loading &&
                state.selectedExpert == null) {
              return const LoadingView();
            }

            // Error state
            if (state.status == TaskExpertStatus.error &&
                state.selectedExpert == null) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? context.l10n.taskExpertLoadFailed,
                onRetry: () {
                  context.read<TaskExpertBloc>().add(
                        TaskExpertLoadDetail(expertId),
                      );
                },
              );
            }

            final expert = state.selectedExpert;
            if (expert == null) {
              return EmptyStateView.noData(
                title: context.l10n.taskExpertExpertNotExist,
                description: context.l10n.taskExpertExpertNotExistDesc,
              );
            }

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile header
                  _ProfileHeader(expert: expert),
                  
                  // Stats section
                  Padding(
                    padding: AppSpacing.allMd,
                    child: Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            value: expert.ratingDisplay,
                            label: context.l10n.taskExpertRating,
                            icon: Icons.star,
                            iconColor: AppColors.gold,
                          ),
                        ),
                        AppSpacing.hMd,
                        Expanded(
                          child: StatCard(
                            value: '${expert.completedTasks}',
                            label: context.l10n.taskExpertCompletedOrders,
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                        AppSpacing.hMd,
                        Expanded(
                          child: StatCard(
                            value: '${expert.totalServices}',
                            label: context.l10n.taskExpertServices,
                            icon: Icons.work_outline,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bio section
                  if (expert.bio != null && expert.bio!.isNotEmpty)
                    Padding(
                      padding: AppSpacing.allMd,
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.l10n.taskExpertBio,
                              style: AppTypography.title3.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            AppSpacing.vSm,
                            Text(
                              expert.bio!,
                              style: AppTypography.body,
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Reviews section
                  Padding(
                    padding: AppSpacing.allMd,
                    child: _ReviewsSection(
                      reviews: state.reviews,
                      isLoading: state.isLoadingReviews,
                    ),
                  ),

                  // Services section header
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    child: Row(
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
                          context.l10n.taskExpertServiceMenu,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          context.l10n.taskExpertServicesCount(
                              state.services.length),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppSpacing.vMd,

                  // Services list
                  Padding(
                    padding: AppSpacing.allMd,
                    child: Column(
                      children: [
                        if (state.services.isEmpty)
                          EmptyStateView.noData(
                            title: context.l10n.taskExpertNoServices,
                            description: context.l10n.taskExpertNoServicesDesc,
                          )
                        else
                          ...state.services.map(
                            (service) => _ServiceItem(
                              service: service,
                              onTap: () =>
                                  context.goToServiceDetail(service.id),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action message snackbar
                  BlocListener<TaskExpertBloc, TaskExpertState>(
                    listenWhen: (previous, current) =>
                        previous.actionMessage != current.actionMessage,
                    listener: (context, state) {
                      if (state.actionMessage != null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(state.actionMessage!),
                            backgroundColor: state.actionMessage!.contains('失败')
                                ? AppColors.error
                                : AppColors.success,
                          ),
                        );
                      }
                    },
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            );
          },
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.expert});

  final TaskExpert expert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.allXl,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          // Avatar（使用 AvatarView 正确处理相对路径）
          AvatarView(
            imageUrl: expert.avatar,
            name: expert.displayName,
            size: 100,
          ),
          AppSpacing.vMd,
          // Name with verification badge
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                expert.displayName,
                style: AppTypography.title.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
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
          AppSpacing.vSm,
          // Rating and stats
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, size: 16, color: AppColors.gold),
              const SizedBox(width: 4),
              Text(
                expert.ratingDisplay,
                style: AppTypography.subheadline.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                context.l10n.leaderboardCompletedCount(expert.completedTasks),
                style: AppTypography.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceItem extends StatelessWidget {
  const _ServiceItem({
    required this.service,
    required this.onTap,
  });

  final TaskExpertService service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        margin: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Service image or icon
            if (service.firstImage != null)
              AsyncImageView(
                imageUrl: service.firstImage,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                borderRadius: AppRadius.allMedium,
                errorWidget: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: AppRadius.allMedium,
                  ),
                  child: const Icon(
                    Icons.work_outline,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              )
            else
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allMedium,
                ),
                child: const Icon(
                  Icons.work_outline,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            AppSpacing.hMd,
            // Service info
            Expanded(
              child: SizedBox(
                height: 100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.serviceName,
                      style: AppTypography.title3.copyWith(
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
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const Spacer(),
                    // 价格 + 箭头
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
                          size: 16,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================
// 评价区域 (对标iOS reviewsCard)
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
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
          // 标题行
          Row(
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
                context.l10n.taskExpertReviews,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (reviews.isNotEmpty)
                Text(
                  context.l10n.taskExpertReviewsCount(reviews.length),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiaryLight,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoading && reviews.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: CircularProgressIndicator(),
              ),
            )
          else if (reviews.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  context.l10n.taskExpertNoReviews,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          else
            ...reviews.map((review) => _ExpertReviewRow(review: review)),
        ],
      ),
    );
  }
}

class _ExpertReviewRow extends StatelessWidget {
  const _ExpertReviewRow({required this.review});

  final Map<String, dynamic> review;

  @override
  Widget build(BuildContext context) {
    final rating = (review['rating'] as num?)?.toDouble() ?? 0;
    final comment = review['comment'] as String?;
    final createdAt = review['created_at'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // 星级
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
                  color = AppColors.textTertiaryLight;
                }
                return Icon(icon, size: 14, color: color);
              }),
              const Spacer(),
              if (createdAt != null)
                Text(
                  _formatTime(createdAt),
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiaryLight,
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          if (comment != null && comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(fontSize: 14, height: 1.5),
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
