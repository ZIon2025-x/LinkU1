import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../data/models/forum.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/forum_bloc.dart';

/// 编辑帖子页：标题、内容、图片（与发帖页一致）
class EditPostView extends StatefulWidget {
  const EditPostView({
    super.key,
    required this.postId,
    required this.post,
  });

  final int postId;
  final ForumPost post;

  @override
  State<EditPostView> createState() => _EditPostViewState();
}

class _EditPostViewState extends State<EditPostView> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;

  /// 保留的已有图片 URL（用户可删）
  final List<String> _existingUrls = [];
  /// 新选的本地图片（提交时上传）
  final List<XFile> _newFiles = [];
  static const int _kMaxImages = 5;
  final _imagePicker = ImagePicker();

  /// 已有的 PDF 附件（来自帖子数据，用户可删除）
  ForumPostAttachment? _existingAttachment;
  /// 新选的本地 PDF 文件（提交时上传，替换已有附件）
  PlatformFile? _newPdfFile;

  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.post.title);
    _contentController = TextEditingController(text: widget.post.content ?? '');
    _existingUrls.addAll(widget.post.images);
    if (widget.post.attachments.isNotEmpty) {
      _existingAttachment = widget.post.attachments.first;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  int get _totalImageCount => _existingUrls.length + _newFiles.length;

  Future<void> _pickImages() async {
    if (_totalImageCount >= _kMaxImages) return;
    try {
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (files.isNotEmpty && mounted) {
        setState(() {
          for (final f in files) {
            if (_totalImageCount < _kMaxImages) _newFiles.add(f);
          }
        });
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removeExistingUrl(int index) {
    setState(() => _existingUrls.removeAt(index));
  }

  void _removeNewFile(int index) {
    setState(() => _newFiles.removeAt(index));
  }

  bool get _hasPdf => _existingAttachment != null || _newPdfFile != null;

  Future<void> _pickPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final f = result.files.first;
        if (f.path != null && f.path!.isNotEmpty) {
          setState(() {
            _existingAttachment = null;
            _newPdfFile = f;
          });
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removePdf() {
    setState(() {
      _existingAttachment = null;
      _newPdfFile = null;
    });
  }

  Future<void> _submit(BuildContext context) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) {
      AppFeedback.showWarning(context, context.l10n.feedbackFillTitleAndContent);
      return;
    }

    final originalContent = widget.post.content ?? '';
    final titleChanged = title != (widget.post.title);
    final contentChanged = content != originalContent;

    final repo = context.read<ForumRepository>();

    List<String>? imageUrls;
    final existingSame = _existingUrls.length == widget.post.images.length &&
        _existingUrls.every((u) => widget.post.images.contains(u));
    final hasNewImageFiles = _newFiles.isNotEmpty;

    // PDF 变化检测
    final originalAtt = widget.post.attachments.isNotEmpty ? widget.post.attachments.first : null;
    final pdfKept = _existingAttachment != null &&
        originalAtt != null &&
        _existingAttachment!.url == originalAtt.url;
    final pdfRemoved = originalAtt != null && _existingAttachment == null && _newPdfFile == null;
    final pdfReplaced = _newPdfFile != null;
    final pdfChanged = pdfRemoved || pdfReplaced || (!pdfKept && originalAtt != null);

    if (hasNewImageFiles || !existingSame || pdfChanged) {
      setState(() => _isUploading = true);
    }

    try {
      // 图片上传
      if (hasNewImageFiles || !existingSame) {
        imageUrls = List<String>.from(_existingUrls);
        for (final file in _newFiles) {
          final path = file.path;
          if (path.isEmpty) continue;
          final url = await repo.uploadPostImage(path);
          imageUrls.add(url);
        }
      }

      // PDF 上传
      List<ForumPostAttachment>? attachments;
      if (pdfChanged) {
        if (pdfReplaced) {
          final att = await repo.uploadPostFile(_newPdfFile!.path!);
          attachments = [att];
        } else if (pdfRemoved) {
          attachments = [];
        }
      }

      if (mounted) setState(() => _isUploading = false);
      if (!context.mounted) return;

      context.read<ForumBloc>().add(
            ForumEditPost(
              widget.postId,
              title: titleChanged ? title : null,
              content: contentChanged ? content : null,
              images: imageUrls,
              attachments: attachments,
            ),
          );
    } catch (e) {
      if (!context.mounted) return;
      setState(() => _isUploading = false);
      AppFeedback.showError(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusy = _isUploading;

    return BlocListener<ForumBloc, ForumState>(
      listenWhen: (prev, curr) =>
          (prev.selectedPost?.id == widget.postId &&
              curr.selectedPost?.id == widget.postId &&
              (prev.selectedPost?.content != curr.selectedPost?.content ||
                  prev.selectedPost?.title != curr.selectedPost?.title ||
                  !listEquals(prev.selectedPost?.images, curr.selectedPost?.images))) ||
          (curr.errorMessage != null && prev.errorMessage != curr.errorMessage),
      listener: (context, state) {
        if (state.errorMessage != null) {
          AppFeedback.showError(context, state.errorMessage!);
          return;
        }
        if (state.selectedPost?.id == widget.postId) {
          context.pop();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.l10n.forumPostUpdated)),
            );
          }
        }
      },
      child: Scaffold(
      backgroundColor: AppColors.backgroundFor(isDark ? Brightness.dark : Brightness.light),
      appBar: AppBar(
        title: Text(context.l10n.commonEdit),
        actions: [
          TextButton(
            onPressed: isBusy ? null : () => _submit(context),
            child: isBusy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.l10n.commonConfirm),
          ),
        ],
      ),
      body: ListView(
        padding: AppSpacing.allMd,
        children: [
          Text(
            context.l10n.forumCreatePostPostTitle,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              hintText: context.l10n.forumCreatePostPostTitlePlaceholder,
              border: const OutlineInputBorder(),
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          AppSpacing.vMd,
          Text(
            context.l10n.forumCreatePostPostContent,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          TextField(
            controller: _contentController,
            decoration: InputDecoration(
              hintText: context.l10n.forumCreatePostContentPlaceholder,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            maxLines: 12,
            minLines: 6,
          ),
          AppSpacing.vMd,
          Text(
            '${context.l10n.forumCreatePostImages}（${context.l10n.commonImageCount(_totalImageCount, _kMaxImages)}）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          _buildImageSection(isDark),
          AppSpacing.vMd,
          Text(
            'PDF 附件（${_hasPdf ? '1' : '0'}/1）',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          _buildPdfSection(isDark),
          if (_isUploading) ...[
            AppSpacing.vMd,
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    ),
    );
  }

  Widget _buildImageSection(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._existingUrls.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: AsyncImageView(
                  imageUrl: entry.value,
                  width: 80,
                  height: 80,
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _removeExistingUrl(entry.key),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        ..._newFiles.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: CrossPlatformImage(
                  xFile: entry.value,
                  width: 80,
                  height: 80,
                ),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _removeNewFile(entry.key),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_totalImageCount < _kMaxImages)
          GestureDetector(
            onTap: _pickImages,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.backgroundLight,
                borderRadius: AppRadius.allSmall,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppColors.textTertiaryLight.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 28,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.forumCreatePostAddImage,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPdfSection(bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;

    // 显示已有附件或新选的文件
    if (_existingAttachment != null) {
      return _pdfChip(
        label: _existingAttachment!.filename,
        subtitle: _existingAttachment!.formattedSize,
        isDark: isDark,
        onRemove: _removePdf,
        onReplace: _pickPdf,
      );
    }
    if (_newPdfFile != null) {
      final sizeStr = _newPdfFile!.size < 1024 * 1024
          ? '${(_newPdfFile!.size / 1024).toStringAsFixed(1)} KB'
          : '${(_newPdfFile!.size / (1024 * 1024)).toStringAsFixed(1)} MB';
      return _pdfChip(
        label: _newPdfFile!.name,
        subtitle: sizeStr,
        isDark: isDark,
        onRemove: _removePdf,
        onReplace: _pickPdf,
      );
    }

    // 无附件时显示添加按钮
    return GestureDetector(
      onTap: _pickPdf,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50,
          borderRadius: AppRadius.allSmall,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.textTertiaryLight.withValues(alpha: 0.4),
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.attach_file, size: 20, color: primary),
            const SizedBox(width: 6),
            Text('添加 PDF', style: TextStyle(fontSize: 14, color: primary)),
          ],
        ),
      ),
    );
  }

  Widget _pdfChip({
    required String label,
    required String subtitle,
    required bool isDark,
    required VoidCallback onRemove,
    required VoidCallback onReplace,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50,
        borderRadius: AppRadius.allSmall,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.picture_as_pdf, size: 28, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.swap_horiz, size: 20),
            tooltip: '更换',
            onPressed: onReplace,
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.error),
            tooltip: '删除',
            onPressed: onRemove,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
