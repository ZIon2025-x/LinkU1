import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/question_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/task_expert_bloc.dart';

/// 任务达人介绍页
/// 对标 iOS TaskExpertsIntroView.swift
class TaskExpertsIntroView extends StatelessWidget {
  const TaskExpertsIntroView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAuthenticated =
        context.select<AuthBloc, bool>((b) => b.state.isAuthenticated);

    return BlocProvider(
      create: (ctx) => TaskExpertBloc(
        taskExpertRepository: ctx.read<TaskExpertRepository>(),
        questionRepository: ctx.read<QuestionRepository>(),
      )..add(const TaskExpertLoadMyExpertApplicationStatus()),
      child: Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskExpertIntro),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 我的申请状态卡片
            if (isAuthenticated)
              BlocBuilder<TaskExpertBloc, TaskExpertState>(
                buildWhen: (p, c) =>
                    p.myExpertApplicationStatus != c.myExpertApplicationStatus,
                builder: (ctx, state) {
                  final app = state.myExpertApplicationStatus;
                  if (app == null) return const SizedBox.shrink();
                  return _MyApplicationStatusCard(
                    applicationData: app,
                    isDark: isDark,
                  );
                },
              ),
            // ========== Hero Section（对标iOS: star.circle.fill + title + subtitle）==========
            const SizedBox(height: AppSpacing.xl),
            const Icon(
              Icons.star_rounded,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              l10n.taskExpertIntroTitle,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                l10n.taskExpertIntroSubtitle,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ========== 什么是任务达人（对标iOS InfoCard）==========
            _InfoCard(
              icon: Icons.lightbulb,
              iconColor: Colors.amber,
              title: l10n.taskExpertBenefit1Title,
              content: l10n.taskExpertBenefit1Desc,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ========== 成为达人的好处（对标iOS BenefitRow）==========
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Text(
                l10n.taskExpertBenefits,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _BenefitRow(
              icon: Icons.visibility,
              title: l10n.taskExpertBenefit2Title,
              description: l10n.taskExpertBenefit2Desc,
            ),
            const SizedBox(height: AppSpacing.sm),
            _BenefitRow(
              icon: Icons.star,
              title: l10n.taskExpertBenefit3Title,
              description: l10n.taskExpertBenefit3Desc,
            ),
            const SizedBox(height: AppSpacing.sm),
            _BenefitRow(
              icon: Icons.show_chart,
              title: l10n.taskExpertBenefit1Title,
              description: l10n.taskExpertBenefit1Desc,
            ),
            const SizedBox(height: AppSpacing.sm),
            _BenefitRow(
              icon: Icons.shield,
              title: l10n.taskExpertBenefit2Title,
              description: l10n.taskExpertBenefit2Desc,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ========== 申请按钮（对标iOS: gradient / primary button）==========
            BlocBuilder<TaskExpertBloc, TaskExpertState>(
              buildWhen: (p, c) =>
                  p.myExpertApplicationStatus != c.myExpertApplicationStatus,
              builder: (ctx, state) {
                final app = state.myExpertApplicationStatus;
                final status = app?['status'] as String?;
                // 已有pending/approved申请时禁用按钮
                final canApply = isAuthenticated &&
                    status != 'pending' &&
                    status != 'approved';

                return SizedBox(
                  height: 52,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: canApply
                          ? const LinearGradient(
                              colors: AppColors.gradientPrimary,
                            )
                          : null,
                      color: canApply ? null : AppColors.primary.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(AppRadius.large),
                    ),
                    child: ElevatedButton(
                      onPressed: canApply
                          ? () => _showApplySheet(ctx)
                          : (!isAuthenticated
                              ? () => context.push('/login')
                              : null),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: Text(
                        isAuthenticated
                            ? l10n.taskExpertApplyNow
                            : l10n.taskExpertLoginToApply,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
      ),
    );
  }
}

/// 显示申请达人的底部弹窗
void _showApplySheet(BuildContext context) {
  final bloc = context.read<TaskExpertBloc>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => BlocProvider.value(
      value: bloc,
      child: const _ExpertApplySheet(),
    ),
  );
}

/// 申请成为达人的表单弹窗（对标 iOS TaskExpertApplyView）
class _ExpertApplySheet extends StatefulWidget {
  const _ExpertApplySheet();

  @override
  State<_ExpertApplySheet> createState() => _ExpertApplySheetState();
}

class _ExpertApplySheetState extends State<_ExpertApplySheet> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final message = _controller.text.trim();
    if (message.isEmpty) return;
    context.read<TaskExpertBloc>().add(
          TaskExpertApplyToBeExpert(message: message),
        );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<TaskExpertBloc, TaskExpertState>(
      listenWhen: (p, c) => p.actionMessage != c.actionMessage,
      listener: (ctx, state) {
        if (state.actionMessage == 'expert_application_submitted') {
          Navigator.of(ctx).pop();
          showDialog<void>(
            context: ctx,
            builder: (dialogCtx) => AlertDialog(
              title: Text(l10n.taskExpertApplicationSubmitted),
              content: Text(l10n.taskExpertApplicationSubmittedMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: Text(l10n.commonOk),
                ),
              ],
            ),
          );
        } else if (state.actionMessage == 'expert_application_failed') {
          ScaffoldMessenger.of(ctx).showSnackBar(
            SnackBar(content: Text(state.errorMessage ?? l10n.errorUnknown)),
          );
        }
      },
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          top: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
                Expanded(
                  child: Text(
                    l10n.taskExpertApplyTitle,
                    style: AppTypography.title3,
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 64), // 平衡取消按钮的宽度
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            // 说明
            Text(
              l10n.taskExpertApplicationInfo,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            // 输入框
            TextField(
              controller: _controller,
              maxLines: 6,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: l10n.taskExpertApplicationHint,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: AppSpacing.md),
            // 提交按钮
            BlocBuilder<TaskExpertBloc, TaskExpertState>(
              buildWhen: (p, c) => p.isSubmitting != c.isSubmitting,
              builder: (ctx, state) {
                final canSubmit =
                    _controller.text.trim().isNotEmpty && !state.isSubmitting;
                return SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _submit : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                    child: state.isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            l10n.taskExpertSubmitApplication,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 信息卡片（对标iOS InfoCard）
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.content,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 28, color: iconColor),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

/// 好处卡片（对标iOS BenefitRow）
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
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

/// 我的达人申请状态卡片
class _MyApplicationStatusCard extends StatelessWidget {
  const _MyApplicationStatusCard({
    required this.applicationData,
    required this.isDark,
  });

  final Map<String, dynamic> applicationData;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final status = applicationData['status'] as String? ?? 'pending';

    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (status) {
      case 'approved':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusText = l10n.taskExpertApplicationApproved;
        break;
      case 'rejected':
        statusColor = AppColors.error;
        statusIcon = Icons.cancel;
        statusText = l10n.taskExpertApplicationRejected;
        break;
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        statusText = l10n.taskExpertApplicationPending;
    }

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              statusText,
              style: AppTypography.body.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
