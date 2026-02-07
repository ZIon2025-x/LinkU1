import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/models/coupon_points.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/coupon_points_repository.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../core/utils/logger.dart';

/// 钱包页面
/// 显示积分余额、交易记录、优惠券和Stripe Connect状态
class WalletView extends StatefulWidget {
  const WalletView({super.key});

  @override
  State<WalletView> createState() => _WalletViewState();
}

class _WalletViewState extends State<WalletView> {
  PointsAccount? _pointsAccount;
  List<PointsTransaction> _transactions = [];
  List<UserCoupon> _myCoupons = [];
  StripeConnectStatus? _stripeConnectStatus;
  bool _isLoading = true;
  bool _isCheckingIn = false;
  String? _errorMessage;
  int _transactionPage = 1;
  bool _hasMoreTransactions = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final couponRepo = context.read<CouponPointsRepository>();
      final paymentRepo = context.read<PaymentRepository>();

      // 并行加载所有数据
      final results = await Future.wait([
        couponRepo.getPointsAccount(),
        couponRepo.getPointsTransactions(page: 1, pageSize: 20),
        couponRepo.getMyCoupons(),
        paymentRepo.getStripeConnectStatus(),
      ]);

      setState(() {
        _pointsAccount = results[0] as PointsAccount;
        _transactions = results[1] as List<PointsTransaction>;
        _myCoupons = results[2] as List<UserCoupon>;
        _stripeConnectStatus = results[3] as StripeConnectStatus;
        _isLoading = false;
        _hasMoreTransactions = _transactions.length >= 20;
      });
    } catch (e) {
      AppLogger.error('Failed to load wallet data', e);
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  Future<void> _checkIn() async {
    if (_isCheckingIn) return;

    setState(() {
      _isCheckingIn = true;
    });

    try {
      final couponRepo = context.read<CouponPointsRepository>();
      final transaction = await couponRepo.checkIn();

      // 刷新积分账户
      final account = await couponRepo.getPointsAccount();

      setState(() {
        _pointsAccount = account;
        _transactions.insert(0, transaction);
        _isCheckingIn = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('签到成功！'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      AppLogger.error('Failed to check in', e);
      setState(() {
        _isCheckingIn = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('签到失败: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreTransactions() async {
    if (!_hasMoreTransactions || _isLoading) return;

    try {
      final couponRepo = context.read<CouponPointsRepository>();
      final nextPage = _transactionPage + 1;
      final moreTransactions = await couponRepo.getPointsTransactions(
        page: nextPage,
        pageSize: 20,
      );

      setState(() {
        _transactions.addAll(moreTransactions);
        _transactionPage = nextPage;
        _hasMoreTransactions = moreTransactions.length >= 20;
      });
    } catch (e) {
      AppLogger.error('Failed to load more transactions', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的钱包'),
      ),
      body: _isLoading && _pointsAccount == null
          ? const LoadingView()
          : _errorMessage != null && _pointsAccount == null
              ? ErrorStateView(
                  message: _errorMessage!,
                  onRetry: _loadData,
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: AppSpacing.allMd,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 积分余额卡片
                        if (_pointsAccount != null) _buildPointsCard(),
                        AppSpacing.vLg,

                        // 签到按钮
                        _buildCheckInButton(),
                        AppSpacing.vLg,

                        // Stripe Connect状态
                        if (_stripeConnectStatus != null)
                          _buildStripeConnectSection(),
                        AppSpacing.vLg,

                        // 交易记录
                        _buildTransactionsSection(),
                        AppSpacing.vLg,

                        // 我的优惠券
                        _buildCouponsSection(),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildPointsCard() {
    final account = _pointsAccount!;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '积分余额',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                account.balanceDisplay,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              AppSpacing.hSm,
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  account.currency,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('累计获得', account.totalEarned.toString()),
              Container(
                width: 1,
                height: 30,
                color: AppColors.dividerLight,
              ),
              _buildStatItem('累计消费', account.totalSpent.toString()),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckInButton() {
    return PrimaryButton(
      text: _isCheckingIn ? '签到中...' : '每日签到',
      icon: Icons.check_circle_outline,
      onPressed: _isCheckingIn ? null : _checkIn,
      isLoading: _isCheckingIn,
    );
  }

  Widget _buildStripeConnectSection() {
    final status = _stripeConnectStatus!;
    return GroupedCard(
      header: Padding(
        padding: AppSpacing.horizontalMd,
        child: const Text(
          '收款账户',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      children: [
        ListTile(
          contentPadding: AppSpacing.horizontalMd,
          title: const Text('Stripe Connect'),
          subtitle: Text(
            status.isFullyActive
                ? '已激活，可以收款'
                : status.isConnected
                    ? '已连接，等待激活'
                    : '未连接',
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
                  ? '已激活'
                  : status.isConnected
                      ? '待激活'
                      : '未连接',
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
        if (!status.isFullyActive)
          Padding(
            padding: AppSpacing.horizontalMd,
            child: SecondaryButton(
              text: status.isConnected ? '查看账户详情' : '设置收款账户',
              onPressed: () async {
                if (status.onboardingUrl != null) {
                  final uri = Uri.parse(status.onboardingUrl!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                }
              },
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.horizontalMd,
          child: const Text(
            '交易记录',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppSpacing.vSm,
        if (_transactions.isEmpty)
          EmptyStateView.noData(
            title: '暂无交易记录',
            description: '您的积分交易记录将显示在这里',
          )
        else
          GroupedCard(
            children: _transactions
                .take(10)
                .map((transaction) => _buildTransactionItem(transaction))
                .toList(),
          ),
        if (_hasMoreTransactions && _transactions.length > 10)
          Padding(
            padding: AppSpacing.allMd,
            child: TextButton(
              onPressed: _loadMoreTransactions,
              child: const Text('查看更多交易记录'),
            ),
          ),
      ],
    );
  }

  Widget _buildTransactionItem(PointsTransaction transaction) {
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
              color: transaction.isIncome
                  ? AppColors.success
                  : AppColors.error,
            ),
          ),
          if (transaction.createdAt != null)
            Text(
              _formatDate(transaction.createdAt!),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textTertiaryLight,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCouponsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: AppSpacing.horizontalMd,
          child: const Text(
            '我的优惠券',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        AppSpacing.vSm,
        if (_myCoupons.isEmpty)
          EmptyStateView.noData(
            title: '暂无优惠券',
            description: '您还没有优惠券',
          )
        else
          GroupedCard(
            children: _myCoupons
                .take(5)
                .map((userCoupon) => _buildCouponItem(userCoupon))
                .toList(),
          ),
      ],
    );
  }

  Widget _buildCouponItem(UserCoupon userCoupon) {
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
        child: const Icon(
          Icons.card_giftcard,
          color: AppColors.primary,
        ),
      ),
      title: Text(coupon.name),
      subtitle: Text(
        '${coupon.typeText} · ${coupon.discountValueDisplay}',
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: userCoupon.isUsable
              ? AppColors.successLight
              : AppColors.errorLight,
          borderRadius: AppRadius.allTiny,
        ),
        child: Text(
          userCoupon.statusText,
          style: TextStyle(
            fontSize: 12,
            color: userCoupon.isUsable
                ? AppColors.success
                : AppColors.error,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return '今天';
    } else if (difference.inDays == 1) {
      return '昨天';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else {
      return '${date.month}/${date.day}';
    }
  }
}
