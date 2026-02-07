import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';

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
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 40),
                      Icon(Icons.workspace_premium,
                          size: 56, color: Colors.white),
                      SizedBox(height: 8),
                      Text(
                        'VIP 会员',
                        style: TextStyle(
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
                child: const Text(
                  '普通用户',
                  style: TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          const Text(
            '升级VIP，解锁更多特权',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          AppSpacing.vSm,
          Text(
            '享受专属权益，提升任务效率',
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
              child: const Text(
                '立即升级',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsSection(BuildContext context) {
    final benefits = [
      const _BenefitItem(
        icon: Icons.bolt,
        title: '优先推荐',
        description: '任务和帖子获得更高曝光度',
        color: AppColors.primary,
      ),
      const _BenefitItem(
        icon: Icons.verified,
        title: 'VIP标识',
        description: '独特VIP身份标识，提升信任度',
        color: Color(0xFFFFD700),
      ),
      const _BenefitItem(
        icon: Icons.discount,
        title: '手续费优惠',
        description: '平台手续费享受折扣',
        color: AppColors.success,
      ),
      const _BenefitItem(
        icon: Icons.support_agent,
        title: '专属客服',
        description: '优先客服响应，快速解决问题',
        color: AppColors.accentPink,
      ),
      const _BenefitItem(
        icon: Icons.card_giftcard,
        title: '专属优惠券',
        description: '每月赠送专属优惠券',
        color: AppColors.accent,
      ),
      const _BenefitItem(
        icon: Icons.analytics,
        title: '数据分析',
        description: '查看任务和帖子的详细数据统计',
        color: Colors.teal,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VIP 专属权益',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '会员套餐',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        _PlanCard(
          title: '月度会员',
          price: '\$4.99',
          period: '/ 月',
          features: const ['全部VIP权益', '随时取消'],
          isPrimary: false,
          onTap: () => context.push('/vip/purchase'),
        ),
        AppSpacing.vSm,
        _PlanCard(
          title: '年度会员',
          price: '\$39.99',
          period: '/ 年',
          features: const ['全部VIP权益', '节省33%', '额外赠送3张优惠券'],
          isPrimary: true,
          badge: '最划算',
          onTap: () => context.push('/vip/purchase'),
        ),
      ],
    );
  }

  Widget _buildFaqSection(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '常见问题',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        _FaqItem(
          question: 'VIP会员可以退款吗？',
          answer: '会员订阅可在试用期内免费取消。超过试用期后，当期费用不予退还，但您可以在下一个计费周期前取消。',
        ),
        _FaqItem(
          question: '会员权益何时生效？',
          answer: '付款成功后立即生效，您可以立刻享受所有VIP权益。',
        ),
        _FaqItem(
          question: '如何取消自动续费？',
          answer: '在"设置-会员管理"中可以随时取消自动续费。取消后，当期会员权益仍可使用至到期日。',
        ),
      ],
    );
  }
}

class _BenefitItem {
  const _BenefitItem({
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
