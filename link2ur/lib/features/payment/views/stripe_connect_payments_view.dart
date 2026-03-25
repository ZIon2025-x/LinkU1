import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';

/// 钱包流水记录页（原 Stripe Connect 收款记录页）
/// 使用本地钱包 API 替代 Stripe Connect API
class StripeConnectPaymentsView extends StatefulWidget {
  const StripeConnectPaymentsView({super.key});

  @override
  State<StripeConnectPaymentsView> createState() =>
      _StripeConnectPaymentsViewState();
}

class _StripeConnectPaymentsViewState
    extends State<StripeConnectPaymentsView> {
  List<WalletTransactionItem> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  int _total = 0;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTransactions();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _items.length < _total) {
        _loadMore();
      }
    }
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });

    try {
      final repo = context.read<PaymentRepository>();
      final result = await repo.getWalletTransactions();

      if (!mounted) return;

      final items = result['items'] as List<WalletTransactionItem>;
      final total = result['total'] as int;

      setState(() {
        _items = items;
        _total = total;
        _page = 1;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore) return;
    setState(() => _isLoadingMore = true);

    try {
      final repo = context.read<PaymentRepository>();
      final result = await repo.getWalletTransactions(
        page: _page + 1,
      );

      if (!mounted) return;

      final items = result['items'] as List<WalletTransactionItem>;
      final total = result['total'] as int;

      setState(() {
        _items = [..._items, ...items];
        _total = total;
        _page = _page + 1;
        _isLoadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentRecordsPaymentRecords),
      ),
      body: _isLoading
          ? const LoadingView()
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(l10n.paymentRecordsLoadFailed),
                      AppSpacing.vMd,
                      TextButton(
                        onPressed: _loadTransactions,
                        child: Text(l10n.commonRetry),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty
                  ? EmptyStateView(
                      icon: Icons.payment,
                      title: l10n.emptyNoPaymentRecords,
                      message: l10n.emptyNoPaymentRecordsMessage,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadTransactions,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _items.length + (_isLoadingMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final item = _items[index];
                          return _WalletTransactionCard(
                            key: ValueKey('wallet_${item.id}'),
                            item: item,
                          );
                        },
                      ),
                    ),
    );
  }
}

/// 钱包流水记录卡片
class _WalletTransactionCard extends StatelessWidget {
  const _WalletTransactionCard({super.key, required this.item});

  final WalletTransactionItem item;

  @override
  Widget build(BuildContext context) {
    final isIncome = item.amount >= 0;
    final isPending = item.status.toLowerCase() == 'pending';
    final typeIcon = _getTypeIcon(item.type);
    final typeColor = _getTypeColor(item.type);
    final sourceLabel = _getSourceLabel(item.source);
    final amountText = _formatAmount(item.amount, isIncome);
    final dateText = _formatDate(item.createdAt);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          // 类型图标
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(typeIcon, color: typeColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          // 描述 + 来源 + 时间
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.description?.isNotEmpty == true
                      ? item.description!
                      : sourceLabel,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      sourceLabel,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary),
                    ),
                    if (dateText.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          dateText,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textTertiary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          // 金额 + 处理中标签
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amountText,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isIncome ? AppColors.success : AppColors.error,
                ),
              ),
              if (isPending) ...[
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '处理中',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'earning':
        return Icons.arrow_downward;
      case 'withdrawal':
        return Icons.arrow_upward;
      case 'payment':
        return Icons.shopping_cart;
      default:
        return Icons.swap_horiz;
    }
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'earning':
        return AppColors.success;
      case 'withdrawal':
        return AppColors.primary;
      case 'payment':
        return AppColors.warning;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getSourceLabel(String source) {
    switch (source.toLowerCase()) {
      case 'task_reward':
        return '任务奖励';
      case 'flea_market_sale':
        return '二手物品售出';
      case 'stripe_transfer':
        return '提现';
      case 'task_payment':
        return '余额支付';
      default:
        return source;
    }
  }

  String _formatAmount(double amount, bool isIncome) {
    final abs = amount.abs();
    const symbol = '£';
    final formatted = abs.toStringAsFixed(2);
    return isIncome ? '+$symbol$formatted' : '-$symbol$formatted';
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}
