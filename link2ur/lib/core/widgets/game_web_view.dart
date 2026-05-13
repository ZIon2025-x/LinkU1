import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../router/page_transitions.dart';
import '../utils/l10n_extension.dart';

/// 异乡游戏全屏沉浸式 WebView。
///
/// 与通用 [ExternalWebView] 不同：
/// - 无 AppBar，无导航按钮，无 chrome
/// - 进入即 immersiveSticky 模式（隐 status bar + nav bar）
/// - 强锁竖屏（pop 时恢复 free orientation）
/// - 右上角悬浮 ✕ 关闭按钮作为唯一退出 UI（外加 iOS 滑返 / Android 硬返）
/// - 黑底 splash + 离线 fallback
/// - 不桥接 cookie / auth（spec A 路径，零互通）
class GameWebView extends StatefulWidget {
  const GameWebView({super.key, required this.url});

  final String url;

  /// 推到 root navigator 全屏覆盖。
  /// 进入即设沉浸模式 + 锁竖屏；pop 时由 GameWebView dispose 还原。
  static Future<void> open(BuildContext context, {required String url}) {
    return pushWithSwipeBack(
      context,
      GameWebView(url: url),
      useRootNavigator: true,
    );
  }

  @override
  State<GameWebView> createState() => _GameWebViewState();
}

class _GameWebViewState extends State<GameWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _enterImmersiveMode();
    _initWebView();
  }

  void _enterImmersiveMode() {
    // 强锁竖屏（游戏是 portrait-only 设计）
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    // 隐 status bar + nav bar，让游戏沾满整个屏幕
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _exitImmersiveMode() {
    // 恢复 free orientation
    SystemChrome.setPreferredOrientations([]);
    // 恢复正常 system UI（status bar 可见 + nav bar 可见）
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _isLoading = false);
          },
          onWebResourceError: (error) {
            // 只对主资源失败显示离线 UI；子资源失败（图片/音频）静默处理
            if (mounted && error.isForMainFrame == true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  void _retry() {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    _controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  void dispose() {
    _exitImmersiveMode();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // WebView 全屏
          if (!_hasError)
            Positioned.fill(child: WebViewWidget(controller: _controller)),

          // 加载中：纯黑 splash（让位给游戏自己的入场动画，不放 spinner）
          if (_isLoading && !_hasError)
            const Positioned.fill(
              child: ColoredBox(color: Colors.black),
            ),

          // 离线 fallback
          if (_hasError)
            Positioned.fill(
              child: _OfflineFallback(onRetry: _retry),
            ),

          // 右上角悬浮 ✕ 按钮（始终在最上，离线/加载/正常都可见）
          Positioned(
            top: topInset + 8,
            right: 8,
            child: _CloseButton(
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.4),
            ),
          ),
          child: const Icon(
            Icons.close,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }
}

class _OfflineFallback extends StatelessWidget {
  const _OfflineFallback({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off,
              color: Colors.white54,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.webviewLoading.contains('载入')
                  ? '需要联网才能玩'
                  : 'Network required',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: Text(
                context.l10n.webviewLoading.contains('载入') ? '重试' : 'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
