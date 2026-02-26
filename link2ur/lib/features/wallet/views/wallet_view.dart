import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/external_web_view.dart';
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
    return BlocBuilder<WalletBloc, WalletState>(
        buildWhen: (previous, current) =>
            previous.isLoading != current.isLoading ||
            previous.pointsAccount != current.pointsAccount ||
            previous.errorMessage != current.errorMessage ||
            previous.transactions != current.transactions,
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
                                _PointsCard(
                                  account: state.pointsAccount!,
                                  connectBalance: state.connectBalance,
                                ),
                              AppSpacing.vLg,
                              // 快捷操作卡片 - 与iOS对齐
                              const _QuickActionCards(),
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
      );
  }
}

// ==================== 子组件 ====================

class _PointsCard extends StatefulWidget {
  const _PointsCard({required this.account, this.connectBalance});
  final PointsAccount account;
  final StripeConnectBalance? connectBalance;

  @override
  State<_PointsCard> createState() => _PointsCardState();
}

class _PointsCardState extends State<_PointsCard> {
  // 3D 倾斜角度（弧度），范围 ±0.03 rad ≈ ±1.7°
  double _rotateX = 0;
  double _rotateY = 0;

  void _onPanUpdate(DragUpdateDetails d) {
    setState(() {
      _rotateY = (d.localPosition.dx / context.size!.width - 0.5) * 0.06;
      _rotateX = -(d.localPosition.dy / context.size!.height - 0.5) * 0.06;
    });
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() { _rotateX = 0; _rotateY = 0; });
  }

  @override
  Widget build(BuildContext context) {
    // 分离 Transform 和装饰：AnimatedContainer 只做 transform 动画，
    // boxShadow 放在静态 Container 里，避免每帧 pan 手势触发阴影插值。
    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        transformAlignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001) // 透视
          ..rotateX(_rotateX)
          ..rotateY(_rotateY),
        child: Container(
        padding: AppSpacing.allLg,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientPrimary,
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
              context.l10n.walletUnwithdrawnIncome,
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
            AppSpacing.vSm,
            // 未提现收入 — Connect available 余额（£）
            Text(
              Helpers.formatPrice(widget.connectBalance?.available ?? 0),
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                height: 1.1,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            AppSpacing.vLg,
            // 累计收入 / 累计消费 — 便士转英镑（/100）
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _BalanceStatItem(
                  label: context.l10n.walletTotalEarned,
                  value: Helpers.formatPrice(widget.account.totalEarned / 100),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
                _BalanceStatItem(
                  label: context.l10n.walletTotalSpent,
                  value: Helpers.formatPrice(widget.account.totalSpent / 100),
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// 快捷操作卡片 - 与iOS对齐：积分与优惠券 + 提现管理
class _QuickActionCards extends StatelessWidget {
  const _QuickActionCards();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickActionCard(
            icon: Icons.card_giftcard_rounded,
            title: context.l10n.profilePointsCoupons,
            gradientColors: AppColors.gradientPrimary,
            onTap: () => context.push('/coupon-points'),
          ),
        ),
        AppSpacing.hMd,
        Expanded(
          child: _QuickActionCard(
            icon: Icons.trending_up_rounded,
            title: context.l10n.walletPayoutManagement,
            gradientColors: AppColors.gradientEmerald,
            onTap: () => context.push('/payment/stripe-connect/payouts'),
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

// _CheckInButton 已移除 —— 签到功能统一由优惠券页入口提供

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
          ListTile(
            contentPadding: AppSpacing.horizontalMd,
            leading: const Icon(Icons.open_in_browser_outlined, size: 20),
            title: Text(context.l10n.stripeConnectOpenDashboard),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () async {
              final repo = context.read<PaymentRepository>();
              try {
                final details = await repo.getStripeConnectAccountDetails();
                final url = details.dashboardUrl;
                if (!context.mounted) return;
                if (url != null && url.isNotEmpty) {
                  await ExternalWebView.openInApp(
                    context,
                    url: url,
                    title: context.l10n.stripeConnectOpenDashboard,
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.stripeConnectDashboardUnavailable)),
                  );
                }
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.stripeConnectDashboardUnavailable)),
                );
              }
            },
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
                  onTap: () => context.push('/coupon-points'),
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
              lineWidth: 1.5,
            ),
          ),
        AppSpacing.vSm,
        if (transactions.isEmpty)
          EmptyStateView.noData(
            context,
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
        // 「查看全部」已跳转至优惠券积分页，不再加载更多
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
      title: Text(_localizePointsType(context, transaction.type)),
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
            context,
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
      subtitle: Text('${_localizeCouponType(context, coupon.type)} · ${coupon.discountDisplayFormatted}'),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:
              userCoupon.isUsable ? AppColors.successLight : AppColors.errorLight,
          borderRadius: AppRadius.allTiny,
        ),
        child: Text(
          _localizeCouponStatus(context, userCoupon.status),
          style: TextStyle(
            fontSize: 12,
            color: userCoupon.isUsable ? AppColors.success : AppColors.error,
          ),
        ),
      ),
    );
  }
}

String _localizePointsType(BuildContext context, String type) {
  final l10n = context.l10n;
  switch (type) {
    case 'earn':
      return l10n.pointsTypeEarn;
    case 'spend':
      return l10n.pointsTypeSpend;
    case 'refund':
      return l10n.pointsTypeRefund;
    case 'expire':
      return l10n.pointsTypeExpire;
    case 'coupon_redeem':
      return l10n.pointsTypeCouponRedeem;
    default:
      return type;
  }
}

String _localizeCouponType(BuildContext context, String type) {
  final l10n = context.l10n;
  switch (type) {
    case 'fixed_amount':
      return l10n.couponTypeFixedAmount;
    case 'percentage':
      return l10n.couponTypePercentage;
    default:
      return type;
  }
}

String _localizeCouponStatus(BuildContext context, String status) {
  final l10n = context.l10n;
  switch (status) {
    case 'unused':
      return l10n.couponStatusUnused;
    case 'used':
      return l10n.couponStatusUsed;
    case 'expired':
      return l10n.couponStatusExpired;
    default:
      return status;
  }
}
