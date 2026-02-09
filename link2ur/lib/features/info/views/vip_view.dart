import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';

/// VIP 会员中心页
/// 参考iOS VIPView.swift
/// 展示会员状态、权益、历史记录
class VipView extends StatelessWidget {
  const VipView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // 顶部渐变 AppBar
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(context.l10n.settingsMembership),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8C00)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 40),
                      const Icon(Icons.workspace_premium,
                          size: 56, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(
                        context.l10n.vipMember,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 内容
          SliverToBoxAdapter(
            child: Padding(
              padding: AppSpacing.allLg,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 当前状态卡片
                  _buildStatusCard(context),
                  AppSpacing.vLg,

                  // VIP 权益
                  _buildBenefitsSection(context),
                  AppSpacing.vLg,

                  // 会员套餐
                  _buildPlansSection(context),
                  AppSpacing.vLg,

                  // 常见问题
                  _buildFaqSection(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                  borderRadius: AppRadius.allPill,
                ),
                child: Text(
                  context.l10n.vipRegularUser,
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          Text(
            context.l10n.vipUnlockPrivileges,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vSm,
          Text(
            context.l10n.vipEnjoyBenefits,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 14,
            ),
          ),
          AppSpacing.vMd,
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.push('/vip/purchase'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFD700),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.allMedium,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(
                context.l10n.vipBuyNow,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(BuildContext context) {
    final l10n = context.l10n;
    final benefits = [
      _BenefitItem(
        icon: Icons.bolt,
        title: l10n.infoVipPriorityRecommend,
        description: l10n.vipPriorityRecommendationDesc,
        color: AppColors.primary,
      ),
      _BenefitItem(
        icon: Icons.verified,
        title: l10n.infoVipBadgeLabel,
        description: l10n.vipExclusiveBadgeDesc,
        color: const Color(0xFFFFD700),
      ),
      _BenefitItem(
        icon: Icons.discount,
        title: l10n.infoVipFeeDiscount,
        description: l10n.vipFeeDiscountDesc,
        color: AppColors.success,
      ),
      _BenefitItem(
        icon: Icons.support_agent,
        title: l10n.infoVipCustomerService,
        description: l10n.vipExclusiveBadgeDesc,
        color: AppColors.accentPink,
      ),
      _BenefitItem(
        icon: Icons.card_giftcard,
        title: l10n.infoVipExclusiveCoupon,
        description: l10n.vipExclusiveActivityDesc,
        color: AppColors.accent,
      ),
      _BenefitItem(
        icon: Icons.analytics,
        title: l10n.infoVipDataAnalytics,
        description: l10n.vipExclusiveActivityDesc,
        color: Colors.teal,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.infoMemberBenefits,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: ResponsiveUtils.gridColumnCount(context, type: GridItemType.standard),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: benefits.length,
          itemBuilder: (context, index) {
            final benefit = benefits[index];
            return Container(
              padding: AppSpacing.allMd,
              decoration: BoxDecoration(
                color: benefit.color.withValues(alpha: 0.08),
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                  color: benefit.color.withValues(alpha: 0.2),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(benefit.icon, color: benefit.color, size: 24),
                  const Spacer(),
                  Text(
                    benefit.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: benefit.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    benefit.description,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildPlansSection(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.vipSelectPackage,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        _PlanCard(
          title: l10n.infoVipMonthly,
          price: '\$4.99',
          period: l10n.vipPerMonth,
          features: [
            l10n.vipPlanFeatureMonthly1,
            l10n.vipPlanFeatureMonthly2,
            l10n.vipPlanFeatureMonthly3,
          ],
          isPrimary: false,
          onTap: () => context.push('/vip/purchase'),
        ),
        AppSpacing.vSm,
        _PlanCard(
          title: l10n.infoVipYearly,
          price: '\$39.99',
          period: l10n.vipPerYear,
          features: [
            l10n.vipPlanFeatureYearly1,
            l10n.vipPlanFeatureYearly2,
            l10n.vipPlanFeatureYearly3,
            l10n.vipPlanFeatureYearly4,
          ],
          isPrimary: true,
          badge: l10n.vipPlanBadgeBestValue,
          onTap: () => context.push('/vip/purchase'),
        ),
      ],
    );
  }

  Widget _buildFaqSection(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.infoFAQTitle,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        _FaqItem(
          question: l10n.vipFaqCanCancel,
          answer: l10n.vipFaqCanCancelAnswer,
        ),
        _FaqItem(
          question: l10n.vipFaqWhenEffective,
          answer: l10n.vipFaqWhenEffectiveAnswer,
        ),
        _FaqItem(
          question: l10n.vipFaqHowToUpgrade,
          answer: l10n.vipFaqHowToUpgradeAnswer,
        ),
      ],
    );
  }
}

class _BenefitItem {
  _BenefitItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color color;
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({
    required this.title,
    required this.price,
    required this.period,
    required this.features,
    required this.isPrimary,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String price;
  final String period;
  final List<String> features;
  final bool isPrimary;
  final String? badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          color: isPrimary ? AppColors.primary.withValues(alpha: 0.08) : null,
          borderRadius: AppRadius.allMedium,
          border: Border.all(
            color: isPrimary ? AppColors.primary : AppColors.dividerLight,
            width: isPrimary ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                      if (badge != null) ...[
                        AppSpacing.hSm,
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: AppRadius.allPill,
                          ),
                          child: Text(
                            badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  AppSpacing.vSm,
                  ...features.map((f) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          children: [
                            const Icon(Icons.check, size: 14, color: AppColors.success),
                            const SizedBox(width: 4),
                            Text(f,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondaryLight)),
                          ],
                        ),
                      )),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  price,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isPrimary ? AppColors.primary : null,
                  ),
                ),
                Text(
                  period,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  const _FaqItem({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => setState(() => _isExpanded = !_isExpanded),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.question,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                ),
                AnimatedRotation(
                  turns: _isExpanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: const Icon(Icons.expand_more, size: 20),
                ),
              ],
            ),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          secondChild: Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              widget.answer,
              style: const TextStyle(
                color: AppColors.textSecondaryLight,
                fontSize: 13,
              ),
            ),
          ),
          crossFadeState: _isExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
