import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../bloc/user_profile_bloc.dart';

class CapabilityEditView extends StatelessWidget {
  const CapabilityEditView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _CapabilityEditContent();
  }
}

class _CapabilityEditContent extends StatefulWidget {
  const _CapabilityEditContent();

  @override
  State<_CapabilityEditContent> createState() => _CapabilityEditContentState();
}

class _CapabilityEditContentState extends State<_CapabilityEditContent> {
  void _showAddSkillDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddSkillDialog(
        onSave: (skillData) {
          context.read<UserProfileBloc>().add(
                UserProfileUpdateCapabilities(capabilities: [skillData]),
              );
        },
      ),
    );
  }

  void _confirmDelete(int id, String skillName) {
    showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除技能'),
        content: Text('确认删除「$skillName」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('删除'),
          ),
        ],
      ),
    ).then((confirmed) {
      if (confirmed == true && mounted) {
        context
            .read<UserProfileBloc>()
            .add(UserProfileDeleteCapability(capabilityId: id));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('管理技能'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSkillDialog,
        icon: const Icon(Icons.add),
        label: const Text('添加技能'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<UserProfileBloc, UserProfileState>(
        listener: (context, state) {
          if (state.status == UserProfileStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.errorMessage ?? '操作失败，请重试'),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state.status == UserProfileStatus.loading ||
              state.status == UserProfileStatus.initial) {
            return const Center(child: CircularProgressIndicator());
          }

          final capabilities = state.summary?.capabilities ?? [];

          if (capabilities.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  AppSpacing.vMd,
                  Text(
                    '还没有技能',
                    style: TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppSpacing.vSm,
                  Text(
                    '点击右下角按钮添加你的第一个技能',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: AppSpacing.allMd,
            itemCount: capabilities.length,
            separatorBuilder: (_, __) => AppSpacing.vSm,
            itemBuilder: (context, index) {
              final cap = capabilities[index];
              return Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.psychology_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    cap.skillName,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cap.categoryNameZh != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          cap.categoryNameZh!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 4),
                      _ProficiencyBadge(proficiency: cap.proficiency),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    color: AppColors.error,
                    tooltip: '删除',
                    onPressed: () => _confirmDelete(cap.id, cap.skillName),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProficiencyBadge extends StatelessWidget {
  const _ProficiencyBadge({required this.proficiency});

  final String proficiency;

  Color get _color {
    switch (proficiency) {
      case 'expert':
        return AppColors.success;
      case 'intermediate':
        return AppColors.primary;
      case 'beginner':
      default:
        return AppColors.textSecondary;
    }
  }

  String get _label {
    switch (proficiency) {
      case 'expert':
        return '精通';
      case 'intermediate':
        return '熟练';
      case 'beginner':
      default:
        return '入门';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: _color.withValues(alpha: 0.3)),
      ),
      child: Text(
        _label,
        style: TextStyle(
          fontSize: 11,
          color: _color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ======================== 添加技能对话框 ========================

class _AddSkillDialog extends StatefulWidget {
  const _AddSkillDialog({required this.onSave});

  final void Function(Map<String, dynamic> skillData) onSave;

  @override
  State<_AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<_AddSkillDialog> {
  final _skillNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  int _selectedCategoryId = 1;
  String _selectedProficiency = 'beginner';

  // 常见技能分类（category_id 与后端对应，这里使用示例分类）
  static const _categories = [
    (1, '学业辅导'),
    (2, '技术开发'),
    (3, '设计创意'),
    (4, '语言翻译'),
    (5, '生活服务'),
    (6, '音乐艺术'),
    (7, '运动健身'),
    (8, '其他'),
  ];

  static const _proficiencies = [
    ('beginner', '入门'),
    ('intermediate', '熟练'),
    ('expert', '精通'),
  ];

  @override
  void dispose() {
    _skillNameController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop();
    widget.onSave({
      'category_id': _selectedCategoryId,
      'skill_name': _skillNameController.text.trim(),
      'proficiency': _selectedProficiency,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加技能'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类选择
              const Text(
                '技能分类',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<int>(
                initialValue: _selectedCategoryId,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.allMedium,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                items: _categories
                    .map(
                      (cat) => DropdownMenuItem<int>(
                        value: cat.$1,
                        child: Text(cat.$2),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategoryId = val);
                },
              ),
              AppSpacing.vMd,

              // 技能名称
              const Text(
                '技能名称',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _skillNameController,
                decoration: InputDecoration(
                  hintText: '例如：Python、平面设计、英语口语',
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.allMedium,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return '请输入技能名称';
                  }
                  if (val.trim().length > 30) {
                    return '技能名称不超过30字';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              AppSpacing.vMd,

              // 熟练度选择
              const Text(
                '熟练度',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: _proficiencies.map((p) {
                  final isSelected = _selectedProficiency == p.$1;
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedProficiency = p.$1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withValues(alpha: 0.1)
                                : Colors.transparent,
                            borderRadius: AppRadius.allMedium,
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.separator,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Text(
                            p.$2,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textPrimary,
                              fontWeight: isSelected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('添加'),
        ),
      ],
    );
  }
}
