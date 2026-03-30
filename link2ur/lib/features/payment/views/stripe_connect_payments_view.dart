import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/utils/helpers.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/payment.dart';
import '../../../data/repositories/payment_repository.dart';

/// 支付记录页 — 展示用户的真实支付历史（PaymentHistory）
class StripeConnectPaymentsView extends StatefulWidget {
  const StripeConnectPaymentsView({super.key});

  @override
  State<StripeConnectPaymentsView> createState() =>
      _StripeConnectPaymentsViewState();
}

class _StripeConnectPaymentsViewState
    extends State<StripeConnectPaymentsView> {
  List<TaskPaymentRecord> _items = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;
  static const _pageSize = 20;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadPayments();
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
      if (!_isLoadingMore && _hasMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _page = 1;
    });

    try {
      final repo = context.read<PaymentRepository>();
      final result = await repo.getPaymentHistory();

      if (!mounted) return;

      final items = result
          .map((e) => TaskPaymentRecord.fromJson(e))
          .toList();
      setState(() {
        _items = items;
        _hasMore = items.length >= _pageSize;
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
      final result = await repo.getPaymentHistory(
        page: _page + 1,
      );

      if (!mounted) return;

      final newItems = result
          .map((e) => TaskPaymentRecord.fromJson(e))
          .toList();

      setState(() {
        _items = [..._items, ...newItems];
        _page = _page + 1;
        _hasMore = newItems.length >= _pageSize;
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
                        onPressed: _loadPayments,
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
                      onRefresh: _loadPayments,
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
                          return GestureDetector(
                            onTap: () => context.push(
                              '/payment/detail',
                              extra: item,
                            ),
                            child: _PaymentHistoryCard(
                              key: ValueKey('payment_${item.id}'),
                              item: item,
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

/// 支付记录卡片
class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({super.key, required this.item});

  final TaskPaymentRecord item;

  @override
  Widget build(BuildContext context) {
    final statusColor = _getStatusColor(item.status);
    final statusLabel = _getStatusLabel(context, item.status);
    final symbol = Helpers.currencySymbolFor(item.currency);
    final amountText = '$symbol${item.amount.toStringAsFixed(2)}';
    final dateText = _formatDate(item.createdAt);
    final methodLabel = _getMethodLabel(item.paymentMethod);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 第一行：任务标题 + 金额
          Row(
            children: [
              // 图标
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.payment, color: statusColor, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              // 任务标题 + 支付方式/时间
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.taskTitle ?? 'Task #${item.taskId ?? item.id}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          methodLabel,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        if (dateText.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              dateText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textTertiary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              // 金额 + 状态
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    amountText,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          // 折扣明细（如果有优惠券或积分抵扣）
          if ((item.couponDiscount != null && item.couponDiscount! > 0) ||
              (item.pointsUsed != null && item.pointsUsed! > 0)) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  if (item.totalAmount != null)
                    _detailRow(
                      context.l10n.paymentRecordsSubtotal,
                      '$symbol${item.totalAmount!.toStringAsFixed(2)}',
                    ),
                  if (item.couponDiscount != null && item.couponDiscount! > 0)
                    _detailRow(
                      context.l10n.paymentRecordsCouponDiscount,
                      '-$symbol${item.couponDiscount!.toStringAsFixed(2)}',
                      valueColor: AppColors.success,
                    ),
                  if (item.pointsUsed != null && item.pointsUsed! > 0)
                    _detailRow(
                      context.l10n.paymentRecordsPointsUsed,
                      '-${item.pointsUsed}',
                      valueColor: AppColors.success,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
        return AppColors.success;
      case 'pending':
        return AppColors.warning;
      case 'failed':
      case 'canceled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getStatusLabel(BuildContext context, String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
        return context.l10n.paymentRecordsStatusSucceeded;
      case 'pending':
        return context.l10n.paymentRecordsStatusPending;
      case 'failed':
        return context.l10n.paymentRecordsStatusFailed;
      case 'canceled':
        return context.l10n.paymentRecordsStatusCanceled;
      default:
        return status;
    }
  }

  String _getMethodLabel(String? method) {
    switch (method?.toLowerCase()) {
      case 'stripe':
        return 'Stripe';
      case 'alipay':
        return 'Alipay';
      case 'wechat_pay':
        return 'WeChat Pay';
      case 'points_only':
        return 'Points';
      default:
        return method ?? 'Stripe';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}
