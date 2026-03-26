import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';

/// Stripe Connect 账户管理 WebView（Android 替代方案）
///
/// 在 Android 上，原生 Stripe Connect SDK (22.8.0) 不支持嵌入式 AccountManagement 组件，
/// 因此使用 WebView 加载 Stripe.js Connect 的 `<stripe-connect-account-management>` Web Component。
///
/// iOS 使用原生 SDK，不走此页面。
class StripeConnectAccountWebView extends StatefulWidget {
  const StripeConnectAccountWebView({
    super.key,
    required this.publishableKey,
    required this.clientSecret,
  });

  final String publishableKey;
  final String clientSecret;

  /// 全屏打开账户管理 WebView
  static Future<void> open(
    BuildContext context, {
    required String publishableKey,
    required String clientSecret,
  }) {
    return Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => StripeConnectAccountWebView(
          publishableKey: publishableKey,
          clientSecret: clientSecret,
        ),
      ),
    );
  }

  @override
  State<StripeConnectAccountWebView> createState() =>
      _StripeConnectAccountWebViewState();
}

class _StripeConnectAccountWebViewState
    extends State<StripeConnectAccountWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  String? _error;

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
          onPageStarted: (_) {
            if (mounted) setState(() => _isLoading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            AppLogger.error(
              'StripeConnectAccountWebView: web resource error',
              error.description,
            );
            if (mounted) {
              setState(() => _error = error.description);
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'StripeAccountCallback',
        onMessageReceived: (message) {
          AppLogger.info(
            'StripeConnectAccountWebView: callback: ${message.message}',
          );
        },
      )
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    // 使用 Stripe Connect embedded components (Web)
    // https://docs.stripe.com/connect/get-started-connect-embedded-components
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
  <title>Account Management</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      background: #f6f8fa;
    }
    #loading {
      display: flex;
      justify-content: center;
      align-items: center;
      height: 60vh;
      color: #666;
      font-size: 16px;
    }
    #error {
      display: none;
      text-align: center;
      padding: 40px 20px;
      color: #d32f2f;
      font-size: 15px;
    }
    #container {
      padding: 0;
      min-height: 100vh;
    }
    stripe-connect-account-management {
      width: 100%;
    }
  </style>
</head>
<body>
  <div id="loading">Loading...</div>
  <div id="error"></div>
  <div id="container"></div>

  <script src="https://connect-js.stripe.com/connect-js/v1.0/connect.js"></script>
  <script>
    (async () => {
      try {
        const stripeConnectInstance = StripeConnect.init({
          publishableKey: "${widget.publishableKey}",
          fetchClientSecret: async () => "${widget.clientSecret}",
          appearance: {
            variables: {
              colorPrimary: "#4F46E5",
            },
          },
        });

        const accountManagement = stripeConnectInstance.create("account-management");
        const container = document.getElementById("container");
        container.appendChild(accountManagement);

        document.getElementById("loading").style.display = "none";

        if (window.StripeAccountCallback) {
          StripeAccountCallback.postMessage("loaded");
        }
      } catch (e) {
        document.getElementById("loading").style.display = "none";
        const errorEl = document.getElementById("error");
        errorEl.style.display = "block";
        errorEl.textContent = "Failed to load account management: " + e.message;

        if (window.StripeAccountCallback) {
          StripeAccountCallback.postMessage("error:" + e.message);
        }
      }
    })();
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.settingsPaymentAccount),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _controller.loadHtmlString(_buildHtml());
                      },
                      child: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading && _error == null)
            const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
        ],
      ),
    );
  }
}
