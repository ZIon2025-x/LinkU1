import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/constants/api_endpoints.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/payment.dart';
import '../../../data/services/api_service.dart';

/// 支付详情页 — 展示完整支付信息 + 收据下载
class PaymentDetailView extends StatelessWidget {
  const PaymentDetailView({super.key, required this.record});

  final TaskPaymentRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final symbol = Helpers.currencySymbolFor(record.currency);
    final statusColor = _statusColor(record.status);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.paymentDetailTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            // ===== Hero: status + amount =====
            _HeroCard(record: record, symbol: symbol, statusColor: statusColor),
            const SizedBox(height: AppSpacing.md),

            // ===== Order info =====
            _SectionCard(
              title: l10n.paymentDetailOrder,
              rows: [
                _Row(l10n.paymentDetailOrderNo, record.orderNo ?? '—'),
                _Row(l10n.paymentDetailDate, _formatDate(record.createdAt)),
                _Row(l10n.paymentDetailPaymentMethod, _methodLabel(record.paymentMethod)),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ===== Item info =====
            _SectionCard(
              title: l10n.paymentDetailItem,
              rows: [
                _Row(l10n.paymentDetailItemName, record.taskTitle ?? 'Task #${record.taskId ?? record.id}'),
                _Row(l10n.paymentDetailItemType, _taskTypeLabel(record.taskSource)),
                if (record.counterpartName != null)
                  _Row(l10n.paymentDetailSeller, record.counterpartName!),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // ===== Amount breakdown =====
            _BreakdownCard(record: record, symbol: symbol),
            const SizedBox(height: AppSpacing.lg),

            // ===== Receipt buttons =====
            if (record.status.toLowerCase() == 'succeeded') ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _downloadReceipt(context),
                  icon: const Icon(Icons.download),
                  label: Text(l10n.paymentDetailDownloadReceipt),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.medium),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _downloadReceipt(BuildContext context) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    messenger.showSnackBar(
      SnackBar(content: Text(l10n.paymentDetailGenerating)),
    );

    try {
      final api = context.read<ApiService>();
      final response = await api.downloadFile(
        ApiEndpoints.paymentReceipt(record.id),
      );

      if (response == null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.paymentDetailReceiptFailed)),
        );
        return;
      }

      // Save to temp dir then share
      final dir = await getTemporaryDirectory();
      final filename = 'receipt_${record.orderNo ?? record.id}.pdf';
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(response);

      messenger.clearSnackBars();

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/pdf')],
        ),
      );
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.paymentDetailReceiptFailed)),
      );
    }
  }

  Color _statusColor(String status) {
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

  String _methodLabel(String? method) {
    switch (method?.toLowerCase()) {
      case 'stripe':
        return 'Stripe';
      case 'alipay':
        return 'Alipay';
      case 'wechat_pay':
        return 'WeChat Pay';
      case 'wallet':
        return 'Wallet Balance';
      case 'coupon':
        return 'Coupon';
      case 'mixed':
        return 'Wallet + Stripe';
      default:
        return method ?? 'Stripe';
    }
  }

  String _taskTypeLabel(String? source) {
    switch (source?.toLowerCase()) {
      case 'flea_market':
        return 'Flea Market';
      case 'rental':
        return 'Rental';
      default:
        return 'Task';
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('yyyy-MM-dd HH:mm').format(date.toLocal());
    } catch (_) {
      return dateStr;
    }
  }
}

// ===== Hero Card =====

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.record, required this.symbol, required this.statusColor});
  final TaskPaymentRecord record;
  final String symbol;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.large),
      ),
      child: Column(
        children: [
          Icon(
            record.status.toLowerCase() == 'succeeded' ? Icons.check_circle : Icons.info,
            color: statusColor,
            size: 40,
          ),
          const SizedBox(height: 8),
          Text(
            _statusLabel(context, record.status),
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor),
          ),
          const SizedBox(height: 8),
          Text(
            '$symbol${record.amount.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, String status) {
    final l10n = context.l10n;
    switch (status.toLowerCase()) {
      case 'succeeded':
        return l10n.paymentRecordsStatusSucceeded;
      case 'pending':
        return l10n.paymentRecordsStatusPending;
      case 'failed':
        return l10n.paymentRecordsStatusFailed;
      case 'canceled':
        return l10n.paymentRecordsStatusCanceled;
      default:
        return status;
    }
  }
}

// ===== Section Card =====

class _Row {
  const _Row(this.label, this.value);
  final String label;
  final String value;
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.rows});
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(height: 1, color: AppColors.primary.withValues(alpha: 0.08)),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(rows[i].label, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
                  Flexible(
                    child: Text(
                      rows[i].value,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      textAlign: TextAlign.end,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ===== Breakdown Card =====

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.record, required this.symbol});
  final TaskPaymentRecord record;
  final String symbol;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.medium),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.paymentDetailBreakdown,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          _breakdownRow(l10n.paymentRecordsSubtotal, '$symbol${record.totalAmount?.toStringAsFixed(2) ?? record.amount.toStringAsFixed(2)}'),
          if (record.couponDiscount != null && record.couponDiscount! > 0)
            _breakdownRow(l10n.paymentRecordsCouponDiscount, '-$symbol${record.couponDiscount!.toStringAsFixed(2)}', color: AppColors.success),
          if (record.pointsUsed != null && record.pointsUsed! > 0)
            _breakdownRow(l10n.paymentRecordsPointsUsed, '-${record.pointsUsed}', color: AppColors.success),
          if (record.applicationFee != null && record.applicationFee! > 0)
            _breakdownRow(l10n.paymentDetailPlatformFee, '$symbol${record.applicationFee!.toStringAsFixed(2)}'),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(l10n.paymentDetailTotalPaid, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              Text('$symbol${record.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _breakdownRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: color)),
        ],
      ),
    );
  }
}
