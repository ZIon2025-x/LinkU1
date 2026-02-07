import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/payment_repository.dart';

/// Stripe Connect 收款记录页
/// 参考iOS StripeConnectPaymentsView.swift
class StripeConnectPaymentsView extends StatefulWidget {
  const StripeConnectPaymentsView({super.key});

  @override
  State<StripeConnectPaymentsView> createState() =>
      _StripeConnectPaymentsViewState();
}

class _StripeConnectPaymentsViewState
    extends State<StripeConnectPaymentsView> {
  List<Map<String, dynamic>> _payments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayments();
  }

  Future<void> _loadPayments() async {
    setState(() => _isLoading = true);

    try {
      final repo = context.read<PaymentRepository>();
      final payments = await repo.getConnectPayments();
      if (mounted) {
        setState(() {
          _payments = payments;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentConnectPayments),
      ),
      body: _isLoading
          ? const LoadingView()
          : _payments.isEmpty
              ? EmptyStateView(
                  icon: Icons.payment,
                  title: l10n.paymentNoPayments,
                  message: l10n.paymentNoPaymentsMessage,
                )
              : RefreshIndicator(
                  onRefresh: _loadPayments,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _payments.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final payment = _payments[index];
                      return _PaymentCard(payment: payment);
                    },
                  ),
                ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final Map<String, dynamic> payment;

  @override
  Widget build(BuildContext context) {
    final amount = (payment['amount'] as num?)?.toDouble() ?? 0;
    final status = payment['status'] as String? ?? '';
    final description = payment['description'] as String? ?? '';
    final createdAt = payment['created_at'] as String? ?? '';

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
              color: amount > 0
                  ? AppColors.success.withOpacity(0.1)
                  : AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              amount > 0 ? Icons.arrow_downward : Icons.arrow_upward,
              color: amount > 0 ? AppColors.success : AppColors.error,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(description,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(createdAt,
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${amount > 0 ? '+' : ''}£${amount.abs().toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: amount > 0 ? AppColors.success : AppColors.error,
                ),
              ),
              const SizedBox(height: 4),
              Text(status,
                  style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
