import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_feedback.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../bloc/create_task_bloc.dart';

/// 创建任务页
/// 参考iOS CreateTaskView.swift
class CreateTaskView extends StatelessWidget {
  const CreateTaskView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CreateTaskBloc(
        taskRepository: context.read<TaskRepository>(),
      ),
      child: const _CreateTaskContent(),
    );
  }
}

class _CreateTaskContent extends StatefulWidget {
  const _CreateTaskContent();

  @override
  State<_CreateTaskContent> createState() => _CreateTaskContentState();
}

class _CreateTaskContentState extends State<_CreateTaskContent> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = 'delivery';
  String _selectedCurrency = 'GBP';
  DateTime? _deadline;

  List<Map<String, String>> _getCategories(BuildContext context) {
    return [
      {'key': 'delivery', 'label': context.l10n.createTaskCategoryDelivery},
      {'key': 'shopping', 'label': context.l10n.createTaskCategoryShopping},
      {'key': 'tutoring', 'label': context.l10n.createTaskCategoryTutoring},
      {'key': 'translation', 'label': context.l10n.createTaskCategoryTranslation},
      {'key': 'design', 'label': context.l10n.createTaskCategoryDesign},
      {'key': 'programming', 'label': context.l10n.createTaskCategoryProgramming},
      {'key': 'writing', 'label': context.l10n.createTaskCategoryWriting},
      {'key': 'other', 'label': context.l10n.createTaskCategoryOther},
    ];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _rewardController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null) {
      setState(() {
        _deadline = date;
      });
    }
  }

  void _submitTask() {
    if (!_formKey.currentState!.validate()) return;

    final reward = double.tryParse(_rewardController.text) ?? 0;

    final request = CreateTaskRequest(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim().isNotEmpty
          ? _descriptionController.text.trim()
          : null,
      taskType: _selectedCategory,
      reward: reward,
      currency: _selectedCurrency,
      location: _locationController.text.trim().isNotEmpty
          ? _locationController.text.trim()
          : null,
      deadline: _deadline,
    );

    context.read<CreateTaskBloc>().add(CreateTaskSubmitted(request));
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
                  validator: Validators.validateTitle,
                ),
                AppSpacing.vMd,

                _buildSectionTitle(context.l10n.taskDetailTaskDescription),
                TextFormField(
                  controller: _descriptionController,
                  decoration:
                      InputDecoration(hintText: context.l10n.createTaskDescHint),
                  maxLines: 5,
                  maxLength: 2000,
                  validator: (value) => Validators.validateDescription(value),
                ),
                AppSpacing.vMd,

                _buildSectionTitle(context.l10n.createTaskReward),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rewardController,
                        decoration: const InputDecoration(
                          hintText: '0.00',
                          prefixText: '£ ',
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: Validators.validateAmount,
                      ),
                    ),
                    AppSpacing.hMd,
                    DropdownButton<String>(
                      value: _selectedCurrency,
                      items: const [
                        DropdownMenuItem(value: 'GBP', child: Text('GBP')),
                        DropdownMenuItem(value: 'USD', child: Text('USD')),
                        DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCurrency = value);
                        }
                      },
                    ),
                  ],
                ),
                AppSpacing.vLg,

                _buildSectionTitle(context.l10n.createTaskLocation),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: context.l10n.createTaskLocationHint,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.my_location),
                      onPressed: () {},
                    ),
                  ),
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
                              ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
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
                AppSpacing.vXxl,

                PrimaryButton(
                  text: context.l10n.createTaskTitle,
                  onPressed: state.isSubmitting ? null : _submitTask,
                  isLoading: state.isSubmitting,
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
        GestureDetector(
          onTap: () {},
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.dividerLight),
              borderRadius: AppRadius.allMedium,
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined,
                    color: AppColors.textSecondaryLight),
                SizedBox(height: 4),
                Text(
                  '0/9',
                  style: TextStyle(
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
