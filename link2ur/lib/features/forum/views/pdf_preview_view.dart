import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/l10n_extension.dart';

/// 帖子 PDF 附件 App 内预览
/// 使用系统 WebView 原生渲染 PDF，清晰度和浏览器一致
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
  late final WebViewController _controller;
  bool _loading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (error) {
          if (mounted) setState(() { _loading = false; _hasError = true; });
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
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
          ? Center(
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(widget.url),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_browser),
                label: Text(context.l10n.commonOpenInBrowser),
              ),
            )
          : Stack(
              children: [
                WebViewWidget(controller: _controller),
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
                          icon: const Icon(Icons.open_in_browser, size: 18),
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
