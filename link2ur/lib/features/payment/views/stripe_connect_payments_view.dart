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

/// Stripe Connect 收款记录页
/// 对标 iOS StripeConnectPaymentsView.swift
/// 合并 Stripe Connect 交易记录 + 任务支付记录，按时间倒序排列
class StripeConnectPaymentsView extends StatefulWidget {
  const StripeConnectPaymentsView({super.key});

  @override
  State<StripeConnectPaymentsView> createState() =>
      _StripeConnectPaymentsViewState();
}

/// 统一支付记录类型（对标 iOS PaymentRecord enum）
sealed class PaymentRecord implements Comparable<PaymentRecord> {
  DateTime get createdAt;

  @override
  int compareTo(PaymentRecord other) =>
      other.createdAt.compareTo(createdAt); // 倒序
}

class StripeConnectRecord extends PaymentRecord {
  StripeConnectRecord(this.transaction);
  final StripeConnectTransaction transaction;

  @override
  DateTime get createdAt {
    if (transaction.createdAt.isEmpty) return DateTime(2000);
    try {
      return DateTime.parse(transaction.createdAt);
    } catch (_) {
      return DateTime(2000);
    }
  }
}

class TaskPaymentRecordItem extends PaymentRecord {
  TaskPaymentRecordItem(this.payment);
  final TaskPaymentRecord payment;

  @override
  DateTime get createdAt {
    if (payment.createdAt == null || payment.createdAt!.isEmpty) {
      return DateTime(2000);
    }
    try {
      return DateTime.parse(payment.createdAt!);
    } catch (_) {
      return DateTime(2000);
    }
  }
}

class _StripeConnectPaymentsViewState
    extends State<StripeConnectPaymentsView> {
  List<PaymentRecord> _records = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  /// 对标 iOS loadTransactions() — 并行加载两种记录
  Future<void> _loadPayments() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final repo = context.read<PaymentRepository>();

      // 并行加载 Stripe Connect 交易记录和任务支付记录
      final results = await Future.wait([
        repo.getStripeConnectTransactions(),
        repo.getTaskPaymentRecords(),
      ]);

      if (!mounted) return;

      final stripeTransactions = results[0] as List<StripeConnectTransaction>;
      final taskPayments = results[1] as List<TaskPaymentRecord>;

      // 合并并排序
      final records = <PaymentRecord>[
        ...stripeTransactions.map((t) => StripeConnectRecord(t)),
        ...taskPayments.map((p) => TaskPaymentRecordItem(p)),
      ]..sort();

      setState(() {
        _records = records;
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
              : _records.isEmpty
                  ? EmptyStateView(
                      icon: Icons.payment,
                      title: l10n.emptyNoPaymentRecords,
                      message: l10n.emptyNoPaymentRecordsMessage,
                    )
                  : RefreshIndicator(
                      onRefresh: _loadPayments,
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: _records.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final record = _records[index];
                          final key = switch (record) {
                            StripeConnectRecord r =>
                              ValueKey('stripe_${r.transaction.id}'),
                            TaskPaymentRecordItem r =>
                              ValueKey('task_${r.payment.id}'),
                          };
                          return switch (record) {
                            StripeConnectRecord r => KeyedSubtree(
                                key: key,
                                child: _StripeTransactionCard(
                                    transaction: r.transaction),
                              ),
                            TaskPaymentRecordItem r => KeyedSubtree(
                                key: key,
                                child: _TaskPaymentCard(payment: r.payment),
                              ),
                          };
                        },
                      ),
                    ),
    );
  }
}

/// Stripe Connect 交易卡片
class _StripeTransactionCard extends StatelessWidget {
  const _StripeTransactionCard({required this.transaction});

  final StripeConnectTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isIncome = transaction.isIncome;
    final statusColor = _getStatusColor(transaction.status);
    final statusText = _getStatusText(transaction.status, l10n);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: (isIncome ? AppColors.success : AppColors.primary)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isIncome ? Icons.arrow_downward : Icons.arrow_upward,
              color: isIncome ? AppColors.success : AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description.isNotEmpty
                      ? transaction.description
                      : (isIncome ? l10n.paymentIncome : l10n.paymentPayout),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.amountDisplay,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: isIncome ? AppColors.success : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'succeeded':
        return AppColors.success;
      case 'pending':
      case 'in_transit':
        return AppColors.warning;
      case 'failed':
      case 'canceled':
        return AppColors.error;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getStatusText(String status, dynamic l10n) {
    switch (status.toLowerCase()) {
      case 'paid':
      case 'succeeded':
        return l10n.paymentStatusSuccess;
      case 'pending':
      case 'in_transit':
        return l10n.paymentStatusProcessing;
      case 'failed':
        return l10n.paymentStatusFailed;
      case 'canceled':
        return l10n.paymentStatusCanceled;
      default:
        return status;
    }
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

/// 任务支付记录卡片
class _TaskPaymentCard extends StatelessWidget {
  const _TaskPaymentCard({required this.payment});

  final TaskPaymentRecord payment;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final statusColor = _getStatusColor(payment.status);
    final statusText = _getStatusText(payment.status, l10n);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.receipt_long,
              color: AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.taskTitle ?? l10n.paymentStatusTaskPayment,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      l10n.paymentStatusTaskPayment,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.primary.withValues(alpha: 0.8),
                      ),
                    ),
                    if (payment.createdAt != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDate(payment.createdAt!),
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.textTertiary),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '-£${payment.amount.abs().toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  statusText,
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
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        return AppColors.success;
      case 'pending':
      case 'processing':
        return AppColors.warning;
      case 'failed':
        return AppColors.error;
      case 'canceled':
      case 'cancelled':
        return AppColors.textTertiary;
      default:
        return AppColors.textTertiary;
    }
  }

  String _getStatusText(String status, dynamic l10n) {
    switch (status.toLowerCase()) {
      case 'succeeded':
      case 'completed':
        return l10n.paymentStatusSuccess;
      case 'pending':
      case 'processing':
        return l10n.paymentStatusProcessing;
      case 'failed':
        return l10n.paymentStatusFailed;
      case 'canceled':
      case 'cancelled':
        return l10n.paymentStatusCanceled;
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}
