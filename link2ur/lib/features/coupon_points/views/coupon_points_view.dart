import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/coupon_points.dart';
import '../../../data/repositories/coupon_points_repository.dart';
import '../bloc/coupon_points_bloc.dart';

/// 优惠券积分视图
/// 参考iOS CouponPointsView.swift
class CouponPointsView extends StatelessWidget {
  const CouponPointsView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CouponPointsBloc(
        couponPointsRepository: context.read<CouponPointsRepository>(),
      )..add(const CouponPointsLoadRequested()),
      child: const _CouponPointsContent(),
    );
  }
}

class _CouponPointsContent extends StatefulWidget {
  const _CouponPointsContent();

  @override
  State<_CouponPointsContent> createState() => _CouponPointsContentState();
}

class _CouponPointsContentState extends State<_CouponPointsContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final bloc = context.read<CouponPointsBloc>();
      switch (_tabController.index) {
        case 0:
          bloc.add(const CouponPointsLoadTransactions());
          break;
        case 1:
          bloc.add(const CouponPointsLoadMyCoupons());
          bloc.add(const CouponPointsLoadAvailableCoupons());
          break;
        case 2:
          bloc.add(const CouponPointsLoadCheckInStatus());
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<CouponPointsBloc, CouponPointsState>(
      listenWhen: (prev, curr) => curr.actionMessage != null,
      listener: (context, state) {
        if (state.actionMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.actionMessage!)),
          );
        }
      },
      child: Scaffold(
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
        body: BlocBuilder<CouponPointsBloc, CouponPointsState>(
          builder: (context, state) {
            if (state.status == CouponPointsStatus.loading) {
              return const LoadingView();
            }

            if (state.status == CouponPointsStatus.error) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '',
                onRetry: () => context
                    .read<CouponPointsBloc>()
                    .add(const CouponPointsLoadRequested()),
              );
            }

            return TabBarView(
              controller: _tabController,
              children: const [
                _PointsTab(),
                _CouponsTab(),
                _CheckInTab(),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 积分页签
class _PointsTab extends StatelessWidget {
  const _PointsTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<CouponPointsBloc, CouponPointsState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<CouponPointsBloc>()
                .add(const CouponPointsLoadRequested());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                      Text(
                        state.pointsAccount.balanceDisplay,
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      AppSpacing.vSm,
                      Text(
                        '累计获得: ${state.pointsAccount.totalEarned}  已使用: ${state.pointsAccount.totalSpent}',
                        style: AppTypography.caption.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                      AppSpacing.vMd,
                      Row(
                        children: [
                          _PointActionButton(
                            icon: Icons.card_giftcard,
                            label: '兑换奖励',
                            onTap: () {
                              context
                                  .read<CouponPointsBloc>()
                                  .add(const CouponPointsLoadAvailableCoupons());
                            },
                          ),
                          AppSpacing.hMd,
                          _PointActionButton(
                            icon: Icons.confirmation_number,
                            label: '兑换码',
                            onTap: () => _showRedemptionCodeDialog(context),
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

                if (state.transactions.isEmpty)
                  EmptyStateView.noData(title: '暂无积分记录')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: state.transactions.length,
                    itemBuilder: (context, index) {
                      final tx = state.transactions[index];
                      return _TransactionRow(transaction: tx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showRedemptionCodeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('输入邀请码'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入邀请码或兑换码',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              final code = controller.text.trim();
              if (code.isNotEmpty) {
                context
                    .read<CouponPointsBloc>()
                    .add(CouponPointsUseInvitationCode(code));
                Navigator.pop(ctx);
              }
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
  }
}

/// 积分交易记录行
class _TransactionRow extends StatelessWidget {
  const _TransactionRow({required this.transaction});

  final PointsTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: transaction.isIncome
                  ? AppColors.success.withValues(alpha: 0.1)
                  : AppColors.error.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              transaction.isIncome
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              size: 18,
              color:
                  transaction.isIncome ? AppColors.success : AppColors.error,
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description ?? transaction.typeText,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (transaction.createdAt != null)
                  Text(
                    _formatDate(transaction.createdAt!),
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            '${transaction.isIncome ? '+' : ''}${transaction.amount}',
            style: AppTypography.bodyBold.copyWith(
              color:
                  transaction.isIncome ? AppColors.success : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
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
  const _CouponsTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CouponPointsBloc, CouponPointsState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<CouponPointsBloc>()
                .add(const CouponPointsLoadMyCoupons());
            context
                .read<CouponPointsBloc>()
                .add(const CouponPointsLoadAvailableCoupons());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: AppSpacing.allMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 可领取的优惠券
                if (state.availableCoupons.isNotEmpty) ...[
                  Text(
                    '可领取',
                    style: AppTypography.title3.copyWith(
                      color:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                    ),
                  ),
                  AppSpacing.vMd,
                  ...state.availableCoupons.map((coupon) => _AvailableCouponCard(
                        coupon: coupon,
                        isSubmitting: state.isSubmitting,
                      )),
                  AppSpacing.vLg,
                ],

                // 我的优惠券
                Text(
                  '我的优惠券',
                  style: AppTypography.title3.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                AppSpacing.vMd,

                if (state.myCoupons.isEmpty)
                  EmptyStateView.noData(title: '暂无优惠券')
                else
                  ...state.myCoupons
                      .map((coupon) => _MyCouponCard(coupon: coupon)),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// 可领取优惠券卡片
class _AvailableCouponCard extends StatelessWidget {
  const _AvailableCouponCard({
    required this.coupon,
    required this.isSubmitting,
  });

  final Coupon coupon;
  final bool isSubmitting;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: AppRadius.allSmall,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  coupon.discountValueDisplay.isNotEmpty
                      ? coupon.discountValueDisplay
                      : '${coupon.discountValue}',
                  style: AppTypography.bodyBold.copyWith(
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
                Text(
                  coupon.typeText,
                  style: AppTypography.caption2.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coupon.name,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (coupon.minAmountDisplay.isNotEmpty)
                  Text(
                    '满 ${coupon.minAmountDisplay} 可用',
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
              ],
            ),
          ),
          SmallActionButton(
            text: '领取',
            onPressed: isSubmitting
                ? null
                : () => context
                    .read<CouponPointsBloc>()
                    .add(CouponPointsClaimCoupon(coupon.id)),
            filled: true,
          ),
        ],
      ),
    );
  }
}

/// 我的优惠券卡片
class _MyCouponCard extends StatelessWidget {
  const _MyCouponCard({required this.coupon});

  final UserCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUsable = coupon.isUsable;

    return Opacity(
      opacity: isUsable ? 1.0 : 0.5,
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (isUsable ? AppColors.accentPink : Colors.grey)
                    .withValues(alpha: 0.1),
                borderRadius: AppRadius.allSmall,
              ),
              child: Icon(
                Icons.local_offer,
                color: isUsable ? AppColors.accentPink : Colors.grey,
              ),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.coupon.name,
                    style: AppTypography.bodyBold.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    coupon.statusText,
                    style: AppTypography.caption.copyWith(
                      color: isUsable ? AppColors.success : Colors.grey,
                    ),
                  ),
                  if (coupon.validUntil != null)
                    Text(
                      '有效期至 ${_formatDate(coupon.validUntil!)}',
                      style: AppTypography.caption2.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// 签到页签
class _CheckInTab extends StatelessWidget {
  const _CheckInTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<CouponPointsBloc, CouponPointsState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<CouponPointsBloc>()
                .add(const CouponPointsLoadCheckInStatus());
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
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
                        '连续签到 ${state.consecutiveDays} 天',
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
                          final isCompleted =
                              index < state.consecutiveDays % 7;
                          final isCurrent =
                              index == state.consecutiveDays % 7;

                          return Column(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isCompleted
                                      ? AppColors.primary
                                      : (isDark
                                          ? AppColors.secondaryBackgroundDark
                                          : AppColors.backgroundLight),
                                  shape: BoxShape.circle,
                                  border: isCurrent
                                      ? Border.all(
                                          color: AppColors.primary,
                                          width: 2)
                                      : null,
                                ),
                                child: Center(
                                  child: isCompleted
                                      ? const Icon(Icons.check,
                                          size: 18, color: Colors.white)
                                      : Text(
                                          '${index + 1}',
                                          style:
                                              AppTypography.caption.copyWith(
                                            color: isDark
                                                ? AppColors.textSecondaryDark
                                                : AppColors
                                                    .textSecondaryLight,
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
                          text: state.isCheckedInToday
                              ? '今日已签到'
                              : '签到领积分',
                          isLoading: state.isSubmitting,
                          onPressed: state.isCheckedInToday ||
                                  state.isSubmitting
                              ? null
                              : () => context
                                  .read<CouponPointsBloc>()
                                  .add(const CouponPointsCheckIn()),
                        ),
                      ),
                    ],
                  ),
                ),

                AppSpacing.vLg,

                // 签到奖励列表
                _buildRewardSection(isDark, state),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardSection(bool isDark, CouponPointsState state) {
    // 使用后端返回的奖励配置，如果没有则显示默认
    final rewards = state.checkInRewards.isNotEmpty
        ? state.checkInRewards
        : [
            {'days': 3, 'reward': '+50积分', 'icon': 'fire'},
            {'days': 7, 'reward': '+100积分 + 优惠券', 'icon': 'star'},
            {'days': 30, 'reward': '+500积分 + VIP体验', 'icon': 'premium'},
          ];

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
        ...rewards.map((reward) {
          final days = reward['days'] ?? 0;
          final rewardText = reward['reward'] ?? '';
          final iconName = reward['icon'] ?? 'star';

          IconData icon;
          Color iconColor;
          switch (iconName) {
            case 'fire':
              icon = Icons.local_fire_department;
              iconColor = AppColors.warning;
              break;
            case 'premium':
              icon = Icons.workspace_premium;
              iconColor = AppColors.purple;
              break;
            default:
              icon = Icons.star;
              iconColor = AppColors.accent;
          }

          final isAchieved = state.consecutiveDays >= (days as int);

          return _RewardRow(
            title: '连续签到$days天',
            reward: rewardText.toString(),
            icon: icon,
            iconColor: iconColor,
            isAchieved: isAchieved,
          );
        }),
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
    this.isAchieved = false,
  });

  final String title;
  final String reward;
  final IconData icon;
  final Color iconColor;
  final bool isAchieved;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
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
          if (isAchieved)
            const Icon(Icons.check_circle, color: AppColors.success, size: 20),
        ],
      ),
    );
  }
}
