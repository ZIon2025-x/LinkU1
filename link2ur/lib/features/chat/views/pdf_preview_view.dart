import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/router/page_transitions.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/media_saver.dart';

/// PDF 嵌入预览页 - flutter_pdfview 渲染本地下载的 PDF
/// 右上角三点菜单提供"用其他应用打开"和"分享 / 保存"
class PdfPreviewView extends StatefulWidget {
  const PdfPreviewView({
    super.key,
    required this.pdfUrl,
    required this.filename,
  });

  final String pdfUrl;
  final String filename;

  /// 便捷方法 - push 进入 PDF 预览页(iOS 支持右滑返回)
  static void show(
    BuildContext context, {
    required String pdfUrl,
    required String filename,
  }) {
    pushWithSwipeBack(
      context,
      PdfPreviewView(pdfUrl: pdfUrl, filename: filename),
    );
  }

  @override
  State<PdfPreviewView> createState() => _PdfPreviewViewState();
}

class _PdfPreviewViewState extends State<PdfPreviewView> {
  String? _localPath;
  String? _error;

  @override
  void initState() {
    super.initState();
    _download();
  }

  Future<void> _download() async {
    try {
      final path = await MediaSaver.downloadToTemp(widget.pdfUrl, widget.filename);
      if (mounted) setState(() => _localPath = path);
    } catch (e) {
      AppLogger.error('PDF download failed', e);
      if (mounted) setState(() => _error = 'chat_file_download_failed');
    }
  }

  Future<void> _openWithOther() async {
    if (_localPath == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await OpenFilex.open(_localPath!);
      if (!mounted) return;
      if (result.type != ResultType.done) {
        messenger.showSnackBar(SnackBar(
          content: Text(context.localizeError('chat_file_download_failed')),
        ));
      }
    } catch (e) {
      AppLogger.error('Open file failed', e);
      if (mounted) {
        messenger.showSnackBar(SnackBar(
          content: Text(context.localizeError('chat_file_download_failed')),
        ));
      }
    }
  }

  Future<void> _shareOrSave() async {
    if (_localPath == null) return;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(_localPath!, mimeType: 'application/pdf')],
          subject: widget.filename,
        ),
      );
    } catch (e) {
      AppLogger.error('Share PDF failed', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'open':
                  _openWithOther();
                  break;
                case 'share':
                  _shareOrSave();
                  break;
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    const Icon(Icons.open_in_new, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.chatPdfOpenWithOther),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'share',
                child: Row(
                  children: [
                    const Icon(Icons.ios_share, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.chatPdfShareOrSave),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(context.localizeError(_error)))
          : _localPath == null
              ? const Center(child: CircularProgressIndicator())
              : PDFView(
                  filePath: _localPath!,
                  onError: (e) {
                    AppLogger.error('PDF render error', e);
                    if (mounted) setState(() => _error = 'chat_pdf_preview_failed');
                  },
                ),
    );
  }
}
