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
import '../../../core/utils/l10n_extension.dart';
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
          Icon(Icons.info_outline, size: 24, color: AppColors.primary),
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
              Icon(Icons.schedule, size: 20, color: AppColors.warning),
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
          Icon(Icons.hourglass_top, size: 24, color: AppColors.primary),
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
              Icon(Icons.verified, size: 18, color: AppColors.success),
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
              Icon(Icons.people, size: 18, color: AppColors.primary),
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
              Icon(Icons.rate_review, size: 18, color: AppColors.warning),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                review.reviewer?.name ??
                    context.l10n.taskDetailAnonymousUser,
                style: AppTypography.bodyBold.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const Spacer(),
              // 星星评分
              Row(
                children: List.generate(
                  5,
                  (i) => Icon(
                    i < review.rating ? Icons.star : Icons.star_border,
                    size: 16,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            const SizedBox(height: 4),
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

    // 未申请 + 任务 open + 无接单者
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
                  context
                      .read<TaskDetailBloc>()
                      .add(const TaskDetailApplyRequested());
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
                        // TODO: 查看退款历史
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
                // TODO: 打开退款申请页面
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
          // TODO: 打开评价弹窗
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
          Icon(Icons.cancel_outlined, size: 18, color: AppColors.error),
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
