import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/l10n_extension.dart';

/// 任务达人介绍页
/// 参考iOS TaskExpertsIntroView.swift
class TaskExpertsIntroView extends StatelessWidget {
  const TaskExpertsIntroView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskExpertIntro),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 头部图片
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.large),
              child: Image.asset(
                AppAssets.service,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 200,
                  color: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.star,
                      size: 64, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // 标题
            Text(
              l10n.taskExpertIntroTitle,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              l10n.taskExpertIntroSubtitle,
              style: const TextStyle(
                  fontSize: 15, color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 优势列表
            _buildBenefitCard(
              context,
              icon: Icons.verified_user,
              title: l10n.taskExpertBenefit1Title,
              description: l10n.taskExpertBenefit1Desc,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildBenefitCard(
              context,
              icon: Icons.trending_up,
              title: l10n.taskExpertBenefit2Title,
              description: l10n.taskExpertBenefit2Desc,
            ),
            const SizedBox(height: AppSpacing.md),
            _buildBenefitCard(
              context,
              icon: Icons.workspace_premium,
              title: l10n.taskExpertBenefit3Title,
              description: l10n.taskExpertBenefit3Desc,
            ),
            const SizedBox(height: AppSpacing.xl),

            // 申请按钮
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: () => context.push('/task-experts'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.large),
                  ),
                ),
                child: Text(
                  l10n.taskExpertApplyNow,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildBenefitCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
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
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(description,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
