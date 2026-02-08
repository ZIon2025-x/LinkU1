import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/buttons.dart';
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
      )..add(TaskExpertLoadDetail(expertId)),
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
        body: BlocBuilder<TaskExpertBloc, TaskExpertState>(
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

                  // Services section
                  Padding(
                    padding: AppSpacing.allMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.taskExpertProvidedServices,
                          style: AppTypography.title2.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        AppSpacing.vMd,
                        if (state.services.isEmpty)
                          EmptyStateView.noData(
                            title: context.l10n.taskExpertNoServices,
                            description: context.l10n.taskExpertNoServicesDesc,
                          )
                        else
                          ...state.services.map(
                            (service) => _ServiceItem(
                              service: service,
                              onApply: () {
                                context.read<TaskExpertBloc>().add(
                                      TaskExpertApplyService(service.id),
                                    );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),

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
          // Avatar
          CircleAvatar(
            radius: 50,
            backgroundColor: AppColors.primary.withValues(alpha: 0.2),
            backgroundImage:
                expert.avatar != null ? NetworkImage(expert.avatar!) : null,
            child: expert.avatar == null
                ? const Icon(Icons.person, color: AppColors.primary, size: 50)
                : null,
          ),
          AppSpacing.vMd,
          // Name
          Text(
            expert.displayName,
            style: AppTypography.title.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
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
    required this.onApply,
  });

  final TaskExpertService service;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Service image or icon
          if (service.firstImage != null)
            AsyncImageView(
              imageUrl: service.firstImage,
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              borderRadius: AppRadius.allSmall,
              errorWidget: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allSmall,
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.allSmall,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  service.serviceName,
                  style: AppTypography.title3.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
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
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      service.priceDisplay,
                      style: AppTypography.priceSmall.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    if (service.viewCount > 0) ...[
                      const SizedBox(width: 12),
                      Icon(
                        Icons.visibility_outlined,
                        size: 14,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${service.viewCount}',
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // Apply button
          BlocBuilder<TaskExpertBloc, TaskExpertState>(
            builder: (context, state) {
              final isSubmitting = state.isSubmitting &&
                  state.services.any((s) => s.id == service.id);
              
              if (service.hasApplied) {
                return SmallActionButton(
                  text: service.userApplicationStatus == 'accepted'
                      ? context.l10n.taskExpertAccepted
                      : service.userApplicationStatus == 'rejected'
                          ? context.l10n.taskExpertRejected
                          : context.l10n.taskExpertAppliedStatus,
                  filled: true,
                  color: service.userApplicationStatus == 'accepted'
                      ? AppColors.success
                      : AppColors.textTertiaryLight,
                );
              }

              return SmallActionButton(
                text: context.l10n.taskExpertBook,
                onPressed: isSubmitting ? null : onApply,
                filled: true,
                color: AppColors.primary,
              );
            },
          ),
        ],
      ),
    );
  }
}
