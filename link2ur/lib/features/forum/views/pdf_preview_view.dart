import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'pdf_web_view_factory_stub.dart'
    if (dart.library.html) 'pdf_web_view_factory.dart'
    as pdf_web;

import '../../../core/design/app_colors.dart';
import '../../../core/utils/l10n_extension.dart';

/// 帖子 PDF 附件 App 内预览
/// 移动端使用系统 WebView 原生渲染 PDF
/// Web 端使用 iframe 嵌入浏览器原生 PDF 渲染器
class PdfPreviewView extends StatefulWidget {
  const PdfPreviewView({
    super.key,
    required this.url,
    this.title,
  });

  final String url;
  final String? title;

  @override
  State<PdfPreviewView> createState() => _PdfPreviewViewState();
}

class _PdfPreviewViewState extends State<PdfPreviewView> {
  WebViewController? _controller;
  bool _loading = true;
  bool _hasError = false;
  String? _webViewType;

  @override
  void initState() {
    super.initState();

    if (kIsWeb) {
      _webViewType = pdf_web.registerPdfIframe(widget.url);
      Future.microtask(() {
        if (mounted) setState(() => _loading = false);
      });
    } else {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.white)
        ..setNavigationDelegate(NavigationDelegate(
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (error) {
            if (mounted) {
              setState(() {
                _loading = false;
                _hasError = true;
              });
            }
          },
        ))
        ..loadRequest(Uri.parse(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          widget.title ?? context.l10n.forumPdfPreviewTitle,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_browser),
            tooltip: context.l10n.commonOpenInBrowser,
            onPressed: () => launchUrl(
              Uri.parse(widget.url),
              mode: LaunchMode.externalApplication,
            ),
          ),
        ],
      ),
      body: kIsWeb
          ? pdf_web.buildPdfWebView(_webViewType!)
          : Stack(
              children: [
                WebViewWidget(controller: _controller!),
                if (_loading)
                  const Center(child: CircularProgressIndicator()),
                if (_hasError)
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 48,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.forumPdfLoadFailed(''),
                          style: TextStyle(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed: () => launchUrl(
                            Uri.parse(widget.url),
                            mode: LaunchMode.externalApplication,
                          ),
                          icon:
                              const Icon(Icons.open_in_browser, size: 18),
                          label: Text(context.l10n.commonOpenInBrowser),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
