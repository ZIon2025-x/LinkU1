import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/models/payment.dart';

/// 支付页面
/// 参考iOS StripePaymentView.swift
/// 支持 Stripe 支付、优惠券选择
class PaymentView extends StatefulWidget {
  const PaymentView({
    super.key,
    required this.taskId,
    this.amount,
  });

  final int taskId;
  final double? amount;

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  bool _isLoading = false;
  bool _isProcessing = false;
  TaskPaymentResponse? _paymentResponse;
  int? _selectedCouponId;
  String? _errorMessage;
  int _selectedPaymentMethod = 0; // 0: Stripe, 1: Apple Pay

  @override
  void initState() {
    super.initState();
    _createPaymentIntent();
  }

  Future<void> _createPaymentIntent() async {
    setState(() => _isLoading = true);

    try {
      final repo = context.read<PaymentRepository>();
      final response = await repo.createPaymentIntent(
        taskId: widget.taskId,
        couponId: _selectedCouponId,
      );
      if (mounted) {
        setState(() {
          _paymentResponse = response;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processPayment() async {
    if (_paymentResponse == null) return;

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<PaymentRepository>();
      await repo.confirmPayment(
        paymentIntentId: _paymentResponse!.paymentIntentId ?? '',
      );

      if (mounted) {
        // 显示成功弹窗
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.check_circle, color: AppColors.success),
                AppSpacing.hSm,
                const Text('支付成功'),
              ],
            ),
            content: const Text('您的支付已成功处理。'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.pop();
                },
                child: const Text('确定'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('确认支付')),
      body: _isLoading
          ? const LoadingView()
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppSpacing.allLg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 错误提示
                          if (_errorMessage != null) ...[
                            Container(
                              padding: AppSpacing.allMd,
                              decoration: BoxDecoration(
                                color: AppColors.errorLight,
                                borderRadius: AppRadius.allMedium,
                              ),
                              child: Text(
                                _errorMessage!,
                                style:
                                    const TextStyle(color: AppColors.error),
                              ),
                            ),
                            AppSpacing.vMd,
                          ],

                          // 订单信息
                          _buildOrderInfo(),
                          AppSpacing.vLg,

                          // 支付方式选择
                          _buildPaymentMethodSection(),
                          AppSpacing.vLg,

                          // 优惠券选择
                          _buildCouponSection(),
                        ],
                      ),
                    ),
                  ),

                  // 底部支付按钮
                  _buildPayButton(),
                ],
              ),
            ),
    );
  }

  Widget _buildOrderInfo() {
    return Container(
      padding: AppSpacing.allLg,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.allMedium,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '订单信息',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          AppSpacing.vMd,
          _InfoRow(label: '任务编号', value: '#${widget.taskId}'),
          AppSpacing.vSm,
          _InfoRow(
            label: '金额',
            value:
                '\$${_paymentResponse?.finalAmount.toStringAsFixed(2) ?? widget.amount?.toStringAsFixed(2) ?? '0.00'}',
            valueStyle: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (_selectedCouponId != null) ...[
            AppSpacing.vSm,
            _InfoRow(
              label: '优惠',
              value: '-\$2.00',
              valueStyle: const TextStyle(color: AppColors.success),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentMethodSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '支付方式',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        _PaymentMethodTile(
          icon: Icons.credit_card,
          title: '信用卡/借记卡',
          subtitle: 'Visa, Mastercard, AMEX',
          isSelected: _selectedPaymentMethod == 0,
          onTap: () => setState(() => _selectedPaymentMethod = 0),
        ),
        AppSpacing.vSm,
        _PaymentMethodTile(
          icon: Icons.apple,
          title: 'Apple Pay',
          subtitle: '快速安全支付',
          isSelected: _selectedPaymentMethod == 1,
          onTap: () => setState(() => _selectedPaymentMethod = 1),
        ),
      ],
    );
  }

  Widget _buildCouponSection() {
    return GestureDetector(
      onTap: () {
        // TODO: 打开优惠券选择页
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          border: Border.all(color: AppColors.dividerLight),
        ),
        child: Row(
          children: [
            const Icon(Icons.local_offer_outlined,
                color: AppColors.accentPink, size: 20),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                _selectedCouponId != null ? '已选择优惠券' : '选择优惠券',
                style: TextStyle(
                  color: _selectedCouponId != null
                      ? AppColors.textPrimaryLight
                      : AppColors.textSecondaryLight,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColors.textTertiaryLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    final amount = _paymentResponse?.finalAmount ?? widget.amount ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: PrimaryButton(
          text: '立即支付 \$${amount.toStringAsFixed(2)}',
          isLoading: _isProcessing,
          onPressed: _isProcessing ? null : _processPayment,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(color: AppColors.textSecondaryLight)),
        Text(value, style: valueStyle),
      ],
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.dividerLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textSecondaryLight),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w500)),
                  Text(subtitle,
                      style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondaryLight)),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppColors.primary, size: 20)
            else
              const Icon(Icons.radio_button_off,
                  color: AppColors.textTertiaryLight, size: 20),
          ],
        ),
      ),
    );
  }
}
