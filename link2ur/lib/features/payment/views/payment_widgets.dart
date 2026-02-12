part of 'payment_view.dart';

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
        maxHeight: MediaQuery.sizeOf(context).height * 0.6,
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
          Text(
            context.l10n.paymentSelectCoupon,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: LoadingView(),
              ),
            )
          else if (_coupons.isEmpty)
            Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  const Icon(Icons.local_offer_outlined,
                      size: 48, color: AppColors.textTertiaryLight),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.paymentNoAvailableCoupons,
                    style: const TextStyle(color: AppColors.textSecondaryLight),
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
                  final isSelected = coupon['id'] == widget.selectedCouponId;
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
                              color:
                                  AppColors.accentPink.withValues(alpha: 0.1),
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
                                  coupon['name'] ?? context.l10n.paymentCoupon,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (coupon['description'] != null)
                                  Text(
                                    coupon['description'],
                                    style: const TextStyle(
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
///
/// 对齐 iOS WeChatPayWebView.swift
/// 使用 webview_flutter 在应用内加载 Stripe Checkout 页面
/// 通过 NavigationDelegate.onNavigationRequest 检测 URL 中的
/// payment-success / payment-cancel 来判断支付结果
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
  late WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (NavigationRequest request) {
            final urlLower = request.url.toLowerCase();

            // 检测支付成功 URL（对齐 iOS decidePolicyFor）
            if (urlLower.contains('payment-success') ||
                urlLower.contains('payment_success') ||
                urlLower.contains('/success')) {
              widget.onPaymentSuccess();
              return NavigationDecision.prevent;
            }

            // 检测支付取消 URL
            if (urlLower.contains('payment-cancel') ||
                urlLower.contains('payment_cancel') ||
                urlLower.contains('/cancel')) {
              widget.onPaymentCancel();
              return NavigationDecision.prevent;
            }

            return NavigationDecision.navigate;
          },
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = error.description;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.checkoutUrl));
  }

  void _confirmCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.paymentCancelPayment),
        content: Text(context.l10n.paymentCancelPaymentConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.paymentContinuePayment),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              widget.onPaymentCancel();
            },
            child: Text(context.l10n.paymentCancelPayment,
                style: const TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.paymentWeChatPay),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _confirmCancel,
        ),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: Theme.of(context)
                  .scaffoldBackgroundColor
                  .withValues(alpha: 0.9),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 16),
                    Text(
                      context.l10n.webviewLoading,
                      style: const TextStyle(
                          color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
            ),
          if (_errorMessage != null)
            Container(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: AppColors.error),
                    const SizedBox(height: 12),
                    Text(context.l10n.paymentLoadFailed,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(_errorMessage!,
                        style: const TextStyle(
                            color: AppColors.textSecondaryLight)),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: widget.onPaymentCancel,
                          child: Text(context.l10n.commonBack),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _errorMessage = null);
                            _controller
                                .loadRequest(Uri.parse(widget.checkoutUrl));
                          },
                          child: Text(context.l10n.paymentRetry),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
