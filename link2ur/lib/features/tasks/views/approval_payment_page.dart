import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_stripe/flutter_stripe.dart' show Stripe, StripeException;

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/models/coupon_points.dart';
import '../../../data/repositories/coupon_points_repository.dart';
import '../../../data/models/payment.dart' show TaskPaymentResponse;
import '../../../data/repositories/payment_repository.dart';
import '../../../data/services/payment_service.dart';
import '../../../core/constants/app_assets.dart';
import '../bloc/task_detail_bloc.dart';
import '../../payment/views/wechat_pay_webview.dart' show WeChatPayWebView;

/// 支付页（对齐 iOS StripePaymentView）
/// 布局：导航栏「支付」+ 取消；可滚动区（倒计时 Banner、金额卡片、支付方式选择）；底部固定支付按钮
class ApprovalPaymentPage extends StatefulWidget {
  const ApprovalPaymentPage({
    super.key,
    required this.paymentData,
  });

  final AcceptPaymentData paymentData;

  @override
  State<ApprovalPaymentPage> createState() => _ApprovalPaymentPageState();
}

enum _PaymentMethod { card, applePay, alipay, wechatPay }

class _ApprovalPaymentPageState extends State<ApprovalPaymentPage> {
  bool _isProcessing = false;
  String? _errorMessage;
  _PaymentMethod _selectedMethod = _PaymentMethod.card;
  bool _applePaySupported = false;
  Timer? _countdownTimer;
  int _secondsRemaining = 0;

  // 优惠券：仅任务支付（taskId != null）时加载与展示
  List<UserCoupon>? _availableCoupons;
  bool _loadingCoupons = false;
  UserCoupon? _selectedUserCoupon;
  // 选券/取消选券后由 createTaskPayment 更新，用于展示金额与调起支付
  String? _effectiveClientSecret;
  String? _effectiveCustomerId;
  String? _effectiveEphemeralKeySecret;
  String? _effectiveAmountDisplay;
  // createTaskPayment 返回的完整响应（用于 Apple Pay amount 等）
  TaskPaymentResponse? _paymentResponse;
  // 支付宝单独 PaymentIntent（选择支付宝时懒加载）
  String? _alipayClientSecret;
  String? _alipayCustomerId;
  String? _alipayEphemeralKeySecret;
  bool _alipayLoading = false;

  /// 任务支付时轮询支付状态（对齐 iOS checkPaymentStatus），避免原生未回调导致一直转圈
  Timer? _paymentPollTimer;
  /// 轮询次数，用于前 30 次 1s 后改为 2s（支付宝等延迟方式需更早发现成功）
  int _paymentPollCount = 0;
  /// 已由轮询检测到支付成功并 pop，避免 presentPaymentSheet 晚回调时重复 pop
  bool _paymentSuccessFromPolling = false;
  /// 支付成功：显示成功 overlay，延迟后 pop（对齐 iOS paymentSuccessView）
  bool _showPaymentSuccess = false;
  /// 进入页面时检测到任务已支付，禁止再次支付并直接展示成功
  bool _alreadyPaid = false;

  @override
  void initState() {
    super.initState();
    _effectiveClientSecret = widget.paymentData.clientSecret;
    _effectiveCustomerId = widget.paymentData.customerId;
    _effectiveEphemeralKeySecret = widget.paymentData.ephemeralKeySecret;
    _effectiveAmountDisplay = widget.paymentData.amountDisplay;
    _initCountdown();
    _loadCouponsIfTaskPayment();
    _checkAlreadyPaid();
    PaymentService.instance.isApplePaySupported().then((v) {
      if (mounted) setState(() => _applePaySupported = v);
    });
    // 提前检查 Stripe 初始化状态，如果 publishableKey 为空则立即显示错误
    if (Stripe.publishableKey.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppLogger.error('Payment page opened but Stripe publishableKey is empty. '
            'Did you pass --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx?');
        setState(() {
          _errorMessage = kDebugMode
              ? 'Stripe key not configured. Pass --dart-define=STRIPE_PUBLISHABLE_KEY_TEST=pk_test_xxx'
              : context.l10n.paymentLoadFailed;
        });
      });
    }
  }

  /// 进入页面时检查任务是否已支付，若已支付则禁止再次支付并直接展示成功（防重复支付）
  Future<void> _checkAlreadyPaid() async {
    final taskId = widget.paymentData.taskId;
    final repo = context.read<PaymentRepository>();
    try {
      final statusData = await repo.getTaskPaymentStatus(taskId);
      if (!mounted) return;
      final isPaid = statusData['is_paid'] == true;
      final details = statusData['payment_details'] as Map<String, dynamic>?;
      final piStatus = details?['status'] as String?;
      if (isPaid || piStatus == 'succeeded') {
        setState(() {
          _alreadyPaid = true;
          _showPaymentSuccess = true;
        });
        AppHaptics.paymentSuccess();
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (!mounted) return;
          Navigator.of(context).pop(true);
        });
      }
    } catch (_) { /* 忽略，按未支付处理 */ }
  }

  /// 选择支付宝时懒加载 Alipay PaymentIntent
  Future<void> _ensureAlipayPaymentData() async {
    if (_alipayClientSecret != null || _alipayLoading) return;
    final taskId = widget.paymentData.taskId;
    setState(() => _alipayLoading = true);
    try {
      final response = await context.read<PaymentRepository>().createTaskPayment(
        taskId: taskId,
        userCouponId: _selectedUserCoupon?.id,
        preferredPaymentMethod: 'alipay',
        taskSource: widget.paymentData.taskSource,
        fleaMarketItemId: widget.paymentData.fleaMarketItemId,
      );
      if (!mounted) return;
      setState(() {
        _alipayClientSecret = response.clientSecret;
        _alipayCustomerId = response.customerId;
        _alipayEphemeralKeySecret = response.ephemeralKeySecret;
        _alipayLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _alipayLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// 支付成功：显示成功界面，1.5 秒后 pop（对齐 iOS paymentSuccessView，避免用户困惑或重复付款）
  void _handlePaymentSuccess() {
    if (!mounted || _showPaymentSuccess) return;
    _paymentPollTimer?.cancel();
    _paymentPollTimer = null;
    _paymentSuccessFromPolling = true;
    setState(() {
      _isProcessing = false;
      _showPaymentSuccess = true;
    });
    AppHaptics.paymentSuccess();
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pop(true);
    });
  }

  void _loadCouponsIfTaskPayment() {
    setState(() => _loadingCoupons = true);
    context.read<CouponPointsRepository>().getMyCoupons(status: 'unused').then((list) {
      if (mounted) {
        setState(() {
          _availableCoupons = list;
          _loadingCoupons = false;
        });
      }
    }).catchError((_) {
      if (mounted) {
        setState(() {
          _availableCoupons = [];
          _loadingCoupons = false;
        });
      }
    });
  }

  Future<void> _applyCoupon(UserCoupon? coupon) async {
    final taskId = widget.paymentData.taskId;
    final previous = _selectedUserCoupon;
    setState(() {
      _selectedUserCoupon = coupon;
      _errorMessage = null;
    });
    try {
      final response = await context.read<PaymentRepository>().createTaskPayment(
        taskId: taskId,
        userCouponId: coupon?.id,
        taskSource: widget.paymentData.taskSource,
        fleaMarketItemId: widget.paymentData.fleaMarketItemId,
      );
      if (!mounted) return;
      setState(() {
        _paymentResponse = response;
        _effectiveClientSecret = response.clientSecret;
        _effectiveCustomerId = response.customerId;
        _effectiveEphemeralKeySecret = response.ephemeralKeySecret;
        _effectiveAmountDisplay = response.finalAmountDisplay;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedUserCoupon = previous;
        _errorMessage = e.toString().replaceAll('PaymentException: ', '');
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? ''),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _initCountdown() {
    final expiresAt = widget.paymentData.paymentExpiresAt;
    if (expiresAt == null || expiresAt.isEmpty) return;
    DateTime? expiry;
    try {
      expiry = DateTime.parse(expiresAt);
    } catch (_) {}
    if (expiry == null) return;
    void update() {
      if (!mounted) return;
      final now = DateTime.now().toUtc();
      final diff = expiry!.toUtc().difference(now);
      final sec = diff.inSeconds;
      setState(() => _secondsRemaining = sec > 0 ? sec : 0);
      if (sec <= 0) _countdownTimer?.cancel();
    }

    update();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) => update());
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _paymentPollTimer?.cancel();
    super.dispose();
  }

  /// 是否显示 Apple Pay 选项：iOS 上始终显示（与原生一致）；Android 仅在 Platform Pay 可用时显示
  bool _showApplePayOption() {
    if (kIsWeb) return false;
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    return _applePaySupported;
  }

  /// Platform Pay 显示文案：iOS → Apple Pay，Android → Google Pay
  String _platformPayLabel(dynamic l10n) =>
      defaultTargetPlatform == TargetPlatform.iOS
          ? l10n.paymentPayWithApplePay
          : l10n.paymentPayWithGooglePay;

  String _payButtonText(dynamic l10n) {
    switch (_selectedMethod) {
      case _PaymentMethod.applePay:
        return _platformPayLabel(l10n);
      case _PaymentMethod.alipay:
        return l10n.paymentPayWithAlipay;
      case _PaymentMethod.wechatPay:
        return l10n.wechatPayTitle;
      case _PaymentMethod.card:
        return l10n.paymentConfirmPayment;
    }
  }

  IconData? _payButtonIcon() {
    switch (_selectedMethod) {
      case _PaymentMethod.applePay:
        return defaultTargetPlatform == TargetPlatform.iOS
            ? Icons.apple
            : Icons.account_balance_wallet;
      case _PaymentMethod.alipay:
      case _PaymentMethod.wechatPay:
        return null; // 使用 leading 显示 logo
      case _PaymentMethod.card:
        return Icons.credit_card;
    }
  }

  Widget? _payButtonLeading() {
    switch (_selectedMethod) {
      case _PaymentMethod.alipay:
        return Image.asset(
          AppAssets.alipay,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        );
      case _PaymentMethod.wechatPay:
        return Image.asset(
          AppAssets.wechatPay,
          width: 20,
          height: 20,
          fit: BoxFit.contain,
        );
      case _PaymentMethod.card:
      case _PaymentMethod.applePay:
        return null;
    }
  }

  String _formatPaymentError(dynamic e) {
    // StripeException：提取 SDK 的 localizedMessage，Debug 模式附加错误码
    if (e is StripeException) {
      final stripeError = e.error;
      final userMessage = stripeError.localizedMessage
          ?? stripeError.message
          ?? context.l10n.paymentLoadFailed;
      if (kDebugMode) {
        return '$userMessage (code: ${stripeError.code}, declineCode: ${stripeError.declineCode})';
      }
      return userMessage;
    }
    final msg = e.toString();
    // PlatformException 包裹的 Stripe 错误（如 flutter_stripe initialization failed）
    if (msg.contains('flutter_stripe')) {
      if (kDebugMode) return msg;
      return context.l10n.paymentLoadFailed;
    }
    return msg
        .replaceAll('PaymentServiceException: ', '')
        .replaceAll('PaymentException: ', '')
        .replaceAll('Instance of \'', '')
        .replaceAll('\'', '');
  }

  Future<void> _pay() async {
    if (_isProcessing || _alreadyPaid) return;
    final taskId = widget.paymentData.taskId;

    // 微信支付：Checkout Session + WebView
    if (_selectedMethod == _PaymentMethod.wechatPay) {
      setState(() {
        _isProcessing = true;
        _errorMessage = null;
      });
      try {
        final url = await context.read<PaymentRepository>().createWeChatCheckoutSession(
          taskId: taskId,
          couponId: _selectedUserCoupon?.id,
          taskSource: widget.paymentData.taskSource,
          fleaMarketItemId: widget.paymentData.fleaMarketItemId,
        );
        if (!mounted) return;
        if (url.isEmpty) throw Exception('No checkout URL');
        final nav = Navigator.of(context);
        final result = await nav.push<bool>(
          MaterialPageRoute(
            builder: (routeContext) => WeChatPayWebView(
              checkoutUrl: url,
              onPaymentSuccess: () => Navigator.of(routeContext).pop(true),
              onPaymentCancel: () => Navigator.of(routeContext).pop(false),
            ),
          ),
        );
        if (!mounted) return;
        if (result == true) {
          setState(() {
            _isProcessing = false;
            _showPaymentSuccess = true;
          });
          AppHaptics.paymentSuccess();
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (!mounted) return;
            Navigator.of(context).pop(true);
          });
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_formatPaymentError(e)), backgroundColor: AppColors.error),
        );
      }
      setState(() => _isProcessing = false);
      return;
    }

    // 支付宝：先确保已拉取 Alipay PaymentIntent
    if (_selectedMethod == _PaymentMethod.alipay) {
      await _ensureAlipayPaymentData();
      if (!mounted) return;
      if (_alipayClientSecret == null || _alipayClientSecret!.isEmpty) {
        setState(() => _isProcessing = false);
        return;
      }
    }

    final useAlipay = _selectedMethod == _PaymentMethod.alipay;
    final clientSecret = useAlipay
        ? _alipayClientSecret
        : (_effectiveClientSecret ?? widget.paymentData.clientSecret);
    final customerId = useAlipay
        ? _alipayCustomerId
        : (_effectiveCustomerId ?? widget.paymentData.customerId);
    final ephemeralKey = useAlipay
        ? _alipayEphemeralKeySecret
        : (_effectiveEphemeralKeySecret ?? widget.paymentData.ephemeralKeySecret);

    if (clientSecret == null || clientSecret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.paymentLoadFailed)),
      );
      return;
    }
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
      _paymentSuccessFromPolling = false;
    });

    // 任务支付且为银行卡/支付宝时：轮询支付状态（对齐 iOS checkPaymentStatus），避免原生未回调导致一直转圈
    // 支付宝等为延迟支付方式，Stripe 需等支付宝回调后才更新为 succeeded，故前 30s 每 1s 轮询以更快反馈
    final isCardOrAlipay = _selectedMethod == _PaymentMethod.card || _selectedMethod == _PaymentMethod.alipay;
    if (isCardOrAlipay) {
      _paymentPollTimer?.cancel();
      _paymentPollCount = 0;
      final repo = context.read<PaymentRepository>();
      Future<void> doPoll() async {
        if (!mounted) return;
        if (!_isProcessing) return;
        try {
          final statusData = await repo.getTaskPaymentStatus(taskId);
          final isPaid = statusData['is_paid'] == true;
          final details = statusData['payment_details'] as Map<String, dynamic>?;
          final piStatus = details?['status'] as String?;
          if (isPaid || piStatus == 'succeeded') {
            _handlePaymentSuccess();
          }
        } catch (_) { /* 忽略单次轮询失败 */ }
      }
      // 首次 0.5 秒后轮询，之后前 30 秒每 1 秒、再后每 2 秒（尽快发现支付宝/卡支付成功，减少用户误以为未成功而重复支付）
      Timer(const Duration(milliseconds: 500), doPoll);
      _paymentPollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        doPoll();
        _paymentPollCount++;
        if (_paymentPollCount == 30 && mounted) {
          _paymentPollTimer?.cancel();
          _paymentPollTimer = Timer.periodic(const Duration(seconds: 2), (_) => doPoll());
        }
      });
    }

    try {
      const paymentTimeout = Duration(seconds: 90);
      bool success = false;
      if (_selectedMethod == _PaymentMethod.applePay) {
        final amountPence = _paymentResponse?.finalAmount
            ?? ((double.tryParse(widget.paymentData.amountDisplay ?? '') ?? 0) * 100).round();
        success = await PaymentService.instance.presentApplePay(
          clientSecret: clientSecret,
          amount: amountPence.round(),
        ).timeout(paymentTimeout);
      } else {
        success = await PaymentService.instance.presentPaymentSheet(
          clientSecret: clientSecret,
          customerId: customerId,
          ephemeralKeySecret: ephemeralKey,
          preferredPaymentMethod: useAlipay ? 'alipay' : null,
        ).timeout(paymentTimeout);
      }
      if (!mounted) return;
      if (_paymentSuccessFromPolling) return; // 已由轮询 pop，避免重复
      if (success) {
        _handlePaymentSuccess();
      } else if (isCardOrAlipay) {
        // 支付宝/卡：Sheet 关闭但未成功，不锁定按钮（有 deeplink 可处理支付完成回跳）
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.paymentWaitingConfirmHint),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      } else {
        setState(() => _isProcessing = false);
      }
    } on TimeoutException {
      if (!mounted) return;
      _paymentPollTimer?.cancel();
      _paymentPollTimer = null;
      if (_paymentSuccessFromPolling) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.paymentTimeoutOrRefreshHint),
          backgroundColor: AppColors.primary,
        ),
      );
    } catch (e, st) {
      if (!mounted) return;
      _paymentPollTimer?.cancel();
      _paymentPollTimer = null;
      if (_paymentSuccessFromPolling) return;
      // 输出完整错误到终端，方便调试（UI 上只显示格式化后的友好文案）
      AppLogger.error('Payment failed in ApprovalPaymentPage', e, st);
      setState(() {
        _isProcessing = false;
        _errorMessage = _formatPaymentError(e);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_errorMessage ?? ''),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      _paymentPollTimer?.cancel();
      _paymentPollTimer = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final amountDisplay = _effectiveAmountDisplay ?? widget.paymentData.amountDisplay;
    final amountText = amountDisplay != null && amountDisplay.isNotEmpty
        ? '£$amountDisplay'
        : '';
    const showCouponSection = true; // taskId is always non-null (int)
    final showCountdown = widget.paymentData.paymentExpiresAt != null &&
        widget.paymentData.paymentExpiresAt!.isNotEmpty;
    final isExpired = showCountdown && _secondsRemaining <= 0;

    return PopScope(
      canPop: !_isProcessing,
      child: Stack(
      children: [
        Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentPayment),
        leading: IconButton(
          icon: Text(
            l10n.paymentCancel,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w400,
            ),
          ),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 任务信息卡片（批准后支付时显示，对齐 iOS）
                  if (widget.paymentData.taskTitle != null ||
                      widget.paymentData.applicantName != null) ...[
                    _TaskInfoCard(
                      taskTitle: widget.paymentData.taskTitle,
                      applicantName: widget.paymentData.applicantName,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (showCountdown) ...[
                    _CountdownBanner(
                      secondsRemaining: _secondsRemaining,
                      isExpired: isExpired,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  // 优惠券选择（仅任务支付时显示，对齐 iOS couponSelectionCard）
                  if (showCouponSection) ...[
                    _CouponSelectionCard(
                      availableCoupons: _availableCoupons,
                      loading: _loadingCoupons,
                      selectedUserCoupon: _selectedUserCoupon,
                      onSelectNone: () => _applyCoupon(null),
                      onSelectCoupon: _applyCoupon,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  if (amountText.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            l10n.paymentFinalPayment,
                            style: AppTypography.bodyBold,
                          ),
                          Text(
                            amountText,
                            style: AppTypography.title2.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  // 支付方式选择卡片（对齐 iOS paymentMethodSelectionCard）
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.credit_card,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              l10n.paymentSelectMethod,
                              style: AppTypography.title3,
                            ),
                          ],
                        ),
                        const Divider(height: 24),
                        _PaymentMethodOption(
                          icon: Icons.credit_card,
                          label: l10n.paymentCreditDebitCard,
                          isSelected: _selectedMethod == _PaymentMethod.card,
                          onTap: () => setState(() => _selectedMethod = _PaymentMethod.card),
                        ),
                        // Platform Pay：iOS → Apple Pay，Android → Google Pay（isPlatformPaySupported）
                        if (_showApplePayOption()) ...[
                          const SizedBox(height: 12),
                          _PaymentMethodOption(
                            icon: defaultTargetPlatform == TargetPlatform.iOS
                                ? Icons.apple
                                : Icons.account_balance_wallet,
                            label: _platformPayLabel(l10n),
                            isSelected: _selectedMethod == _PaymentMethod.applePay,
                            onTap: () => setState(() => _selectedMethod = _PaymentMethod.applePay),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _PaymentMethodOption(
                          imageAsset: AppAssets.alipay,
                          label: l10n.paymentPayWithAlipay,
                          isSelected: _selectedMethod == _PaymentMethod.alipay,
                          onTap: () {
                            setState(() => _selectedMethod = _PaymentMethod.alipay);
                            _ensureAlipayPaymentData();
                          },
                        ),
                        const SizedBox(height: 12),
                        _PaymentMethodOption(
                          imageAsset: AppAssets.wechatPay,
                          label: l10n.wechatPayTitle,
                          isSelected: _selectedMethod == _PaymentMethod.wechatPay,
                          onTap: () => setState(() => _selectedMethod = _PaymentMethod.wechatPay),
                        ),
                      ],
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // 底部固定支付按钮栏（对齐 iOS paymentButtonBar）
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isProcessing &&
                          (_selectedMethod == _PaymentMethod.card ||
                              _selectedMethod == _PaymentMethod.alipay))
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: Text(
                            l10n.paymentConfirmingDoNotRepeat,
                            style: AppTypography.caption.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      PrimaryButton(
                        text: _payButtonText(l10n),
                        icon: _payButtonIcon(),
                        leading: _payButtonLeading(),
                        isLoading: _isProcessing,
                        onPressed: (_isProcessing || _alreadyPaid) ? null : _pay,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
        if (_showPaymentSuccess)
          Positioned.fill(
            child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  size: 64,
                  color: AppColors.success,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  l10n.paymentSuccess,
                  style: AppTypography.title2.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                  child: Text(
                    l10n.paymentSuccessMessage,
                    textAlign: TextAlign.center,
                    style: AppTypography.body.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ),
      ],
    ));
  }
}

class _TaskInfoCard extends StatelessWidget {
  const _TaskInfoCard({
    this.taskTitle,
    this.applicantName,
  });

  final String? taskTitle;
  final String? applicantName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.paymentTaskInfo,
                style: AppTypography.title3,
              ),
            ],
          ),
          const Divider(height: 24),
          if (taskTitle != null && taskTitle!.isNotEmpty) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.list_alt, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.paymentTaskTitle,
                        style: AppTypography.subheadline.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        taskTitle!,
                        style: AppTypography.bodyBold,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (applicantName != null && applicantName!.isNotEmpty) ...[
            if (taskTitle != null && taskTitle!.isNotEmpty) const Divider(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.paymentApplicant,
                        style: AppTypography.subheadline.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        applicantName!,
                        style: AppTypography.bodyBold,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CountdownBanner extends StatelessWidget {
  const _CountdownBanner({
    required this.secondsRemaining,
    required this.isExpired,
  });

  final int secondsRemaining;
  final bool isExpired;

  String get _formatted {
    if (secondsRemaining <= 0) return '0:00';
    final m = secondsRemaining ~/ 60;
    final s = secondsRemaining % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = isExpired ? AppColors.error : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(
            isExpired ? Icons.warning_amber_rounded : Icons.schedule,
            size: 20,
            color: color,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isExpired
                      ? l10n.paymentCountdownExpired
                      : l10n.paymentCountdownBannerTitle,
                  style: AppTypography.bodyBold.copyWith(color: color),
                ),
                if (!isExpired)
                  Text(
                    l10n.paymentCountdownBannerSubtitle(_formatted),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
          if (!isExpired)
            Text(
              _formatted,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: color,
              ),
            ),
        ],
      ),
    );
  }
}

class _PaymentMethodOption extends StatelessWidget {
  const _PaymentMethodOption({
    this.icon,
    this.imageAsset,
    required this.label,
    required this.isSelected,
    required this.onTap,
  }) : assert(icon != null || imageAsset != null);

  final IconData? icon;
  final String? imageAsset;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: imageAsset != null
                  ? Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(imageAsset!, fit: BoxFit.contain),
                    )
                  : Icon(
                      icon,
                      size: 24,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: AppTypography.body,
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                size: 20,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

/// 优惠券选择卡片（仅任务支付页显示，对齐 iOS couponSelectionCard）
class _CouponSelectionCard extends StatelessWidget {
  const _CouponSelectionCard({
    required this.availableCoupons,
    required this.loading,
    required this.selectedUserCoupon,
    required this.onSelectNone,
    required this.onSelectCoupon,
  });

  final List<UserCoupon>? availableCoupons;
  final bool loading;
  final UserCoupon? selectedUserCoupon;
  final VoidCallback onSelectNone;
  final ValueChanged<UserCoupon> onSelectCoupon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                l10n.paymentCoupons,
                style: AppTypography.title3,
              ),
            ],
          ),
          const Divider(height: 24),
          // 不使用优惠券
          _CouponRow(
            label: l10n.paymentDoNotUseCoupon,
            isSelected: selectedUserCoupon == null,
            onTap: onSelectNone,
          ),
          if (loading) ...[
            const SizedBox(height: 12),
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          ] else if (availableCoupons != null) ...[
            ...availableCoupons!.map((uc) {
              final c = uc.coupon;
              final subtitle = c.minAmount > 0
                  ? l10n.couponMinAmountAvailable(c.minAmountDisplay)
                  : l10n.couponNoThreshold;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _CouponRow(
                  label: c.name,
                  subtitle: '${c.discountValueDisplay} · $subtitle',
                  isSelected: selectedUserCoupon?.id == uc.id,
                  onTap: () => onSelectCoupon(uc),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _CouponRow extends StatelessWidget {
  const _CouponRow({
    required this.label,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(label, style: AppTypography.bodyBold),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, size: 20, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
