import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/l10n_extension.dart';

/// 微信支付 WebView 页面（与 payment_view 共用，供批准支付页等调用）
///
/// 对齐 iOS WeChatPayWebView.swift
/// 使用 webview_flutter 在应用内加载 Stripe Checkout 页面
/// 通过 NavigationDelegate 检测 payment-success / payment-cancel 判断支付结果
class WeChatPayWebView extends StatefulWidget {
  const WeChatPayWebView({
    super.key,
    required this.checkoutUrl,
    required this.onPaymentSuccess,
    required this.onPaymentCancel,
  });

  final String checkoutUrl;
  final VoidCallback onPaymentSuccess;
  final VoidCallback onPaymentCancel;

  @override
  State<WeChatPayWebView> createState() => _WeChatPayWebViewState();
}

class _WeChatPayWebViewState extends State<WeChatPayWebView> {
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
            if (urlLower.contains('payment-success') ||
                urlLower.contains('payment_success') ||
                urlLower.contains('/success')) {
              widget.onPaymentSuccess();
              return NavigationDecision.prevent;
            }
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
            child: Text(
              context.l10n.paymentCancelPayment,
              style: const TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentWeChatPay),
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
                      l10n.webviewLoading,
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                      ),
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
                    const Icon(
                      Icons.error_outline,
                      size: 48,
                      color: AppColors.error,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.paymentLoadFailed,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        OutlinedButton(
                          onPressed: widget.onPaymentCancel,
                          child: Text(l10n.commonBack),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          onPressed: () {
                            setState(() => _errorMessage = null);
                            _controller.loadRequest(Uri.parse(widget.checkoutUrl));
                          },
                          child: Text(l10n.paymentRetry),
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
