import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/payment_repository.dart';

/// Stripe Connect 提现记录页
/// 参考iOS StripeConnectPayoutsView.swift
class StripeConnectPayoutsView extends StatefulWidget {
  const StripeConnectPayoutsView({super.key});

  @override
  State<StripeConnectPayoutsView> createState() =>
      _StripeConnectPayoutsViewState();
}

class _StripeConnectPayoutsViewState
    extends State<StripeConnectPayoutsView> {
  List<Map<String, dynamic>> _payouts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPayouts();
  }

  Future<void> _loadPayouts() async {
    setState(() => _isLoading = true);

    try {
      final repo = context.read<PaymentRepository>();
      final payouts = await repo.getConnectPayouts();
      if (mounted) {
        setState(() {
          _payouts = payouts;
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
        title: Text(l10n.paymentConnectPayouts),
      ),
      body: _isLoading
          ? const LoadingView()
          : _payouts.isEmpty
              ? EmptyStateView(
                  icon: Icons.account_balance,
                  title: l10n.paymentNoPayouts,
                  message: l10n.paymentNoPayoutsMessage,
                )
              : RefreshIndicator(
                  onRefresh: _loadPayouts,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: _payouts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, index) {
                      final payout = _payouts[index];
                      return _PayoutCard(payout: payout);
                    },
                  ),
                ),
    );
  }
}

class _PayoutCard extends StatelessWidget {
  const _PayoutCard({required this.payout});

  final Map<String, dynamic> payout;

  @override
  Widget build(BuildContext context) {
    final amount = (payout['amount'] as num?)?.toDouble() ?? 0;
    final status = payout['status'] as String? ?? '';
    final arrivalDate = payout['arrival_date'] as String? ?? '';
    final method = payout['method'] as String? ?? 'bank_account';

    Color statusColor;
    switch (status) {
      case 'paid':
        statusColor = AppColors.success;
        break;
      case 'pending':
        statusColor = AppColors.warning;
        break;
      case 'failed':
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.textTertiary;
    }

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
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              method == 'bank_account'
                  ? Icons.account_balance
                  : Icons.credit_card,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '£${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                if (arrivalDate.isNotEmpty)
                  Text(arrivalDate,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  color: statusColor,
                  fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
