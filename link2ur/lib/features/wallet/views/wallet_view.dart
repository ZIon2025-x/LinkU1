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
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.walletPointsBalance,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondaryLight)),
          AppSpacing.vSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(account.balanceDisplay,
                  style: const TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary)),
              AppSpacing.hSm,
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(account.currency,
                    style: const TextStyle(
                        fontSize: 16, color: AppColors.textSecondaryLight)),
              ),
            ],
          ),
          AppSpacing.vMd,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(label: context.l10n.walletTotalEarned, value: account.totalEarned.toString()),
              Container(width: 1, height: 30, color: AppColors.dividerLight),
              _StatItem(label: context.l10n.walletTotalSpent, value: account.totalSpent.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(label,
            style:
                const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
      ],
    );
  }
}

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
          child: Text(context.l10n.walletTransactionHistory,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
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
