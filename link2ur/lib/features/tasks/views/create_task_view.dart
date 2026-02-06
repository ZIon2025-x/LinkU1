import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/utils/validators.dart';

/// 创建任务页
/// 参考iOS CreateTaskView.swift
class CreateTaskView extends StatefulWidget {
  const CreateTaskView({super.key});

  @override
  State<CreateTaskView> createState() => _CreateTaskViewState();
}

class _CreateTaskViewState extends State<CreateTaskView> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _rewardController = TextEditingController();
  final _locationController = TextEditingController();

  String _selectedCategory = 'delivery';
  String _selectedCurrency = 'USD';
  DateTime? _deadline;
  bool _isSubmitting = false;

  final List<Map<String, String>> _categories = [
    {'key': 'delivery', 'label': '代取代送'},
    {'key': 'shopping', 'label': '代购'},
    {'key': 'tutoring', 'label': '辅导'},
    {'key': 'translation', 'label': '翻译'},
    {'key': 'design', 'label': '设计'},
    {'key': 'programming', 'label': '编程'},
    {'key': 'writing', 'label': '写作'},
    {'key': 'other', 'label': '其他'},
  ];

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

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // TODO: 提交任务
      await Future.delayed(const Duration(seconds: 2));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('任务发布成功')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('发布失败: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('发布任务'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.allMd,
          children: [
            // 任务类型
            _buildSectionTitle('任务类型'),
            _buildCategorySelector(),
            AppSpacing.vLg,

            // 任务标题
            _buildSectionTitle('任务标题'),
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: '请输入任务标题',
              ),
              maxLength: 100,
              validator: Validators.validateTitle,
            ),
            AppSpacing.vMd,

            // 任务描述
            _buildSectionTitle('任务描述'),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: '请详细描述任务要求...',
              ),
              maxLines: 5,
              maxLength: 2000,
              validator: (value) => Validators.validateDescription(value),
            ),
            AppSpacing.vMd,

            // 任务报酬
            _buildSectionTitle('任务报酬'),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _rewardController,
                    decoration: const InputDecoration(
                      hintText: '0.00',
                      prefixText: '\$ ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: Validators.validateAmount,
                  ),
                ),
                AppSpacing.hMd,
                DropdownButton<String>(
                  value: _selectedCurrency,
                  items: const [
                    DropdownMenuItem(value: 'USD', child: Text('USD')),
                    DropdownMenuItem(value: 'CNY', child: Text('CNY')),
                    DropdownMenuItem(value: 'EUR', child: Text('EUR')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCurrency = value;
                      });
                    }
                  },
                ),
              ],
            ),
            AppSpacing.vLg,

            // 任务地点
            _buildSectionTitle('任务地点'),
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                hintText: '请输入任务地点',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () {
                    // TODO: 获取当前位置
                  },
                ),
              ),
            ),
            AppSpacing.vLg,

            // 截止时间
            _buildSectionTitle('截止时间'),
            GestureDetector(
              onTap: _selectDeadline,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Theme.of(context).inputDecorationTheme.fillColor,
                  borderRadius: AppRadius.input,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      color: AppColors.textSecondaryLight,
                    ),
                    AppSpacing.hMd,
                    Text(
                      _deadline != null
                          ? '${_deadline!.year}-${_deadline!.month.toString().padLeft(2, '0')}-${_deadline!.day.toString().padLeft(2, '0')}'
                          : '选择截止日期',
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

            // 添加图片
            _buildSectionTitle('添加图片'),
            _buildImagePicker(),
            AppSpacing.vXxl,

            // 提交按钮
            PrimaryButton(
              text: '发布任务',
              onPressed: _submitTask,
              isLoading: _isSubmitting,
            ),
            AppSpacing.vXxl,
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildCategorySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _categories.map((category) {
        final isSelected = _selectedCategory == category['key'];
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedCategory = category['key']!;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : Colors.transparent,
              borderRadius: AppRadius.allSmall,
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.dividerLight,
              ),
            ),
            child: Text(
              category['label']!,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textSecondaryLight,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
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
        // 添加按钮
        GestureDetector(
          onTap: () {
            // TODO: 选择图片
          },
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
                Icon(Icons.add_photo_alternate_outlined, 
                    color: AppColors.textSecondaryLight),
                const SizedBox(height: 4),
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
