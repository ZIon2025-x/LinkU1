import 'dart:async' show unawaited;
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/link_search_dialog.dart';
import '../../../core/utils/forum_permission_helper.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/forum_bloc.dart';
import '../../../data/models/forum.dart';

/// 创建帖子页
/// 支持同时上传图片和文件附件
class CreatePostView extends StatefulWidget {
  const CreatePostView({
    super.key,
    this.officialTaskId,
    this.officialTaskTitle,
  });

  final int? officialTaskId;
  final String? officialTaskTitle;

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int? _selectedCategoryId;

  // 图片
  static const int _kMaxImages = 5;
  final List<XFile> _selectedImages = [];
  final _imagePicker = ImagePicker();

  // 文件
  static const int _kMaxFiles = 1;
  final List<PlatformFile> _selectedFiles = [];

  bool _isUploading = false;
  static const String _kDraftKey = 'forum_create_post_draft';
  static const Duration _kDraftMaxAge = Duration(days: 7);
  bool _hasDraft = false;

  bool get _isOfficialTaskFlow => widget.officialTaskId != null;

  bool get _hasUnsavedChanges {
    return _titleController.text.isNotEmpty ||
        _contentController.text.isNotEmpty ||
        _selectedImages.isNotEmpty ||
        _selectedFiles.isNotEmpty;
  }

  String? _linkedItemType;
  String? _linkedItemId;
  String? _linkedName;

  /// Cached user-related linkable content, pre-loaded once.
  List<Map<String, dynamic>>? _cachedUserRelated;

  @override
  void initState() {
    super.initState();
    if (!_isOfficialTaskFlow) {
      _checkForDraft();
    }
    _preloadUserRelated();
  }

  Future<void> _preloadUserRelated() async {
    try {
      final repo = context.read<DiscoveryRepository>();
      final list = await repo.getLinkableContentForUser();
      if (mounted) setState(() => _cachedUserRelated = list);
    } catch (_) {
      // Fallback: dialog will load on its own if cache is null
    }
  }

  Future<void> _saveDraft() async {
    if (_isOfficialTaskFlow) return;
    final prefs = await SharedPreferences.getInstance();
    final draft = jsonEncode({
      'title': _titleController.text,
      'content': _contentController.text,
      'categoryId': _selectedCategoryId,
      'savedAt': DateTime.now().toIso8601String(),
    });
    await prefs.setString(_kDraftKey, draft);
  }

  Future<void> _clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDraftKey);
  }

  Future<void> _checkForDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDraftKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final savedAt = DateTime.tryParse(map['savedAt'] as String? ?? '');
      if (savedAt == null || DateTime.now().difference(savedAt) > _kDraftMaxAge) {
        await _clearDraft();
        return;
      }
      if (!mounted) return;
      setState(() => _hasDraft = true);
    } catch (_) {
      await _clearDraft();
    }
  }

  Future<void> _restoreDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kDraftKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _titleController.text = map['title'] as String? ?? '';
      _contentController.text = map['content'] as String? ?? '';
      setState(() {
        _selectedCategoryId = map['categoryId'] as int?;
        _hasDraft = false;
      });
    } catch (_) {
      setState(() => _hasDraft = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  // ── 图片选择 ──
  Future<void> _pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (files.isNotEmpty && mounted) {
        setState(() {
          for (final f in files) {
            if (_selectedImages.length < _kMaxImages) _selectedImages.add(f);
          }
        });
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removeImage(int index) {
    setState(() => _selectedImages.removeAt(index));
  }

  // ── 文件选择 ──
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          for (final f in result.files) {
            if (_selectedFiles.length < _kMaxFiles) {
              _selectedFiles.add(f);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removeFile(int index) {
    setState(() => _selectedFiles.removeAt(index));
  }

  Future<void> _showLinkSearchDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discoveryRepo = context.read<DiscoveryRepository>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => LinkSearchDialog(
        discoveryRepo: discoveryRepo,
        isDark: isDark,
        cachedUserRelated: _cachedUserRelated,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _linkedItemType = result['type']!;
        _linkedItemId = result['id']!;
        _linkedName = result['name']!;
      });
    }
  }

  void _clearLinked() {
    setState(() {
      _linkedItemType = null;
      _linkedItemId = null;
      _linkedName = null;
    });
  }

  Future<void> _submit(BuildContext context) async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();

    if (title.isEmpty || content.isEmpty) {
      AppFeedback.showWarning(context, context.l10n.feedbackFillTitleAndContent);
      return;
    }

    if (title.length > 200) {
      AppFeedback.showWarning(context, context.l10n.validatorFieldMaxLength(context.l10n.forumEnterTitle, 200));
      return;
    }

    if (content.length < 10) {
      AppFeedback.showWarning(
        context,
        context.l10n.validatorFieldMinLength(context.l10n.forumShareThoughts, 10),
      );
      return;
    }

    if (_selectedCategoryId == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }

    // 在 await 之前捕获 bloc 和 repo 引用，避免 async gap 后 context 失效
    final repo = context.read<ForumRepository>();
    final bloc = context.read<ForumBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final errorLocalizer = context.localizeError;
    final List<String> imageUrls = [];
    final List<ForumPostAttachment> uploadedAttachments = [];

    setState(() => _isUploading = true);

    try {
      if (_selectedImages.isNotEmpty) {
        for (final file in _selectedImages) {
          final url = await repo.uploadPostImage(await file.readAsBytes(), file.name);
          if (!mounted) return;
          imageUrls.add(url);
        }
      }
      if (_selectedFiles.isNotEmpty) {
        for (final file in _selectedFiles) {
          final att = await repo.uploadPostFile(file.bytes!, file.name);
          if (!mounted) return;
          uploadedAttachments.add(att);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);
      messenger.showSnackBar(SnackBar(content: Text(errorLocalizer(e.toString()))));
      return;
    }

    if (!mounted) return;
    setState(() => _isUploading = false);

    bloc.add(
      ForumCreatePost(
        CreatePostRequest(
          title: title,
          content: content,
          categoryId: _selectedCategoryId!,
          images: imageUrls,
          attachments: uploadedAttachments,
          linkedItemType: _linkedItemType,
          linkedItemId: _linkedItemId,
          officialTaskId: widget.officialTaskId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )..add(const ForumLoadCategories()),
      child: BlocConsumer<ForumBloc, ForumState>(
        listenWhen: (prev, curr) =>
            prev.isCreatingPost != curr.isCreatingPost ||
            prev.createPostSuccess != curr.createPostSuccess ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          if (!state.isCreatingPost && state.errorMessage != null) {
            AppFeedback.showError(context, context.localizeError(state.errorMessage));
          } else if (state.createPostSuccess) {
              unawaited(_clearDraft());
              _titleController.clear();
              _contentController.clear();
              _selectedImages.clear();
              _selectedFiles.clear();

              // Show official task reward SnackBar if applicable
              if (state.lastOfficialTaskReward != null) {
                final amount = state.lastOfficialTaskReward!['reward_amount']?.toString() ?? '0';
                AppFeedback.showSuccess(
                  context,
                  context.l10n.officialTaskRewardEarned(amount),
                );
              } else {
                AppFeedback.showSuccess(
                    context, context.l10n.feedbackPostPublishSuccess);
              }
              context.pop();
            }
        },
        builder: (context, state) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isBusy =
              state.isCreatingPost == true || _isUploading == true;

          return PopScope(
            canPop: !_hasUnsavedChanges,
            onPopInvokedWithResult: (didPop, _) {
              if (!didPop) {
                showDialog<String>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(context.l10n.forumDraftDialogTitle),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop('cancel'),
                        child: Text(context.l10n.commonCancel),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop('discard'),
                        child: Text(context.l10n.forumDraftDontSave),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop('save'),
                        child: Text(context.l10n.forumDraftSaveDraft),
                      ),
                    ],
                  ),
                ).then((result) {
                  if (!context.mounted) return;
                  if (result == 'save') {
                    _saveDraft().then((_) {
                      if (context.mounted) Navigator.of(context).pop();
                    });
                  } else if (result == 'discard') {
                    _clearDraft().then((_) {
                      if (context.mounted) Navigator.of(context).pop();
                    });
                  }
                });
              }
            },
            child: Scaffold(
            backgroundColor:
                AppColors.backgroundFor(Theme.of(context).brightness),
            appBar: AppBar(
              title: Text(context.l10n.forumCreatePostTitle),
              actions: [
                TextButton(
                  onPressed: isBusy ? null : () => _submit(context),
                  child: isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(context.l10n.forumPublish),
                ),
              ],
            ),
            body: ListView(
              padding: AppSpacing.allMd,
              children: [
                if (_hasDraft)
                  Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.md),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: AppRadius.allMedium,
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.edit_note, size: 18, color: AppColors.primary),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            context.l10n.forumDraftBannerText,
                            style: const TextStyle(fontSize: 13),
                          ),
                        ),
                        TextButton(
                          onPressed: () => _clearDraft().then((_) {
                            if (mounted) setState(() => _hasDraft = false);
                          }),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                          ),
                          child: Text(context.l10n.commonDiscard, style: const TextStyle(fontSize: 13)),
                        ),
                        FilledButton(
                          onPressed: _restoreDraft,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            textStyle: const TextStyle(fontSize: 13),
                          ),
                          child: Text(context.l10n.forumDraftRestore),
                        ),
                      ],
                    ),
                  ),
                // 分类选择（过滤掉仅管理员可发帖的板块）
                if (state.categories.isNotEmpty) ...[
                  Builder(builder: (context) {
                    final currentUser =
                        context.read<AuthBloc>().state.user;
                    final postableCategories =
                        ForumPermissionHelper.filterPostableCategories(
                            state.categories, currentUser);
                    // 如果当前选中的分类不在可发帖列表中，重置
                    if (_selectedCategoryId != null &&
                        !postableCategories
                            .any((c) => c.id == _selectedCategoryId)) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() => _selectedCategoryId = null);
                        }
                      });
                    }
                    return DropdownButtonFormField<int>(
                      key: ValueKey(_selectedCategoryId),
                      initialValue: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: context.l10n.forumSelectCategory,
                        border: const OutlineInputBorder(),
                      ),
                      items: postableCategories.map((category) {
                        return DropdownMenuItem<int>(
                          value: category.id,
                          child: Text(category.displayName(
                              Localizations.localeOf(context))),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedCategoryId = value);
                      },
                    );
                  }),
                  AppSpacing.vMd,
                ],
                // Official task linked banner
              if (_isOfficialTaskFlow) ...[
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight.withValues(alpha: 0.1),
                    borderRadius: AppRadius.allSmall,
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.flag_rounded,
                          size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          context.l10n.officialTaskLinked(
                            widget.officialTaskTitle ?? '',
                          ),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
                // 标题
                TextField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    hintText: context.l10n.forumEnterTitle,
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const Divider(),
                // 内容
                TextField(
                  controller: _contentController,
                  decoration: InputDecoration(
                    hintText: context.l10n.forumShareThoughts,
                    border: InputBorder.none,
                  ),
                  maxLines: null,
                  minLines: 10,
                ),
                AppSpacing.vMd,
                // 图片（选填，最多 5 张）
                Text(
                  '${context.l10n.forumCreatePostImages}（${context.l10n.commonImageCount(_selectedImages.length, _kMaxImages)}）',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                AppSpacing.vSm,
                _buildImagePicker(isDark),
                AppSpacing.vMd,
                // 文件附件（选填，最多 1 个）
                Text(
                  context.l10n.forumFileAttachmentCount('${_selectedFiles.length}', '$_kMaxFiles'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                AppSpacing.vSm,
                _buildFilePicker(isDark),
                AppSpacing.vMd,
                // 关联内容（选填）
                Text(
                  context.l10n.publishRelatedContent,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                AppSpacing.vSm,
                _buildLinkedChip(isDark),
                if (_isUploading) ...[
                  AppSpacing.vMd,
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
            ),
          ),
          );
        },
      ),
    );
  }

  Widget _buildImagePicker(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._selectedImages.asMap().entries.map((entry) {
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
                child: Semantics(
                  button: true,
                  label: 'Remove image',
                  child: GestureDetector(
                    onTap: () => _removeImage(entry.key),
                    child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                ),
              ),
            ],
          );
        }),
        if (_selectedImages.length < _kMaxImages)
          Semantics(
            button: true,
            label: 'Add image',
            child: GestureDetector(
              onTap: _pickImages,
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.backgroundLight,
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
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.forumCreatePostAddImage,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),
      ],
    );
  }

  Widget _buildFilePicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._selectedFiles.asMap().entries.map((entry) {
          final file = entry.value;
          final sizeKb = (file.size / 1024).toStringAsFixed(1);
          return Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.backgroundLight,
              borderRadius: AppRadius.allSmall,
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppColors.textTertiaryLight.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  _fileIcon(file.extension ?? ''),
                  size: 28,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        '$sizeKb KB',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Remove file',
                  child: GestureDetector(
                    onTap: () => _removeFile(entry.key),
                    child: const Icon(Icons.close, size: 20, color: AppColors.error),
                  ),
                ),
              ],
            ),
          );
        }),
        if (_selectedFiles.length < _kMaxFiles)
          Semantics(
            button: true,
            label: context.l10n.forumFileAddFile,
            child: GestureDetector(
              onTap: _pickFiles,
              child: Container(
                width: double.infinity,
                padding: AppSpacing.verticalMd,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.backgroundLight,
                  borderRadius: AppRadius.allSmall,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.textTertiaryLight.withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.upload_file,
                      size: 28,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    AppSpacing.vXs,
                    Text(
                      context.l10n.forumFileAddFile,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  IconData _fileIcon(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      default:
        return Icons.insert_drive_file;
    }
  }

  Widget _buildLinkedChip(bool isDark) {
    if (_linkedName != null && _linkedName!.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Chip(
              avatar: Icon(
                Icons.link,
                size: 18,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              label: Text(
                _linkedName!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onDeleted: _clearLinked,
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: _showLinkSearchDialog,
        icon: const Icon(Icons.add_link, size: 20),
        label: Text(context.l10n.publishSearchAndLink),
      ),
    );
  }
}


