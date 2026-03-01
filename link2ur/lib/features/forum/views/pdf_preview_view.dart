import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';

/// 帖子 PDF 附件 App 内预览
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
  PdfControllerPinch? _controller;
  bool _loading = true;
  bool _isEmpty = false;
  String? _rawError;

  @override
  void initState() {
    super.initState();
    _loadPdf();
  }

  Future<void> _loadPdf() async {
    try {
      final dio = Dio();
      final response = await dio.get<Uint8List>(
        widget.url,
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          setState(() {
            _isEmpty = true;
            _loading = false;
          });
        }
        return;
      }
      final document = await PdfDocument.openData(bytes);
      if (!mounted) return;
      setState(() {
        _controller = PdfControllerPinch(
          document: Future.value(document),
        );
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _rawError = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.backgroundDark : AppColors.backgroundLight;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(
          widget.title ?? context.l10n.forumPdfPreviewTitle,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: _buildBody(context, isDark),
    );
  }

  Widget _buildBody(BuildContext context, bool isDark) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_isEmpty || _rawError != null) {
      final errorText = _isEmpty
          ? context.l10n.forumPdfContentEmpty
          : context.l10n.forumPdfLoadFailed(_rawError!);
      return Center(
        child: Padding(
          padding: AppSpacing.allLg,
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
              AppSpacing.vMd,
              Text(
                errorText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }
    final controller = _controller;
    if (controller == null) {
      return const SizedBox.shrink();
    }
    return PdfViewPinch(
      controller: controller,
    );
  }
}
