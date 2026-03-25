import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/cross_platform_image.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/services/task_draft_service.dart';
import '../bloc/create_task_bloc.dart';
import 'create_task_widgets.dart';

/// 任务草稿预填数据（从 AI 助手生成）
class TaskDraftData {
  const TaskDraftData({
    this.title,
    this.description,
    this.taskType,
    this.reward,
    this.currency,
    this.location,
    this.deadline,
  });

  final String? title;
  final String? description;
  final String? taskType;
  final double? reward;
  final String? currency;
  final String? location;
  final DateTime? deadline;

  factory TaskDraftData.fromJson(Map<String, dynamic> json) {
    DateTime? deadline;
    if (json['deadline'] != null) {
      deadline = DateTime.tryParse(json['deadline'].toString());
    }
    return TaskDraftData(
      title: json['title'] as String?,
      description: json['description'] as String?,
      taskType: json['task_type'] as String?,
      reward: (json['reward'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'GBP',
      location: json['location'] as String?,
      deadline: deadline,
    );
  }
}

/// 创建任务页
class CreateTaskView extends StatelessWidget {
  const CreateTaskView({super.key, this.draft});

  final TaskDraftData? draft;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateTaskBloc(
        taskRepository: context.read<TaskRepository>(),
      ),
      child: _CreateTaskContent(draft: draft),
    );
  }
}

class _CreateTaskContent extends StatefulWidget {
  const _CreateTaskContent({this.draft});

  final TaskDraftData? draft;

  @override
  State<_CreateTaskContent> createState() => _CreateTaskContentState();
}

class _CreateTaskContentState extends State<_CreateTaskContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();

  String? _location;
  double? _latitude;
  double? _longitude;
  String _selectedCategory = 'design';
  String _selectedCurrency = 'GBP';
  String _pricingType = 'fixed';
  String _taskMode = 'online';
  String? _deadlinePreset;
  DateTime? _deadline;
  final List<String> _selectedSkills = [];
  final List<XFile> _selectedImages = [];
  bool _isUploadingImages = false;
  final _imagePicker = ImagePicker();

  /// 分类对应的技能建议
  static const _skillSuggestions = <String, List<String>>{
    'design': ['Figma', 'UI设计', 'Sketch', '原型设计', 'Adobe XD', 'Photoshop'],
    'programming': ['Python', 'Flutter', 'React', 'JavaScript', 'Java', 'iOS'],
    'photography': ['人像', '产品', '风光', '视频', 'Lightroom', 'PR'],
    'copywriting': ['公众号', 'SEO', '品牌文案', '短视频脚本', '翻译'],
    'music': ['作曲', '编曲', '混音', '吉他', '钢琴', '声乐'],
    'lifestyle': ['搬家', '清洁', '维修', '跑腿', '代购'],
    'tutoring': ['数学', '英语', '编程', '考试辅导', '论文'],
  };

  /// 旧分类名到新分类名映射
  static const _categoryMigration = <String, String>{
    'Housekeeping': 'lifestyle',
    'Campus Life': 'lifestyle',
    'Second-hand & Rental': 'lifestyle',
    'Errand Running': 'lifestyle',
    'Skill Service': 'design',
    'Social Help': 'lifestyle',
    'Transportation': 'lifestyle',
    'Pet Care': 'lifestyle',
    'Life Convenience': 'lifestyle',
    'Other': 'design',
  };

  bool get _hasUnsavedChanges {
    return _titleController.text.isNotEmpty ||
        _descriptionController.text.isNotEmpty ||
        _rewardController.text.isNotEmpty ||
        _selectedImages.isNotEmpty;
  }

  @override
  void initState() {
    super.initState();
    // Pre-fill from AI draft
    final d = widget.draft;
    if (d != null) {
      if (d.title != null) _titleController.text = d.title!;
      if (d.description != null) _descriptionController.text = d.description!;
      if (d.reward != null) {
        _rewardController.text = Helpers.formatAmountNumber(d.reward!);
      }
      if (d.currency != null) _selectedCurrency = d.currency!;
      if (d.location != null) _location = d.location;
      if (d.deadline != null && d.deadline!.isAfter(DateTime.now())) {
        _deadline = d.deadline;
      }
      if (d.taskType != null) {
        // Map old category keys to new ones
        const newKeys = [
          'design', 'programming', 'photography',
          'copywriting', 'music', 'lifestyle', 'tutoring',
        ];
        if (newKeys.contains(d.taskType)) {
          _selectedCategory = d.taskType!;
        } else {
          _selectedCategory = _categoryMigration[d.taskType] ?? 'design';
        }
      }
    }
    // Check for local draft
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkLocalDraft());
  }

  Future<void> _checkLocalDraft() async {
    if (widget.draft != null) return; // AI draft takes priority
    final draft = await TaskDraftService.loadDraft();
    if (draft != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.createTaskDraftLoaded),
          action: SnackBarAction(
            label: context.l10n.createTaskDraftRestore,
            onPressed: () => _restoreDraft(draft),
          ),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _restoreDraft(Map<String, dynamic> draft) {
    setState(() {
      _titleController.text = draft['title'] as String? ?? '';
      _descriptionController.text = draft['description'] as String? ?? '';
      _selectedCategory = draft['task_type'] as String? ?? 'design';
      _pricingType = draft['pricing_type'] as String? ?? 'fixed';
      _taskMode = draft['task_mode'] as String? ?? 'online';
      _rewardController.text = draft['reward'] as String? ?? '';
      _deadlinePreset = draft['deadline_preset'] as String?;
      final skills = draft['required_skills'];
      if (skills is List) {
        _selectedSkills
          ..clear()
          ..addAll(skills.cast<String>());
      }
    });
  }

  Future<void> _saveDraft() async {
    await TaskDraftService.saveDraft({
      'title': _titleController.text,
      'description': _descriptionController.text,
      'task_type': _selectedCategory,
      'pricing_type': _pricingType,
      'task_mode': _taskMode,
      'reward': _rewardController.text,
      'deadline_preset': _deadlinePreset,
      'required_skills': _selectedSkills,
    });
    if (mounted) {
      AppFeedback.showSuccess(context, context.l10n.createTaskDraftSaved);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: (_deadline != null && _deadline!.isAfter(DateTime.now()))
          ? _deadline!
          : DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final initialTime = _deadline != null
        ? TimeOfDay(hour: _deadline!.hour, minute: _deadline!.minute)
        : const TimeOfDay(hour: 12, minute: 0);
    final time = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );
    if (time != null && mounted) {
      setState(() {
        _deadline = DateTime(
            date.year, date.month, date.day, time.hour, time.minute);
      });
    } else if (mounted) {
      setState(() {
        _deadline = DateTime(date.year, date.month, date.day, 12);
      });
    }
  }

  void _onDeadlinePreset(String preset) {
    setState(() {
      _deadlinePreset = preset;
      final now = DateTime.now();
      switch (preset) {
        case '24h':
          _deadline = now.add(const Duration(hours: 24));
        case '3d':
          _deadline = now.add(const Duration(days: 3));
        case '1w':
          _deadline = now.add(const Duration(days: 7));
        case '2w':
          _deadline = now.add(const Duration(days: 14));
        case 'no_rush':
          _deadline = null;
        case 'custom':
          _selectDeadline();
      }
    });
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deadline != null && _deadline!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.createTaskSelectDeadline),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final reward = _pricingType == 'negotiable'
        ? null
        : (double.tryParse(_rewardController.text) ?? 0.0);
    if (_pricingType != 'negotiable' && (reward == null || reward < 1.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.validatorAmountMin(1.0)),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final List<String> imageUrls = [];
    if (_selectedImages.isNotEmpty) {
      setState(() => _isUploadingImages = true);
      try {
        final repo = context.read<TaskRepository>();
        final urls = await Future.wait(
          _selectedImages.map((img) async {
            final bytes = await img.readAsBytes();
            return repo.uploadTaskImage(bytes, img.name);
          }),
        );
        if (!mounted) return;
        imageUrls.addAll(urls);
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingImages = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(context.l10n.createTaskImageUploadFailed),
                backgroundColor: AppColors.error),
          );
        }
        return;
      }
      if (mounted) setState(() => _isUploadingImages = false);
    }

    if (!mounted) return;

    final request = CreateTaskRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      taskType: _selectedCategory,
      reward: reward,
      currency: _selectedCurrency,
      location: _taskMode == 'online' ? 'Online' : _location,
      latitude: _taskMode == 'online' ? null : _latitude,
      longitude: _taskMode == 'online' ? null : _longitude,
      deadline: _deadline,
      images: imageUrls,
      pricingType: _pricingType,
      taskMode: _taskMode,
      requiredSkills: _selectedSkills,
    );

    context.read<CreateTaskBloc>().add(CreateTaskSubmitted(request));
  }

  Future<void> _pickImages() async {
    final remaining = 9 - _selectedImages.length;
    if (remaining <= 0) return;
    final picked = await _imagePicker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1920,
    );
    if (picked.isNotEmpty && mounted) {
      setState(() {
        _selectedImages.addAll(picked.take(remaining));
      });
    }
  }

  void _onAIOptimize() {
    context.read<CreateTaskBloc>().add(CreateTaskAIOptimize(
          title: _titleController.text,
          description: _descriptionController.text,
          taskType: _selectedCategory,
        ));
  }

  Future<void> _showAIOptimizeResult(
      String title, String desc, List<String> skills) async {
    final accepted = await AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: context.l10n.createTaskAiOptimize,
      content:
          '$title\n\n$desc\n\n${skills.isNotEmpty ? "建议技能: ${skills.join(", ")}" : ""}',
      confirmText: context.l10n.commonConfirm,
    );
    if (accepted == true && mounted) {
      setState(() {
        _titleController.text = title;
        _descriptionController.text = desc;
        if (skills.isNotEmpty) {
          _selectedSkills
            ..clear()
            ..addAll(skills);
        }
      });
    }
  }

  Future<void> _addCustomSkill() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.createTaskAddCustomSkill),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: context.l10n.createTaskRequiredSkills),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.commonConfirm),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty && mounted) {
      setState(() {
        if (!_selectedSkills.contains(result)) {
          _selectedSkills.add(result);
        }
      });
    }
  }

  void _preview() {
    AdaptiveDialogs.showInfoDialog(
      context: context,
      title: context.l10n.createTaskPreview,
      content: '${_titleController.text}\n\n'
          '${context.l10n.createTaskType}: $_selectedCategory\n'
          '${context.l10n.createTaskReward}: ${_pricingType == "negotiable" ? context.l10n.createTaskPricingNegotiable : "£${_rewardController.text}"}\n'
          '${context.l10n.createTaskModeLabel}: $_taskMode\n\n'
          '${_descriptionController.text.length > 200 ? "${_descriptionController.text.substring(0, 200)}..." : _descriptionController.text}',
    );
  }

  void _onSkillToggle(String skill) {
    setState(() {
      if (_selectedSkills.contains(skill)) {
        _selectedSkills.remove(skill);
      } else {
        _selectedSkills.add(skill);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateTaskBloc, CreateTaskState>(
      listener: (context, state) {
        if (state.isSuccess) {
          TaskDraftService.deleteDraft();
          AppFeedback.showSuccess(
              context, context.l10n.feedbackTaskPublishSuccess);
          context.pop();
        } else if (state.status == CreateTaskStatus.error) {
          AppFeedback.showError(context,
              context.localizeError(state.errorMessage ?? 'create_task_failed'));
        }
        // Handle AI optimize result
        if (state.optimizedTitle != null) {
          _showAIOptimizeResult(
            state.optimizedTitle!,
            state.optimizedDescription ?? '',
            state.suggestedSkills,
          );
          // Reset AI state to avoid re-showing
          context.read<CreateTaskBloc>().add(const CreateTaskReset());
        }
      },
      builder: (context, state) {
        return PopScope(
          canPop: !_hasUnsavedChanges,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) {
              AdaptiveDialogs.showConfirmDialog(
                context: context,
                title: context.l10n.commonDiscardChanges,
                content: context.l10n.commonDiscardChangesMessage,
                confirmText: context.l10n.commonDiscard,
                isDestructive: true,
              ).then((confirmed) {
                if (confirmed == true && context.mounted) {
                  Navigator.of(context).pop();
                }
              });
            }
          },
          child: Scaffold(
            appBar: AppBar(
              title: Text(context.l10n.createTaskPublishBtn),
              actions: [
                TextButton(
                  onPressed: (state.isSubmitting || _isUploadingImages)
                      ? null
                      : _submitTask,
                  child: Text(
                    context.l10n.createTaskPublishBtn,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            body: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
                child: Column(
                  children: [
                    // 标题
                    SectionCard(
                      label: context.l10n.createTaskTitleField,
                      isRequired: true,
                      child: TextFormField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          hintText: context.l10n.createTaskTitleHint,
                          counterText:
                              '${_titleController.text.length}/50',
                        ),
                        maxLength: 50,
                        buildCounter: (context,
                                {required currentLength,
                                required isFocused,
                                required maxLength}) =>
                            null,
                        onChanged: (_) => setState(() {}),
                        validator: (v) =>
                            Validators.validateTitle(v, l10n: context.l10n),
                      ),
                    ),

                    // 参考图片
                    SectionCard(
                      label: context.l10n.createTaskRefImages,
                      child: _buildImagePicker(),
                    ),

                    // 详细描述
                    SectionCard(
                      label: context.l10n.taskDetailTaskDescription,
                      isRequired: true,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                                hintText: context.l10n.createTaskDescHint),
                            maxLines: 5,
                            maxLength: 2000,
                            validator: (value) =>
                                Validators.validateDescription(value,
                                    l10n: context.l10n),
                          ),
                          const AITipCard(),
                        ],
                      ),
                    ),

                    // 分类
                    SectionCard(
                      label: context.l10n.createTaskType,
                      isRequired: true,
                      child: CategoryChips(
                        selected: _selectedCategory,
                        onSelected: (cat) {
                          setState(() {
                            _selectedCategory = cat;
                            // Clear skills that don't match the new category
                            _selectedSkills.clear();
                          });
                        },
                      ),
                    ),

                    // 预算
                    SectionCard(
                      label: context.l10n.createTaskReward,
                      isRequired: true,
                      child: PriceRow(
                        controller: _rewardController,
                        pricingType: _pricingType,
                        onPricingTypeChanged: (type) =>
                            setState(() => _pricingType = type),
                      ),
                    ),

                    // 任务方式
                    SectionCard(
                      label: context.l10n.createTaskModeLabel,
                      child: Column(
                        children: [
                          TaskModeSelector(
                            selected: _taskMode,
                            onSelected: (mode) =>
                                setState(() => _taskMode = mode),
                          ),
                          // Location input: only show when not online
                          if (_taskMode != 'online') ...[
                            AppSpacing.vMd,
                            LocationInputField(
                              initialValue: _location,
                              hintText: context.l10n.createTaskLocationHint,
                              onChanged: (address) {
                                _location =
                                    address.isNotEmpty ? address : null;
                                _latitude = null;
                                _longitude = null;
                              },
                              onLocationPicked: (address, lat, lng) {
                                _location =
                                    address.isNotEmpty ? address : null;
                                _latitude = lat;
                                _longitude = lng;
                              },
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 截止时间
                    SectionCard(
                      label: context.l10n.createTaskDeadline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          DeadlineChips(
                            selected: _deadlinePreset,
                            onSelected: _onDeadlinePreset,
                          ),
                          if (_deadline != null) ...[
                            AppSpacing.vSm,
                            Text(
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(_deadline!),
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // 技能
                    SectionCard(
                      label: context.l10n.createTaskRequiredSkills,
                      child: SkillTagSelector(
                        selected: _selectedSkills,
                        suggestions:
                            _skillSuggestions[_selectedCategory] ?? [],
                        onToggle: _onSkillToggle,
                        onAddCustom: _addCustomSkill,
                      ),
                    ),

                    // AI 优化
                    AIOptimizeBar(
                      onTap: _onAIOptimize,
                      isLoading: state.isAiOptimizing,
                    ),
                  ],
                ),
              ),
            ),
            bottomNavigationBar: _buildBottomBar(context, state),
          ),
        );
      },
    );
  }

  Widget _buildImagePicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._selectedImages.asMap().entries.map((entry) {
          final idx = entry.key;
          final img = entry.value;
          return Stack(
            children: [
              ClipRRect(
                borderRadius: AppRadius.allMedium,
                child: CrossPlatformImage(
                  xFile: img,
                  width: 80,
                  height: 80,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: Semantics(
                  button: true,
                  label: 'Remove image',
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _selectedImages.removeAt(idx)),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.close,
                          size: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_selectedImages.length < 9)
          Semantics(
            button: true,
            label: 'Add images',
            child: GestureDetector(
              onTap: _pickImages,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.dividerLight),
                  borderRadius: AppRadius.allMedium,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_photo_alternate_outlined,
                        color: AppColors.textSecondaryLight),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n
                          .commonImageCount(_selectedImages.length, 9),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
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

  Widget _buildBottomBar(BuildContext context, CreateTaskState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF3A3A3C) : const Color(0xFFEEEEEE),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            child: PrimaryButton(
              text: context.l10n.createTaskPublishBtn,
              onPressed: (state.isSubmitting || _isUploadingImages)
                  ? null
                  : _submitTask,
              isLoading: state.isSubmitting || _isUploadingImages,
            ),
          ),
          AppSpacing.vSm,
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: _saveDraft,
                icon: const Icon(Icons.save_outlined, size: 18),
                label: Text(context.l10n.createTaskSaveDraft),
              ),
              const SizedBox(width: 16),
              TextButton.icon(
                onPressed: _preview,
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: Text(context.l10n.createTaskPreview),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
