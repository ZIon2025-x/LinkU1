import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// 验证码类型
enum CaptchaType {
  recaptchaV2,
  hcaptcha,
}

/// 验证码 WebView 组件
/// 参考iOS CaptchaWebView.swift
/// 支持 reCAPTCHA v2 和 hCaptcha
class CaptchaWebView extends StatefulWidget {
  const CaptchaWebView({
    super.key,
    required this.siteKey,
    this.captchaType = CaptchaType.recaptchaV2,
    required this.onVerified,
    this.onError,
    this.height = 500,
  });

  /// 站点密钥
  final String siteKey;

  /// 验证码类型
  final CaptchaType captchaType;

  /// 验证成功回调，返回 token
  final void Function(String token) onVerified;

  /// 错误回调
  final void Function(String error)? onError;

  /// 组件高度
  final double height;

  /// 便捷方法 - 显示验证码弹窗
  static Future<String?> show(
    BuildContext context, {
    required String siteKey,
    CaptchaType captchaType = CaptchaType.recaptchaV2,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    '安全验证',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // 验证码
            SizedBox(
              height: 500,
              child: CaptchaWebView(
                siteKey: siteKey,
                captchaType: captchaType,
                onVerified: (token) {
                  Navigator.pop(ctx, token);
                },
                onError: (error) {
                  Navigator.pop(ctx);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  State<CaptchaWebView> createState() => _CaptchaWebViewState();
}

class _CaptchaWebViewState extends State<CaptchaWebView> {
  late WebViewController _controller;
  bool _isLoading = true;

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
            widget.onError?.call(error.description);
          },
        ),
      )
      ..addJavaScriptChannel(
        'CaptchaCallback',
        onMessageReceived: (message) {
          final token = message.message;
          if (token.isNotEmpty) {
            widget.onVerified(token);
          }
        },
      )
      ..loadHtmlString(_buildHtml());
  }

  String _buildHtml() {
    if (widget.captchaType == CaptchaType.hcaptcha) {
      return _buildHCaptchaHtml();
    }
    return _buildReCaptchaHtml();
  }

  String _buildReCaptchaHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: transparent;
    }
  </style>
  <script src="https://www.google.com/recaptcha/api.js" async defer></script>
</head>
<body>
  <div class="g-recaptcha"
    data-sitekey="${widget.siteKey}"
    data-callback="onCaptchaSuccess"
    data-error-callback="onCaptchaError">
  </div>
  <script>
    function onCaptchaSuccess(token) {
      CaptchaCallback.postMessage(token);
    }
    function onCaptchaError() {
      CaptchaCallback.postMessage('error');
    }
  </script>
</body>
</html>
''';
  }

  String _buildHCaptchaHtml() {
    return '''
<!DOCTYPE html>
<html>
<head>
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <style>
    body {
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: transparent;
    }
  </style>
  <script src="https://js.hcaptcha.com/1/api.js" async defer></script>
</head>
<body>
  <div class="h-captcha"
    data-sitekey="${widget.siteKey}"
    data-callback="onCaptchaSuccess"
    data-error-callback="onCaptchaError">
  </div>
  <script>
    function onCaptchaSuccess(token) {
      CaptchaCallback.postMessage(token);
    }
    function onCaptchaError() {
      CaptchaCallback.postMessage('error');
    }
  </script>
</body>
</html>
''';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
