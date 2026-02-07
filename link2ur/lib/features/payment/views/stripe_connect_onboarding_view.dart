import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/l10n_extension.dart';

/// Stripe Connect 入驻页
/// 参考iOS StripeConnectOnboardingView.swift
class StripeConnectOnboardingView extends StatefulWidget {
  const StripeConnectOnboardingView({
    super.key,
    required this.onboardingUrl,
  });

  final String onboardingUrl;

  @override
  State<StripeConnectOnboardingView> createState() =>
      _StripeConnectOnboardingViewState();
}

class _StripeConnectOnboardingViewState
    extends State<StripeConnectOnboardingView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onNavigationRequest: (request) {
            // 检查回调URL，完成后关闭
            if (request.url.contains('stripe-connect/return') ||
                request.url.contains('stripe-connect/refresh')) {
              Navigator.of(context).pop(true);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.onboardingUrl));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.paymentStripeConnect),
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
