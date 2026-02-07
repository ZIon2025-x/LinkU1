import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/user_repository.dart';

/// 任务偏好设置页
/// 参考iOS TaskPreferencesView.swift
class TaskPreferencesView extends StatefulWidget {
  const TaskPreferencesView({super.key});

  @override
  State<TaskPreferencesView> createState() => _TaskPreferencesViewState();
}

class _TaskPreferencesViewState extends State<TaskPreferencesView> {
  bool _isLoading = true;
  bool _isSaving = false;

  final Set<String> _selectedTaskTypes = {};
  final Set<String> _selectedLocations = {};
  final Set<String> _selectedLevels = {};
  int _minDeadlineDays = 1;

  static const _taskTypes = [
    ('Housekeeping', 'housekeeping'),
    ('Campus Life', 'campusLife'),
    ('Second-hand & Rental', 'secondhandRental'),
    ('Errand Running', 'errandRunning'),
    ('Skill Service', 'skillService'),
    ('Social Help', 'socialHelp'),
    ('Transportation', 'transportation'),
    ('Pet Care', 'petCare'),
    ('Life Convenience', 'lifeConvenience'),
    ('Other', 'other'),
  ];

  static const _locations = [
    'Online', 'London', 'Edinburgh', 'Manchester', 'Birmingham',
    'Glasgow', 'Bristol', 'Sheffield', 'Leeds', 'Nottingham',
    'Newcastle', 'Southampton', 'Liverpool', 'Cardiff', 'Coventry',
    'Exeter', 'Leicester', 'York', 'Aberdeen', 'Bath', 'Dundee',
    'Reading', 'St Andrews', 'Belfast', 'Brighton', 'Durham',
    'Norwich', 'Swansea', 'Loughborough', 'Lancaster', 'Warwick',
    'Cambridge', 'Oxford', 'Other',
  ];

  static const _taskLevels = ['Normal', 'VIP', 'Super'];

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final repo = context.read<UserRepository>();
      final prefs = await repo.getUserPreferences();
      if (mounted) {
        setState(() {
          _selectedTaskTypes.addAll(prefs['task_types'] as List<String>? ?? []);
          _selectedLocations.addAll(prefs['locations'] as List<String>? ?? []);
          _selectedLevels.addAll(prefs['task_levels'] as List<String>? ?? []);
          _minDeadlineDays = prefs['min_deadline_days'] as int? ?? 1;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    setState(() => _isSaving = true);

    try {
      final repo = context.read<UserRepository>();
      await repo.updateUserPreferences({
        'task_types': _selectedTaskTypes.toList(),
        'locations': _selectedLocations.toList(),
        'task_levels': _selectedLevels.toList(),
        'min_deadline_days': _minDeadlineDays,
      });
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    }
  }

  void _toggleItem(Set<String> set, String item) {
    setState(() {
      if (set.contains(item)) {
        set.remove(item);
      } else {
        set.add(item);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.taskPreferencesTitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonDone),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // 偏好任务类型
                  _PreferenceSection(
                    title: l10n.taskPreferencesTypes,
                    description: l10n.taskPreferencesTypesDesc,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _taskTypes.map((type) {
                        final isSelected =
                            _selectedTaskTypes.contains(type.$1);
                        return _ToggleChip(
                          label: type.$1,
                          isSelected: isSelected,
                          onTap: () =>
                              _toggleItem(_selectedTaskTypes, type.$1),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 偏好地点
                  _PreferenceSection(
                    title: l10n.taskPreferencesLocations,
                    description: l10n.taskPreferencesLocationsDesc,
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: _locations.map((loc) {
                        final isSelected =
                            _selectedLocations.contains(loc);
                        return _ToggleChip(
                          label: loc,
                          isSelected: isSelected,
                          onTap: () =>
                              _toggleItem(_selectedLocations, loc),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 偏好等级
                  _PreferenceSection(
                    title: l10n.taskPreferencesLevels,
                    description: l10n.taskPreferencesLevelsDesc,
                    child: Row(
                      children: _taskLevels.map((level) {
                        final isSelected =
                            _selectedLevels.contains(level);
                        return Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4),
                            child: _ToggleChip(
                              label: level,
                              isSelected: isSelected,
                              onTap: () =>
                                  _toggleItem(_selectedLevels, level),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 最短截止时间
                  _PreferenceSection(
                    title: l10n.taskPreferencesMinDeadline,
                    description: l10n.taskPreferencesMinDeadlineDesc,
                    child: Row(
                      children: [
                        Text(
                          '$_minDeadlineDays ${l10n.taskPreferencesDays}',
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: _minDeadlineDays > 1
                              ? () => setState(
                                  () => _minDeadlineDays--)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        IconButton(
                          onPressed: _minDeadlineDays < 30
                              ? () => setState(
                                  () => _minDeadlineDays++)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // 保存按钮
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _savePreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppRadius.large),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : Text(l10n.taskPreferencesSave,
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
    );
  }
}

class _PreferenceSection extends StatelessWidget {
  const _PreferenceSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(description,
              style: TextStyle(
                  fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.separator,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isSelected
                ? AppColors.primary
                : AppColors.textPrimary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
