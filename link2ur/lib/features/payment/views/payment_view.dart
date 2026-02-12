import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/buttons.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/widgets/loading_view.dart';
import '../../../data/repositories/payment_repository.dart';
import '../../../data/services/payment_service.dart';
import '../../../data/models/payment.dart';
import '../bloc/payment_bloc.dart';

part 'payment_widgets.dart';

/// 支付方式枚举 —— 对齐 iOS PaymentMethod
enum PaymentMethod {
  card,
  applePay,
  wechatPay,
  alipay,
}

/// 获取支付方式对应的 Stripe preferred_payment_method 参数
/// 对齐 iOS PaymentViewModel.preferredPaymentMethodForAPI
String? _preferredPaymentMethodForAPI(PaymentMethod method) {
  switch (method) {
    case PaymentMethod.card:
    case PaymentMethod.applePay: // Apple Pay 复用 card PaymentIntent
      return 'card';
    case PaymentMethod.alipay:
      return 'alipay';
    case PaymentMethod.wechatPay:
      return null; // 微信走独立的 Checkout Session
  }
}

/// 支付页面
///
/// 对齐 iOS StripePaymentView.swift + PaymentViewModel.swift
/// - 信用卡/借记卡、支付宝：Stripe PaymentSheet
/// - Apple Pay：Stripe Platform Pay (STPApplePayContext)
/// - 微信支付：Stripe Checkout Session + WebView
class PaymentView extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PaymentBloc(
        paymentRepository: context.read<PaymentRepository>(),
      )..add(PaymentCreateIntent(
          taskId: taskId,
          preferredPaymentMethod: 'card', // 默认卡支付，对齐 iOS
        )),
      child: _PaymentContent(
        taskId: taskId,
        amount: amount,
        expiresAt: expiresAt,
      ),
    );
  }
}

/// 支付内容页面 —— 对齐 iOS StripePaymentView
class _PaymentContent extends StatefulWidget {
  const _PaymentContent({
    required this.taskId,
    this.amount,
    this.expiresAt,
  });

  final int taskId;
  final double? amount;
  final DateTime? expiresAt;

  @override
  State<_PaymentContent> createState() => _PaymentContentState();
}

class _PaymentContentState extends State<_PaymentContent> {
  // 仅保留 UI 本地状态（支付方式选择 & 倒计时），其余状态由 BLoC 管理
  PaymentMethod _selectedPaymentMethod = PaymentMethod.card;
  Timer? _countdownTimer;
  Duration? _remainingTime;

  @override
  void initState() {
    super.initState();
    _startCountdownIfNeeded();
    // 自动检查支付状态 —— 对齐 iOS viewDidAppear 中的 checkPaymentStatus()
    // 处理用户返回支付页时已通过其他渠道完成支付的场景
    _checkPaymentStatusOnInit();
  }

  /// 初始化时检查支付状态（延迟执行，等待 PaymentIntent 创建完成后再检查）
  Future<void> _checkPaymentStatusOnInit() async {
    // 等待 BLoC 创建 PaymentIntent 完成
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    context.read<PaymentBloc>().add(PaymentCheckStatus(widget.taskId));
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  // ==================== 支付方式切换（对齐 iOS methodSwitched）====================

  /// 切换支付方式时重建 PaymentIntent
  ///
  /// 对齐 iOS PaymentViewModel.methodSwitched():
  /// - card → createPaymentIntent(preferred: 'card')
  /// - alipay → createPaymentIntent(preferred: 'alipay')
  /// - applePay → 复用 card intent，不需要重建
  /// - wechatPay → 不需要 PaymentIntent（走 Checkout Session）
  void _onPaymentMethodChanged(PaymentMethod newMethod) {
    final oldMethod = _selectedPaymentMethod;
    setState(() => _selectedPaymentMethod = newMethod);

    // 判断是否需要重建 PaymentIntent
    final oldApiMethod = _preferredPaymentMethodForAPI(oldMethod);
    final newApiMethod = _preferredPaymentMethodForAPI(newMethod);

    if (newApiMethod != null && newApiMethod != oldApiMethod) {
      context.read<PaymentBloc>().add(PaymentCreateIntent(
            taskId: widget.taskId,
            preferredPaymentMethod: newApiMethod,
            isMethodSwitch: true,
          ));
    }
  }

  // ==================== 倒计时 ====================

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
        title: Text(context.l10n.paymentExpired),
        content: Text(context.l10n.paymentExpiredMessage),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.pop();
            },
            child: Text(context.l10n.commonOk),
          ),
        ],
      ),
    );
  }

  // ==================== 支付处理（对齐 iOS processPayment）====================

  /// 根据选择的支付方式发起支付
  ///
  /// 对齐 iOS PaymentViewModel.processPayment():
  /// - 免费订单：后端在创建 PaymentIntent 时已处理，直接标记成功
  /// - Card：Stripe PaymentSheet
  /// - Apple Pay：Stripe Platform Pay (confirmPlatformPayPaymentIntent)
  /// - Alipay：Stripe PaymentSheet（PaymentIntent 已配置 alipay 方式）
  /// - WeChat：Stripe Checkout Session + WebView
  Future<void> _processPayment() async {
    final bloc = context.read<PaymentBloc>();
    final state = bloc.state;
    if (state.paymentResponse == null) return;

    // 免费订单 —— 后端已在创建 PaymentIntent 时处理
    if (state.paymentResponse!.isFree) {
      bloc.add(const PaymentMarkSuccess());
      return;
    }

    switch (_selectedPaymentMethod) {
      case PaymentMethod.card:
        await _presentStripePaymentSheet();
        break;
      case PaymentMethod.applePay:
        await _presentApplePay();
        break;
      case PaymentMethod.alipay:
        await _presentStripePaymentSheet();
        break;
      case PaymentMethod.wechatPay:
        _startWeChatPayment();
        break;
    }
  }

  /// Card / Alipay —— 通过 Stripe PaymentSheet 完成支付
  ///
  /// 对齐 iOS PaymentViewModel.confirmAlipayPaymentViaPaymentSheet()
  /// 和 PaymentViewModel.confirmCardPayment() 内的 PaymentSheet 流程
  Future<void> _presentStripePaymentSheet() async {
    final bloc = context.read<PaymentBloc>();
    final response = bloc.state.paymentResponse!;

    if (!response.requiresStripePayment) {
      bloc.add(const PaymentMarkSuccess());
      return;
    }

    bloc.add(const PaymentStartProcessing());

    try {
      final success = await PaymentService.instance.presentPaymentSheet(
        clientSecret: response.clientSecret!,
        customerId: response.customerId ?? '',
        ephemeralKeySecret: response.ephemeralKeySecret ?? '',
      );

      if (!mounted) return;
      if (success) {
        bloc.add(const PaymentMarkSuccess());
      } else {
        // 用户取消 —— 恢复到 ready 状态
        bloc.add(const PaymentClearError());
      }
    } catch (e) {
      if (mounted) {
        bloc.add(PaymentMarkFailed(_formatPlatformPaymentError(e)));
      }
    }
  }

  /// Apple Pay —— 通过 Stripe Platform Pay API 完成支付
  ///
  /// 对齐 iOS PaymentViewModel.startApplePay()
  /// 使用 STPApplePayContext / confirmPlatformPayPaymentIntent
  Future<void> _presentApplePay() async {
    if (kIsWeb) {
      context.read<PaymentBloc>().add(
            PaymentMarkFailed(context.l10n.paymentApplePayIOSOnly),
          );
      return;
    }

    final bloc = context.read<PaymentBloc>();
    final response = bloc.state.paymentResponse!;

    if (!response.requiresStripePayment) {
      bloc.add(const PaymentMarkSuccess());
      return;
    }

    bloc.add(const PaymentStartProcessing());

    // 在 await 之前获取本地化字符串，避免异步间隙使用 BuildContext
    final notSupportedMsg = context.l10n.paymentApplePayNotSupported;
    final label = context.l10n.paymentApplePayLabel(widget.taskId);

    try {
      final paymentService = PaymentService.instance;
      final isSupported = await paymentService.isApplePaySupported();
      if (!isSupported) {
        if (mounted) {
          bloc.add(PaymentMarkFailed(notSupportedMsg));
        }
        return;
      }

      final success = await paymentService.presentApplePay(
        clientSecret: response.clientSecret!,
        amount: response.finalAmount,
        currency: response.currency,
        label: label,
      );

      if (!mounted) return;
      if (success) {
        bloc.add(const PaymentMarkSuccess());
      } else {
        bloc.add(const PaymentClearError());
      }
    } catch (e) {
      if (mounted) {
        bloc.add(PaymentMarkFailed(_formatPlatformPaymentError(e)));
      }
    }
  }

  /// 微信支付 —— 通过 Stripe Checkout Session + WebView 完成支付
  ///
  /// 对齐 iOS PaymentViewModel.confirmWeChatPayment()
  /// Stripe PaymentSheet 不支持微信支付，需要通过 Checkout Session
  /// 创建 checkout_url → 在 WebView 中打开 → 用户扫码支付
  void _startWeChatPayment() {
    final state = context.read<PaymentBloc>().state;
    context.read<PaymentBloc>().add(
          PaymentCreateWeChatSession(
            taskId: widget.taskId,
            couponId: state.selectedCouponId,
          ),
        );
  }

  /// 打开微信支付 WebView
  ///
  /// 对齐 iOS WeChatPayWebView.swift
  /// 通过 URL 检测 payment-success / payment-cancel 判断支付结果
  Future<void> _openWeChatWebView(String checkoutUrl) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _WeChatPayWebView(
          checkoutUrl: checkoutUrl,
          onPaymentSuccess: () => Navigator.of(context).pop(true),
          onPaymentCancel: () => Navigator.of(context).pop(false),
        ),
      ),
    );
    if (!mounted) return;
    if (result == true) {
      context.read<PaymentBloc>().add(const PaymentMarkSuccess());
    } else {
      context.read<PaymentBloc>().add(const PaymentClearError());
    }
  }

  /// 平台原生支付错误格式化
  String _formatPlatformPaymentError(dynamic error) {
    final msg = error.toString();
    if (msg.contains('insufficient_funds')) {
      return context.l10n.errorInsufficientFunds;
    } else if (msg.contains('card_declined')) {
      return context.l10n.errorCardDeclined;
    } else if (msg.contains('expired_card')) {
      return context.l10n.errorExpiredCard;
    } else if (msg.contains('network')) {
      return context.l10n.paymentNetworkConnectionFailed;
    } else if (msg.contains('timeout')) {
      return context.l10n.paymentRequestTimeout;
    }
    return msg
        .replaceAll('PaymentException: ', '')
        .replaceAll('PaymentServiceException: ', '');
  }

  // ==================== 支付成功 ====================

  void _showPaymentSuccess() {
    AppHaptics.heavy();
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
            Text(context.l10n.paymentSuccess),
          ],
        ),
        content: Text(
          context.l10n.paymentSuccessMessage,
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
              child: Text(context.l10n.commonOk),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 优惠券 ====================

  Future<void> _showCouponSelector() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _CouponSelectorSheet(
        selectedCouponId: context.read<PaymentBloc>().state.selectedCouponId,
      ),
    );

    if (result != null && mounted) {
      final bloc = context.read<PaymentBloc>();
      bloc.add(PaymentSelectCoupon(
        couponId: result['id'] as int?,
        couponName: result['name'] as String?,
      ));
      // 重新创建支付意向（含优惠券 + 当前支付方式）
      bloc.add(PaymentCreateIntent(
        taskId: widget.taskId,
        couponId: result['id'] as int?,
        preferredPaymentMethod:
            _preferredPaymentMethodForAPI(_selectedPaymentMethod),
      ));
    }
  }

  void _removeCoupon() {
    final bloc = context.read<PaymentBloc>();
    bloc.add(const PaymentRemoveCoupon());
    bloc.add(PaymentCreateIntent(
      taskId: widget.taskId,
      preferredPaymentMethod:
          _preferredPaymentMethodForAPI(_selectedPaymentMethod),
    ));
  }

  // ==================== 构建 UI ====================

  @override
  Widget build(BuildContext context) {
    return BlocListener<PaymentBloc, PaymentState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          (prev.weChatCheckoutUrl == null && curr.weChatCheckoutUrl != null),
      listener: (context, state) {
        // 支付成功 → 弹出成功对话框
        if (state.status == PaymentStatus.success) {
          _showPaymentSuccess();
        }
        // 微信支付 Checkout URL 就绪 → 打开 WebView
        if (state.weChatCheckoutUrl != null &&
            state.status == PaymentStatus.ready) {
          _openWeChatWebView(state.weChatCheckoutUrl!);
        }
      },
      child: BlocBuilder<PaymentBloc, PaymentState>(
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: Text(context.l10n.paymentConfirmPayment)),
            body: state.isLoading
                ? const LoadingView()
                : SafeArea(
                    child: Stack(
                      children: [
                        Column(
                          children: [
                            // 支付倒计时
                            if (_remainingTime != null) _buildCountdownBanner(),

                            Expanded(
                              child: SingleChildScrollView(
                                padding: AppSpacing.allLg,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // 错误提示
                                    if (state.errorMessage != null) ...[
                                      _buildErrorBanner(state.errorMessage!),
                                      AppSpacing.vMd,
                                    ],

                                    // 订单信息
                                    _buildOrderInfo(state.paymentResponse),
                                    AppSpacing.vLg,

                                    // 支付方式选择
                                    _buildPaymentMethodSection(),
                                    AppSpacing.vLg,

                                    // 优惠券选择
                                    _buildCouponSection(state),
                                  ],
                                ),
                              ),
                            ),

                            // 底部支付按钮
                            _buildPayButton(state),
                          ],
                        ),

                        // 方法切换时的半透明加载指示器
                        if (state.isMethodSwitching)
                          Positioned.fill(
                            child: Container(
                              color: Colors.black.withValues(alpha: 0.05),
                              child: const Center(
                                child: SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          );
        },
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
            context.l10n.paymentRemainingTime('${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}'),
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

  Widget _buildErrorBanner(String errorMessage) {
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
              errorMessage,
              style: const TextStyle(color: AppColors.error, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: () =>
                context.read<PaymentBloc>().add(const PaymentClearError()),
            child: const Icon(Icons.close, color: AppColors.error, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderInfo(TaskPaymentResponse? response) {
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
          Text(
            context.l10n.paymentOrderInfo,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          AppSpacing.vMd,
          _InfoRow(label: context.l10n.paymentTaskNumber, value: '#${widget.taskId}'),
          if (response != null) ...[
            AppSpacing.vSm,
            _InfoRow(
              label: context.l10n.paymentOriginalPrice,
              value: response.originalAmountDisplay.isNotEmpty
                  ? response.originalAmountDisplay
                  : '£${(response.originalAmount / 100).toStringAsFixed(2)}',
            ),
            if (response.hasDiscount) ...[
              AppSpacing.vSm,
              _InfoRow(
                label: context.l10n.paymentDiscount(response.couponName ?? ''),
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
              label: context.l10n.paymentFinalAmount,
              value: response.finalAmountDisplay.isNotEmpty
                  ? response.finalAmountDisplay
                  : '£${(response.finalAmount / 100).toStringAsFixed(2)}',
              valueStyle: const TextStyle(
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
        Text(
          context.l10n.paymentMethod,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        AppSpacing.vMd,
        _PaymentMethodTile(
          icon: Icons.credit_card,
          title: context.l10n.paymentCreditDebitCard,
          subtitle: 'Visa, Mastercard, AMEX',
          isSelected: _selectedPaymentMethod == PaymentMethod.card,
          onTap: () => _onPaymentMethodChanged(PaymentMethod.card),
        ),
        AppSpacing.vSm,
        if (!kIsWeb) ...[
          _PaymentMethodTile(
            icon: Icons.apple,
            title: 'Apple Pay',
            subtitle: context.l10n.paymentFastSecure,
            isSelected: _selectedPaymentMethod == PaymentMethod.applePay,
            onTap: () => _onPaymentMethodChanged(PaymentMethod.applePay),
          ),
          AppSpacing.vSm,
        ],
        _PaymentMethodTile(
          iconWidget: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.wechatGreen,
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                const Icon(Icons.chat_bubble, color: Colors.white, size: 14),
          ),
          title: context.l10n.paymentWeChatPay,
          subtitle: 'WeChat Pay (Stripe)',
          isSelected: _selectedPaymentMethod == PaymentMethod.wechatPay,
          onTap: () => _onPaymentMethodChanged(PaymentMethod.wechatPay),
        ),
        AppSpacing.vSm,
        _PaymentMethodTile(
          iconWidget: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.alipayBlue,
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
          title: context.l10n.paymentAlipay,
          subtitle: 'Alipay (Stripe)',
          isSelected: _selectedPaymentMethod == PaymentMethod.alipay,
          onTap: () => _onPaymentMethodChanged(PaymentMethod.alipay),
        ),
      ],
    );
  }

  Widget _buildCouponSection(PaymentState state) {
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
              child: state.selectedCouponId != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.selectedCouponName ?? context.l10n.paymentCouponSelected,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (state.paymentResponse?.couponDescription != null)
                          Text(
                            state.paymentResponse!.couponDescription!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                            ),
                          ),
                      ],
                    )
                  : Text(
                      context.l10n.paymentSelectCoupon,
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
            ),
            if (state.selectedCouponId != null)
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

  Widget _buildPayButton(PaymentState state) {
    final response = state.paymentResponse;
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
          text: isFree ? context.l10n.paymentConfirmFree : context.l10n.paymentPayNow(amount),
          isLoading: state.isProcessing,
          onPressed: state.isProcessing ? null : _processPayment,
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
        Text(label, style: const TextStyle(color: AppColors.textSecondaryLight)),
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
        AppHaptics.selection();
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
                      style: const TextStyle(
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
