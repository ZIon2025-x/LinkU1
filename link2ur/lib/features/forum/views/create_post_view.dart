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
import '../widgets/topic_chip.dart';
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

  Widget _sectionLabel(BuildContext context, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
      ),
    );
  }

  Widget _buildTopicChipForCurrentState(ForumState state) {
    if (_selectedCategoryId == null) return const SizedBox.shrink();

    // 自动清除 _selectedCategoryId 当用户无权发到该板块 (规避 _submit 时被后端拒)
    // lockCategory 模式跳过 (锁定的 id 是上游强制的, 不应清空)
    if (!widget.lockCategory) {
      final currentUser = context.read<AuthBloc>().state.user;
      final postable = ForumPermissionHelper.filterPostableCategories(
          state.categories, currentUser);
      if (!postable.any((c) => c.id == _selectedCategoryId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _selectedCategoryId = null);
        });
      }
    }

    final cat = state.categories.firstWhere(
      (c) => c.id == _selectedCategoryId,
      orElse: () => ForumCategory(id: _selectedCategoryId!, name: ''),
    );
    final label = cat.displayName(Localizations.localeOf(context));
    return Align(
      alignment: Alignment.centerLeft,
      child: TopicChip(
        label: label.isEmpty ? context.l10n.forumSelectCategory : label,
        emoji: cat.icon,
        locked: widget.lockCategory,
        onRemove: widget.lockCategory
            ? null
            : () => setState(() => _selectedCategoryId = null),
      ),
    );
  }

  String? _lockedReasonForCurrentFlow(BuildContext context) {
    if (_isOfficialTaskFlow) return context.l10n.forumTopicLockedOfficialTask;
    // 通用兜底; 后续按入口类型 (达人/admin/校园) 细分
    return context.l10n.forumTopicLockedAdmin;
  }

  Future<void> _showTopicPicker(
      BuildContext context, List<ForumCategory> allCategories) async {
    final currentUser = context.read<AuthBloc>().state.user;
    final postable =
        ForumPermissionHelper.filterPostableCategories(allCategories, currentUser);
    final result = await showModalBottomSheet<int?>(
      context: context,
      builder: (sheetCtx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.clear),
              title: Text(context.l10n.commonCancel),
              onTap: () => Navigator.pop(sheetCtx, -1), // sentinel = clear
            ),
            const Divider(height: 1),
            for (final cat in postable)
              ListTile(
                leading: cat.icon != null && cat.icon!.isNotEmpty
                    ? Text(cat.icon!, style: const TextStyle(fontSize: 18))
                    : null,
                title: Text(cat.displayName(Localizations.localeOf(context))),
                trailing: _selectedCategoryId == cat.id ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetCtx, cat.id),
              ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _selectedCategoryId = result == -1 ? null : result;
      });
    }
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
              body: SafeArea(
                bottom: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 8),
                  children: [
                    // 草稿恢复 banner
                    if (_hasDraft) ...[
                      Container(
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
                            const Icon(Icons.edit_note,
                                size: 18, color: AppColors.primary),
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
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                minimumSize: Size.zero,
                              ),
                              child: Text(context.l10n.commonDiscard,
                                  style: const TextStyle(fontSize: 13)),
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
                      const SizedBox(height: 16),
                    ],

                    // 官方任务关联 banner
                    if (_isOfficialTaskFlow) ...[
                      Container(
                        width: double.infinity,
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
                      const SizedBox(height: 12),
                    ],

                    // 话题 chip (选中或锁定时显示)
                    if (_selectedCategoryId != null) ...[
                      _buildTopicChipForCurrentState(state),
                      const SizedBox(height: 18),
                    ],

                    // 标题 + 正文 (一个卡片视觉单元)
                    _ComposerCard(
                      titleController: _titleController,
                      contentController: _contentController,
                    ),
                    const SizedBox(height: 18),

                    // 图片 section (有图片时)
                    if (_selectedImages.isNotEmpty) ...[
                      _sectionLabel(
                        context,
                        '${context.l10n.forumCreatePostImages} '
                        '${context.l10n.commonImageCount(_selectedImages.length, _kMaxImages)}',
                      ),
                      const SizedBox(height: 6),
                      _ImageThumbGrid4(
                        images: _selectedImages,
                        maxImages: _kMaxImages,
                        onRemove: _removeImage,
                        onAdd: _pickImages,
                      ),
                      const SizedBox(height: 18),
                    ],

                    // 文件 section
                    if (_selectedFiles.isNotEmpty) ...[
                      _sectionLabel(
                        context,
                        context.l10n.forumFileAttachmentCount(
                            '${_selectedFiles.length}', '$_kMaxFiles'),
                      ),
                      const SizedBox(height: 6),
                      for (final entry in _selectedFiles.asMap().entries)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _FilePdfCard(
                            file: entry.value,
                            onRemove: () => _removeFile(entry.key),
                          ),
                        ),
                      const SizedBox(height: 18),
                    ],

                    // 关联内容 section
                    if (_linkedName != null && _linkedName!.isNotEmpty) ...[
                      _sectionLabel(context, context.l10n.publishRelatedContent),
                      const SizedBox(height: 6),
                      _LinkedChip(
                        itemType: _linkedItemType ?? '',
                        itemName: _linkedName!,
                        onRemove: _clearLinked,
                      ),
                      const SizedBox(height: 18),
                    ],

                    if (_isUploading) ...[
                      const SizedBox(height: 8),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
              bottomNavigationBar: _BottomComposerToolbar(
                imageCount: _selectedImages.length,
                fileCount: _selectedFiles.length,
                linkedCount:
                    (_linkedName != null && _linkedName!.isNotEmpty) ? 1 : 0,
                topicCount: _selectedCategoryId != null ? 1 : 0,
                lockedReason: widget.lockCategory
                    ? _lockedReasonForCurrentFlow(context)
                    : null,
                onTapImage: _pickImages,
                onTapFile: _pickFiles,
                onTapLink: _showLinkSearchDialog,
                onTapTopic: () => _showTopicPicker(context, state.categories),
              ),
            ),
          );
        },
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

/// 发帖页标题 + 正文一体化卡片
/// 视觉: 圆角白卡 + 柔和阴影 + dividerLight 边框, 内部上半 title 大字号,
///        细分割线, 下半 content 大书写区 + 右下角字数计数器
class _ComposerCard extends StatefulWidget {
  const _ComposerCard({
    required this.titleController,
    required this.contentController,
  });

  final TextEditingController titleController;
  final TextEditingController contentController;

  @override
  State<_ComposerCard> createState() => _ComposerCardState();
}

class _ComposerCardState extends State<_ComposerCard> {
  late final FocusNode _titleFocus;
  late final FocusNode _contentFocus;

  @override
  void initState() {
    super.initState();
    _titleFocus = FocusNode();
    _contentFocus = FocusNode();
    _titleFocus.addListener(_onFocusChange);
    _contentFocus.addListener(_onFocusChange);
    widget.contentController.addListener(_onContentChange);
  }

  @override
  void dispose() {
    _titleFocus.dispose();
    _contentFocus.dispose();
    widget.contentController.removeListener(_onContentChange);
    super.dispose();
  }

  void _onFocusChange() => setState(() {});
  void _onContentChange() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.cardBackgroundDark : Colors.white;
    final dividerColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    final isFocused = _titleFocus.hasFocus || _contentFocus.hasFocus;
    final borderColor = isFocused
        ? AppColors.primary.withValues(alpha: 0.4)
        : dividerColor;
    final count = widget.contentController.text.length;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadius.allMedium,
        border: Border.all(color: borderColor, width: isFocused ? 1.5 : 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isFocused ? 0.06 : 0.03),
            offset: const Offset(0, 2),
            blurRadius: 12,
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 标题
          TextField(
            controller: widget.titleController,
            focusNode: _titleFocus,
            decoration: InputDecoration(
              hintText: context.l10n.forumEnterTitle,
              hintStyle: const TextStyle(
                color: AppColors.textPlaceholderLight,
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
                height: 1.4,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            ),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              height: 1.4,
            ),
            cursorHeight: 22,
            maxLength: 200,
            buildCounter: (context,
                    {required currentLength,
                    required isFocused,
                    maxLength}) =>
                null,
            textInputAction: TextInputAction.next,
            onSubmitted: (_) => _contentFocus.requestFocus(),
          ),
          // 细分割线
          Divider(height: 1, thickness: 1, color: dividerColor),
          // 正文
          TextField(
            controller: widget.contentController,
            focusNode: _contentFocus,
            decoration: InputDecoration(
              hintText: context.l10n.forumShareThoughts,
              hintStyle: const TextStyle(
                color: AppColors.textPlaceholderLight,
                fontSize: 15,
                height: 1.6,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            ),
            style: const TextStyle(fontSize: 15, height: 1.6),
            cursorHeight: 18,
            maxLines: null,
            minLines: 8,
          ),
          // 字数计数器
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                  '$count / 5000',
                  style: TextStyle(
                    fontSize: 11,
                    color: count >= 5000
                        ? AppColors.error
                        : (isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight),
                  ),
                ),
              ),
            ),
          ],
        ),
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
                  // UX audit #9: 不显示假的"100% 已就绪"进度条; 未来真做上传进度时再加。
                  '$sizeKb KB',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
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

class _LinkedChip extends StatelessWidget {
  const _LinkedChip({
    required this.itemType,
    required this.itemName,
    required this.onRemove,
  });

  final String itemType;
  final String itemName;
  final VoidCallback onRemove;

  static const _purpleGradient = [Color(0xFF7359F2), Color(0xFFA18BFF)];

  // UX audit #17: 改 l10n, 对齐 _LinkedItemCard._typeLabel (forum_post_detail_view.dart)
  String _typeLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (itemType) {
      case 'product':
        return l10n.discoveryFeedTypeProduct;
      case 'service':
      case 'expert':
        return l10n.discoveryFeedTypeService;
      case 'activity':
        return l10n.homeHotEvents;
      case 'ranking':
        return l10n.discoveryFeedTypeRanking;
      case 'forum_post':
        return l10n.discoveryFeedTypePost;
      default:
        return itemType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final purple = _purpleGradient[0];
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: purple.withValues(alpha: isDark ? 0.14 : 0.08),
        border: Border.all(color: purple.withValues(alpha: 0.30)),
        borderRadius: AppRadius.allMedium,
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: _purpleGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(9),
              boxShadow: [
                BoxShadow(
                  color: purple.withValues(alpha: 0.4),
                  offset: const Offset(0, 4),
                  blurRadius: 10,
                  spreadRadius: -2,
                ),
              ],
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.dashboard, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _typeLabel(context),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: purple,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  itemName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.close,
                size: 13,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomComposerToolbar extends StatelessWidget {
  const _BottomComposerToolbar({
    required this.imageCount,
    required this.fileCount,
    required this.linkedCount,
    required this.topicCount,
    required this.lockedReason,
    required this.onTapImage,
    required this.onTapFile,
    required this.onTapLink,
    required this.onTapTopic,
  });

  final int imageCount;
  final int fileCount;
  final int linkedCount;
  final int topicCount;

  /// null = 普通模式可点; 非 null = 锁定模式, 点 topic 弹 SnackBar 显示该文案
  final String? lockedReason;

  final VoidCallback onTapImage;
  final VoidCallback onTapFile;
  final VoidCallback onTapLink;
  final VoidCallback onTapTopic;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
        : Colors.white.withValues(alpha: 0.85);
    final divider = isDark ? AppColors.dividerDark : AppColors.dividerLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divider)),
      ),
      padding: EdgeInsets.fromLTRB(
        14,
        10,
        14,
        16 + MediaQuery.of(context).padding.bottom,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _ToolButton(
            label: '图片',
            icon: Icons.image_outlined,
            tint: const Color(0xFF26BF73),
            count: imageCount,
            onTap: onTapImage,
          ),
          _ToolButton(
            label: '附件',
            icon: Icons.upload_file_outlined,
            tint: const Color(0xFFF24D4D),
            count: fileCount,
            onTap: onTapFile,
          ),
          _ToolButton(
            label: '关联',
            icon: Icons.link,
            tint: const Color(0xFF7359F2),
            count: linkedCount,
            onTap: onTapLink,
          ),
          _ToolButton(
            label: '话题',
            icon: Icons.local_offer_outlined,
            tint: AppColors.primary,
            count: topicCount,
            disabled: lockedReason != null,
            disabledHint: Icons.lock_outline,
            onTap: lockedReason != null
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(lockedReason!)),
                    )
                : onTapTopic,
          ),
        ],
      ),
    );
  }
}

class _ToolButton extends StatelessWidget {
  const _ToolButton({
    required this.label,
    required this.icon,
    required this.tint,
    required this.count,
    required this.onTap,
    this.disabled = false,
    this.disabledHint,
  });

  final String label;
  final IconData icon;
  final Color tint;
  final int count;
  final VoidCallback onTap;
  final bool disabled;
  final IconData? disabledHint;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveTint = disabled
        ? (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)
        : tint;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: effectiveTint.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: effectiveTint),
                ),
                if (disabled && disabledHint != null)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.cardBackgroundDark
                            : Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(disabledHint, size: 10, color: effectiveTint),
                    ),
                  )
                else if (count > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16),
                      height: 16,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? AppColors.cardBackgroundDark
                              : Colors.white,
                          width: 2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: effectiveTint,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

