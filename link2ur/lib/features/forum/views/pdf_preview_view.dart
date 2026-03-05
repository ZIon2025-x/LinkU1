import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show Uint8List;
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/l10n_extension.dart';

/// 帖子 PDF 附件 App 内预览
/// 全平台使用 pdfx 渲染（移动端用 pdfium，Web 端用 pdf.js）
/// 支持缩放和多页浏览
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
  PdfControllerPinch? _pdfController;
  bool _loading = true;
  bool _hasError = false;
  int _currentPage = 1;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final dio = Dio();
      final response = await dio.get<List<int>>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      if (!mounted) return;

      final document = await PdfDocument.openData(
        Uint8List.fromList(response.data!),
      );
      if (!mounted) return;

      _pdfController = PdfControllerPinch(
        document: Future.value(document),
      );

      setState(() {
        _loading = false;
        _totalPages = document.pagesCount;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _pdfController?.dispose();
    super.dispose();
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
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
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
      body: _buildBody(isDark),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_hasError) {
      return Center(
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
      );
    }

    return PdfViewPinch(
      controller: _pdfController!,
      onPageChanged: (page) {
        setState(() => _currentPage = page);
      },
      builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
        options: const DefaultBuilderOptions(),
        documentLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        pageLoaderBuilder: (_) =>
            const Center(child: CircularProgressIndicator()),
        errorBuilder: (_, error) => Center(
          child: Text(
            context.l10n.forumPdfLoadFailed(error.toString()),
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }
}
