import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../data/models/message.dart';

/// 文件(PDF)消息气泡 — 显示 PDF 图标 + 文件名 + 大小。
/// 点击行为由 caller 决定(本任务不实现,Task 15 接入 PdfPreviewView)。
class FileMessageBubble extends StatelessWidget {
  const FileMessageBubble({
    super.key,
    required this.attachment,
    required this.isMine,
    this.onTap,
  });

  final MessageAttachment attachment;
  final bool isMine;
  final VoidCallback? onTap;

  String get _filename =>
      (attachment.meta?['original_filename'] as String?) ?? 'file.pdf';

  String get _sizeLabel {
    final size = attachment.meta?['size'];
    if (size is num && size > 0) {
      final kb = size / 1024;
      if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
      return '${(kb / 1024).toStringAsFixed(1)} MB';
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final bg = isMine
        ? AppColors.primary.withValues(alpha: 0.1)
        : AppColors.cardBackgroundLight;
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.allMedium,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 260),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AppRadius.allMedium,
          border: Border.all(color: AppColors.dividerLight),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.picture_as_pdf, size: 32, color: Colors.red),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filename,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_sizeLabel.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      _sizeLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
