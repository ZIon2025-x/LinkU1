import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state_view.dart';

/// 优惠券积分视图
/// 参考iOS CouponPointsView.swift
class CouponPointsView extends StatefulWidget {
  const CouponPointsView({super.key});

  @override
  State<CouponPointsView> createState() => _CouponPointsViewState();
}

class _CouponPointsViewState extends State<CouponPointsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.profilePointsCoupons),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: '积分'),
            Tab(text: '优惠券'),
            Tab(text: '签到'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PointsTab(),
          _CouponsTab(),
          _CheckInTab(),
        ],
      ),
    );
  }
}

/// 积分页签
class _PointsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 积分卡片
          Container(
            width: double.infinity,
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.allLarge,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '我的积分',
                  style: AppTypography.subheadline.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                AppSpacing.vSm,
                const Text(
                  '0',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                AppSpacing.vMd,
                Row(
                  children: [
                    _PointActionButton(
                      icon: Icons.card_giftcard,
                      label: '兑换奖励',
                      onTap: () {},
                    ),
                    AppSpacing.hMd,
                    _PointActionButton(
                      icon: Icons.confirmation_number,
                      label: '兑换码',
                      onTap: () {},
                    ),
                  ],
                ),
              ],
            ),
          ),

          AppSpacing.vLg,

          // 积分记录
          Text(
            '积分记录',
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,

          // 空状态
          EmptyStateView.noData(
            title: '暂无积分记录',
          ),
        ],
      ),
    );
  }
}

class _PointActionButton extends StatelessWidget {
  const _PointActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: AppRadius.allSmall,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTypography.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 优惠券页签
class _CouponsTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 兑换码输入
          _RedemptionCodeInput(),
          AppSpacing.vLg,
          // 优惠券列表
          Expanded(
            child: EmptyStateView.noData(
              title: '暂无优惠券',
            ),
          ),
        ],
      ),
    );
  }
}

/// 兑换码输入组件
class _RedemptionCodeInput extends StatelessWidget {
  final TextEditingController _controller = TextEditingController();

  _RedemptionCodeInput();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                hintText: '输入兑换码',
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          AppSpacing.hSm,
          SmallActionButton(
            text: '兑换',
            onPressed: () {},
            filled: true,
          ),
        ],
      ),
    );
  }
}

/// 签到页签
class _CheckInTab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        children: [
          // 签到日历卡片
          Container(
            width: double.infinity,
            padding: AppSpacing.allLg,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.cardBackgroundLight,
              borderRadius: AppRadius.allLarge,
            ),
            child: Column(
              children: [
                Text(
                  '每日签到',
                  style: AppTypography.title3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                AppSpacing.vSm,
                Text(
                  '连续签到可获得更多积分奖励',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                AppSpacing.vLg,

                // 签到天数展示（7天）
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(7, (index) {
                    return Column(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: index < 0
                                ? AppColors.primary
                                : (isDark
                                    ? AppColors.secondaryBackgroundDark
                                    : AppColors.backgroundLight),
                            shape: BoxShape.circle,
                            border: index == 0
                                ? Border.all(
                                    color: AppColors.primary, width: 2)
                                : null,
                          ),
                          child: Center(
                            child: index < 0
                                ? const Icon(Icons.check,
                                    size: 18, color: Colors.white)
                                : Text(
                                    '${index + 1}',
                                    style: AppTypography.caption.copyWith(
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '+${(index + 1) * 5}',
                          style: AppTypography.caption2.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ],
                    );
                  }),
                ),

                AppSpacing.vLg,

                SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    text: '签到领积分',
                    onPressed: () {},
                  ),
                ),
              ],
            ),
          ),

          AppSpacing.vLg,

          // 签到奖励列表
          _buildRewardSection(isDark, context),
        ],
      ),
    );
  }

  Widget _buildRewardSection(bool isDark, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '签到奖励',
          style: AppTypography.title3.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        AppSpacing.vMd,
        _RewardRow(
          title: '连续签到3天',
          reward: '+50积分',
          icon: Icons.local_fire_department,
          iconColor: AppColors.warning,
        ),
        _RewardRow(
          title: '连续签到7天',
          reward: '+100积分 + 优惠券',
          icon: Icons.star,
          iconColor: AppColors.accent,
        ),
        _RewardRow(
          title: '连续签到30天',
          reward: '+500积分 + VIP体验',
          icon: Icons.workspace_premium,
          iconColor: AppColors.purple,
        ),
      ],
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.title,
    required this.reward,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String reward;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Icon(icon, size: 24, color: iconColor),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  reward,
                  style: AppTypography.caption.copyWith(
                    color: iconColor,
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
