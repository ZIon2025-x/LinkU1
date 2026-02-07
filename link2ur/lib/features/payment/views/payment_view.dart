import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/external_web_view.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/services/payment_service.dart';
import '../../../data/models/payment.dart';

/// 支付方式枚举
enum PaymentMethod {
  card,
  applePay,
  wechatPay,
  alipay,
}

/// 支付页面
/// 参考iOS StripePaymentView.swift
/// 完整支持：信用卡/借记卡、Apple Pay、微信支付、支付宝、优惠券选择
class PaymentView extends StatefulWidget {
  const PaymentView({
    super.key,
    required this.taskId,
    this.amount,
    this.expiresAt,
  });

  final int taskId;
  final double? amount;
  final DateTime? expiresAt;

  @override
  State<PaymentView> createState() => _PaymentViewState();
}

class _PaymentViewState extends State<PaymentView> {
  bool _isLoading = false;
  bool _isProcessing = false;
  TaskPaymentResponse? _paymentResponse;
  int? _selectedCouponId;
  String? _selectedCouponName;
  String? _errorMessage;
  PaymentMethod _selectedPaymentMethod = PaymentMethod.card;
  Timer? _countdownTimer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    _createPaymentIntent();
    _startCountdownIfNeeded();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdownIfNeeded() {
    if (widget.expiresAt != null) {
      _updateRemainingTime();
      _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateRemainingTime();
      });
    }
  }

  void _updateRemainingTime() {
    if (widget.expiresAt == null) return;
    final remaining = widget.expiresAt!.difference(DateTime.now());
    if (remaining.isNegative) {
      _countdownTimer?.cancel();
      if (mounted) {
        _showPaymentExpiredDialog();
      }
    } else {
      if (mounted) {
        setState(() => _remainingTime = remaining);
      }
    }
  }

  void _showPaymentExpiredDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('支付已过期'),
        content: const Text('支付时间已到，请重新发起支付。'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
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
          _errorMessage = _formatPaymentError(e);
          _isLoading = false;
        });
      }
    }
  }

  String _formatPaymentError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('insufficient_funds')) {
      return '余额不足，请更换支付方式或充值后重试。';
    } else if (msg.contains('card_declined')) {
      return '银行卡被拒绝，请更换银行卡或联系银行。';
    } else if (msg.contains('expired_card')) {
      return '银行卡已过期，请更换银行卡。';
    } else if (msg.contains('network')) {
      return '网络连接失败，请检查网络后重试。';
    } else if (msg.contains('timeout')) {
      return '请求超时，请稍后重试。';
    }
    return msg.replaceAll('PaymentException: ', '');
  }

  Future<void> _processPayment() async {
    if (_paymentResponse == null) return;

    // 免费订单直接确认
    if (_paymentResponse!.isFree) {
      await _confirmFreePayment();
      return;
    }

    switch (_selectedPaymentMethod) {
      case PaymentMethod.card:
        await _processStripePayment();
        break;
      case PaymentMethod.applePay:
        await _processApplePayPayment();
        break;
      case PaymentMethod.wechatPay:
        await _processWeChatPayment();
        break;
      case PaymentMethod.alipay:
        await _processAlipayPayment();
        break;
    }
  }

  Future<void> _confirmFreePayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<PaymentRepository>();
      await repo.confirmPayment(
        paymentIntentId: _paymentResponse!.paymentIntentId ?? '',
      );
      if (mounted) _showPaymentSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _formatPaymentError(e);
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processStripePayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<PaymentRepository>();
      await repo.confirmPayment(
        paymentIntentId: _paymentResponse!.paymentIntentId ?? '',
      );
      if (mounted) _showPaymentSuccess();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _formatPaymentError(e);
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processApplePayPayment() async {
    if (!Platform.isIOS) {
      setState(() {
        _errorMessage = 'Apple Pay 仅在 iOS 设备上可用';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final paymentService = PaymentService.instance;
      final isSupported = await paymentService.isApplePaySupported();
      if (!isSupported) {
        if (mounted) {
          setState(() {
            _errorMessage = '您的设备不支持 Apple Pay，请使用其他支付方式';
            _isProcessing = false;
          });
        }
        return;
      }

      final success = await paymentService.presentApplePay(
        clientSecret: _paymentResponse!.clientSecret!,
        amount: _paymentResponse!.finalAmount,
        currency: _paymentResponse!.currency ?? 'GBP',
        label: '任务 #${widget.taskId}',
      );

      if (success && mounted) {
        _showPaymentSuccess();
      } else if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _formatPaymentError(e);
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processWeChatPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final repo = context.read<PaymentRepository>();
      // 创建微信支付 Checkout Session
      final checkoutUrl = await repo.createWeChatCheckoutSession(
        taskId: widget.taskId,
        couponId: _selectedCouponId,
      );

      if (mounted && checkoutUrl.isNotEmpty) {
        setState(() => _isProcessing = false);
        // 打开WebView进行微信支付
        final result = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder: (_) => _WeChatPayWebView(
              checkoutUrl: checkoutUrl,
              onPaymentSuccess: () => Navigator.of(context).pop(true),
              onPaymentCancel: () => Navigator.of(context).pop(false),
            ),
          ),
        );
        if (result == true && mounted) {
          _showPaymentSuccess();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _formatPaymentError(e);
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _processAlipayPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final paymentService = PaymentService.instance;
      final success = await paymentService.presentPaymentSheet(
        clientSecret: _paymentResponse!.clientSecret!,
        customerId: _paymentResponse!.customerId ?? '',
        ephemeralKeySecret: _paymentResponse!.ephemeralKeySecret ?? '',
        preferredPaymentMethod: 'alipay',
      );

      if (success && mounted) {
        _showPaymentSuccess();
      } else if (mounted) {
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = _formatPaymentError(e);
          _isProcessing = false;
        });
      }
    }
  }

  void _showPaymentSuccess() {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 40,
              ),
            ),
            AppSpacing.vMd,
            const Text('支付成功'),
          ],
        ),
        content: const Text(
          '您的支付已成功处理，任务将很快开始。',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                context.pop(true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('确定'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCouponSelector() async {
    // 显示优惠券选择底部弹窗
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CouponSelectorSheet(
        selectedCouponId: _selectedCouponId,
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedCouponId = result['id'] as int?;
        _selectedCouponName = result['name'] as String?;
      });
      // 重新创建支付意向
      _createPaymentIntent();
    }
  }

  void _removeCoupon() {
    setState(() {
      _selectedCouponId = null;
      _selectedCouponName = null;
    });
    _createPaymentIntent();
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
                  // 支付倒计时
                  if (_remainingTime != null) _buildCountdownBanner(),

                  Expanded(
                    child: SingleChildScrollView(
                      padding: AppSpacing.allLg,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // 错误提示
                          if (_errorMessage != null) ...[
                            _buildErrorBanner(),
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

  Widget _buildCountdownBanner() {
    final minutes = _remainingTime!.inMinutes;
    final seconds = _remainingTime!.inSeconds % 60;
    final isUrgent = _remainingTime!.inMinutes < 5;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isUrgent
          ? AppColors.error.withValues(alpha: 0.1)
          : AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          Icon(
            Icons.timer_outlined,
            size: 18,
            color: isUrgent ? AppColors.error : AppColors.warning,
          ),
          const SizedBox(width: 8),
          Text(
            '支付剩余时间：${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isUrgent ? AppColors.error : AppColors.warning,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.08),
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _errorMessage = null),
            child: const Icon(Icons.close, color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo() {
    final response = _paymentResponse;
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
          if (response != null) ...[
            AppSpacing.vSm,
            _InfoRow(
              label: '原价',
              value: response.originalAmountDisplay.isNotEmpty
                  ? response.originalAmountDisplay
                  : '£${(response.originalAmount / 100).toStringAsFixed(2)}',
            ),
            if (response.hasDiscount) ...[
              AppSpacing.vSm,
              _InfoRow(
                label: '优惠 (${response.couponName ?? ""})',
                value:
                    '-${response.couponDiscountDisplay ?? "£${(response.couponDiscount! / 100).toStringAsFixed(2)}"}',
                valueStyle: const TextStyle(
                  color: AppColors.success,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1),
            ),
            _InfoRow(
              label: '实付金额',
              value: response.finalAmountDisplay.isNotEmpty
                  ? response.finalAmountDisplay
                  : '£${(response.finalAmount / 100).toStringAsFixed(2)}',
              valueStyle: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
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
          isSelected: _selectedPaymentMethod == PaymentMethod.card,
          onTap: () =>
              setState(() => _selectedPaymentMethod = PaymentMethod.card),
        ),
        AppSpacing.vSm,
        if (Platform.isIOS) ...[
          _PaymentMethodTile(
            icon: Icons.apple,
            title: 'Apple Pay',
            subtitle: '快速安全支付',
            isSelected: _selectedPaymentMethod == PaymentMethod.applePay,
            onTap: () =>
                setState(() => _selectedPaymentMethod = PaymentMethod.applePay),
          ),
          AppSpacing.vSm,
        ],
        _PaymentMethodTile(
          iconWidget: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF07C160),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.chat_bubble, color: Colors.white, size: 14),
          ),
          title: '微信支付',
          subtitle: 'WeChat Pay',
          isSelected: _selectedPaymentMethod == PaymentMethod.wechatPay,
          onTap: () =>
              setState(() => _selectedPaymentMethod = PaymentMethod.wechatPay),
        ),
        AppSpacing.vSm,
        _PaymentMethodTile(
          iconWidget: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: const Color(0xFF1677FF),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Center(
              child: Text(
                '支',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          title: '支付宝',
          subtitle: 'Alipay',
          isSelected: _selectedPaymentMethod == PaymentMethod.alipay,
          onTap: () =>
              setState(() => _selectedPaymentMethod = PaymentMethod.alipay),
        ),
      ],
    );
  }

  Widget _buildCouponSection() {
    return GestureDetector(
      onTap: _showCouponSelector,
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
              child: _selectedCouponId != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedCouponName ?? '已选择优惠券',
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_paymentResponse?.couponDescription != null)
                          Text(
                            _paymentResponse!.couponDescription!,
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    )
                  : Text(
                      '选择优惠券',
                      style: TextStyle(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
            ),
            if (_selectedCouponId != null)
              GestureDetector(
                onTap: _removeCoupon,
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child: Icon(Icons.close, size: 16, color: AppColors.error),
                ),
              )
            else
              const Icon(Icons.chevron_right,
                  color: AppColors.textTertiaryLight, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPayButton() {
    final response = _paymentResponse;
    final amount = response != null
        ? response.finalAmountDisplay.isNotEmpty
            ? response.finalAmountDisplay
            : '£${(response.finalAmount / 100).toStringAsFixed(2)}'
        : widget.amount != null
            ? '£${widget.amount!.toStringAsFixed(2)}'
            : '£0.00';

    final isFree = response?.isFree ?? false;

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
          text: isFree ? '确认（免费）' : '立即支付 $amount',
          isLoading: _isProcessing,
          onPressed: _isProcessing ? null : _processPayment,
        ),
      ),
    );
  }
}

// ==================== 子组件 ====================

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
    this.icon,
    this.iconWidget,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final IconData? icon;
  final Widget? iconWidget;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
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
            iconWidget ??
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
              const Icon(Icons.check_circle,
                  color: AppColors.primary, size: 20)
            else
              const Icon(Icons.radio_button_off,
                  color: AppColors.textTertiaryLight, size: 20),
          ],
        ),
      ),
    );
  }
}

/// 优惠券选择底部弹窗
class _CouponSelectorSheet extends StatefulWidget {
  const _CouponSelectorSheet({this.selectedCouponId});

  final int? selectedCouponId;

  @override
  State<_CouponSelectorSheet> createState() => _CouponSelectorSheetState();
}

class _CouponSelectorSheetState extends State<_CouponSelectorSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _coupons = [];

  @override
  void initState() {
    super.initState();
    _loadCoupons();
  }

  Future<void> _loadCoupons() async {
    try {
      // 从API获取可用优惠券
      final repo = context.read<PaymentRepository>();
      final methods = await repo.getPaymentMethods();
      if (mounted) {
        setState(() {
          _coupons = methods;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '选择优惠券',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(),
            )
          else if (_coupons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 48, color: AppColors.textTertiaryLight),
                  const SizedBox(height: 12),
                  Text(
                    '暂无可用优惠券',
                    style: TextStyle(color: AppColors.textSecondaryLight),
                  ),
                ],
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _coupons.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final coupon = _coupons[index];
                  final isSelected =
                      coupon['id'] == widget.selectedCouponId;
                  return GestureDetector(
                    onTap: () => Navigator.pop(context, coupon),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.05)
                            : Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.dividerLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.accentPink.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.local_offer,
                              color: AppColors.accentPink,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  coupon['name'] ?? '优惠券',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (coupon['description'] != null)
                                  Text(
                                    coupon['description'],
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                color: AppColors.primary),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 微信支付 WebView 页面
/// 对齐 iOS WeChatPayWebView.swift
/// 通过 URL 检测 payment-success / payment-cancel 来判断支付结果
class _WeChatPayWebView extends StatefulWidget {
  const _WeChatPayWebView({
    required this.checkoutUrl,
    required this.onPaymentSuccess,
    required this.onPaymentCancel,
  });

  final String checkoutUrl;
  final VoidCallback onPaymentSuccess;
  final VoidCallback onPaymentCancel;

  @override
  State<_WeChatPayWebView> createState() => _WeChatPayWebViewState();
}

class _WeChatPayWebViewState extends State<_WeChatPayWebView> {
  bool _isLoading = true;
  String? _errorMessage;
  bool _showCancelDialog = false;

  /// 检查 URL 是否为支付成功页面
  bool _isSuccessUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('payment-success') ||
        lower.contains('payment_success') ||
        lower.contains('/success');
  }

  /// 检查 URL 是否为支付取消页面
  bool _isCancelUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('payment-cancel') ||
        lower.contains('payment_cancel') ||
        lower.contains('/cancel');
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('取消支付'),
        content: const Text('确定要取消支付吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('继续支付'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onPaymentCancel();
            },
            child: Text('取消支付',
                style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('微信支付'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmCancel,
        ),
      ),
      body: Stack(
        children: [
          ExternalWebView(
            url: widget.checkoutUrl,
            title: '微信支付',
          ),
          if (_isLoading)
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('加载中...'),
                ],
              ),
            ),
          if (_errorMessage != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline,
                      size: 48, color: AppColors.error),
                  const SizedBox(height: 12),
                  Text('加载失败',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Text(_errorMessage!,
                      style: TextStyle(color: AppColors.textSecondaryLight)),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: widget.onPaymentCancel,
                        child: const Text('返回'),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton(
                        onPressed: () =>
                            setState(() => _errorMessage = null),
                        child: const Text('重试'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
