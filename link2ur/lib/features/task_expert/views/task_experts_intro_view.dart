import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
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
            SizedBox(
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: isAuthenticated
                      ? const LinearGradient(
                          colors: AppColors.gradientPrimary,
                        )
                      : null,
                  color: isAuthenticated ? null : AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (isAuthenticated) {
                      context.push('/task-experts');
                    } else {
                      context.push('/login');
                    }
                  },
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
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
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
