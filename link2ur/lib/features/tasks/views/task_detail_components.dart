import 'package:flutter/material.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/bouncing_widget.dart';
import '../../../core/widgets/animated_star_rating.dart';
import '../../../core/widgets/review_bottom_sheet.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_application.dart';
import '../../../data/models/review.dart';
import '../../../data/models/refund_request.dart';
import '../bloc/task_detail_bloc.dart';

// ============================================================
// 角色辅助：根据任务来源返回角色称谓
// ============================================================

/// 获取发布者角色称谓
String getPosterRoleText(Task task, BuildContext context) {
  switch (task.taskSource) {
    case AppConstants.taskSourceFleaMarket:
      return context.l10n.taskDetailBuyer;
    case AppConstants.taskSourceExpertService:
      return context.l10n.taskDetailPublisher; // 用户
    case AppConstants.taskSourceExpertActivity:
      return context.l10n.taskDetailPublisher; // 参与者
    default:
      return context.l10n.taskDetailPublisher;
  }
}

/// 获取接单者角色称谓
String getTakerRoleText(Task task, BuildContext context) {
  switch (task.taskSource) {
    case AppConstants.taskSourceFleaMarket:
      return context.l10n.taskDetailSeller;
    case AppConstants.taskSourceExpertService:
      return context.l10n.taskSourceExpertService; // 达人
    case AppConstants.taskSourceExpertActivity:
      return context.l10n.taskSourceExpertActivity; // 组织者
    default:
      return context.l10n.actionsContactRecipient;
  }
}

/// 获取联系按钮文本
String getContactButtonText(
    Task task, bool isPoster, BuildContext context) {
  if (isPoster) {
    // 发布者联系接单者
    return task.isFleaMarketTask
        ? context.l10n.taskDetailSeller
        : context.l10n.actionsContactRecipient;
  } else {
    // 接单者联系发布者
    return task.isFleaMarketTask
        ? context.l10n.taskDetailBuyer
        : context.l10n.actionsContactPoster;
  }
}

// ============================================================
// 任务来源标签
// ============================================================

class TaskSourceBadge extends StatelessWidget {
  const TaskSourceBadge({super.key, required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    if (!task.hasSpecialSource) return const SizedBox.shrink();

    final (icon, label, color) = _sourceInfo(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.allPill,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  (IconData, String, Color) _sourceInfo(BuildContext context) {
    switch (task.taskSource) {
      case AppConstants.taskSourceFleaMarket:
        return (
          Icons.shopping_bag,
          context.l10n.taskSourceFleaMarket,
          AppColors.warning
        );
      case AppConstants.taskSourceExpertService:
        return (
          Icons.star,
          context.l10n.taskSourceExpertService,
          AppColors.primary
        );
      case AppConstants.taskSourceExpertActivity:
        return (
          Icons.groups,
          context.l10n.taskSourceExpertActivity,
          AppColors.pendingPurple
        );
      default:
        return (Icons.tag, context.l10n.taskSourceNormal, AppColors.primary);
    }
  }
}

// ============================================================
// 任务等级标签
// ============================================================

class TaskLevelBadge extends StatelessWidget {
  const TaskLevelBadge({super.key, required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    if (!task.hasSpecialLevel) return const SizedBox.shrink();

    final isVip = task.isVipTask;
    final color = isVip ? AppColors.busy : AppColors.pendingPurple;
    final icon = isVip ? Icons.star : Icons.local_fire_department;
    final text =
        isVip ? context.l10n.taskDetailVipTask : context.l10n.taskDetailSuperTask;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
        ),
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            text,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 发布者提示卡片 (isPoster && open)
// ============================================================

class PosterInfoCard extends StatelessWidget {
  const PosterInfoCard({super.key, required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight.withValues(alpha: 0.15),
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 24, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.taskDetailYourTask,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.taskDetailManageTask,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 确认截止提醒卡片 (pendingConfirmation && isPoster)
// ============================================================

class ConfirmationReminderCard extends StatelessWidget {
  const ConfirmationReminderCard({
    super.key,
    required this.deadline,
    required this.isDark,
    required this.onConfirm,
  });

  final String deadline;
  final bool isDark;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule, size: 20, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                context.l10n.taskDetailPleaseConfirmComplete,
                style: AppTypography.bodyBold.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.taskDetailAutoConfirmSoon,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: context.l10n.taskDetailConfirmNow,
              onPressed: onConfirm,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 等待确认卡片 (pendingConfirmation && isTaker)
// ============================================================

class WaitingConfirmationCard extends StatelessWidget {
  const WaitingConfirmationCard({super.key, required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.hourglass_top, size: 24, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.taskDetailWaitingPosterConfirm,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.taskDetailAutoConfirmOnExpiry,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 完成证据卡片
// ============================================================

class CompletionEvidenceCard extends StatelessWidget {
  const CompletionEvidenceCard({
    super.key,
    required this.evidence,
    required this.isDark,
  });

  final String evidence;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
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
          Row(
            children: [
              const Icon(Icons.verified, size: 18, color: AppColors.success),
              const SizedBox(width: 8),
              Text(
                context.l10n.taskDetailTaskCompletionEvidence,
                style: AppTypography.title3.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            evidence,
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 申请状态卡片 (非发布者已申请时)
// ============================================================

class ApplicationStatusCard extends StatelessWidget {
  const ApplicationStatusCard({
    super.key,
    required this.task,
    this.application,
    required this.isDark,
  });

  final Task task;
  final TaskApplication? application;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final appStatus = application?.status ?? task.userApplicationStatus;
    if (appStatus == null) return const SizedBox.shrink();

    final (color, icon, title, desc) = _statusInfo(appStatus, context);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: AppRadius.allMedium,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.title3.copyWith(color: color),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                ),
                if (application?.message != null &&
                    application!.message!.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.taskDetailMessageLabel(application!.message!),
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  (Color, IconData, String, String) _statusInfo(
      String status, BuildContext context) {
    switch (status) {
      case 'pending':
        return (
          AppColors.warning,
          Icons.access_time_filled,
          context.l10n.taskDetailWaitingReview,
          context.l10n.taskDetailApplicationSuccess,
        );
      case 'approved':
        if (task.status == AppConstants.taskStatusPendingPayment) {
          return (
            AppColors.warning,
            Icons.credit_card,
            context.l10n.taskStatusPendingPayment,
            context.l10n.taskDetailPendingPaymentMessage,
          );
        } else if (task.status ==
            AppConstants.taskStatusPendingConfirmation) {
          return (
            AppColors.pendingPurple,
            Icons.verified,
            context.l10n.taskDetailTaskCompleted,
            context.l10n.taskDetailTaskCompletedMessage,
          );
        }
        return (
          AppColors.success,
          Icons.check_circle,
          context.l10n.taskDetailApplicationApproved,
          context.l10n.taskDetailApplicationApprovedMessage,
        );
      case 'rejected':
        return (
          AppColors.error,
          Icons.cancel,
          context.l10n.taskDetailApplicationRejected,
          context.l10n.taskDetailApplicationRejectedMessage,
        );
      default:
        return (
          AppColors.textSecondaryLight,
          Icons.help,
          context.l10n.taskDetailUnknownStatus,
          '',
        );
    }
  }
}

// ============================================================
// 申请列表 (isPoster && open)
// ============================================================

class ApplicationsListView extends StatelessWidget {
  const ApplicationsListView({
    super.key,
    required this.applications,
    required this.isLoading,
    required this.isDark,
  });

  final List<TaskApplication> applications;
  final bool isLoading;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
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
          Row(
            children: [
              const Icon(Icons.people, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                context.l10n
                    .taskDetailApplicantsList(applications.length),
                style: AppTypography.title3.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xl),
                child: LoadingView(),
              ),
            )
          else if (applications.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 40,
                      color: AppColors.textTertiaryLight
                          .withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.taskDetailNoApplicants,
                      style: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...applications
                .map((app) => _ApplicationItem(
                      application: app,
                      isDark: isDark,
                    ))
                ,
        ],
      ),
    );
  }
}

class _ApplicationItem extends StatelessWidget {
  const _ApplicationItem({
    required this.application,
    required this.isDark,
  });

  final TaskApplication application;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final statusColor = application.isPending
        ? AppColors.warning
        : application.isApproved
            ? AppColors.success
            : AppColors.error;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.backgroundDark
              : AppColors.backgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarView(
                  imageUrl: application.applicantAvatar,
                  name: application.applicantName,
                  size: 40,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        application.applicantName ??
                            context.l10n.taskDetailUnknownUser,
                        style: AppTypography.bodyBold.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      if (application.createdAt != null)
                        Text(
                          application.createdAt!,
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: AppRadius.allPill,
                  ),
                  child: Text(
                    _statusText(context),
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
            if (application.message != null &&
                application.message!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: (isDark
                          ? AppColors.cardBackgroundDark
                          : AppColors.cardBackgroundLight)
                      .withValues(alpha: 0.7),
                  borderRadius: AppRadius.allSmall,
                ),
                child: Text(
                  application.message!,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
            // 操作按钮 (仅 pending 时显示)
            if (application.isPending) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  _ActionCircleButton(
                    icon: Icons.check_circle,
                    color: AppColors.success,
                    onTap: () {
                      AppHaptics.medium();
                      context.read<TaskDetailBloc>().add(
                            TaskDetailAcceptApplicant(application.id),
                          );
                    },
                  ),
                  const SizedBox(width: 16),
                  _ActionCircleButton(
                    icon: Icons.cancel,
                    color: AppColors.error,
                    onTap: () {
                      AppHaptics.medium();
                      context.read<TaskDetailBloc>().add(
                            TaskDetailRejectApplicant(application.id),
                          );
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _statusText(BuildContext context) {
    if (application.isPending) return context.l10n.taskDetailPendingReview;
    if (application.isApproved) return context.l10n.taskDetailApproved;
    if (application.isRejected) return context.l10n.taskDetailRejected;
    return context.l10n.taskDetailUnknown;
  }
}

class _ActionCircleButton extends StatelessWidget {
  const _ActionCircleButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncingWidget(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, size: 24, color: Colors.white),
      ),
    );
  }
}

// ============================================================
// 评价区域
// ============================================================

class TaskReviewsSection extends StatelessWidget {
  const TaskReviewsSection({
    super.key,
    required this.reviews,
    required this.isDark,
  });

  final List<Review> reviews;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return _buildReviewsSection(context);
  }

  Widget _buildReviewsSection(BuildContext context) {
    if (reviews.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
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
          Row(
            children: [
              const Icon(Icons.rate_review, size: 18, color: AppColors.warning),
              const SizedBox(width: 8),
              Text(
                context.l10n.taskDetailMyReviews,
                style: AppTypography.title3.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ...reviews.map((review) => _ReviewItem(
                review: review,
                isDark: isDark,
              )),
        ],
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  const _ReviewItem({required this.review, required this.isDark});
  final Review review;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedStarRating(
                rating: review.rating,
                size: 14,
                spacing: 2,
                allowHalfRating: true,
              ),
              if (review.createdAt != null) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  DateFormatter.formatRelative(
                    review.createdAt!,
                    l10n: context.l10n,
                  ),
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              review.comment!,
              style: AppTypography.body.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// 退款状态卡片
// ============================================================

class RefundStatusCard extends StatelessWidget {
  const RefundStatusCard({
    super.key,
    required this.refundRequest,
    required this.isDark,
  });

  final RefundRequest refundRequest;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.allMedium,
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _statusText(context),
                style: AppTypography.bodyBold.copyWith(color: color),
              ),
              const Spacer(),
              if (refundRequest.refundAmount != null)
                Text(
                  '£${refundRequest.refundAmount!.toStringAsFixed(2)}',
                  style: AppTypography.title3.copyWith(color: color),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            refundRequest.reason,
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Color _statusColor() {
    switch (refundRequest.status) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.primary;
      case 'approved':
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _statusText(BuildContext context) {
    switch (refundRequest.status) {
      case 'pending':
        return context.l10n.refundStatusPending;
      case 'processing':
        return context.l10n.refundStatusProcessing;
      case 'approved':
        return context.l10n.refundStatusApproved;
      case 'rejected':
        return context.l10n.refundStatusRejected;
      case 'completed':
        return context.l10n.refundStatusCompleted;
      case 'cancelled':
        return context.l10n.refundStatusCancelled;
      default:
        return context.l10n.refundStatusUnknown;
    }
  }
}

// ============================================================
// 操作按钮区域 — 7 个条件按钮块
// ============================================================

class TaskActionButtonsView extends StatelessWidget {
  const TaskActionButtonsView({
    super.key,
    required this.task,
    required this.isPoster,
    required this.isTaker,
    required this.isDark,
    required this.state,
  });

  final Task task;
  final bool isPoster;
  final bool isTaker;
  final bool isDark;
  final TaskDetailState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1. 发布者支付按钮
        _buildPosterPaymentButton(context),
        // 2. 申请者按钮 (非发布者)
        _buildApplicantButtons(context),
        // 3. 接单者完成按钮
        _buildTakerCompleteButton(context),
        // 4. 发布者确认 + 退款
        _buildPosterConfirmationButtons(context),
        // 4b. 接单者退款状态 + 反驳入口
        _buildTakerRefundSection(context),
        // 5. 沟通按钮
        _buildCommunicationButton(context),
        // 6. 评价按钮
        _buildReviewButton(context),
        // 7. 取消按钮
        _buildCancelButton(context),
      ],
    );
  }

  // 1. 发布者支付按钮
  Widget _buildPosterPaymentButton(BuildContext context) {
    if (!isPoster ||
        task.status != AppConstants.taskStatusPendingPayment) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimaryButton(
        text: context.l10n.taskDetailPlatformServiceFee,
        icon: Icons.credit_card,
        onPressed: task.isPaymentExpired
            ? null
            : () {
                // TODO: 跳转支付页面
              },
      ),
    );
  }

  // 2. 申请者按钮 (非发布者)
  Widget _buildApplicantButtons(BuildContext context) {
    if (isPoster) return const SizedBox.shrink();

    // 有申请记录
    final userApp = state.userApplication;
    if (userApp != null) {
      if (userApp.isPending) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PrimaryButton(
            text: context.l10n.taskDetailWaitingPosterConfirm,
            icon: Icons.access_time,
            onPressed: null,
          ),
        );
      }
      // approved/rejected 由 ApplicationStatusCard 在内容区显示
      return const SizedBox.shrink();
    }

    // 详情接口返回 hasApplied
    if (task.hasApplied) {
      if (task.userApplicationStatus == 'pending') {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PrimaryButton(
            text: context.l10n.taskDetailWaitingPosterConfirm,
            icon: Icons.access_time,
            onPressed: null,
          ),
        );
      }
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: PrimaryButton(
          text: context.l10n.taskDetailAlreadyApplied,
          icon: Icons.check_circle,
          onPressed: null,
        ),
      );
    }

    // 未申请 + 任务 open + 无接单者 → 弹出申请框（留言 + 议价 + 金额）
    if (task.status == AppConstants.taskStatusOpen &&
        task.takerId == null) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: PrimaryButton(
          text: context.l10n.actionsApplyForTask,
          icon: Icons.pan_tool,
          isLoading: state.isSubmitting,
          onPressed: state.isSubmitting
              ? null
              : () {
                  final bloc = context.read<TaskDetailBloc>();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (ctx) => BlocProvider.value(
                      value: bloc,
                      child: BlocListener<TaskDetailBloc, TaskDetailState>(
                        listenWhen: (prev, cur) =>
                            cur.actionMessage == 'application_submitted',
                        listener: (c, _) => Navigator.of(c).pop(),
                        child: ApplyTaskSheet(task: task),
                      ),
                    ),
                  );
                },
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // 3. 接单者完成按钮
  Widget _buildTakerCompleteButton(BuildContext context) {
    if (task.status != AppConstants.taskStatusInProgress || !isTaker) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimaryButton(
        text: context.l10n.actionsMarkComplete,
        icon: Icons.check_circle,
        isLoading: state.isSubmitting,
        onPressed: state.isSubmitting
            ? null
            : () {
                context
                    .read<TaskDetailBloc>()
                    .add(const TaskDetailCompleteRequested());
              },
        gradient: LinearGradient(
          colors: [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
        ),
      ),
    );
  }

  // 4. 发布者确认 + 退款区域
  Widget _buildPosterConfirmationButtons(BuildContext context) {
    if (task.status != AppConstants.taskStatusPendingConfirmation ||
        !isPoster) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // 确认完成按钮
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: PrimaryButton(
            text: context.l10n.actionsConfirmComplete,
            icon: Icons.verified,
            isLoading: state.isSubmitting,
            onPressed: state.isSubmitting
                ? null
                : () {
                    context.read<TaskDetailBloc>().add(
                        const TaskDetailConfirmCompletionRequested());
                  },
            gradient: LinearGradient(
              colors: [AppColors.success, AppColors.success.withValues(alpha: 0.8)],
            ),
          ),
        ),
        // 退款区域
        if (state.refundRequest != null) ...[
          RefundStatusCard(
            refundRequest: state.refundRequest!,
            isDark: isDark,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (state.refundRequest!.isPending)
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<TaskDetailBloc>().add(
                            TaskDetailCancelRefund(
                                state.refundRequest!.id));
                      },
                      child: Text(
                          context.l10n.refundWithdrawApply),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        context.read<TaskDetailBloc>().add(
                            const TaskDetailLoadRefundHistory());
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(20)),
                          ),
                          builder: (_) => BlocProvider.value(
                            value: context.read<TaskDetailBloc>(),
                            child: const RefundHistorySheet(),
                          ),
                        );
                      },
                      child: Text(context.l10n.refundViewHistory),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ] else if (!state.isLoadingRefundStatus) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PrimaryButton(
              text: context.l10n.refundTaskIncompleteApplyRefund,
              icon: Icons.undo,
              onPressed: () {
                final bloc = context.read<TaskDetailBloc>();
                showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: RefundRequestSheet(
                      taskId: task.id,
                      taskAmount: task.displayReward,
                    ),
                  ),
                ).then((submitted) {
                  if (submitted == true) {
                    // 退款申请提交后重新加载退款状态
                    bloc.add(const TaskDetailLoadRefundStatus());
                  }
                });
              },
              gradient: LinearGradient(
                colors: [AppColors.error, AppColors.error.withValues(alpha: 0.8)],
              ),
            ),
          ),
        ],
      ],
    );
  }

  // 4b. 接单者退款状态 + 反驳入口（对齐 iOS taker refund section）
  Widget _buildTakerRefundSection(BuildContext context) {
    // 仅接单者 + pendingConfirmation + 有退款申请时显示
    if (!isTaker ||
        task.status != AppConstants.taskStatusPendingConfirmation ||
        state.refundRequest == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        RefundStatusCard(
          refundRequest: state.refundRequest!,
          isDark: isDark,
        ),
        const SizedBox(height: AppSpacing.sm),
        // 退款待处理 且 未反驳 → 显示反驳按钮
        if (state.refundRequest!.isPending &&
            !state.refundRequest!.hasRebuttal)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: PrimaryButton(
              text: context.l10n.refundSubmitRebuttalEvidence,
              icon: Icons.gavel,
              onPressed: () {
                final bloc = context.read<TaskDetailBloc>();
                showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20)),
                  ),
                  builder: (_) => BlocProvider.value(
                    value: bloc,
                    child: RefundRebuttalSheet(
                      refundId: state.refundRequest!.id,
                    ),
                  ),
                ).then((submitted) {
                  if (submitted == true) {
                    bloc.add(const TaskDetailLoadRefundStatus());
                  }
                });
              },
            ),
          ),
        // 已有反驳 → 显示反驳信息
        if (state.refundRequest!.hasRebuttal)
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.06),
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                    color: AppColors.success.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      color: AppColors.success, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.refundRebuttalSubmitted,
                      style: AppTypography.caption.copyWith(
                          color: AppColors.success),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  // 5. 沟通按钮
  Widget _buildCommunicationButton(BuildContext context) {
    final isActive = task.status == AppConstants.taskStatusInProgress ||
        task.status == AppConstants.taskStatusPendingConfirmation ||
        task.status == AppConstants.taskStatusPendingPayment;

    if (!isActive || (!isPoster && !isTaker)) {
      return const SizedBox.shrink();
    }

    final contactText = getContactButtonText(task, isPoster, context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimaryButton(
        text: contactText,
        icon: Icons.message,
        onPressed: () {
          AppHaptics.selection();
          // 导航到任务聊天 (非私聊)
          context.goToTaskChat(task.id);
        },
      ),
    );
  }

  // 6. 评价按钮
  Widget _buildReviewButton(BuildContext context) {
    // 只有任务完成且用户是发布者或接单者才能评价
    if (task.status != AppConstants.taskStatusCompleted) {
      return const SizedBox.shrink();
    }
    if (!isPoster && !isTaker) return const SizedBox.shrink();

    if (task.hasReviewed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: PrimaryButton(
          text: context.l10n.taskDetailTaskAlreadyReviewed,
          icon: Icons.check_circle,
          onPressed: null,
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PrimaryButton(
        text: context.l10n.actionsRateTask,
        icon: Icons.star,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (sheetContext) => ReviewBottomSheet(
              onSubmit: (rating, comment, isAnonymous) async {
                final bloc = context.read<TaskDetailBloc>();
                bloc.add(
                  TaskDetailReviewRequested(
                    CreateReviewRequest(
                      rating: rating,
                      comment: comment,
                      isAnonymous: isAnonymous,
                    ),
                  ),
                );
                await for (final s in bloc.stream) {
                  if (s.actionMessage == 'review_submitted' ||
                      s.actionMessage == 'review_failed') {
                    return (
                      success: s.actionMessage == 'review_submitted',
                      error: s.errorMessage,
                    );
                  }
                }
                return (success: false, error: null);
              },
            ),
          );
        },
        gradient: LinearGradient(
          colors: [AppColors.warning, AppColors.warning.withValues(alpha: 0.8)],
        ),
      ),
    );
  }

  // 7. 取消按钮
  Widget _buildCancelButton(BuildContext context) {
    if ((!isPoster && !isTaker) ||
        (task.status != AppConstants.taskStatusOpen &&
            task.status != AppConstants.taskStatusInProgress)) {
      return const SizedBox.shrink();
    }

    return TextButton(
      onPressed: () {
        // TODO: 显示取消确认弹窗
        context
            .read<TaskDetailBloc>()
            .add(const TaskDetailCancelRequested());
      },
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
          const SizedBox(width: 6),
          Text(
            context.l10n.actionsCancelTask,
            style: AppTypography.body.copyWith(
              color: AppColors.error,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 申请任务弹窗（对齐 iOS ApplyTaskSheet：留言 + 是否议价 + 议价金额）
// ============================================================

class ApplyTaskSheet extends StatefulWidget {
  const ApplyTaskSheet({
    super.key,
    required this.task,
  });

  final Task task;

  @override
  State<ApplyTaskSheet> createState() => _ApplyTaskSheetState();
}

class _ApplyTaskSheetState extends State<ApplyTaskSheet> {
  final _messageController = TextEditingController();
  final _amountController = TextEditingController();
  bool _showNegotiatePrice = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final base = widget.task.baseReward ?? widget.task.reward;
    if (base > 0) _amountController.text = base == base.truncateToDouble() ? base.toInt().toString() : base.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String? _validate() {
    if (_showNegotiatePrice) {
      final amount = double.tryParse(_amountController.text.trim());
      if (amount == null || amount <= 0) {
        return context.l10n.fleaMarketNegotiatePriceTooLow;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() {
        _errorMessage = error;
        _isSubmitting = false;
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final message = _messageController.text.trim();
    final negotiatedPrice = _showNegotiatePrice
        ? double.tryParse(_amountController.text.trim())
        : null;
    final currency = _showNegotiatePrice ? widget.task.currency : null;

    if (!mounted) return;
    context.read<TaskDetailBloc>().add(TaskDetailApplyRequested(
          message: message.isEmpty ? null : message,
          negotiatedPrice: negotiatedPrice,
          currency: currency,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final showPriceSection = widget.task.isMultiParticipant != true;

    return BlocListener<TaskDetailBloc, TaskDetailState>(
      listenWhen: (prev, cur) =>
          cur.actionMessage == 'application_failed' && cur.isSubmitting == false,
      listener: (_, __) {
        if (mounted) setState(() => _isSubmitting = false);
      },
      child: DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textTertiary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      l10n.taskApplicationApplyTask,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 申请信息 / 留言
                      Text(
                        l10n.taskApplicationApplyInfo,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _messageController,
                        maxLines: 4,
                        maxLength: 500,
                        decoration: InputDecoration(
                          hintText: l10n.taskApplicationAdvantagePlaceholder,
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppRadius.medium),
                          ),
                          filled: true,
                          fillColor: isDark
                              ? AppColors.skeletonBase
                              : AppColors.skeletonHighlight,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 价格协商（非多参与者任务时显示）
                      if (showPriceSection) ...[
                        Text(
                          l10n.taskDetailPriceNegotiation,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile(
                          value: _showNegotiatePrice,
                          onChanged: (value) {
                            setState(() {
                              _showNegotiatePrice = value;
                              if (value &&
                                  _amountController.text.trim().isEmpty) {
                                final base = widget.task.baseReward ??
                                    widget.task.reward;
                                if (base > 0) {
                                  _amountController.text = base ==
                                          base.truncateToDouble()
                                      ? base.toInt().toString()
                                      : base.toStringAsFixed(2);
                                }
                              }
                            });
                          },
                          title: Text(
                            l10n.taskApplicationIWantToNegotiatePrice,
                            style: const TextStyle(fontSize: 15),
                          ),
                          activeTrackColor: AppColors.primary,
                        ),
                        if (_showNegotiatePrice) ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: InputDecoration(
                              labelText: l10n.taskApplicationExpectedAmount,
                              prefixText:
                                  '${widget.task.currency == 'GBP' ? '£' : widget.task.currency} ',
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.medium),
                              ),
                              filled: true,
                              fillColor: isDark
                                  ? AppColors.skeletonBase
                                  : AppColors.skeletonHighlight,
                            ),
                            onChanged: (_) =>
                                setState(() => _errorMessage = null),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.taskApplicationNegotiatePriceHint,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(
                              color: AppColors.error, fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                      ],

                      const SizedBox(height: 24),
                      PrimaryButton(
                        text: l10n.taskApplicationSubmitApplication,
                        icon: Icons.pan_tool,
                        isLoading: _isSubmitting,
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                await _submit();
                              },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    ),
    );
  }
}

// ============================================================
// 退款申请表单（对齐 iOS RefundRequestSheet）
// ============================================================

class RefundRequestSheet extends StatefulWidget {
  const RefundRequestSheet({
    super.key,
    required this.taskId,
    required this.taskAmount,
  });

  final int taskId;
  final double taskAmount; // 任务金额（英镑）

  @override
  State<RefundRequestSheet> createState() => _RefundRequestSheetState();
}

class _RefundRequestSheetState extends State<RefundRequestSheet> {
  RefundReasonType? _selectedReasonType;
  final _reasonController = TextEditingController();
  String _refundType = 'full'; // full / partial
  final _amountController = TextEditingController();
  final _percentageController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    _percentageController.dispose();
    super.dispose();
  }

  /// 金额 → 百分比自动互算
  void _onAmountChanged(String value) {
    if (widget.taskAmount <= 0) return;
    final amount = double.tryParse(value);
    if (amount != null && amount > 0) {
      final pct = (amount / widget.taskAmount * 100).toStringAsFixed(1);
      _percentageController.text = pct;
    }
  }

  void _onPercentageChanged(String value) {
    if (widget.taskAmount <= 0) return;
    final pct = double.tryParse(value);
    if (pct != null && pct > 0) {
      final amount = (widget.taskAmount * pct / 100).toStringAsFixed(2);
      _amountController.text = amount;
    }
  }

  String? _validate() {
    if (_selectedReasonType == null) {
      return context.l10n.refundReasonTypePlaceholder;
    }
    if (_reasonController.text.trim().length < 10) {
      return context.l10n.refundReasonMinLength;
    }
    if (_refundType == 'partial') {
      final amount = double.tryParse(_amountController.text);
      final pct = double.tryParse(_percentageController.text);
      if ((amount == null || amount <= 0) && (pct == null || pct <= 0)) {
        return context.l10n.errorCodeRefundAmountRequired;
      }
      if (amount != null && amount <= 0) {
        return context.l10n.refundAmountMustBePositive;
      }
      if (amount != null && amount >= widget.taskAmount) {
        return context.l10n.refundPartialAmountTooHigh;
      }
      if (pct != null && (pct <= 0 || pct > 100)) {
        return context.l10n.refundRatioRange;
      }
    }
    return null;
  }

  Future<void> _submit() async {
    final error = _validate();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final amount = double.tryParse(_amountController.text);
    final pct = double.tryParse(_percentageController.text);

    context.read<TaskDetailBloc>().add(TaskDetailRequestRefund(
          reasonType: _selectedReasonType!.value,
          reason: _reasonController.text.trim(),
          refundType: _refundType,
          refundAmount: _refundType == 'partial' ? amount : null,
          refundPercentage: _refundType == 'partial' ? pct : null,
        ));

    // 等待 BLoC 处理结果
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 拖拽指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              context.l10n.refundApplyRefund,
              style: AppTypography.title2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 提示
            Text(
              context.l10n.refundApplyRefundHint,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 错误提示
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: AppRadius.allMedium,
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 退款原因类型
            Text(
              context.l10n.refundReasonTypeRequired,
              style: AppTypography.bodyBold,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                  color: isDark
                      ? AppColors.dividerDark
                      : AppColors.dividerLight,
                ),
                color: isDark
                    ? AppColors.secondaryBackgroundDark
                    : AppColors.backgroundLight,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<RefundReasonType>(
                  value: _selectedReasonType,
                  isExpanded: true,
                  hint: Text(context.l10n.refundReasonTypePlaceholder),
                  items: RefundReasonType.values.map((type) {
                    return DropdownMenuItem(
                      value: type,
                      child: Text(_reasonTypeText(type, context)),
                    );
                  }).toList(),
                  onChanged: (v) =>
                      setState(() => _selectedReasonType = v),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 详细原因
            Text(
              context.l10n.refundReasonDetailRequired,
              style: AppTypography.bodyBold,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reasonController,
              maxLines: 4,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: context.l10n.refundReasonDetailRequired,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.secondaryBackgroundDark
                    : AppColors.backgroundLight,
              ),
            ),
            const SizedBox(height: 16),

            // 退款类型
            Text(
              context.l10n.refundTypeRequired,
              style: AppTypography.bodyBold,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _RefundTypeChip(
                    label: context.l10n.refundTypeFull,
                    isSelected: _refundType == 'full',
                    onTap: () =>
                        setState(() => _refundType = 'full'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _RefundTypeChip(
                    label: context.l10n.refundTypePartial,
                    isSelected: _refundType == 'partial',
                    onTap: () =>
                        setState(() => _refundType = 'partial'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 部分退款金额/百分比
            if (_refundType == 'partial') ...[
              Text(
                context.l10n.refundAmountOrRatioRequired,
                style: AppTypography.bodyBold,
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.refundTaskAmountFormat(widget.taskAmount),
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onAmountChanged,
                      decoration: InputDecoration(
                        labelText: context.l10n.refundAmountPound,
                        prefixText: '£ ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.secondaryBackgroundDark
                            : AppColors.backgroundLight,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _percentageController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: _onPercentageChanged,
                      decoration: InputDecoration(
                        labelText: context.l10n.refundRatioPercent,
                        suffixText: '%',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.secondaryBackgroundDark
                            : AppColors.backgroundLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // 提交按钮
            PrimaryButton(
              text: context.l10n.refundSubmitRefundApplication,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
              gradient: LinearGradient(
                colors: [
                  AppColors.error,
                  AppColors.error.withValues(alpha: 0.8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _reasonTypeText(RefundReasonType type, BuildContext context) {
    switch (type) {
      case RefundReasonType.completionTimeUnsatisfactory:
        return context.l10n.refundReasonCompletionTime;
      case RefundReasonType.notCompleted:
        return context.l10n.refundReasonNotCompleted;
      case RefundReasonType.qualityIssue:
        return context.l10n.refundReasonQualityIssue;
      case RefundReasonType.other:
        return context.l10n.refundReasonOther;
    }
  }
}

/// 退款类型选择芯片
class _RefundTypeChip extends StatelessWidget {
  const _RefundTypeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.dividerLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected
                  ? Icons.check_circle
                  : Icons.radio_button_off,
              size: 18,
              color: isSelected
                  ? AppColors.primary
                  : AppColors.textTertiaryLight,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppColors.primary : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// 退款历史列表（对齐 iOS RefundHistorySheet）
// ============================================================

class RefundHistorySheet extends StatelessWidget {
  const RefundHistorySheet({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<TaskDetailBloc, TaskDetailState>(
      builder: (context, state) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 拖拽指示器
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),

              // 标题
              Text(
                context.l10n.refundHistorySheetTitle,
                style: AppTypography.title2,
              ),
              const SizedBox(height: 16),

              // 内容
              if (state.isLoadingRefundHistory)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: LoadingView(),
                )
              else if (state.refundHistory.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history,
                        size: 48,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.refundNoHistory,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: state.refundHistory.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final refund = state.refundHistory[index];
                      return _RefundHistoryItem(
                        refund: refund,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 退款历史单条记录
class _RefundHistoryItem extends StatelessWidget {
  const _RefundHistoryItem({
    required this.refund,
    required this.isDark,
  });

  final RefundRequest refund;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(refund.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 状态行
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _statusText(refund.status, context),
                  style: AppTypography.caption.copyWith(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              if (refund.refundAmount != null)
                Text(
                  '£${refund.refundAmount!.toStringAsFixed(2)}',
                  style: AppTypography.bodyBold.copyWith(color: color),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // 原因类型
          if (refund.reasonType != null) ...[
            Text(
              '${context.l10n.refundReasonTypeLabel} ${_reasonTypeText(refund.reasonType!, context)}',
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
          ],

          // 退款类型
          if (refund.refundType != null)
            Text(
              '${context.l10n.refundTypeLabel} ${refund.refundType == 'full' ? context.l10n.refundTypeFull : context.l10n.refundTypePartial}',
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),

          // 原因
          if (refund.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              refund.reason,
              style: AppTypography.body,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // 管理员评论
          if (refund.adminComment != null &&
              refund.adminComment!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.l10n.refundAdminCommentLabel(refund.adminComment!),
              style: AppTypography.caption.copyWith(
                color: AppColors.warning,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],

          // 反驳信息
          if (refund.hasRebuttal) ...[
            const SizedBox(height: 6),
            Text(
              '${context.l10n.refundTakerRebuttal}: ${refund.rebuttalText}',
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          // 时间
          const SizedBox(height: 6),
          Text(
            context.l10n.refundApplyTimeLabel(refund.createdAt),
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warning;
      case 'processing':
        return AppColors.primary;
      case 'approved':
      case 'completed':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      default:
        return AppColors.textSecondaryLight;
    }
  }

  String _statusText(String status, BuildContext context) {
    switch (status) {
      case 'pending':
        return context.l10n.refundStatusPending;
      case 'processing':
        return context.l10n.refundStatusProcessing;
      case 'approved':
        return context.l10n.refundStatusApproved;
      case 'rejected':
        return context.l10n.refundStatusRejected;
      case 'completed':
        return context.l10n.refundStatusCompleted;
      case 'cancelled':
        return context.l10n.refundStatusCancelled;
      default:
        return context.l10n.refundStatusUnknown;
    }
  }

  String _reasonTypeText(String reasonType, BuildContext context) {
    switch (reasonType) {
      case 'completion_time_unsatisfactory':
        return context.l10n.refundReasonCompletionTime;
      case 'not_completed':
        return context.l10n.refundReasonNotCompleted;
      case 'quality_issue':
        return context.l10n.refundReasonQualityIssue;
      case 'other':
        return context.l10n.refundReasonOther;
      default:
        return reasonType;
    }
  }
}

// ============================================================
// 退款反驳表单（对齐 iOS RefundRebuttalSheet）
// ============================================================

class RefundRebuttalSheet extends StatefulWidget {
  const RefundRebuttalSheet({
    super.key,
    required this.refundId,
  });

  final int refundId;

  @override
  State<RefundRebuttalSheet> createState() => _RefundRebuttalSheetState();
}

class _RefundRebuttalSheetState extends State<RefundRebuttalSheet> {
  final _rebuttalController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _rebuttalController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _rebuttalController.text.trim();
    if (text.length < 10) {
      setState(() =>
          _errorMessage = context.l10n.refundRebuttalMinLength);
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    context.read<TaskDetailBloc>().add(TaskDetailSubmitRebuttal(
          refundId: widget.refundId,
          content: text,
        ));

    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 拖拽指示器
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 标题
            Text(
              context.l10n.refundSubmitRebuttalNavTitle,
              style: AppTypography.title2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // 提示
            Text(
              context.l10n.refundRebuttalHint,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),

            // 错误提示
            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.08),
                  borderRadius: AppRadius.allMedium,
                  border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // 反驳文本
            Text(
              context.l10n.refundRebuttalDescription,
              style: AppTypography.bodyBold,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _rebuttalController,
              maxLines: 5,
              maxLength: 2000,
              decoration: InputDecoration(
                hintText: context.l10n.refundRebuttalDescription,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: isDark
                    ? AppColors.secondaryBackgroundDark
                    : AppColors.backgroundLight,
              ),
            ),
            const SizedBox(height: 20),

            // 提交按钮
            PrimaryButton(
              text: context.l10n.refundSubmitRebuttalEvidence,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
