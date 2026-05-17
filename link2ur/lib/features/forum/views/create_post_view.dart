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
import '../../../core/widgets/app_select_sheet.dart';
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
    this.initialCategoryId,
    this.lockCategory = false,
  });

  final int? officialTaskId;
  final String? officialTaskTitle;
  final int? initialCategoryId;

  /// 锁死分类选择:隐藏切换 UI,禁用权限过滤的"不在可发帖列表则重置"逻辑。
  /// 用于"达人发自己板块的动态"等场景,分类由上游强制决定。
  final bool lockCategory;

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
    _selectedCategoryId = widget.initialCategoryId;
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
      final files = await _imagePicker.pickMultiImage();
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
  static const int _kMaxFileSizeMB = 20;

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        for (final f in result.files) {
          // 校验文件大小（后端限制 10MB）
          if (f.size > _kMaxFileSizeMB * 1024 * 1024) {
            if (mounted) {
              AppFeedback.showError(
                context,
                context.l10n.forumFileTooBig('$_kMaxFileSizeMB'),
              );
            }
            return;
          }
          // 校验 bytes 已加载
          if (f.bytes == null) {
            if (mounted) {
              AppFeedback.showError(context, context.l10n.forumFileReadFailed);
            }
            return;
          }
        }
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

    // category_id 现在可选 (Task 6 / migration 220): 用户可以不选板块直接发帖

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
          final bytes = file.bytes;
          if (bytes == null) {
            throw Exception(errorLocalizer('forum_file_read_failed'));
          }
          final att = await repo.uploadPostFile(bytes, file.name);
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
          categoryId: _selectedCategoryId,
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
            appBar: _CreateAppBar(
              isBusy: isBusy,
              onPublish: () => _submit(context),
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
                    // 锁死模式：分类由上游强制，渲染只读展示，跳过权限过滤/重置逻辑
                    if (widget.lockCategory && _selectedCategoryId != null) {
                      final locked = state.categories.firstWhere(
                        (c) => c.id == _selectedCategoryId,
                        orElse: () => ForumCategory(
                          id: _selectedCategoryId!,
                          name: '',
                        ),
                      );
                      final label = locked.displayName(
                          Localizations.localeOf(context));
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      return Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: AppRadius.allSmall,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.forum_outlined, size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                label.isNotEmpty
                                    ? label
                                    : context.l10n.forumSelectCategory,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                      );
                    }

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
                    return AppSelectField<int>(
                      key: ValueKey(_selectedCategoryId),
                      value: _selectedCategoryId,
                      hint: context.l10n.forumAddTopicOptional,
                      sheetTitle: context.l10n.forumAddTopicOptional,
                      prefixIcon: Icons.forum_outlined,
                      options: postableCategories.map((category) {
                        return SelectOption(
                          value: category.id,
                          label: category.displayName(Localizations.localeOf(context)),
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
                _TitleField(controller: _titleController),
                const SizedBox(height: 8),
                // 内容
                _ContentField(controller: _contentController),
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
                _ImageThumbGrid4(
                  images: _selectedImages,
                  maxImages: _kMaxImages,
                  onRemove: _removeImage,
                  onAdd: _pickImages,
                ),
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in _selectedFiles.asMap().entries)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _FilePdfCard(
                          file: entry.value,
                          onRemove: () => _removeFile(entry.key),
                        ),
                      ),
                    if (_selectedFiles.length < _kMaxFiles)
                      _AddFileTile(onTap: _pickFiles),
                  ],
                ),
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

class _CreateAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _CreateAppBar({
    required this.isBusy,
    required this.onPublish,
  });

  final bool isBusy;
  final VoidCallback onPublish;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      backgroundColor: AppColors.backgroundFor(
        isDark ? Brightness.dark : Brightness.light,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: Text(
        context.l10n.forumCreatePostTitle,
        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: _PublishButton(isBusy: isBusy, onTap: onPublish),
        ),
      ],
    );
  }
}

class _PublishButton extends StatelessWidget {
  const _PublishButton({required this.isBusy, required this.onTap});
  final bool isBusy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.35),
                offset: const Offset(0, 6),
                blurRadius: 18,
                spreadRadius: -6,
              ),
            ],
          ),
          child: isBusy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : Text(
                  context.l10n.forumPublish,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: context.l10n.forumEnterTitle,
        hintStyle: const TextStyle(
          color: AppColors.textPlaceholderLight,
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
        border: InputBorder.none,
        contentPadding: EdgeInsets.zero,
        isDense: true,
      ),
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
      maxLength: 200,
      buildCounter: (context,
              {required currentLength, required isFocused, maxLength}) =>
          null,
      textInputAction: TextInputAction.next,
    );
  }
}

class _ContentField extends StatefulWidget {
  const _ContentField({required this.controller});
  final TextEditingController controller;

  @override
  State<_ContentField> createState() => _ContentFieldState();
}

class _ContentFieldState extends State<_ContentField> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final count = widget.controller.text.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: widget.controller,
          decoration: InputDecoration(
            hintText: context.l10n.forumShareThoughts,
            hintStyle: const TextStyle(
              color: AppColors.textPlaceholderLight,
              fontSize: 15,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            isDense: true,
          ),
          style: const TextStyle(fontSize: 15, height: 1.65),
          maxLines: null,
          minLines: 10,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '$count / 5000',
            style: TextStyle(
              fontSize: 11,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageThumbGrid4 extends StatelessWidget {
  const _ImageThumbGrid4({
    required this.images,
    required this.maxImages,
    required this.onRemove,
    required this.onAdd,
  });

  final List<XFile> images;
  final int maxImages;
  final void Function(int index) onRemove;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canAdd = images.length < maxImages;
    final cellCount = images.length + (canAdd ? 1 : 0);

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: cellCount,
      itemBuilder: (context, index) {
        if (canAdd && index == images.length) {
          return _AddImageTile(onTap: onAdd, isDark: isDark);
        }
        return _ImageTile(
          file: images[index],
          index: index,
          isCover: index == 0,
          onRemove: () => onRemove(index),
        );
      },
    );
  }
}

class _ImageTile extends StatelessWidget {
  const _ImageTile({
    required this.file,
    required this.index,
    required this.isCover,
    required this.onRemove,
  });

  final XFile file;
  final int index;
  final bool isCover;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: AppRadius.allSmall,
          child: CrossPlatformImage(
            xFile: file,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        if (isCover)
          Positioned(
            left: 4,
            top: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                '封面',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          )
        else
          Positioned(
            left: 4,
            bottom: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.6),
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close, size: 12, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class _AddImageTile extends StatelessWidget {
  const _AddImageTile({required this.onTap, required this.isDark});
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allSmall,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
              width: 1.5,
            ),
            borderRadius: AppRadius.allSmall,
          ),
          // Flutter built-in 不支持 dashed border, 接受 solid 妥协 (mockup 上 dashed
          // 是视觉细节; 用 third-party 包 'dotted_border' 才能实现, YAGNI)
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, size: 22, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                context.l10n.forumCreatePostAddImage,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// PDF/文件附件卡片
/// 视觉: 44x44 红渐变方块 (#F24D4D → #FF7A7A) + "PDF" 白字,
///        文件名 + 大小 / 进度文案 + 3px 蓝色进度条,
///        26x26 红色 × 圆按钮。
class _FilePdfCard extends StatelessWidget {
  const _FilePdfCard({
    required this.file,
    required this.onRemove,
  });

  final PlatformFile file;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sizeKb = (file.size / 1024).toStringAsFixed(1);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: AppRadius.allMedium,
        border: Border.all(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 8,
            spreadRadius: -3,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF24D4D), Color(0xFFFF7A7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF24D4D).withValues(alpha: 0.35),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Text(
              'PDF',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 12),
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
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  // 客户端选好文件即视为"已就绪",真实上传发生在 publish 时
                  // (整体进度由外层 _isUploading 决定),这里只展示文件元数据。
                  '$sizeKb KB · 已就绪',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: 1.0,
                    minHeight: 3,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Semantics(
            button: true,
            label: 'Remove file',
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.close, size: 14, color: AppColors.error),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 添加文件按钮 (虚线感蓝色 tile)
class _AddFileTile extends StatelessWidget {
  const _AddFileTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allSmall,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.04),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.35),
            ),
            borderRadius: AppRadius.allSmall,
          ),
          child: Column(
            children: [
              const Icon(Icons.upload_file, size: 26, color: AppColors.primary),
              const SizedBox(height: 4),
              Text(
                context.l10n.forumFileAddFile,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

