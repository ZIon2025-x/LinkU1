import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sparkline_chart.dart';
import '../../../data/models/coupon_points.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/coupon_points_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../bloc/wallet_bloc.dart';

/// 钱包页面
/// 显示积分余额、交易记录、优惠券和Stripe Connect状态
class WalletView extends StatelessWidget {
  const WalletView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => WalletBloc(
        couponPointsRepository: context.read<CouponPointsRepository>(),
        paymentRepository: context.read<PaymentRepository>(),
      )..add(const WalletLoadRequested()),
      child: const _WalletContent(),
    );
  }
}

class _WalletContent extends StatelessWidget {
  const _WalletContent();

  @override
  Widget build(BuildContext context) {
    return BlocListener<WalletBloc, WalletState>(
      listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
      listener: (context, state) {
        if (state.actionMessage != null) {
          final isError = state.actionMessage!.contains('失败');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.actionMessage!),
              backgroundColor: isError ? AppColors.error : AppColors.success,
            ),
          );
        }
      },
      child: BlocBuilder<WalletBloc, WalletState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.profileMyWallet),
            ),
            body: state.isLoading && state.pointsAccount == null
                ? const LoadingView()
                : state.errorMessage != null && state.pointsAccount == null
                    ? ErrorStateView(
                        message: state.errorMessage!,
                        onRetry: () => context
                            .read<WalletBloc>()
                            .add(const WalletLoadRequested()),
                      )
                    : RefreshIndicator(
                        onRefresh: () async {
                          context
                              .read<WalletBloc>()
                              .add(const WalletLoadRequested());
                        },
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: AppSpacing.allMd,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (state.pointsAccount != null)
                                _PointsCard(account: state.pointsAccount!),
                              AppSpacing.vLg,
                              // 快捷操作卡片 - 与iOS对齐
                              const _QuickActionCards(),
                              AppSpacing.vLg,
                              _CheckInButton(
                                isCheckingIn: state.isCheckingIn,
                                onPressed: () => context
                                    .read<WalletBloc>()
                                    .add(const WalletCheckIn()),
                              ),
                              AppSpacing.vLg,
                              if (state.stripeConnectStatus != null)
                                _StripeConnectSection(
                                    status: state.stripeConnectStatus!),
                              AppSpacing.vLg,
                              _TransactionsSection(
                                transactions: state.transactions,
                                hasMore: state.hasMoreTransactions,
                                onLoadMore: () => context
                                    .read<WalletBloc>()
                                    .add(const WalletLoadMoreTransactions()),
                              ),
                              AppSpacing.vLg,
                              _CouponsSection(coupons: state.coupons),
                            ],
                          ),
                        ),
                      ),
          );
        },
      ),
    );
  }
}

// ==================== 子组件 ====================

class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.account});
  final PointsAccount account;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.walletPointsBalance,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          AppSpacing.vSm,
          // 余额大字体 - 与iOS对齐使用48pt
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                account.balanceDisplay,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              AppSpacing.hSm,
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  account.currency,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vLg,
          // 统计项 - 白色文字
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _BalanceStatItem(
                label: context.l10n.walletTotalEarned,
                value: account.totalEarned.toString(),
              ),
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              _BalanceStatItem(
                label: context.l10n.walletTotalSpent,
                value: account.totalSpent.toString(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 快捷操作卡片 - 与iOS QuickActionCard对齐
class _QuickActionCards extends StatelessWidget {
  const _QuickActionCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.account_balance_wallet_outlined,
            title: context.l10n.walletTopUp,
            gradientColors: const [Color(0xFF2659F2), Color(0xFF4088FF)],
            onTap: () => context.push('/wallet/top-up'),
          ),
        ),
        AppSpacing.hMd,
        Expanded(
          child: _QuickActionCard(
            icon: Icons.send_rounded,
            title: context.l10n.walletTransfer,
            gradientColors: const [Color(0xFF26BF73), Color(0xFF4DD99B)],
            onTap: () => context.push('/wallet/transfer'),
          ),
        ),
        AppSpacing.hMd,
        Expanded(
          child: _QuickActionCard(
            icon: Icons.history_rounded,
            title: context.l10n.walletTransactionHistory,
            gradientColors: const [Color(0xFFFFA600), Color(0xFFFFBF4D)],
            onTap: () => context.push('/wallet/transactions'),
          ),
        ),
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.gradientColors,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 渐变图标背景
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: gradientColors.first.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// 余额卡片内统计项 (白色文字)
class _BalanceStatItem extends StatelessWidget {
  const _BalanceStatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: 0.95),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

// _StatItem 已被 _BalanceStatItem 替代

class _CheckInButton extends StatelessWidget {
  const _CheckInButton({required this.isCheckingIn, required this.onPressed});
  final bool isCheckingIn;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PrimaryButton(
      text: isCheckingIn ? context.l10n.walletCheckingIn : context.l10n.walletDailyCheckIn,
      icon: Icons.check_circle_outline,
      onPressed: isCheckingIn ? null : onPressed,
      isLoading: isCheckingIn,
    );
  }
}

class _StripeConnectSection extends StatelessWidget {
  const _StripeConnectSection({required this.status});
  final StripeConnectStatus status;

  @override
  Widget build(BuildContext context) {
    return GroupedCard(
      header: Padding(
        padding: AppSpacing.horizontalMd,
        child: Text(context.l10n.walletPayoutAccount,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      children: [
        ListTile(
          contentPadding: AppSpacing.horizontalMd,
          title: const Text('Stripe Connect'),
          subtitle: Text(
            status.isFullyActive
                ? context.l10n.walletActivated
                : status.isConnected
                    ? context.l10n.walletConnectedPending
                    : context.l10n.walletNotConnected,
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: status.isFullyActive
                  ? AppColors.successLight
                  : status.isConnected
                      ? AppColors.warningLight
                      : AppColors.errorLight,
              borderRadius: AppRadius.allTiny,
            ),
            child: Text(
              status.isFullyActive
                  ? context.l10n.walletActivatedShort
                  : status.isConnected
                      ? context.l10n.walletPendingActivation
                      : context.l10n.walletNotConnectedShort,
              style: TextStyle(
                fontSize: 12,
                color: status.isFullyActive
                    ? AppColors.success
                    : status.isConnected
                        ? AppColors.warning
                        : AppColors.error,
              ),
            ),
          ),
        ),
        if (status.isFullyActive) ...[
          ListTile(
            contentPadding: AppSpacing.horizontalMd,
            leading: const Icon(Icons.payments_outlined, size: 20),
            title: Text(context.l10n.walletPayoutRecordsFull),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/payment/stripe-connect/payments'),
          ),
          ListTile(
            contentPadding: AppSpacing.horizontalMd,
            leading: const Icon(Icons.account_balance_outlined, size: 20),
            title: Text(context.l10n.walletWithdrawalRecords),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/payment/stripe-connect/payouts'),
          ),
        ],
        if (!status.isFullyActive)
          Padding(
            padding: AppSpacing.horizontalMd,
            child: SecondaryButton(
              text: status.isConnected ? context.l10n.walletViewAccountDetail : context.l10n.walletSetupPayoutAccount,
              onPressed: () =>
                  context.push('/payment/stripe-connect/onboarding'),
            ),
          ),
      ],
    );
  }
}

class _TransactionsSection extends StatelessWidget {
  const _TransactionsSection({
    required this.transactions,
    required this.hasMore,
    required this.onLoadMore,
  });
  final List<PointsTransaction> transactions;
  final bool hasMore;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.horizontalMd,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(context.l10n.walletTransactionHistory,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              if (transactions.isNotEmpty)
                GestureDetector(
                  onTap: () => context.push('/wallet/transactions'),
                  child: Text(
                    context.l10n.walletViewAll,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppSpacing.vSm,
        // 积分趋势迷你折线图
        if (transactions.length >= 3)
          Padding(
            padding: AppSpacing.horizontalMd,
            child: SparklineChart(
              data: transactions
                  .take(20)
                  .toList()
                  .reversed
                  .map((t) => t.balanceAfter.toDouble())
                  .toList(),
              height: 50,
              color: AppColors.primary,
              fillGradient: true,
              lineWidth: 1.5,
            ),
          ),
        AppSpacing.vSm,
        if (transactions.isEmpty)
          EmptyStateView.noData(
            title: context.l10n.walletNoTransactions,
            description: context.l10n.walletTransactionsDesc,
          )
        else
          GroupedCard(
            children: transactions
                .take(10)
                .map((t) => _TransactionItem(transaction: t))
                .toList(),
          ),
        if (hasMore && transactions.length > 10)
          Padding(
            padding: AppSpacing.allMd,
            child: TextButton(
              onPressed: onLoadMore,
              child: Text(context.l10n.walletViewMore),
            ),
          ),
      ],
    );
  }
}

class _TransactionItem extends StatelessWidget {
  const _TransactionItem({required this.transaction});
  final PointsTransaction transaction;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppSpacing.horizontalMd,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: transaction.isIncome
              ? AppColors.successLight
              : AppColors.errorLight,
          shape: BoxShape.circle,
        ),
        child: Icon(
          transaction.isIncome ? Icons.add : Icons.remove,
          color: transaction.isIncome ? AppColors.success : AppColors.error,
          size: 20,
        ),
      ),
      title: Text(transaction.typeText),
      subtitle: Text(
        transaction.description ?? transaction.source ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${transaction.isIncome ? '+' : '-'}${transaction.amountDisplay}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color:
                  transaction.isIncome ? AppColors.success : AppColors.error,
            ),
          ),
          if (transaction.createdAt != null)
            Text(
              _formatDate(context, transaction.createdAt!),
              style:
                  const TextStyle(fontSize: 12, color: AppColors.textTertiaryLight),
            ),
        ],
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inDays == 0) return context.l10n.walletToday;
    if (difference.inDays == 1) return context.l10n.walletYesterday;
    if (difference.inDays < 7) return context.l10n.timeDaysAgo(difference.inDays);
    return '${date.month}/${date.day}';
  }
}

class _CouponsSection extends StatelessWidget {
  const _CouponsSection({required this.coupons});
  final List<UserCoupon> coupons;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.horizontalMd,
          child: Text(context.l10n.walletMyCoupons,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
        AppSpacing.vSm,
        if (coupons.isEmpty)
          EmptyStateView.noData(
            title: context.l10n.walletNoCoupons,
            description: context.l10n.walletNoCouponsDesc,
          )
        else
          GroupedCard(
            children:
                coupons.take(5).map((uc) => _CouponItem(userCoupon: uc)).toList(),
          ),
      ],
    );
  }
}

class _CouponItem extends StatelessWidget {
  const _CouponItem({required this.userCoupon});
  final UserCoupon userCoupon;

  @override
  Widget build(BuildContext context) {
    final coupon = userCoupon.coupon;
    return ListTile(
      contentPadding: AppSpacing.horizontalMd,
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: AppRadius.allSmall,
        ),
        child: const Icon(Icons.card_giftcard, color: AppColors.primary),
      ),
      title: Text(coupon.name),
      subtitle: Text('${coupon.typeText} · ${coupon.discountValueDisplay}'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              userCoupon.isUsable ? AppColors.successLight : AppColors.errorLight,
          borderRadius: AppRadius.allTiny,
        ),
        child: Text(
          userCoupon.statusText,
          style: TextStyle(
            fontSize: 12,
            color: userCoupon.isUsable ? AppColors.success : AppColors.error,
          ),
        ),
      ),
    );
  }
}
