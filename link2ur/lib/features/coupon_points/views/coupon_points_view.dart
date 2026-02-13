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
          final isError = state.actionMessage!.contains('failed');
          final message = switch (state.actionMessage) {
            'check_in_success' => context.l10n.actionCheckInSuccess,
            'check_in_failed' => state.errorMessage != null
                ? '${context.l10n.actionCheckInFailed}: ${state.errorMessage}'
                : context.l10n.actionCheckInFailed,
            'coupon_claimed' => context.l10n.actionCouponClaimed,
            'coupon_redeemed' => context.l10n.actionCouponRedeemed,
            'invite_code_used' => context.l10n.actionInviteCodeUsed,
            'claim_failed' => state.errorMessage != null
                ? '${context.l10n.actionSubmitFailed}: ${state.errorMessage}'
                : context.l10n.actionSubmitFailed,
            'redeem_failed' => state.errorMessage != null
                ? '${context.l10n.actionSubmitFailed}: ${state.errorMessage}'
                : context.l10n.actionSubmitFailed,
            'invite_code_failed' => state.errorMessage != null
                ? '${context.l10n.actionSubmitFailed}: ${state.errorMessage}'
                : context.l10n.actionSubmitFailed,
            _ => state.actionMessage ?? '',
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: isError ? AppColors.error : AppColors.success,
            ),
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
            tabs: [
              Tab(text: context.l10n.couponPointsTab),
              Tab(text: context.l10n.couponCouponsTab),
              Tab(text: context.l10n.couponCheckInTab),
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
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // 积分卡片
              SliverPadding(
                padding: AppSpacing.allMd,
                sliver: SliverToBoxAdapter(
                  child: Container(
                    width: double.infinity,
                    padding: AppSpacing.allLg,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: AppColors.gradientGold,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: AppRadius.allLarge,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.pointsBalance,
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
                          '${context.l10n.pointsTotalEarned}: ${state.pointsAccount.totalEarned}  ${context.l10n.pointsTotalSpent}: ${state.pointsAccount.totalSpent}',
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        AppSpacing.vMd,
                        Row(
                          children: [
                            _PointActionButton(
                              icon: Icons.card_giftcard,
                              label: context.l10n.couponRedeemReward,
                              onTap: () {
                                context
                                    .read<CouponPointsBloc>()
                                    .add(const CouponPointsLoadAvailableCoupons());
                              },
                            ),
                            AppSpacing.hMd,
                            _PointActionButton(
                              icon: Icons.confirmation_number,
                              label: context.l10n.couponRedeemCode,
                              onTap: () => _showRedemptionCodeDialog(context),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 积分记录标题
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.l10n.pointsTransactionHistory,
                    style: AppTypography.title3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ),

              // 积分记录列表 — 使用 SliverList 实现虚拟化渲染
              if (state.transactions.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyStateView.noData(context, title: context.l10n.couponNoPointsRecords),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  sliver: SliverList.builder(
                    itemCount: state.transactions.length,
                    itemBuilder: (context, index) {
                      final tx = state.transactions[index];
                      return _TransactionRow(transaction: tx);
                    },
                  ),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: AppSpacing.md)),
            ],
          ),
        );
      },
    );
  }

  void _showRedemptionCodeDialog(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.couponEnterInviteCodeTitle),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: context.l10n.couponEnterInviteCodeHint,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
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
            child: Text(context.l10n.commonConfirm),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
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
                    context.l10n.couponAvailable,
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
                  context.l10n.walletMyCoupons,
                  style: AppTypography.title3.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                AppSpacing.vMd,

                if (state.myCoupons.isEmpty)
                  EmptyStateView.noData(context, title: context.l10n.couponNoCoupons)
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
                    context.l10n.couponMinAmountAvailable(coupon.minAmountDisplay),
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
            text: context.l10n.couponClaim,
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

    return Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: (isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight)
              .withValues(alpha: isUsable ? 1.0 : 0.6),
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
                      context.l10n.couponValidUntil(_formatDate(coupon.validUntil!)),
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
                        context.l10n.walletDailyCheckIn,
                        style: AppTypography.title3.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      AppSpacing.vSm,
                      Text(
                        context.l10n.couponConsecutiveDays(state.consecutiveDays),
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
                              ? context.l10n.pointsCheckedInToday
                              : context.l10n.pointsCheckInReward,
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
                Builder(
                  builder: (ctx) => _buildRewardSection(ctx, isDark, state),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRewardSection(BuildContext context, bool isDark, CouponPointsState state) {
    // 签到活动尚未开放，显示占位文案
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.l10n.couponCheckInReward,
          style: AppTypography.title3.copyWith(
            color: isDark
                ? AppColors.textPrimaryDark
                : AppColors.textPrimaryLight,
          ),
        ),
        AppSpacing.vMd,
        Container(
          width: double.infinity,
          padding: AppSpacing.allLg,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allMedium,
          ),
          child: Column(
            children: [
              Icon(
                Icons.event_available_rounded,
                size: 48,
                color: AppColors.textSecondaryLight.withValues(alpha: 0.5),
              ),
              AppSpacing.vMd,
              Text(
                context.l10n.couponCheckInComingSoon,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// _RewardRow 已移除 —— 签到奖励区域改为占位文案
