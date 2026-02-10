import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/buttons.dart';
import '../../../data/models/flea_market.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../flea_market/bloc/flea_market_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../forum/bloc/forum_bloc.dart';
import '../../tasks/bloc/create_task_bloc.dart';
import '../../../core/utils/forum_permission_helper.dart';

/// 统一发布页面
/// 从底部滑入，底部有关闭按钮。
/// 默认「任务发布」，可切换为「闲置发布」或「帖子发布」。
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
  _PublishType _type = _PublishType.task;

  // ── 任务表单 ──
  final _taskFormKey = GlobalKey<FormState>();
  final _taskTitleCtrl = TextEditingController();
  final _taskDescCtrl = TextEditingController();
  final _taskRewardCtrl = TextEditingController();
  final _taskLocationCtrl = TextEditingController();
  String? _taskCategory;
  String _taskCurrency = 'GBP';
  DateTime? _taskDeadline;

  // ── 闲置表单 ──
  final _fleaFormKey = GlobalKey<FormState>();
  final _fleaTitleCtrl = TextEditingController();
  final _fleaDescCtrl = TextEditingController();
  final _fleaPriceCtrl = TextEditingController();
  final _fleaLocationCtrl = TextEditingController();
  String? _fleaCategory;
  final List<File> _fleaImages = [];
  final _imagePicker = ImagePicker();

  // ── 帖子表单 ──
  final _postFormKey = GlobalKey<FormState>();
  final _postTitleCtrl = TextEditingController();
  final _postContentCtrl = TextEditingController();
  int? _postCategoryId;

  // ── 关闭动画 ──
  late final AnimationController _closeAnimCtrl;

  @override
  void initState() {
    super.initState();
    _closeAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _taskTitleCtrl.dispose();
    _taskDescCtrl.dispose();
    _taskRewardCtrl.dispose();
    _taskLocationCtrl.dispose();
    _fleaTitleCtrl.dispose();
    _fleaDescCtrl.dispose();
    _fleaPriceCtrl.dispose();
    _fleaLocationCtrl.dispose();
    _postTitleCtrl.dispose();
    _postContentCtrl.dispose();
    _closeAnimCtrl.dispose();
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
    if (_taskCategory == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }
    final reward = double.tryParse(_taskRewardCtrl.text) ?? 0;
    final request = CreateTaskRequest(
      title: _taskTitleCtrl.text.trim(),
      description: _taskDescCtrl.text.trim().isNotEmpty ? _taskDescCtrl.text.trim() : null,
      taskType: _taskCategory!,
      reward: reward,
      currency: _taskCurrency,
      location: _taskLocationCtrl.text.trim().isNotEmpty ? _taskLocationCtrl.text.trim() : null,
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
      location: _fleaLocationCtrl.text.trim().isEmpty ? null : _fleaLocationCtrl.text.trim(),
      images: [],
    );
    context.read<FleaMarketBloc>().add(FleaMarketCreateItem(request));
  }

  void _submitPost() {
    if (_postTitleCtrl.text.trim().isEmpty || _postContentCtrl.text.trim().isEmpty) {
      AppFeedback.showWarning(context, context.l10n.feedbackFillTitleAndContent);
      return;
    }
    if (_postCategoryId == null) {
      AppFeedback.showWarning(context, context.l10n.feedbackSelectCategory);
      return;
    }
    context.read<ForumBloc>().add(
          ForumCreatePost(
            CreatePostRequest(
              title: _postTitleCtrl.text.trim(),
              content: _postContentCtrl.text.trim(),
              categoryId: _postCategoryId!,
            ),
          ),
        );
  }

  void _submit() {
    AppHaptics.medium();
    switch (_type) {
      case _PublishType.task:
        _submitTask();
      case _PublishType.fleaMarket:
        _submitFleaMarket();
      case _PublishType.post:
        _submitPost();
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

  String get _submitButtonText {
    switch (_type) {
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
    return isTaskSubmitting || isFleaSubmitting || isPostSubmitting;
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
          listenWhen: (prev, curr) => prev.actionMessage != curr.actionMessage,
          listener: (context, state) {
            if (state.actionMessage != null) {
              final isSuccess = state.actionMessage!.contains('成功');
              if (isSuccess) {
                AppFeedback.showSuccess(context, state.actionMessage!);
                context.pop();
              } else {
                AppFeedback.showError(context, state.actionMessage!);
              }
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
          child: Column(
            children: [
              // ── 顶部：拖拽指示器 + 标题 ──
              _buildHeader(isDark),

              // ── 类型切换（三段） ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: _SegmentControl(
                  isDark: isDark,
                  selected: _type,
                  onChanged: (type) {
                    AppHaptics.selection();
                    setState(() => _type = type);
                  },
                ),
              ),

              const SizedBox(height: AppSpacing.md),

              // ── 表单内容（可滚动）──
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: switch (_type) {
                    _PublishType.task => _buildTaskForm(isDark),
                    _PublishType.fleaMarket => _buildFleaMarketForm(isDark),
                    _PublishType.post => _buildPostForm(isDark),
                  },
                ),
              ),

              // ── 底部：提交按钮 + 关闭按钮 ──
              _buildBottomBar(isDark, bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== Header ====================
  Widget _buildHeader(bool isDark) {
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
          const SizedBox(height: AppSpacing.sm),
        ],
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
    if (_taskCategory != null) {
      final match = taskCategories.where((c) => c.$1 == _taskCategory);
      if (match.isEmpty || !match.first.$3) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) setState(() => _taskCategory = null);
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
          TextFormField(
            controller: _taskLocationCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.createTaskLocationHint,
              icon: Icons.location_on_outlined,
              isDark: isDark,
            ),
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
          TextFormField(
            controller: _fleaLocationCtrl,
            decoration: _inputDecoration(
              hint: context.l10n.fleaMarketLocationHint,
              icon: Icons.location_on_outlined,
              isDark: isDark,
            ),
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

    // 只展示当前用户有权发布的板块
    final postableCategories = ForumPermissionHelper.filterVisibleCategories(
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
        child: DropdownButtonFormField<String>(
          value: _taskCategory,
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
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            isDense: true,
          ),
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
                            ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                      ),
                    ),
                  ),
                  if (!enabled)
                    Icon(
                      Icons.lock_outline,
                      size: 14,
                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
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
            setState(() => _taskCategory = v);
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
          value: value,
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

// ==================== 三段切换器 ====================
class _SegmentControl extends StatelessWidget {
  const _SegmentControl({
    required this.isDark,
    required this.selected,
    required this.onChanged,
  });

  final bool isDark;
  final _PublishType selected;
  final ValueChanged<_PublishType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildTab(
            context,
            type: _PublishType.task,
            label: context.l10n.publishTaskTab,
            icon: Icons.task_alt_rounded,
          ),
          _buildTab(
            context,
            type: _PublishType.fleaMarket,
            label: context.l10n.publishFleaMarketTab,
            icon: Icons.storefront_rounded,
          ),
          _buildTab(
            context,
            type: _PublishType.post,
            label: context.l10n.publishPostTab,
            icon: Icons.article_rounded,
          ),
        ],
      ),
    );
  }

  Widget _buildTab(
    BuildContext context, {
    required _PublishType type,
    required String label,
    required IconData icon,
  }) {
    final isActive = selected == type;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isActive
                ? (isDark ? AppColors.cardBackgroundDark : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? AppColors.primary
                    : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                  color: isActive
                      ? AppColors.primary
                      : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
