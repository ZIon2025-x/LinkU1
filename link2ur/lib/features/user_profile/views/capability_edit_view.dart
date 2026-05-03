import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/user_profile_repository.dart';
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
  List<(int, String)> _categories = _AddSkillDialog._fallbackCategories;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final repo = context.read<UserProfileRepository>();
      final data = await repo.getSkillCategories();
      if (mounted && data.isNotEmpty) {
        setState(() {
          _categories = data.map((c) => (
            c['id'] as int,
            (c['name_zh'] as String?) ?? (c['name_en'] as String?) ?? '',
          )).toList();
        });
      }
    } catch (_) {
      // Keep fallback
    }
  }

  void _showAddSkillDialog() {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddSkillDialog(
        categories: _categories,
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
        title: Text(ctx.l10n.profileDeleteSkill),
        content: Text(ctx.l10n.profileDeleteSkillConfirm(skillName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: Text(ctx.l10n.commonDelete),
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
        title: Text(context.l10n.profileManageSkills),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSkillDialog,
        icon: const Icon(Icons.add),
        label: Text(context.l10n.profileAddSkill),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: BlocConsumer<UserProfileBloc, UserProfileState>(
        listener: (context, state) {
          if (state.status == UserProfileStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.localizeError(state.errorMessage)),
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
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.psychology_outlined,
                    size: 64,
                    color: AppColors.textSecondary,
                  ),
                  AppSpacing.vMd,
                  Text(
                    context.l10n.profileNoSkillsTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  AppSpacing.vSm,
                  Text(
                    context.l10n.profileNoSkillsSubtitle,
                    style: const TextStyle(
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
                    tooltip: context.l10n.commonDelete,
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

  String _label(BuildContext context) {
    switch (proficiency) {
      case 'expert':
        return context.l10n.skillLevelExpert;
      case 'intermediate':
        return context.l10n.skillLevelIntermediate;
      case 'beginner':
      default:
        return context.l10n.skillLevelBeginner;
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
        _label(context),
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
  const _AddSkillDialog({required this.onSave, required this.categories});

  final void Function(Map<String, dynamic> skillData) onSave;
  final List<(int, String)> categories;

  /// Fallback categories when backend fetch fails (English-first; localized on display where needed).
  /// NOTE: Display-side prefers backend `name_zh`/`name_en`; this list is a last-resort fallback only.
  static const _fallbackCategories = [
    (1, 'Academic'),
    (2, 'Technical'),
    (3, 'Design'),
    (4, 'Language'),
    (5, 'Lifestyle'),
    (6, 'Music & Art'),
    (7, 'Sports'),
    (8, 'Other'),
  ];

  @override
  State<_AddSkillDialog> createState() => _AddSkillDialogState();
}

class _AddSkillDialogState extends State<_AddSkillDialog> {
  final _skillNameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late int _selectedCategoryId;
  String _selectedProficiency = 'beginner';

  @override
  void initState() {
    super.initState();
    _selectedCategoryId = widget.categories.isNotEmpty ? widget.categories.first.$1 : 1;
  }

  List<(String, String)> _proficiencies(BuildContext c) => [
        ('beginner', c.l10n.skillLevelBeginner),
        ('intermediate', c.l10n.skillLevelIntermediate),
        ('expert', c.l10n.skillLevelExpert),
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
      title: Text(context.l10n.profileAddSkill),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 分类选择
              Text(
                context.l10n.profileSkillCategory,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              AppSelectField<int>(
                value: _selectedCategoryId,
                hint: context.l10n.profileSkillCategory,
                sheetTitle: context.l10n.profileSkillCategory,
                options: widget.categories
                    .map((cat) => SelectOption(value: cat.$1, label: cat.$2))
                    .toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategoryId = val);
                },
              ),
              AppSpacing.vMd,

              // 技能名称
              Text(
                context.l10n.profileSkillName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              TextFormField(
                controller: _skillNameController,
                decoration: InputDecoration(
                  hintText: context.l10n.profileSkillNameHint,
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
                    return context.l10n.profileSkillNameRequired;
                  }
                  if (val.trim().length > 30) {
                    return context.l10n.profileSkillNameTooLong;
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
              ),
              AppSpacing.vMd,

              // 熟练度选择
              Text(
                context.l10n.profileSkillProficiency,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: _proficiencies(context).map((p) {
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
          child: Text(context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: Text(context.l10n.commonAdd),
        ),
      ],
    );
  }
}
