import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/forum_bloc.dart';
import '../../../data/models/forum.dart';

/// 创建帖子页
/// 参考 iOS CreatePostView.swift，支持图片上传与关联内容
class CreatePostView extends StatefulWidget {
  const CreatePostView({super.key});

  @override
  State<CreatePostView> createState() => _CreatePostViewState();
}

class _CreatePostViewState extends State<CreatePostView> {
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  int? _selectedCategoryId;

  static const int _kMaxImages = 5;
  final List<XFile> _selectedImages = [];
  final _imagePicker = ImagePicker();
  bool _isUploadingImages = false;

  String? _linkedItemType;
  String? _linkedItemId;
  String? _linkedName;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
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

  Future<void> _showLinkSearchDialog() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discoveryRepo = context.read<DiscoveryRepository>();
    List<Map<String, dynamic>> userRelated = [];
    try {
      userRelated = await discoveryRepo.getLinkableContentForUser();
    } catch (_) {}
    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _LinkSearchDialog(
        discoveryRepo: discoveryRepo,
        isDark: isDark,
        userRelated: userRelated,
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
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      AppFeedback.showWarning(context, context.l10n.feedbackFillTitleAndContent);
      return;
    }

    if (_selectedCategoryId == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }

    List<String> imageUrls = [];
    if (_selectedImages.isNotEmpty) {
      setState(() => _isUploadingImages = true);
      try {
        final repo = context.read<ForumRepository>();
        for (final file in _selectedImages) {
          final path = file.path;
          if (path.isEmpty) continue;
          final url = await repo.uploadPostImage(path);
          imageUrls.add(url);
        }
      } catch (e) {
        if (!context.mounted) return;
        setState(() => _isUploadingImages = false);
        AppFeedback.showError(context, e.toString());
        return;
      }
      if (mounted) setState(() => _isUploadingImages = false);
    }

    if (!context.mounted) return;
    final bloc = context.read<ForumBloc>();
    bloc.add(
      ForumCreatePost(
        CreatePostRequest(
          title: _titleController.text.trim(),
          content: _contentController.text.trim(),
          categoryId: _selectedCategoryId!,
          images: imageUrls,
          linkedItemType: _linkedItemType,
          linkedItemId: _linkedItemId,
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
        listener: (context, state) {
          if (state.isCreatingPost == false && state.errorMessage != null) {
            AppFeedback.showError(context, state.errorMessage!);
          } else if (state.isCreatingPost == false &&
              state.posts.isNotEmpty &&
              state.posts.first.title == _titleController.text.trim()) {
            AppFeedback.showSuccess(
                context, context.l10n.feedbackPostPublishSuccess);
            context.pop();
          }
        },
        builder: (context, state) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isBusy =
              state.isCreatingPost == true || _isUploadingImages == true;

          return Scaffold(
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
                // 分类选择
                if (state.categories.isNotEmpty) ...[
                  DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: InputDecoration(
                      labelText: context.l10n.forumSelectCategory,
                      border: const OutlineInputBorder(),
                    ),
                    items: state.categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category.id,
                        child: Text(category.displayName(
                            Localizations.localeOf(context))),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => _selectedCategoryId = value);
                    },
                  ),
                  AppSpacing.vMd,
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
                  '${context.l10n.forumCreatePostImages}（${_selectedImages.length}/$_kMaxImages）',
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
                if (_isUploadingImages) ...[
                  AppSpacing.vMd,
                  const Center(child: CircularProgressIndicator()),
                ],
              ],
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
            ],
          );
        }),
        if (_selectedImages.length < _kMaxImages)
          GestureDetector(
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
      ],
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

/// 关联内容搜索弹窗（与 publish_view 逻辑一致）
class _LinkSearchDialog extends StatefulWidget {
  const _LinkSearchDialog({
    required this.discoveryRepo,
    required this.isDark,
    required this.userRelated,
  });

  final DiscoveryRepository discoveryRepo;
  final bool isDark;
  final List<Map<String, dynamic>> userRelated;

  @override
  State<_LinkSearchDialog> createState() => _LinkSearchDialogState();
}

class _LinkSearchDialogState extends State<_LinkSearchDialog> {
  late final TextEditingController _queryCtrl;
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _runSearch(String q) async {
    if (q.trim().isEmpty) return;
    setState(() => _loading = true);
    try {
      final list = await widget.discoveryRepo.searchLinkableContent(
          query: q.trim());
      if (mounted) {
        setState(() {
          _results = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        AppFeedback.showError(context, e.toString());
      }
    }
  }

  Widget _buildList(List<Map<String, dynamic>> list, double height) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final r = list[i];
          final type = r['item_type'] as String? ?? '';
          final name =
              r['name'] as String? ?? r['title'] as String? ?? '未命名';
          final id = r['item_id']?.toString() ?? '';
          final subtitle = r['subtitle'] as String? ?? type;
          return ListTile(
            title: Text(name),
            subtitle: Text(subtitle),
            onTap: () {
              Navigator.of(context).pop(
                  <String, String>{'type': type, 'id': id, 'name': name});
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    return AlertDialog(
      title: Text(context.l10n.publishRelatedContent),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _queryCtrl,
                      decoration: InputDecoration(
                        hintText: context.l10n.publishSearchHint,
                        border: const OutlineInputBorder(),
                      ),
                      onSubmitted: _runSearch,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _runSearch(_queryCtrl.text),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (widget.userRelated.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.publishRelatedToMe,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _buildList(widget.userRelated, 200),
                const SizedBox(height: 12),
              ],
              if (_loading) const Center(child: CircularProgressIndicator()),
              if (!_loading && _results.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.publishSearchResults,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                _buildList(_results, 220),
              ],
              if (!_loading &&
                  _results.isEmpty &&
                  _queryCtrl.text.trim().isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(context.l10n.publishNoResultsTryKeywords),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
      ],
    );
  }
}
