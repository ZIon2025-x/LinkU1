import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/task.dart';
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
  String _taskCurrency = 'GBP';
  DateTime? _taskDeadline;

  // ── 闲置表单 ──
  final _fleaFormKey = GlobalKey<FormState>();
  final _fleaTitleCtrl = TextEditingController();
  final _fleaDescCtrl = TextEditingController();
  final _fleaPriceCtrl = TextEditingController();
  String? _fleaLocation;
  double? _fleaLatitude;
  double? _fleaLongitude;
  String? _fleaCategory;
  final List<File> _fleaImages = [];
  final _imagePicker = ImagePicker();

  // ── 帖子表单 ──
  final _postFormKey = GlobalKey<FormState>();
  final _postTitleCtrl = TextEditingController();
  final _postContentCtrl = TextEditingController();
  int? _postCategoryId;
  final List<File> _postImages = [];
  String? _postLinkedType;
  String? _postLinkedId;
  String? _postLinkedName;
  bool _postUploadingImages = false;

  // ── 关闭动画 ──
  late final AnimationController _closeAnimCtrl;

  @override
  void initState() {
    super.initState();
    _closeAnimCtrl = AnimationController(
      vsync: this,
      duration: AppConstants.animationDuration,
    );
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
  void _submitTask() {
    if (!_taskFormKey.currentState!.validate()) return;
    if (_taskCategoryNotifier.value == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }
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
    );
    context.read<CreateTaskBloc>().add(CreateTaskSubmitted(request));
  }

  void _submitFleaMarket() {
    if (!_fleaFormKey.currentState!.validate()) return;
    final price = double.tryParse(_fleaPriceCtrl.text.trim());
    if (price == null || price <= 0) {
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
    List<String> imageUrls = [];
    if (_postImages.isNotEmpty) {
      setState(() => _postUploadingImages = true);
      try {
        final repo = context.read<ForumRepository>();
        for (final file in _postImages) {
          final url = await repo.uploadPostImage(file.path);
          imageUrls.add(url);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _postUploadingImages = false);
          AppFeedback.showError(context, e.toString());
        }
        return;
      }
      if (mounted) setState(() => _postUploadingImages = false);
    }
    if (!mounted) return;
    context.read<ForumBloc>().add(
          ForumCreatePost(
            CreatePostRequest(
              title: title,
              content: content,
              categoryId: _postCategoryId!,
              images: imageUrls,
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
      case _PublishType.fleaMarket:
        _submitFleaMarket();
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
    if (date != null) setState(() => _taskDeadline = date);
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
            if (_fleaImages.length < 9) _fleaImages.add(File(f.path));
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
            if (_postImages.length < _kPostMaxImages) _postImages.add(File(f.path));
          }
        });
      }
    } catch (e) {
      if (mounted) AppFeedback.showError(context, e.toString());
    }
  }

  void _removePostImage(int index) => setState(() => _postImages.removeAt(index));

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

  bool get _isSubmitting {
    final isTaskSubmitting = context.watch<CreateTaskBloc>().state.isSubmitting;
    final isFleaSubmitting = context.watch<FleaMarketBloc>().state.isSubmitting;
    final isPostSubmitting = context.watch<ForumBloc>().state.isCreatingPost;
    return isTaskSubmitting || isFleaSubmitting || isPostSubmitting || _postUploadingImages;
  }

  // ==================== Build ====================
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return MultiBlocListener(
      listeners: [
        // 任务发布成功监听
        BlocListener<CreateTaskBloc, CreateTaskState>(
          listener: (context, state) {
            if (state.isSuccess) {
              AppFeedback.showSuccess(context, context.l10n.feedbackTaskPublishSuccess);
              context.pop();
            } else if (state.status == CreateTaskStatus.error) {
              AppFeedback.showError(context, state.errorMessage ?? context.l10n.feedbackPublishFailed);
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
              var message = state.errorMessage ?? context.l10n.feedbackPublishFailed;
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
              AppFeedback.showError(context, state.errorMessage!);
            } else if (!state.isCreatingPost &&
                state.posts.isNotEmpty &&
                state.posts.first.title == _postTitleCtrl.text.trim()) {
              AppFeedback.showSuccess(context, context.l10n.feedbackPostPublishSuccess);
              context.pop();
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        body: SafeArea(
          bottom: false,
          child: _selectedType == null
              ? _buildTypePicker(isDark, bottomPadding)
              : _buildFormView(isDark, bottomPadding),
        ),
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
                      const SizedBox(height: 8),
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
                              gradient: const [Color(0xFF2659F2), Color(0xFF4088FF)],
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
          const SizedBox(height: 4),
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
  Widget _buildFormView(bool isDark, double bottomPadding) {
    final type = _selectedType!;
    return Column(
      children: [
        _buildFormHeader(isDark, type),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: switch (type) {
              _PublishType.task => _buildTaskForm(isDark),
              _PublishType.fleaMarket => _buildFleaMarketForm(isDark),
              _PublishType.post => _buildPostForm(isDark),
            },
          ),
        ),
        _buildBottomBar(isDark, bottomPadding),
      ],
    );
  }

  Widget _buildFormHeader(bool isDark, _PublishType type) {
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
        right: AppSpacing.lg,
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
          const SizedBox(width: 44),
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

  // ==================== 底部操作栏 ====================
  Widget _buildBottomBar(bool isDark, double bottomPadding) {
    final isSubmitting = _isSubmitting;

    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.md,
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: _submitButtonText,
              onPressed: isSubmitting ? null : _submit,
              isLoading: isSubmitting,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          GestureDetector(
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
        ],
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

    return Form(
      key: _taskFormKey,
      child: ListView(
        key: const ValueKey('task_form'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: AppRadius.allMedium,
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _taskCurrency,
                    isDense: true,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.primary,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                      DropdownMenuItem(value: 'USD', child: Text('USD')),
                      DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _taskCurrency = v);
                    },
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
                        ? '${_taskDeadline!.year}-${_taskDeadline!.month.toString().padLeft(2, '0')}-${_taskDeadline!.day.toString().padLeft(2, '0')}'
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
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ==================== 闲置发布表单 ====================
  Widget _buildFleaMarketForm(bool isDark) {
    return Form(
      key: _fleaFormKey,
      child: ListView(
        key: const ValueKey('flea_form'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
              if (price == null || price <= 0) return context.l10n.fleaMarketInvalidPrice;
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
          const SizedBox(height: 120),
        ],
      ),
    );
  }

  // ==================== 帖子发布表单 ====================
  Widget _buildPostForm(bool isDark) {
    final forumState = context.watch<ForumBloc>().state;
    final currentUser = context.watch<AuthBloc>().state.user;

    // 只展示当前用户有权发布的板块（可见且非仅管理员发帖）
    final postableCategories = ForumPermissionHelper.filterPostableCategories(
      forumState.categories,
      currentUser,
    );

    // 如果当前选中的分类不在可发布列表中，重置选择
    if (_postCategoryId != null &&
        !postableCategories.any((c) => c.id == _postCategoryId)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _postCategoryId = null);
      });
    }

    return Form(
      key: _postFormKey,
      child: ListView(
        key: const ValueKey('post_form'),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
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
                  .map((c) => DropdownMenuItem(value: c.id, child: Text(c.displayName)))
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
          _sectionTitle('图片（选填，最多 $_kPostMaxImages 张）'),
          _buildPostImagePicker(isDark),
          AppSpacing.vMd,
          _sectionTitle('关联内容（选填，可关联服务/活动/商品/排行榜等）'),
          _buildPostLinkedChip(isDark),
          if (_postUploadingImages) ...[
            AppSpacing.vMd,
            const Center(child: CircularProgressIndicator()),
          ],
          const SizedBox(height: 120),
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
                child: Image.file(entry.value, width: 80, height: 80, fit: BoxFit.cover),
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
                child: Image.file(entry.value, width: 80, height: 80, fit: BoxFit.cover),
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
        label: const Text('搜索并关联'),
      ),
    );
  }

  Future<void> _showPostLinkSearchDialog(bool isDark) async {
    final queryCtrl = TextEditingController();
    final discoveryRepo = context.read<DiscoveryRepository>();
    List<Map<String, dynamic>> results = [];
    bool loading = false;

    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> runSearch(String q) async {
              if (q.trim().isEmpty) return;
              setDialogState(() => loading = true);
              try {
                final list = await discoveryRepo.searchLinkableContent(query: q.trim(), type: 'all');
                if (ctx.mounted) {
                  setDialogState(() {
                    results = list;
                    loading = false;
                  });
                }
              } catch (e) {
                if (ctx.mounted) {
                  setDialogState(() => loading = false);
                  AppFeedback.showError(ctx, e.toString());
                }
              }
            }
            return AlertDialog(
              title: const Text('关联内容'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: queryCtrl,
                            decoration: const InputDecoration(
                              hintText: '输入关键词搜索服务、活动、商品、排行榜…',
                              border: OutlineInputBorder(),
                            ),
                            onSubmitted: runSearch,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () => runSearch(queryCtrl.text),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (loading) const Center(child: CircularProgressIndicator()),
                    if (!loading && results.isNotEmpty)
                      Flexible(
                        child: ListView.builder(
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final r = results[i];
                            final type = r['item_type'] as String? ?? '';
                            final name = r['name'] as String? ?? r['title'] as String? ?? '未命名';
                            final id = r['item_id']?.toString() ?? '';
                            return ListTile(
                              title: Text(name),
                              subtitle: Text(type),
                              onTap: () {
                                setState(() {
                                  _postLinkedType = type;
                                  _postLinkedId = id;
                                  _postLinkedName = name;
                                });
                                Navigator.of(ctx).pop();
                              },
                            );
                          },
                        ),
                      ),
                    if (!loading && results.isEmpty && queryCtrl.text.trim().isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Text('无结果，换关键词试试'),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
                ),
              ],
            );
          },
        );
      },
    );
    queryCtrl.dispose();
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
                    const SizedBox(width: 16),
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
                    const SizedBox(height: 8),
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
