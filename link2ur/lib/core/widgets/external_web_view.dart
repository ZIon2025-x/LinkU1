import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../utils/l10n_extension.dart';

/// 外部 WebView - 应用内显示外部链接
/// 对齐 iOS ExternalWebView.swift
/// 使用 webview_flutter 在应用内加载网页，支持后退/前进/完成/加载中
class ExternalWebView extends StatefulWidget {
  const ExternalWebView({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  /// 便捷方法 - 在外部浏览器中打开
  static Future<void> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  /// 便捷方法 - 在应用内打开（push 一个全屏 WebView 页面）
  static Future<void> openInApp(
    BuildContext context, {
    required String url,
    String? title,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ExternalWebViewPage(url: url, title: title),
      ),
    );
  }

  /// 便捷方法 - 显示为底部 Sheet
  static void showAsSheet(
    BuildContext context, {
    required String url,
    String? title,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
            child: _ExternalWebViewPage(url: url, title: title),
          );
        },
      ),
    );
  }

  @override
  State<ExternalWebView> createState() => _ExternalWebViewState();
}

class _ExternalWebViewState extends State<ExternalWebView> {
  late WebViewController _controller;
  bool _isLoading = true;
  bool _canGoBack = false;
  bool _canGoForward = false;

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
            if (mounted) {
              _updateNavigationState();
              setState(() => _isLoading = false);
            }
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() => _isLoading = false);
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _updateNavigationState() async {
    final canGoBack = await _controller.canGoBack();
    final canGoForward = await _controller.canGoForward();
    if (mounted) {
      setState(() {
        _canGoBack = canGoBack;
        _canGoForward = canGoForward;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WebViewWidget(controller: _controller),
        if (_isLoading)
          Container(
            color: Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.8),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: 16),
                  Text(
                    context.l10n.webviewLoading,
                    style: AppTypography.subheadline.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// 提供给外部（如 _ExternalWebViewPage）读取导航状态
  bool get canGoBack => _canGoBack;
  bool get canGoForward => _canGoForward;

  Future<void> goBack() async {
    await _controller.goBack();
    _updateNavigationState();
  }

  Future<void> goForward() async {
    await _controller.goForward();
    _updateNavigationState();
  }
}

/// 全屏 WebView 页面 - 带 AppBar（后退/前进 + 完成）
/// 对齐 iOS ExternalWebView 的 NavigationView 布局
class _ExternalWebViewPage extends StatefulWidget {
  const _ExternalWebViewPage({
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  State<_ExternalWebViewPage> createState() => _ExternalWebViewPageState();
}

class _ExternalWebViewPageState extends State<_ExternalWebViewPage> {
  final GlobalKey<_ExternalWebViewState> _webViewKey =
      GlobalKey<_ExternalWebViewState>();

  bool _canGoBack = false;
  bool _canGoForward = false;

  void _refreshNavState() {
    final state = _webViewKey.currentState;
    if (state != null && mounted) {
      setState(() {
        _canGoBack = state.canGoBack;
        _canGoForward = state.canGoForward;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 定期刷新导航按钮状态（页面加载完成后 ExternalWebView 内部已 setState，
    // 但 parent 需要监听变化。使用 postFrameCallback 来同步）
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshNavState());

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          widget.title ?? context.l10n.webviewWebPage,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: 8),
            _NavButton(
              icon: Icons.chevron_left,
              enabled: _canGoBack,
              onTap: () async {
                await _webViewKey.currentState?.goBack();
                _refreshNavState();
              },
            ),
            _NavButton(
              icon: Icons.chevron_right,
              enabled: _canGoForward,
              onTap: () async {
                await _webViewKey.currentState?.goForward();
                _refreshNavState();
              },
            ),
          ],
        ),
        leadingWidth: 88,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              context.l10n.webviewDone,
              style: const TextStyle(color: AppColors.primary),
            ),
          ),
        ],
      ),
      body: ExternalWebView(
        key: _webViewKey,
        url: widget.url,
        title: widget.title,
      ),
    );
  }
}

/// 导航按钮（后退/前进）
class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.textTertiaryLight,
          size: 28,
        ),
      ),
    );
  }
}
