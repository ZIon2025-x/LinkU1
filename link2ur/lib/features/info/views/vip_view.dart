import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/responsive.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/iap_service.dart';
import '../../auth/bloc/auth_bloc.dart';

/// VIP 会员中心页
/// 参考iOS VIPView.swift
/// 展示会员状态、权益、历史记录
class VipView extends StatefulWidget {
  const VipView({super.key});

  @override
  State<VipView> createState() => _VipViewState();
}

class _VipViewState extends State<VipView> {
  Map<String, dynamic>? _vipStatus;
  bool _isLoadingStatus = false;
  bool? _localAutoRenew;

  @override
  void initState() {
    super.initState();
    _loadVipInfo();
  }

  Future<void> _loadVipInfo() async {
    final user = context.read<AuthBloc>().state.user;
    final level = user?.userLevel;
    final isVip = level == 'vip' || level == 'super';
    if (!isVip) return;

    setState(() => _isLoadingStatus = true);

    try {
      final status =
          await context.read<UserRepository>().getVipStatus();
      if (mounted) {
        setState(() {
          _vipStatus = status;
          _isLoadingStatus = false;
        });
      }
    } catch (e) {
      AppLogger.error('Failed to load VIP status', e);
      if (mounted) setState(() => _isLoadingStatus = false);
    }

    _loadLocalSubscriptionInfo();
  }

  Future<void> _loadLocalSubscriptionInfo() async {
    try {
      final iap = IAPService.instance;
      final apiService = context.read<ApiService>();
      await iap.ensureInitialized(apiService: apiService);

      final autoRenew = _vipStatus?['subscription']?['auto_renew_status'];
      if (mounted && autoRenew is bool) {
        setState(() => _localAutoRenew = autoRenew);
      }
    } catch (e) {
      AppLogger.error('Failed to load local subscription info', e);
    }
  }

  String _formatExpiryDate(String? dateString) {
    if (dateString == null) return '';
    try {
      final date = DateTime.parse(dateString);
      return DateFormat.yMMMd().format(date);
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) => prev.user?.userLevel != curr.user?.userLevel,
      builder: (context, authState) {
        final isVip = authState.user?.userLevel == 'vip' ||
            authState.user?.userLevel == 'super';

        return Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 200,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(context.l10n.settingsMembership),
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: AppColors.gradientGold,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 40),
                          Icon(
                            isVip ? Icons.workspace_premium : Icons.star_outline,
                            size: 56,
                            color: Colors.white,
                          ),
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

              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.allLg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildStatusCard(context, isVip),
                      AppSpacing.vLg,
                      _buildBenefitsSection(context),
                      AppSpacing.vLg,
                      _buildPlansSection(context),
                      AppSpacing.vLg,
                      _buildFaqSection(context),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusCard(BuildContext context, bool isVip) {
    if (isVip) {
      return _buildVipActiveCard(context);
    }
    return _buildNonVipCard(context);
  }

  Widget _buildVipActiveCard(BuildContext context) {
    final subscription =
        _vipStatus?['subscription'] as Map<String, dynamic>?;
    final expiresDate = subscription?['expires_date'] as String?;

    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: AppColors.gradientGold,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 6),
              Text(
                context.l10n.vipAlreadyVip,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          AppSpacing.vSm,
          Text(
            context.l10n.vipThankYou,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.85),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (_isLoadingStatus) ...[
            AppSpacing.vMd,
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ] else if (expiresDate != null) ...[
            AppSpacing.vMd,
            Text(
              context.l10n.vipExpiryTime(_formatExpiryDate(expiresDate)),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 13,
              ),
            ),
            if (_localAutoRenew != null) ...[
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _localAutoRenew!
                        ? Icons.autorenew
                        : Icons.error_outline,
                    size: 14,
                    color: _localAutoRenew!
                        ? Colors.white
                        : Colors.orange.shade100,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _localAutoRenew!
                        ? context.l10n.vipWillAutoRenew
                        : context.l10n.vipAutoRenewCancelled,
                    style: TextStyle(
                      color: _localAutoRenew!
                          ? Colors.white
                          : Colors.orange.shade100,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildNonVipCard(BuildContext context) {
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.2),
                  borderRadius: AppRadius.allPill,
                ),
                child: Text(
                  context.l10n.vipRegularUser,
                  style: const TextStyle(
                    color: AppColors.gold,
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
                backgroundColor: AppColors.gold,
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
        color: AppColors.gold,
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
            crossAxisCount: ResponsiveUtils.gridColumnCount(context),
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
