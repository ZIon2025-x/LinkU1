import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/bouncing_widget.dart';
import '../../../core/widgets/animated_star_rating.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_application.dart';
import '../../../data/models/review.dart';
import '../../../data/models/refund_request.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/task_detail_bloc.dart';

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

    final Color color;
    final IconData icon;
    final String text;

    if (task.isVipTask) {
      color = AppColors.busy;
      icon = Icons.star;
      text = context.l10n.taskDetailVipTask;
    } else if (task.isExpertTask) {
      color = AppColors.indigo;
      icon = Icons.verified;
      text = context.l10n.taskDetailExpertTask;
    } else if (task.isSuperTask) {
      color = AppColors.pendingPurple;
      icon = Icons.local_fire_department;
      text = context.l10n.taskDetailSuperTask;
    } else {
      return const SizedBox.shrink();
    }

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
    required this.evidenceList,
    required this.isDark,
  });

  final List<Map<String, dynamic>> evidenceList;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final texts = <String>[];
    final images = <String>[];

    for (final item in evidenceList) {
      final type = item['type'] as String? ?? '';
      final content = item['content'] as String? ?? '';
      if (type == 'image' && content.isNotEmpty) {
        images.add(content);
      } else if (content.isNotEmpty) {
        texts.add(content);
      }
      final url = item['url'] as String?;
      if (url != null && url.isNotEmpty) {
        images.add(url);
      }
    }

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
          if (texts.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            ...texts.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                t,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.6,
                ),
              ),
            )),
          ],
          if (images.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: images.map((url) => ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: AsyncImageView(
                  imageUrl: url,
                  width: 100,
                  height: 100,
                ),
              )).toList(),
            ),
          ],
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
    required this.task,
  });

  final List<TaskApplication> applications;
  final bool isLoading;
  final bool isDark;
  final Task task;

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
                      key: ValueKey(app.id),
                      application: app,
                      isDark: isDark,
                      task: task,
                    ))
                ,
        ],
      ),
    );
  }
}

/// Parse ISO 8601 time string, convert UTC→local, and format as relative time.
String _formatTimeString(String timeStr) {
  final dt = DateTime.tryParse(timeStr);
  if (dt == null) return timeStr;
  return DateFormatter.formatRelative(dt.toLocal());
}

class _ApplicationItem extends StatelessWidget {
  const _ApplicationItem({
    super.key,
    required this.application,
    required this.isDark,
    required this.task,
  });

  final TaskApplication application;
  final bool isDark;
  final Task task;

  void _confirmReject(BuildContext context) {
    AdaptiveDialogs.showConfirmDialog<bool>(
      context: context,
      title: context.l10n.taskDetailRejectApplication,
      content: context.l10n.taskDetailRejectApplicationConfirm,
      confirmText: context.l10n.commonConfirm,
      cancelText: context.l10n.commonCancel,
      isDestructive: true,
      onConfirm: () => true,
      onCancel: () => false,
    ).then((confirmed) {
      if (confirmed == true && context.mounted) {
        AppHaptics.medium();
        context.read<TaskDetailBloc>().add(
              TaskDetailRejectApplicant(application.id),
            );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = application.isPending
        ? AppColors.warning
        : application.isChatting
            ? AppColors.primary
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
                Semantics(
                  button: true,
                  label: 'View profile',
                  child: GestureDetector(
                    onTap: () {
                      if (application.applicantId != null) {
                        context.push('/user/${application.applicantId}');
                      }
                    },
                    child: AvatarView(
                      imageUrl: application.applicantAvatar,
                      name: application.applicantName,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Semantics(
                    button: true,
                    label: 'View profile',
                    child: GestureDetector(
                      onTap: () {
                        if (application.applicantId != null) {
                          context.push('/user/${application.applicantId}');
                        }
                      },
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
                            _formatTimeString(application.createdAt!),
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                      ],
                    ),
                    ),
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
            // 议价金额
            if (application.proposedPrice != null &&
                application.proposedPrice! > 0) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allSmall,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.price_change_outlined,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      '${context.l10n.taskApplicationExpectedAmount}: ${Helpers.formatPrice(application.proposedPrice!, currency: task.currency)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            // 操作按钮 (pending 或 chatting 时显示)
            if (application.isPending) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  if (task.isMultiParticipant)
                    // 多人任务：保持原有的直接接受按钮
                    _ActionCircleButton(
                      icon: Icons.check_circle,
                      color: AppColors.success,
                      onTap: () {
                        AppHaptics.medium();
                        context.read<TaskDetailBloc>().add(
                              TaskDetailAcceptApplicant(application.id),
                            );
                      },
                    )
                  else ...[
                    // 单人任务：直接批准按钮
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
                    const SizedBox(width: 12),
                    // 单人任务：同意沟通按钮
                    Expanded(
                      child: BouncingWidget(
                        onTap: () {
                          AppHaptics.medium();
                          context.read<TaskDetailBloc>().add(
                                TaskDetailStartChat(application.id),
                              );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.sm,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.allSmall,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.chat_bubble_outline,
                                  size: 18, color: AppColors.primary),
                              const SizedBox(width: 6),
                              Text(
                                context.l10n.agreeToChat,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 12),
                  _ActionCircleButton(
                    icon: Icons.cancel,
                    color: AppColors.error,
                    onTap: () => _confirmReject(context),
                  ),
                ],
              ),
            ],
            // chatting 状态：显示打开聊天和拒绝按钮
            if (application.isChatting) ...[
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: BouncingWidget(
                      onTap: () async {
                        await context.push(
                          '/tasks/${task.id}/applications/${application.id}/chat',
                        );
                        if (!context.mounted) return;
                        // Refresh task detail after returning from chat
                        context.read<TaskDetailBloc>()
                          ..add(TaskDetailLoadRequested(task.id))
                          ..add(TaskDetailLoadApplications(
                            currentUserId: StorageService.instance.getUserId(),
                          ));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.1),
                          borderRadius: AppRadius.allSmall,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                const Icon(Icons.chat,
                                    size: 18, color: AppColors.success),
                                if (application.unreadCount > 0)
                                  Positioned(
                                    right: -6,
                                    top: -6,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: const BoxDecoration(
                                        color: AppColors.error,
                                        shape: BoxShape.circle,
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 16,
                                        minHeight: 16,
                                      ),
                                      child: Text(
                                        application.unreadCount > 99
                                            ? '99+'
                                            : '${application.unreadCount}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              context.l10n.applicationChatting,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.success,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  _ActionCircleButton(
                    icon: Icons.cancel,
                    color: AppColors.error,
                    onTap: () => _confirmReject(context),
                  ),
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
    if (application.isChatting) return context.l10n.applicationChatting;
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
                context.l10n.taskDetailReviewsTitle,
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
    final reviewerName = review.isAnonymous
        ? context.l10n.taskDetailAnonymousUser
        : review.reviewer?.name;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (reviewerName != null) ...[
            Text(
              reviewerName,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              AnimatedStarRating(
                rating: review.rating,
                size: 14,
                spacing: 2,
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
              if (review.isAnonymous) ...[
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.textTertiaryDark.withValues(alpha: 0.2)
                        : AppColors.textTertiaryLight.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    context.l10n.taskDetailReviewAnonymous,
                    style: AppTypography.caption.copyWith(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
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
    this.currency = 'GBP',
  });

  final RefundRequest refundRequest;
  final bool isDark;
  final String currency;

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
                  Helpers.formatPrice(refundRequest.refundAmount!, currency: currency),
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
// 申请任务弹窗（对齐 iOS ApplyTaskSheet：留言 + 是否议价 + 议价金额）
// ============================================================

class ApplyTaskSheet extends StatefulWidget {
  const ApplyTaskSheet({
    super.key,
    required this.task,
    required this.bloc,
  });

  final Task task;
  final TaskDetailBloc bloc;

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
    if (widget.task.rewardToBeQuoted) {
      _showNegotiatePrice = true; // 待报价任务必须填写报价金额
    } else {
      final base = widget.task.baseReward ?? widget.task.reward;
      if (base > 0) _amountController.text = Helpers.formatAmountNumber(base);
    }
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
      // 待报价任务：报价金额必须大于 £1
      if (widget.task.rewardToBeQuoted && amount <= 1.0) {
        return context.l10n.taskApplyQuoteAmountMin(Helpers.currencySymbolFor(widget.task.currency));
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
    // 待报价任务必须传报价金额；普通任务可选议价
    final negotiatedPrice = widget.task.rewardToBeQuoted
        ? double.tryParse(_amountController.text.trim())
        : (_showNegotiatePrice
            ? double.tryParse(_amountController.text.trim())
            : null);
    final currency = (widget.task.rewardToBeQuoted || _showNegotiatePrice)
        ? widget.task.currency
        : null;

    if (!mounted) return;
    widget.bloc.add(TaskDetailApplyRequested(
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
      bloc: widget.bloc,
      listenWhen: (prev, cur) =>
          cur.isSubmitting != prev.isSubmitting ||
          (cur.actionMessage != null &&
              cur.actionMessage != prev.actionMessage),
      listener: (_, state) {
        if (!mounted) return;
        if (state.actionMessage == 'application_failed') {
          setState(() => _isSubmitting = false);
        }
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
                      tooltip: 'Close',
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

                      // 价格协商（非多参与者任务时显示）；待报价任务必须填写报价金额
                      if (showPriceSection) ...[
                        Text(
                          widget.task.rewardToBeQuoted
                              ? l10n.taskApplyQuoteAmountLabel
                              : l10n.taskDetailPriceNegotiation,
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        if (!widget.task.rewardToBeQuoted)
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
                                    _amountController.text =
                                        Helpers.formatAmountNumber(base);
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
                              hintText: widget.task.rewardToBeQuoted
                                  ? l10n.taskApplyQuoteAmountHint(Helpers.currencySymbolFor(widget.task.currency))
                                  : null,
                              prefixText:
                                  '${Helpers.currencySymbolFor(widget.task.currency)} ',
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
                            widget.task.rewardToBeQuoted
                                ? l10n.taskApplyQuoteAmountMin(Helpers.currencySymbolFor(widget.task.currency))
                                : l10n.taskApplicationNegotiatePriceHint,
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
    required this.bloc,
    this.currency = 'GBP',
  });

  final int taskId;
  final double taskAmount;
  final TaskDetailBloc bloc;
  final String currency;

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
      final amount = Helpers.formatAmountNumber(widget.taskAmount * pct / 100);
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

    widget.bloc.add(TaskDetailRequestRefund(
          reasonType: _selectedReasonType!.value,
          reason: _reasonController.text.trim(),
          refundType: _refundType,
          refundAmount: _refundType == 'partial' ? amount : null,
          refundPercentage: _refundType == 'partial' ? pct : null,
        ));
    // BlocListener in build() handles pop on success
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<TaskDetailBloc, TaskDetailState>(
      bloc: widget.bloc,
      listenWhen: (prev, curr) =>
          curr.actionMessage != null &&
          prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage == 'refund_submitted') {
          Navigator.of(context).pop(true);
        }
        if (state.actionMessage == 'refund_failed') {
          setState(() => _isSubmitting = false);
        }
      },
      child: Container(
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
            AppSelectField<RefundReasonType>(
              value: _selectedReasonType,
              hint: context.l10n.refundReasonTypePlaceholder,
              sheetTitle: context.l10n.refundReasonTypeRequired,
              clearable: false,
              options: RefundReasonType.values
                  .map((type) => SelectOption(
                        value: type,
                        label: _reasonTypeText(type, context),
                      ))
                  .toList(),
              onChanged: (v) =>
                  setState(() => _selectedReasonType = v),
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
                context.l10n.refundTaskAmountFormat(widget.taskAmount, Helpers.currencySymbolFor(widget.currency)),
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
                        labelText: context.l10n.refundAmountPound(Helpers.currencySymbolFor(widget.currency)),
                        prefixText: '${Helpers.currencySymbolFor(widget.currency)} ',
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
    return Semantics(
      button: true,
      label: 'Select refund type',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
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
      ),
    );
  }
}

// ============================================================
// 退款历史列表（对齐 iOS RefundHistorySheet）
// ============================================================

class RefundHistorySheet extends StatelessWidget {
  const RefundHistorySheet({super.key, this.currency = 'GBP'});

  final String currency;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<TaskDetailBloc, TaskDetailState>(
      buildWhen: (prev, curr) =>
          prev.refundHistory != curr.refundHistory,
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
                SizedBox(
                  height: (MediaQuery.sizeOf(context).height * 0.5).clamp(200.0, 400.0),
                  child: ListView.separated(
                    itemCount: state.refundHistory.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final refund = state.refundHistory[index];
                      return _RefundHistoryItem(
                        key: ValueKey(refund.id),
                        refund: refund,
                        isDark: isDark,
                        currency: currency,
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
    super.key,
    required this.refund,
    required this.isDark,
    this.currency = 'GBP',
  });

  final RefundRequest refund;
  final bool isDark;
  final String currency;

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
                  Helpers.formatPrice(refund.refundAmount!, currency: currency),
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
            context.l10n.refundApplyTimeLabel(_formatTimeString(refund.createdAt)),
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
    // BlocListener in build() handles pop on success
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<TaskDetailBloc, TaskDetailState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null &&
          prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage == 'dispute_submitted') {
          Navigator.of(context).pop(true);
        }
        if (state.actionMessage == 'dispute_failed') {
          setState(() => _isSubmitting = false);
        }
      },
      child: Container(
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
      ),
    );
  }
}

/// 证据收集 Sheet（支持图片+文字），用于 TaskActionButtonsView
class _EvidenceCollectionSheet extends StatefulWidget {
  const _EvidenceCollectionSheet({
    required this.bloc,
    required this.taskRepo,
  });

  final TaskDetailBloc bloc;
  final TaskRepository taskRepo;

  @override
  State<_EvidenceCollectionSheet> createState() => _EvidenceCollectionSheetState();
}

class _EvidenceCollectionSheetState extends State<_EvidenceCollectionSheet> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<XFile> _images = [];
  bool _isSubmitting = false;

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final remaining = 5 - _images.length;
    if (remaining <= 0) return;
    final picked = await _imagePicker.pickMultiImage(imageQuality: 80, maxWidth: 1920);
    if (picked.isNotEmpty && mounted) {
      setState(() => _images.addAll(picked.take(remaining)));
    }
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    try {
      List<String>? imageUrls;
      if (_images.isNotEmpty) {
        imageUrls = [];
        for (final img in _images) {
          final url = await widget.taskRepo.uploadTaskImage(await img.readAsBytes(), img.name);
          imageUrls.add(url);
        }
      }
      final text = _textController.text.trim();
      widget.bloc.add(TaskDetailCompleteRequested(
        evidenceImages: imageUrls,
        evidenceText: text.isEmpty ? null : text,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.localizeError(e.toString())),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24, right: 24, top: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.taskEvidenceTitle, style: AppTypography.title3),
          const SizedBox(height: 8),
          Text(l10n.taskEvidenceHint, style: AppTypography.footnote),
          const SizedBox(height: 16),
          TextField(
            controller: _textController,
            maxLines: 4,
            maxLength: 500,
            decoration: InputDecoration(
              hintText: l10n.taskEvidenceTextHint,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ..._images.asMap().entries.map((entry) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CrossPlatformImage(xFile: entry.value, width: 72, height: 72),
                  ),
                  Positioned(
                    top: 2, right: 2,
                    child: Semantics(
                      button: true,
                      label: 'Remove image',
                      child: GestureDetector(
                        onTap: () => setState(() => _images.removeAt(entry.key)),
                        child: Container(
                          decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                          padding: const EdgeInsets.all(2),
                          child: const Icon(Icons.close, size: 14, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              )),
              if (_images.length < 5)
                Semantics(
                  button: true,
                  label: 'Add images',
                  child: GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 72, height: 72,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.dividerLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: AppColors.textSecondaryLight),
                        Text('${_images.length}/5',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                      ],
                    ),
                  ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSubmitting ? null : _submit,
              icon: _isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_circle),
              label: Text(l10n.taskEvidenceSubmit),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ============================================================
// 指定任务报价单 (designated task quote sheet)
// ============================================================

class QuoteDesignatedPriceSheet extends StatefulWidget {
  const QuoteDesignatedPriceSheet({super.key, this.currency, required this.bloc});

  final String? currency;
  final TaskDetailBloc bloc;

  @override
  State<QuoteDesignatedPriceSheet> createState() =>
      _QuoteDesignatedPriceSheetState();
}

class _QuoteDesignatedPriceSheetState
    extends State<QuoteDesignatedPriceSheet> {
  final _amountController = TextEditingController();
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _validate() {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 1.0) {
      return context.l10n.taskApplyQuoteAmountMin(Helpers.currencySymbolFor(widget.currency ?? 'GBP'));
    }
    return null;
  }

  void _submit() {
    final error = _validate();
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final amount = double.parse(_amountController.text.trim());
    widget.bloc.add(
      TaskDetailQuoteDesignatedPriceRequested(price: amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currencySymbol = Helpers.currencySymbolFor(widget.currency ?? 'GBP');

    return BlocListener<TaskDetailBloc, TaskDetailState>(
      bloc: widget.bloc,
      listenWhen: (prev, cur) =>
          cur.actionMessage == 'quote_failed' &&
          cur.actionMessage != prev.actionMessage,
      listener: (_, state) {
        if (mounted) setState(() => _isSubmitting = false);
      },
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : Colors.white,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 拖拽条
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.taskDetailSubmitQuote,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: l10n.taskApplyQuoteAmountLabel,
                    hintText: l10n.taskApplyQuoteAmountHint(currencySymbol),
                    prefixText: '$currencySymbol ',
                    border: const OutlineInputBorder(),
                    errorText: _errorMessage,
                  ),
                  onChanged: (_) {
                    if (_errorMessage != null) setState(() => _errorMessage = null);
                  },
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: l10n.taskDetailSubmitQuote,
                    isLoading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
