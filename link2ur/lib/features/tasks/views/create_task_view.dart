import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../bloc/create_task_bloc.dart';

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
/// 参考iOS CreateTaskView.swift
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
  String _selectedCategory = 'Errand Running';
  String _selectedCurrency = 'GBP';
  DateTime? _deadline;
  bool _isPublic = true;
  bool _rewardToBeQuoted = false;
  final List<XFile> _selectedImages = [];
  bool _isUploadingImages = false;
  final _imagePicker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final d = widget.draft;
    if (d != null) {
      if (d.title != null) _titleController.text = d.title!;
      if (d.description != null) _descriptionController.text = d.description!;
      if (d.reward != null) _rewardController.text = Helpers.formatAmountNumber(d.reward!);
      if (d.currency != null) _selectedCurrency = d.currency!;
      if (d.location != null) _location = d.location;
      if (d.deadline != null) _deadline = d.deadline;
      if (d.taskType != null) {
        const validKeys = [
          'Housekeeping', 'Campus Life', 'Second-hand & Rental',
          'Errand Running', 'Skill Service', 'Social Help',
          'Transportation', 'Pet Care', 'Life Convenience', 'Other',
        ];
        if (validKeys.contains(d.taskType)) {
          _selectedCategory = d.taskType!;
        }
      }
    }
  }

  List<Map<String, String>> _getCategories(BuildContext context) {
    return [
      {'key': 'Housekeeping', 'label': context.l10n.taskTypeHousekeeping},
      {'key': 'Campus Life', 'label': context.l10n.taskTypeCampusLife},
      {'key': 'Second-hand & Rental', 'label': context.l10n.taskTypeSecondHandRental},
      {'key': 'Errand Running', 'label': context.l10n.taskTypeErrandRunning},
      {'key': 'Skill Service', 'label': context.l10n.taskTypeSkillService},
      {'key': 'Social Help', 'label': context.l10n.taskTypeSocialHelp},
      {'key': 'Transportation', 'label': context.l10n.taskTypeTransportation},
      {'key': 'Pet Care', 'label': context.l10n.taskTypePetCare},
      {'key': 'Life Convenience', 'label': context.l10n.taskTypeLifeConvenience},
      {'key': 'Other', 'label': context.l10n.taskTypeOther},
    ];
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
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
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
        _deadline = DateTime(date.year, date.month, date.day, time.hour, time.minute);
      });
    } else if (mounted) {
      setState(() {
        _deadline = DateTime(date.year, date.month, date.day, 12);
      });
    }
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;

    if (_deadline != null && _deadline!.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.createTaskSelectDeadline),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final reward = _rewardToBeQuoted
        ? null
        : (double.tryParse(_rewardController.text) ?? 0.0);
    if (!_rewardToBeQuoted && (reward == null || reward < 1.0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.validatorAmountMin(1.0)),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final List<String> imageUrls = [];
    if (_selectedImages.isNotEmpty) {
      setState(() => _isUploadingImages = true);
      try {
        final repo = context.read<TaskRepository>();
        for (final img in _selectedImages) {
          final url = await repo.uploadTaskImage(img.path);
          imageUrls.add(url);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploadingImages = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('图片上传失败: $e'), backgroundColor: Colors.red),
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
      location: _location,
      latitude: _latitude,
      longitude: _longitude,
      deadline: _deadline,
      images: imageUrls,
      isPublic: _isPublic ? 1 : 0,
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

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CreateTaskBloc, CreateTaskState>(
      listener: (context, state) {
        if (state.isSuccess) {
          AppFeedback.showSuccess(context, context.l10n.feedbackTaskPublishSuccess);
          context.pop();
        } else if (state.status == CreateTaskStatus.error) {
          AppFeedback.showError(context, state.errorMessage ?? context.l10n.feedbackPublishFailed);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(title: Text(context.l10n.createTaskTitle)),
          body: Form(
            key: _formKey,
            child: ListView(
              padding: AppSpacing.allMd,
              children: [
                _buildSectionTitle(context.l10n.createTaskType),
                _buildCategorySelector(),
                AppSpacing.vLg,

                _buildSectionTitle(context.l10n.createTaskTitleField),
                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(hintText: context.l10n.createTaskTitleHint),
                  maxLength: 100,
                  validator: (v) => Validators.validateTitle(v, l10n: context.l10n),
                ),
                AppSpacing.vMd,

                _buildSectionTitle(context.l10n.taskDetailTaskDescription),
                TextFormField(
                  controller: _descriptionController,
                  decoration:
                      InputDecoration(hintText: context.l10n.createTaskDescHint),
                  maxLines: 5,
                  maxLength: 2000,
                  validator: (value) => Validators.validateDescription(value, l10n: context.l10n),
                ),
                AppSpacing.vMd,

                _buildSectionTitle(context.l10n.createTaskReward),
                CheckboxListTile(
                  value: _rewardToBeQuoted,
                  onChanged: (v) => setState(() => _rewardToBeQuoted = v ?? false),
                  title: Text(
                    context.l10n.createTaskRewardToBeQuoted,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                ),
                if (!_rewardToBeQuoted)
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _rewardController,
                          decoration: InputDecoration(
                            hintText: '0.00',
                            prefixText: context.l10n.commonCurrencySymbol,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          validator: (v) => Validators.validateAmount(
                            v,
                            l10n: context.l10n,
                            min: 1.0,
                          ),
                        ),
                      ),
                      AppSpacing.hMd,
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          'GBP',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                AppSpacing.vLg,

                _buildSectionTitle(context.l10n.createTaskLocation),
                LocationInputField(
                  initialValue: _location,
                  hintText: context.l10n.createTaskLocationHint,
                  onChanged: (address) {
                    _location = address.isNotEmpty ? address : null;
                    _latitude = null;
                    _longitude = null;
                  },
                  onLocationPicked: (address, lat, lng) {
                    _location = address.isNotEmpty ? address : null;
                    _latitude = lat;
                    _longitude = lng;
                  },
                ),
                AppSpacing.vLg,

                _buildSectionTitle(context.l10n.createTaskDeadline),
                GestureDetector(
                  onTap: _selectDeadline,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).inputDecorationTheme.fillColor,
                      borderRadius: AppRadius.input,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            color: AppColors.textSecondaryLight),
                        AppSpacing.hMd,
                        Text(
                          _deadline != null
                              ? DateFormat('yyyy-MM-dd HH:mm').format(_deadline!)
                              : context.l10n.createTaskSelectDeadline,
                          style: TextStyle(
                            color: _deadline != null
                                ? null
                                : AppColors.textPlaceholderLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                AppSpacing.vLg,

                _buildSectionTitle(context.l10n.createTaskAddImages),
                _buildImagePicker(),
                AppSpacing.vLg,

                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('公开任务', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    _isPublic ? '所有人可见' : '仅自己可见',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondaryLight),
                  ),
                  value: _isPublic,
                  onChanged: (v) => setState(() => _isPublic = v),
                ),
                AppSpacing.vXxl,

                PrimaryButton(
                  text: context.l10n.createTaskTitle,
                  onPressed: (state.isSubmitting || _isUploadingImages) ? null : _submitTask,
                  isLoading: state.isSubmitting || _isUploadingImages,
                ),
                AppSpacing.vXxl,
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _getCategories(context).map((category) {
        final isSelected = _selectedCategory == category['key'];
        return GestureDetector(
          onTap: () => setState(() => _selectedCategory = category['key']!),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: AppRadius.allSmall,
              border: Border.all(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.dividerLight,
              ),
            ),
            child: Text(
              category['label']!,
              style: TextStyle(
                color: isSelected
                    ? Colors.white
                    : AppColors.textSecondaryLight,
                fontWeight:
                    isSelected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
        );
      }).toList(),
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
                child: Image.file(
                  File(img.path),
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () => setState(() => _selectedImages.removeAt(idx)),
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(2),
                    child: const Icon(Icons.close, size: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        }),
        if (_selectedImages.length < 9)
          GestureDetector(
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
                    context.l10n.commonImageCount(_selectedImages.length, 9),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
