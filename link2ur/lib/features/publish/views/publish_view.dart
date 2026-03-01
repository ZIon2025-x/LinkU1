import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/task.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../flea_market/bloc/flea_market_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../forum/bloc/forum_bloc.dart';
import '../../tasks/bloc/create_task_bloc.dart';
import '../../../core/utils/forum_permission_helper.dart';

/// 统一发布页面（样式 B：大卡片网格）
/// 从底部滑入。先选类型（任务 / 闲置 / 帖子），再进入对应表单；支持返回重选。
class PublishView extends StatelessWidget {
  const PublishView({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) => CreateTaskBloc(
            taskRepository: context.read<TaskRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => FleaMarketBloc(
            fleaMarketRepository: context.read<FleaMarketRepository>(),
          ),
        ),
        BlocProvider(
          create: (context) => ForumBloc(
            forumRepository: context.read<ForumRepository>(),
          )..add(const ForumLoadCategories()),
        ),
      ],
      child: const _PublishContent(),
    );
  }
}

/// 关联内容弹窗内容：内部持有 TextEditingController，随弹窗 dispose，避免 disposed 后仍被使用。
class _PostLinkSearchDialogContent extends StatefulWidget {
  const _PostLinkSearchDialogContent({
    required this.discoveryRepo,
    required this.isDark,
  });

  final DiscoveryRepository discoveryRepo;
  final bool isDark;

  @override
  State<_PostLinkSearchDialogContent> createState() => _PostLinkSearchDialogContentState();
}

class _PostLinkSearchDialogContentState extends State<_PostLinkSearchDialogContent> {
  late final TextEditingController _queryCtrl;
  List<Map<String, dynamic>> _userRelated = [];
  List<Map<String, dynamic>> _results = [];
  bool _loadingRelated = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController();
    _loadUserRelated();
  }

  Future<void> _loadUserRelated() async {
    try {
      final list = await widget.discoveryRepo.getLinkableContentForUser();
      if (mounted) {
        setState(() {
          _userRelated = list;
          _loadingRelated = false;
        });
      }
    } catch (e) {
      AppLogger.warning('Failed to load linkable content for post: $e');
      if (mounted) setState(() => _loadingRelated = false);
    }
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
      final list = await widget.discoveryRepo.searchLinkableContent(query: q.trim());
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

  Widget _buildLinkableList(List<Map<String, dynamic>> list, double height) {
    return SizedBox(
      height: height,
      child: ListView.builder(
        itemCount: list.length,
        itemBuilder: (context, i) {
          final r = list[i];
          final type = r['item_type'] as String? ?? '';
          final name = r['name'] as String? ?? r['title'] as String? ?? context.l10n.commonUnnamed;
          final id = r['item_id']?.toString() ?? '';
          final subtitle = r['subtitle'] as String? ?? type;
          return ListTile(
            title: Text(name),
            subtitle: Text(subtitle),
            onTap: () {
              Navigator.of(context).pop(<String, String>{'type': type, 'id': id, 'name': name});
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
                  AppSpacing.hSm,
                  IconButton(
                    icon: const Icon(Icons.search),
                    onPressed: () => _runSearch(_queryCtrl.text),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingRelated)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                )
              else if (_userRelated.isNotEmpty) ...[
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    context.l10n.publishRelatedToMe,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                AppSpacing.vXs,
                _buildLinkableList(_userRelated, 200),
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
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                AppSpacing.vXs,
                _buildLinkableList(_results, 220),
              ],
              if (!_loading && _results.isEmpty && _queryCtrl.text.trim().isNotEmpty)
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

// ── 发布类型 ──
enum _PublishType { task, fleaMarket, post }

class _PublishContent extends StatefulWidget {
  const _PublishContent();

  @override
  State<_PublishContent> createState() => _PublishContentState();
}

class _PublishContentState extends State<_PublishContent>
    with TickerProviderStateMixin {
  /// null = 展示类型选择卡片；非 null = 已选类型，展示对应表单
  _PublishType? _selectedType;

  // ── 任务表单 ──
  final _taskFormKey = GlobalKey<FormState>();
  final _taskTitleCtrl = TextEditingController();
  final _taskDescCtrl = TextEditingController();
  final _taskRewardCtrl = TextEditingController();
  String? _taskLocation;
  double? _taskLatitude;
  double? _taskLongitude;
  final ValueNotifier<String?> _taskCategoryNotifier = ValueNotifier(null);
  final String _taskCurrency = 'GBP';
  DateTime? _taskDeadline;
  final List<XFile> _taskImages = [];
  static const int _kTaskMaxImages = 5;

  // ── 闲置表单 ──
  final _fleaFormKey = GlobalKey<FormState>();
  final _fleaTitleCtrl = TextEditingController();
  final _fleaDescCtrl = TextEditingController();
  final _fleaPriceCtrl = TextEditingController();
  String? _fleaLocation;
  double? _fleaLatitude;
  double? _fleaLongitude;
  String? _fleaCategory;
  final List<XFile> _fleaImages = [];
  final _imagePicker = ImagePicker();

  // ── 帖子表单 ──
  final _postFormKey = GlobalKey<FormState>();
  final _postTitleCtrl = TextEditingController();
  final _postContentCtrl = TextEditingController();
  int? _postCategoryId;
  final List<XFile> _postImages = [];
  PlatformFile? _postPdfFile;
  String? _postLinkedType;
  String? _postLinkedId;
  String? _postLinkedName;
  bool _postUploading = false;

  // ── 关闭动画 ──
  late final AnimationController _closeAnimCtrl;

  // ── 折叠区块（最近发布 + 发布小贴士）──
  bool _recentSectionExpanded = false;
  bool _tipsSectionExpanded = false;
  List<_RecentPublishItem>? _recentItems; // null = loading, [] = empty

  @override
  void initState() {
    super.initState();
    _closeAnimCtrl = AnimationController(
      vsync: this,
      duration: AppConstants.animationDuration,
    );
    _loadRecentItems();
  }

  Future<void> _loadRecentItems() async {
    try {
      final taskRepo = context.read<TaskRepository>();
      final forumRepo = context.read<ForumRepository>();
      final fleaRepo = context.read<FleaMarketRepository>();
      final locale = Localizations.localeOf(context);

      final results = await Future.wait([
        taskRepo.getMyTasks(role: 'poster', pageSize: 2),
        forumRepo.getMyPosts(pageSize: 2),
        fleaRepo.getMyItems(pageSize: 2),
      ]);

      final items = <_RecentPublishItem>[];
      for (final task in (results[0] as TaskListResponse).tasks) {
        items.add(_RecentPublishItem(
          type: _RecentItemType.task,
          id: task.id.toString(),
          title: task.displayTitle(locale),
          createdAt: task.createdAt ?? DateTime(1970),
        ));
      }
      for (final post in (results[1] as ForumPostListResponse).posts) {
        items.add(_RecentPublishItem(
          type: _RecentItemType.post,
          id: post.id.toString(),
          title: post.displayTitle(locale),
          createdAt: post.createdAt ?? DateTime(1970),
        ));
      }
      for (final fleaItem in (results[2] as FleaMarketListResponse).items) {
        items.add(_RecentPublishItem(
          type: _RecentItemType.fleaMarket,
          id: fleaItem.id,
          title: fleaItem.title,
          createdAt: fleaItem.createdAt ?? DateTime(1970),
        ));
      }
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      final top3 = items.take(3).toList();
      if (mounted) setState(() => _recentItems = top3);
    } catch (_) {
      if (mounted) setState(() => _recentItems = []);
    }
  }

  @override
  void dispose() {
    _taskTitleCtrl.dispose();
    _taskDescCtrl.dispose();
    _taskRewardCtrl.dispose();
    _fleaTitleCtrl.dispose();
    _fleaDescCtrl.dispose();
    _fleaPriceCtrl.dispose();
    _postTitleCtrl.dispose();
    _postContentCtrl.dispose();
    _closeAnimCtrl.dispose();
    _taskCategoryNotifier.dispose();
    super.dispose();
  }

  void _dismiss() {
    AppHaptics.light();
    context.pop();
  }

  // ==================== 任务类别列表（对齐后端 TASK_TYPES） ====================
  /// 返回全量任务类型，含 enabled 标记。
  /// 后端 TASK_TYPES: Housekeeping, Campus Life, Second-hand & Rental,
  /// Errand Running, Skill Service, Social Help, Transportation,
  /// Pet Care, Life Convenience, Other
  ///
  /// 返回 (value, label, enabled)
  List<(String, String, bool)> _getTaskCategories(BuildContext context) {
    final l10n = context.l10n;
    final user = context.read<AuthBloc>().state.user;
    final isStudent = user?.isStudentVerified ?? false;

    return [
      ('Housekeeping', l10n.taskTypeHousekeeping, true),
      ('Campus Life', l10n.taskTypeCampusLife, isStudent),
      ('Second-hand & Rental', l10n.taskTypeSecondHandRental, true),
      ('Errand Running', l10n.taskTypeErrandRunning, true),
      ('Skill Service', l10n.taskTypeSkillService, true),
      ('Social Help', l10n.taskTypeSocialHelp, true),
      ('Transportation', l10n.taskTypeTransportation, true),
      ('Pet Care', l10n.taskTypePetCare, true),
      ('Life Convenience', l10n.taskTypeLifeConvenience, true),
      ('Other', l10n.taskTypeOther, true),
    ];
  }

  // ==================== 闲置类别列表 ====================
  List<(String, String)> _getFleaCategories(BuildContext context) => [
        (context.l10n.fleaMarketCategoryKeyElectronics, context.l10n.fleaMarketCategoryElectronics),
        (context.l10n.fleaMarketCategoryKeyBooks, context.l10n.fleaMarketCategoryBooks),
        (context.l10n.fleaMarketCategoryKeyDaily, context.l10n.fleaMarketCategoryDailyUse),
        (context.l10n.fleaMarketCategoryKeyClothing, context.l10n.fleaMarketCategoryClothing),
        (context.l10n.fleaMarketCategoryKeySports, context.l10n.fleaMarketCategorySports),
        (context.l10n.fleaMarketCategoryKeyOther, context.l10n.fleaMarketCategoryOther),
      ];

  // ==================== 提交 ====================
  Future<void> _submitTask() async {
    if (!_taskFormKey.currentState!.validate()) return;
    if (_taskCategoryNotifier.value == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }
    final List<String> imageUrls = [];
    if (_taskImages.isNotEmpty) {
      setState(() => _postUploading = true);
      try {
        final repo = context.read<TaskRepository>();
        for (final file in _taskImages) {
          final url = await repo.uploadTaskImage(file.path);
          imageUrls.add(url);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _postUploading = false);
          AppFeedback.showError(context, context.l10n.createTaskImageUploadFailed);
        }
        return;
      }
      if (mounted) setState(() => _postUploading = false);
    }
    if (!mounted) return;
    final reward = double.tryParse(_taskRewardCtrl.text) ?? 0;
    final request = CreateTaskRequest(
      title: _taskTitleCtrl.text.trim(),
      description: _taskDescCtrl.text.trim().isNotEmpty ? _taskDescCtrl.text.trim() : null,
      taskType: _taskCategoryNotifier.value!,
      reward: reward,
      currency: _taskCurrency,
      location: _taskLocation,
      latitude: _taskLatitude,
      longitude: _taskLongitude,
      deadline: _taskDeadline,
      images: imageUrls,
    );
    context.read<CreateTaskBloc>().add(CreateTaskSubmitted(request));
  }

  void _submitFleaMarket() {
    if (!_fleaFormKey.currentState!.validate()) return;
    final price = double.tryParse(_fleaPriceCtrl.text.trim());
    if (price == null || price < 0) {
      AppFeedback.showError(context, context.l10n.fleaMarketInvalidPrice);
      return;
    }
    final request = CreateFleaMarketRequest(
      title: _fleaTitleCtrl.text.trim(),
      description: _fleaDescCtrl.text.trim().isEmpty ? null : _fleaDescCtrl.text.trim(),
      price: price,
      category: _fleaCategory,
      location: _fleaLocation,
      latitude: _fleaLatitude,
      longitude: _fleaLongitude,
      images: [],
    );
    context.read<FleaMarketBloc>().add(FleaMarketCreateItem(request));
  }

  Future<void> _submitPost() async {
    final title = _postTitleCtrl.text.trim();
    final content = _postContentCtrl.text.trim();
    if (title.isEmpty || content.isEmpty) {
      AppFeedback.showWarning(context, context.l10n.feedbackFillTitleAndContent);
      return;
    }
    if (content.length < 10) {
      AppFeedback.showWarning(
        context,
        context.l10n.validatorFieldMinLength(
          context.l10n.forumCreatePostPostContent,
          10,
        ),
      );
      return;
    }
    if (_postCategoryId == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }
    final repo = context.read<ForumRepository>();
    final List<String> imageUrls = [];
    final List<ForumPostAttachment> attachments = [];

    if (_postImages.isNotEmpty || _postPdfFile != null) {
      setState(() => _postUploading = true);
      try {
        for (final file in _postImages) {
          final url = await repo.uploadPostImage(file.path);
          imageUrls.add(url);
        }
        if (_postPdfFile != null &&
            _postPdfFile!.path != null &&
            _postPdfFile!.path!.isNotEmpty) {
          final att = await repo.uploadPostFile(_postPdfFile!.path!);
          attachments.add(att);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _postUploading = false);
          AppFeedback.showError(context, e.toString());
        }
        return;
      }
      if (mounted) setState(() => _postUploading = false);
    }
    if (!mounted) return;
    context.read<ForumBloc>().add(
          ForumCreatePost(
            CreatePostRequest(
              title: title,
              content: content,
              categoryId: _postCategoryId!,
              images: imageUrls,
              attachments: attachments,
              linkedItemType: _postLinkedType,
              linkedItemId: _postLinkedId,
            ),
          ),
        );
  }

  void _submit() {
    final type = _selectedType;
    if (type == null) return;
    AppHaptics.medium();
    switch (type) {
      case _PublishType.task:
        _submitTask();
        break;
      case _PublishType.fleaMarket:
        _submitFleaMarket();
        break;
      case _PublishType.post:
        _submitPost();
        break;
    }
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _taskDeadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final initialTime = _taskDeadline != null
        ? TimeOfDay(hour: _taskDeadline!.hour, minute: _taskDeadline!.minute)
        : const TimeOfDay(hour: 12, minute: 0);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time != null && mounted) {
      setState(() {
        _taskDeadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      });
    } else if (mounted) {
      // 只选了日期未选时间时，使用 12:00
      setState(() {
        _taskDeadline = DateTime(date.year, date.month, date.day, 12);
      });
    }
  }

  Future<void> _pickImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (files.isNotEmpty) {
        setState(() {
          for (final f in files) {
            if (_fleaImages.length < 9) _fleaImages.add(f);
          }
        });
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removeImage(int index) => setState(() => _fleaImages.removeAt(index));

  static const int _kPostMaxImages = 5;

  Future<void> _pickPostImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (files.isNotEmpty && mounted) {
        setState(() {
          for (final f in files) {
            if (_postImages.length < _kPostMaxImages) _postImages.add(f);
          }
        });
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removePostImage(int index) => setState(() => _postImages.removeAt(index));

  Future<void> _pickPostPdf() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result != null && result.files.isNotEmpty && mounted) {
        final f = result.files.first;
        if (f.path != null && f.path!.isNotEmpty) {
          setState(() => _postPdfFile = f);
        }
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removePostPdf() => setState(() => _postPdfFile = null);

  Future<void> _pickTaskImages() async {
    try {
      final files = await _imagePicker.pickMultiImage(
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (files.isNotEmpty && mounted) {
        setState(() {
          for (final f in files) {
            if (_taskImages.length < _kTaskMaxImages) _taskImages.add(f);
          }
        });
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removeTaskImage(int index) => setState(() => _taskImages.removeAt(index));

  void _clearPostLinked() => setState(() {
    _postLinkedType = null;
    _postLinkedId = null;
    _postLinkedName = null;
  });

  String get _submitButtonText {
    final type = _selectedType;
    if (type == null) return context.l10n.createTaskPublishTask;
    switch (type) {
      case _PublishType.task:
        return context.l10n.createTaskPublishTask;
      case _PublishType.fleaMarket:
        return context.l10n.fleaMarketPublishItem;
      case _PublishType.post:
        return context.l10n.forumPublish;
    }
  }

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    // 必须在 build 内使用 context.select，不能放在 getter 或子 build 里
    final isTaskSubmitting = context.select<CreateTaskBloc, bool>((b) => b.state.isSubmitting);
    final isFleaSubmitting = context.select<FleaMarketBloc, bool>((b) => b.state.isSubmitting);
    final isPostSubmitting = context.select<ForumBloc, bool>((b) => b.state.isCreatingPost);
    final isSubmitting = isTaskSubmitting || isFleaSubmitting || isPostSubmitting || _postUploading;
    final postCategories = context.select<ForumBloc, List<ForumCategory>>((b) => b.state.categories);
    final postCurrentUser = context.select<AuthBloc, User?>((b) => b.state.user);

    return MultiBlocListener(
      listeners: [
        // 任务发布成功监听
        BlocListener<CreateTaskBloc, CreateTaskState>(
          listener: (context, state) {
            if (state.isSuccess) {
              AppFeedback.showSuccess(context, context.l10n.feedbackTaskPublishSuccess);
              context.pop();
            } else if (state.status == CreateTaskStatus.error) {
              AppFeedback.showError(context, context.localizeError(state.errorMessage));
            }
          },
        ),
        // 闲置发布成功监听
        BlocListener<FleaMarketBloc, FleaMarketState>(
          listenWhen: (prev, curr) =>
              prev.actionMessage != curr.actionMessage ||
              prev.errorMessage != curr.errorMessage,
          listener: (context, state) {
            if (state.actionMessage == 'item_published') {
              AppFeedback.showSuccess(context, context.l10n.actionItemPublished);
              context.pop();
            } else if (state.actionMessage == 'publish_failed') {
              // 显示后端返回的具体错误信息（如收款账户验证失败等）
              // 清理异常类名前缀（如 "FleaMarketException: "）
              var message = context.localizeError(state.errorMessage);
              final colonIndex = message.indexOf(': ');
              if (colonIndex > 0 && colonIndex < 30) {
                message = message.substring(colonIndex + 2);
              }
              AppFeedback.showError(context, message);
            }
          },
        ),
        // 帖子发布成功监听
        BlocListener<ForumBloc, ForumState>(
          listenWhen: (prev, curr) =>
              prev.isCreatingPost != curr.isCreatingPost ||
              prev.errorMessage != curr.errorMessage,
          listener: (context, state) {
            if (!state.isCreatingPost && state.errorMessage != null) {
              AppFeedback.showError(context, context.localizeError(state.errorMessage));
            } else if (!state.isCreatingPost &&
                state.posts.isNotEmpty &&
                state.posts.first.title == _postTitleCtrl.text.trim()) {
              AppFeedback.showSuccess(context, context.l10n.feedbackPostPublishSuccess);
              context.pop();
            }
          },
        ),
      ],
      child: Builder(
        builder: (context) {
          final isDesktop = ResponsiveUtils.isDesktop(context);
          final bodyContent = _selectedType == null
              ? _buildTypePicker(isDark, bottomPadding)
              : _buildFormView(isDark, bottomPadding, isSubmitting, postCategories, postCurrentUser);
          return Scaffold(
            backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
            resizeToAvoidBottomInset: false,
            body: SafeArea(
              bottom: false,
              child: isDesktop ? ContentConstraint(child: bodyContent) : bodyContent,
            ),
          );
        },
      ),
    );
  }

  // ==================== 类型选择页（样式 B：大卡片网格）====================
  Widget _buildTypePicker(bool isDark, double bottomPadding) {
    return Column(
      children: [
        _buildPickerHeader(isDark),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: LayoutBuilder(
              builder: (context, constraints) {
                const gap = 12.0;
                final width = (constraints.maxWidth - gap) / 2;
                return SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSpacing.vSm,
                      Row(
                        children: [
                          SizedBox(
                            width: width,
                            height: width,
                            child: _PublishTypeCard(
                              isDark: isDark,
                              type: _PublishType.task,
                              label: context.l10n.publishTaskCardLabel,
                              icon: Icons.task_alt_rounded,
                              gradient: const [Color(0xFF007AFF), Color(0xFF409CFF)],
                              onTap: () {
                                AppHaptics.selection();
                                setState(() => _selectedType = _PublishType.task);
                              },
                            ),
                          ),
                          const SizedBox(width: gap),
                          SizedBox(
                            width: width,
                            height: width,
                            child: _PublishTypeCard(
                              isDark: isDark,
                              type: _PublishType.fleaMarket,
                              label: context.l10n.publishFleaCardLabel,
                              icon: Icons.storefront_rounded,
                              gradient: const [Color(0xFF26BF73), Color(0xFF34D399)],
                              onTap: () {
                                AppHaptics.selection();
                                setState(() => _selectedType = _PublishType.fleaMarket);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: gap),
                      _PublishTypeCard(
                        isDark: isDark,
                        type: _PublishType.post,
                        label: context.l10n.publishPostCardLabel,
                        icon: Icons.article_rounded,
                        gradient: const [Color(0xFF7359F2), Color(0xFFA78BFA)],
                        fullWidth: true,
                        onTap: () {
                          AppHaptics.selection();
                          setState(() => _selectedType = _PublishType.post);
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildRecentSection(isDark),
                      AppSpacing.vSm,
                      _buildTipsSection(isDark),
                      SizedBox(height: bottomPadding + 24),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
        _buildCloseButton(isDark, bottomPadding),
      ],
    );
  }

  Widget _buildRecentSection(bool isDark) {
    return _buildCollapsibleSection(
      isDark: isDark,
      title: context.l10n.publishRecentSectionTitle,
      expanded: _recentSectionExpanded,
      onTap: () {
        AppHaptics.selection();
        setState(() => _recentSectionExpanded = !_recentSectionExpanded);
      },
      child: _recentItems == null
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            )
          : _recentItems!.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    context.l10n.publishRecentEmpty,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _recentItems!
                      .map((item) => _RecentPublishListItem(
                            isDark: isDark,
                            item: item,
                            onTap: () {
                              AppHaptics.selection();
                              switch (item.type) {
                                case _RecentItemType.task:
                                  context.push('/tasks/${item.id}');
                                  break;
                                case _RecentItemType.fleaMarket:
                                  context.push('/flea-market/${item.id}');
                                  break;
                                case _RecentItemType.post:
                                  context.push('/forum/posts/${item.id}');
                                  break;
                              }
                            },
                          ))
                      .toList(),
                ),
    );
  }

  Widget _buildTipsSection(bool isDark) {
    final List<String> tips = [
      context.l10n.publishTip1,
      context.l10n.publishTip2,
      context.l10n.publishTip3,
      context.l10n.publishTip4,
    ];
    return _buildCollapsibleSection(
      isDark: isDark,
      title: context.l10n.publishTipsSectionTitle,
      expanded: _tipsSectionExpanded,
      onTap: () {
        AppHaptics.selection();
        setState(() => _tipsSectionExpanded = !_tipsSectionExpanded);
      },
      child: Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: tips
              .map<Widget>(
                (String t) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 18,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                      AppSpacing.hSm,
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildCollapsibleSection({
    required bool isDark,
    required String title,
    required bool expanded,
    required VoidCallback onTap,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allMedium,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: AppRadius.allMedium,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const Spacer(),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 24,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: child,
            ),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.sm),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : Colors.black.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.l10n.publishTitle,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vXs,
          Text(
            context.l10n.publishTypeSubtitle,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  // ==================== 表单页（含返回 + 表单 + 底部栏）====================
  Widget _buildFormView(
    bool isDark,
    double bottomPadding,
    bool isSubmitting,
    List<ForumCategory> postCategories,
    User? postCurrentUser,
  ) {
    final type = _selectedType!;
    return Column(
      children: [
        _buildFormHeader(isDark, type, isSubmitting),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: switch (type) {
              _PublishType.task => _buildTaskForm(isDark),
              _PublishType.fleaMarket => _buildFleaMarketForm(isDark),
              _PublishType.post => _buildPostForm(isDark, postCategories, postCurrentUser),
            },
          ),
        ),
        _buildBottomBar(isDark, bottomPadding, isSubmitting),
      ],
    );
  }

  Widget _buildFormHeader(bool isDark, _PublishType type, bool isSubmitting) {
    String title;
    switch (type) {
      case _PublishType.task:
        title = context.l10n.publishTaskTab;
        break;
      case _PublishType.fleaMarket:
        title = context.l10n.publishFleaMarketTab;
        break;
      case _PublishType.post:
        title = context.l10n.publishPostTab;
        break;
    }
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.sm,
        bottom: AppSpacing.sm,
        left: AppSpacing.sm,
        right: AppSpacing.sm,
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              AppHaptics.light();
              setState(() => _selectedType = null);
            },
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 20,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          Expanded(
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
          ),
          isSubmitting
              ? SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                  ),
                )
              : TextButton(
                  onPressed: _submit,
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    minimumSize: const Size(44, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    _submitButtonText,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildCloseButton(bool isDark, double bottomPadding) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: bottomPadding + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 底部操作栏（仅关闭按钮，固定底部不随键盘动）====================
  Widget _buildBottomBar(bool isDark, double bottomPadding, bool isSubmitting) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.sm,
        bottom: bottomPadding + AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Center(
        child: GestureDetector(
          onTap: _dismiss,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.05),
            ),
            child: Icon(
              Icons.close_rounded,
              size: 22,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ),
    );
  }

  // ==================== 任务发布表单 ====================
  Widget _buildTaskForm(bool isDark) {
    final taskCategories = _getTaskCategories(context);

    // 如果当前选中的类型被禁用，重置
    if (_taskCategoryNotifier.value != null) {
      final match = taskCategories.where((c) => c.$1 == _taskCategoryNotifier.value);
      if (match.isEmpty || !match.first.$3) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _taskCategoryNotifier.value = null;
        });
      }
    }

    final viewInsets = MediaQuery.of(context).viewInsets;
    return Form(
      key: _taskFormKey,
      child: ListView(
        key: const ValueKey('task_form'),
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 120 + viewInsets.bottom,
        ),
        children: [
          // ── 任务类型（下拉框，半宽） ──
          _sectionTitle(context.l10n.createTaskType),
          _buildTaskCategoryDropdown(isDark, taskCategories),
          AppSpacing.vLg,

          _sectionTitle(context.l10n.createTaskTitleField),
          TextFormField(
            controller: _taskTitleCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.createTaskTitleHint,
              icon: Icons.title_rounded,
              isDark: isDark,
            ),
            maxLength: 100,
            validator: (v) => Validators.validateTitle(v, l10n: context.l10n),
          ),
          AppSpacing.vMd,

          _sectionTitle(context.l10n.taskDetailTaskDescription),
          TextFormField(
            controller: _taskDescCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.createTaskDescHint,
              icon: Icons.description_outlined,
              isDark: isDark,
            ),
            maxLines: 4,
            maxLength: 2000,
            validator: (value) => Validators.validateDescription(value, l10n: context.l10n),
          ),
          AppSpacing.vMd,

          _sectionTitle(context.l10n.createTaskImages),
          _buildTaskImagePicker(isDark),
          AppSpacing.vMd,

          _sectionTitle(context.l10n.createTaskReward),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _taskRewardCtrl,
                  decoration: _inputDecoration(
                    hint: '0.00',
                    icon: Icons.payments_outlined,
                    isDark: isDark,
                    prefix: '£ ',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  validator: (v) => Validators.validateAmount(v, l10n: context.l10n),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.allMedium,
                ),
                child: Text(
                  'GBP',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vLg,

          _sectionTitle(context.l10n.createTaskLocation),
          LocationInputField(
            hintText: context.l10n.createTaskLocationHint,
            onChanged: (address) {
              _taskLocation = address.isNotEmpty ? address : null;
              _taskLatitude = null;
              _taskLongitude = null;
            },
            onLocationPicked: (address, lat, lng) {
              _taskLocation = address.isNotEmpty ? address : null;
              _taskLatitude = lat;
              _taskLongitude = lng;
            },
          ),
          AppSpacing.vLg,

          _sectionTitle(context.l10n.createTaskDeadline),
          GestureDetector(
            onTap: _selectDeadline,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.backgroundLight,
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : AppColors.separatorLight.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _taskDeadline != null
                        ? DateFormat('yyyy-MM-dd HH:mm').format(_taskDeadline!)
                        : context.l10n.createTaskSelectDeadline,
                    style: TextStyle(
                      color: _taskDeadline != null
                          ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                          : (isDark ? AppColors.textTertiaryDark : AppColors.textPlaceholderLight),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 闲置发布表单 ====================
  Widget _buildFleaMarketForm(bool isDark) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    return Form(
      key: _fleaFormKey,
      child: ListView(
        key: const ValueKey('flea_form'),
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 120 + viewInsets.bottom,
        ),
        children: [
          _sectionTitle(context.l10n.fleaMarketProductImages),
          _buildFleaImagePicker(isDark),
          AppSpacing.vLg,

          _sectionTitle(context.l10n.fleaMarketProductTitle),
          TextFormField(
            controller: _fleaTitleCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.fleaMarketProductTitlePlaceholder,
              icon: Icons.title_rounded,
              isDark: isDark,
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return context.l10n.fleaMarketTitleRequired;
              if (value.trim().length < 2) return context.l10n.fleaMarketTitleMinLength;
              return null;
            },
          ),
          AppSpacing.vMd,

          _sectionTitle(context.l10n.fleaMarketDescOptional),
          TextFormField(
            controller: _fleaDescCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.fleaMarketDescHint,
              icon: Icons.description_outlined,
              isDark: isDark,
            ),
            maxLines: 4,
            maxLength: 500,
          ),
          AppSpacing.vMd,

          _sectionTitle(context.l10n.fleaMarketPrice),
          TextFormField(
            controller: _fleaPriceCtrl,
            decoration: _inputDecoration(
              hint: '0.00',
              icon: Icons.attach_money_rounded,
              isDark: isDark,
              prefix: '£ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            validator: (value) {
              if (value == null || value.trim().isEmpty) return context.l10n.fleaMarketPriceRequired;
              final price = double.tryParse(value.trim());
              if (price == null || price < 0) return context.l10n.fleaMarketInvalidPrice;
              return null;
            },
          ),
          AppSpacing.vMd,

          // ── 分类（窄下拉框） ──
          _sectionTitle(context.l10n.fleaMarketCategoryLabel),
          _buildNarrowDropdown<String>(
            isDark: isDark,
            value: _fleaCategory,
            hint: context.l10n.fleaMarketSelectCategory,
            icon: Icons.category_outlined,
            items: _getFleaCategories(context)
                .map((c) => DropdownMenuItem(value: c.$1, child: Text(c.$2)))
                .toList(),
            onChanged: (v) => setState(() => _fleaCategory = v),
          ),
          AppSpacing.vMd,

          _sectionTitle(context.l10n.fleaMarketLocationOptional),
          LocationInputField(
            hintText: context.l10n.fleaMarketLocationHint,
            onChanged: (address) {
              _fleaLocation = address.isNotEmpty ? address : null;
              _fleaLatitude = null;
              _fleaLongitude = null;
            },
            onLocationPicked: (address, lat, lng) {
              _fleaLocation = address.isNotEmpty ? address : null;
              _fleaLatitude = lat;
              _fleaLongitude = lng;
            },
          ),
        ],
      ),
    );
  }

  // ==================== 帖子发布表单 ====================
  /// [categories] 与 [currentUser] 必须在 build 内通过 context.select 取得后传入，避免在子 build 里用 select 导致崩溃
  Widget _buildPostForm(
    bool isDark,
    List<ForumCategory> categories,
    User? currentUser,
  ) {
    // 只展示当前用户有权发布的板块（可见且非仅管理员发帖）
    final postableCategories = ForumPermissionHelper.filterPostableCategories(
      categories,
      currentUser,
    );

    // 如果当前选中的分类不在可发布列表中，重置选择
    if (_postCategoryId != null &&
        !postableCategories.any((c) => c.id == _postCategoryId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _postCategoryId = null);
      });
    }

    final viewInsets = MediaQuery.of(context).viewInsets;
    return Form(
      key: _postFormKey,
      child: ListView(
        key: const ValueKey('post_form'),
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          bottom: 120 + viewInsets.bottom,
        ),
        children: [
          // ── 帖子分类（窄下拉框，仅可发布的板块） ──
          if (postableCategories.isNotEmpty) ...[
            _sectionTitle(context.l10n.forumSelectCategory),
            _buildNarrowDropdown<int>(
              isDark: isDark,
              value: _postCategoryId,
              hint: context.l10n.forumSelectCategory,
              icon: Icons.forum_outlined,
              items: postableCategories
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName(Localizations.localeOf(context)))))
                  .toList(),
              onChanged: (v) => setState(() => _postCategoryId = v),
            ),
            AppSpacing.vLg,
          ],

          _sectionTitle(context.l10n.forumEnterTitle),
          TextFormField(
            controller: _postTitleCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.forumEnterTitle,
              icon: Icons.title_rounded,
              isDark: isDark,
            ),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            maxLength: 200,
          ),
          AppSpacing.vMd,

          _sectionTitle(context.l10n.forumShareThoughts),
          TextFormField(
            controller: _postContentCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.forumShareThoughts,
              icon: Icons.edit_note_rounded,
              isDark: isDark,
            ),
            maxLines: 8,
            minLines: 5,
          ),
          AppSpacing.vMd,
          _sectionTitle(context.l10n.publishImagesOptional('$_kPostMaxImages')),
          _buildPostImagePicker(isDark),
          AppSpacing.vMd,
          _sectionTitle(context.l10n.forumPdfAttachmentOptional),
          _buildPostPdfSection(isDark),
          AppSpacing.vMd,
          _sectionTitle(context.l10n.publishRelatedContentOptional),
          _buildPostLinkedChip(isDark),
          if (_postUploading) ...[
            AppSpacing.vMd,
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  // ==================== 窄下拉框（约 60% 宽度，左对齐） ====================
  // ==================== 任务类型下拉框（含禁用项） ====================
  Widget _buildTaskCategoryDropdown(
    bool isDark,
    List<(String, String, bool)> categories,
  ) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: ValueListenableBuilder<String?>(
          valueListenable: _taskCategoryNotifier,
          builder: (context, value, child) {
            return DropdownButtonFormField<String>(
              initialValue: value,
              isExpanded: true,
              decoration: InputDecoration(
                hintText: context.l10n.createTaskType,
                prefixIcon: const Icon(Icons.category_outlined, size: 20),
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.backgroundLight,
                border: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.separatorLight.withValues(alpha: 0.5),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : AppColors.separatorLight.withValues(alpha: 0.5),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppRadius.allMedium,
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 1.5),
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                isDense: true,
              ),
              style: TextStyle(
                fontSize: 14,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              // 所有选项都可选择（enabled 项和 disabled 项都用同一个 value）
              items: categories.map((c) {
                final enabled = c.$3;
                return DropdownMenuItem<String>(
                  value: c.$1,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.$2,
                          style: TextStyle(
                            color: enabled
                                ? (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight)
                                : (isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight),
                          ),
                        ),
                      ),
                      if (!enabled)
                        Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (v) {
                if (v == null) return;
                // 查找该选项是否 enabled
                final match = categories.firstWhere((c) => c.$1 == v);
                if (!match.$3) {
                  // 禁用项 → 弹出提示，不更新选择
                  AppHaptics.light();
                  AppFeedback.showWarning(
                    context,
                    context.l10n.taskTypeCampusLifeNeedVerify,
                  );
                  // 重置回之前的值（用 addPostFrameCallback 避免 build 中 setState）
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) setState(() {}); // 触发重绘恢复旧值
                  });
                  return;
                }
                _taskCategoryNotifier.value = v;
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildNarrowDropdown<T>({
    required bool isDark,
    required T? value,
    required String hint,
    required IconData icon,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 220),
        child: DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 20),
            filled: true,
            fillColor: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.separatorLight.withValues(alpha: 0.5),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : AppColors.separatorLight.withValues(alpha: 0.5),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: AppRadius.allMedium,
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ==================== 闲置图片选择器 ====================
  Widget _buildFleaImagePicker(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._fleaImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: CrossPlatformImage(xFile: entry.value, width: 80, height: 80),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _removeImage(entry.key),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_fleaImages.length < 9)
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
                    '${_fleaImages.length}/9',
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

  // ==================== 任务图片选择器（最多 5 张） ====================
  Widget _buildTaskImagePicker(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._taskImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: CrossPlatformImage(xFile: entry.value, width: 80, height: 80),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _removeTaskImage(entry.key),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_taskImages.length < _kTaskMaxImages)
          GestureDetector(
            onTap: _pickTaskImages,
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
                    '${_taskImages.length}/$_kTaskMaxImages',
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

  // ==================== 帖子图片选择器（最多 5 张） ====================
  Widget _buildPostImagePicker(bool isDark) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._postImages.asMap().entries.map((entry) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.allSmall,
                child: CrossPlatformImage(xFile: entry.value, width: 80, height: 80),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: GestureDetector(
                  onTap: () => _removePostImage(entry.key),
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_postImages.length < _kPostMaxImages)
          GestureDetector(
            onTap: _pickPostImages,
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
                    '${_postImages.length}/$_kPostMaxImages',
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

  // ==================== 帖子 PDF 附件（最多 1 个） ====================
  Widget _buildPostPdfSection(bool isDark) {
    final primary = Theme.of(context).colorScheme.primary;

    if (_postPdfFile != null) {
      final f = _postPdfFile!;
      final sizeStr = f.size < 1024 * 1024
          ? '${(f.size / 1024).toStringAsFixed(1)} KB'
          : '${(f.size / (1024 * 1024)).toStringAsFixed(1)} MB';
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
            Icon(Icons.picture_as_pdf, size: 28, color: primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  Text(
                    sizeStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20, color: AppColors.error),
              tooltip: context.l10n.commonDelete,
              onPressed: _removePostPdf,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ),
      );
    }

    return Semantics(
      button: true,
      label: context.l10n.forumPdfAddPdf,
      child: GestureDetector(
        onTap: _pickPostPdf,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade50,
            borderRadius: AppRadius.allSmall,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppColors.textTertiaryLight.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.attach_file, size: 20, color: primary),
              const SizedBox(width: 6),
              Text(context.l10n.forumPdfAddPdf, style: TextStyle(fontSize: 14, color: primary)),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== 帖子关联内容（单选） ====================
  Widget _buildPostLinkedChip(bool isDark) {
    if (_postLinkedName != null && _postLinkedName!.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Chip(
              avatar: Icon(Icons.link, size: 18, color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              label: Text(_postLinkedName!, maxLines: 1, overflow: TextOverflow.ellipsis),
              onDeleted: _clearPostLinked,
            ),
          ),
        ],
      );
    }
    return Align(
      alignment: Alignment.centerLeft,
      child: OutlinedButton.icon(
        onPressed: () => _showPostLinkSearchDialog(isDark),
        icon: const Icon(Icons.add_link, size: 20),
        label: Text(context.l10n.publishSearchAndLink),
      ),
    );
  }

  Future<void> _showPostLinkSearchDialog(bool isDark) async {
    final discoveryRepo = context.read<DiscoveryRepository>();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => _PostLinkSearchDialogContent(
        discoveryRepo: discoveryRepo,
        isDark: isDark,
      ),
    );
    if (result != null && mounted) {
      setState(() {
        _postLinkedType = result['type']!;
        _postLinkedId = result['id']!;
        _postLinkedName = result['name']!;
      });
    }
  }

  // ==================== 工具方法 ====================
  Widget _sectionTitle(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isDark,
    String? prefix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixText: prefix,
      prefixIcon: Icon(icon, size: 20),
      filled: true,
      fillColor: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.backgroundLight,
      border: OutlineInputBorder(
        borderRadius: AppRadius.allMedium,
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.separatorLight.withValues(alpha: 0.5),
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppRadius.allMedium,
        borderSide: BorderSide(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : AppColors.separatorLight.withValues(alpha: 0.5),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppRadius.allMedium,
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}

// ── 最近发布数据与列表项 ──
enum _RecentItemType { task, fleaMarket, post }

class _RecentPublishItem {
  const _RecentPublishItem({
    required this.type,
    required this.id,
    required this.title,
    required this.createdAt,
  });
  final _RecentItemType type;
  final String id;
  final String title;
  final DateTime createdAt;
}

class _RecentPublishListItem extends StatelessWidget {
  const _RecentPublishListItem({
    required this.isDark,
    required this.item,
    required this.onTap,
  });
  final bool isDark;
  final _RecentPublishItem item;
  final VoidCallback onTap;

  IconData get _icon {
    switch (item.type) {
      case _RecentItemType.task:
        return Icons.task_alt_rounded;
      case _RecentItemType.fleaMarket:
        return Icons.storefront_rounded;
      case _RecentItemType.post:
        return Icons.article_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(
              _icon,
              size: 20,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 发布类型卡片（样式 B）====================
class _PublishTypeCard extends StatelessWidget {
  const _PublishTypeCard({
    required this.isDark,
    required this.type,
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
    this.fullWidth = false,
  });

  final bool isDark;
  final _PublishType type;
  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.allLarge,
        child: Container(
          padding: fullWidth
              ? const EdgeInsets.symmetric(horizontal: 20, vertical: 20)
              : const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradient,
            ),
            borderRadius: AppRadius.allLarge,
            boxShadow: [
              BoxShadow(
                color: gradient.first.withValues(alpha: 0.35),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: fullWidth
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 32, color: Colors.white),
                    AppSpacing.hMd,
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 32, color: Colors.white),
                    AppSpacing.vSm,
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
