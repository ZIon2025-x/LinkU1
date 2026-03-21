import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/user_profile.dart';
import '../bloc/user_profile_bloc.dart';

class PreferenceEditView extends StatelessWidget {
  const PreferenceEditView({
    super.key,
    this.currentPreference,
  });

  final UserProfilePreference? currentPreference;

  @override
  Widget build(BuildContext context) {
    return _PreferenceEditContent(
      currentPreference: currentPreference ?? const UserProfilePreference(),
    );
  }
}

class _PreferenceEditContent extends StatefulWidget {
  const _PreferenceEditContent({required this.currentPreference});

  final UserProfilePreference currentPreference;

  @override
  State<_PreferenceEditContent> createState() => _PreferenceEditContentState();
}

class _PreferenceEditContentState extends State<_PreferenceEditContent> {
  late String _mode;
  late String _durationType;
  late String _rewardPreference;
  late Set<String> _preferredTimeSlots;
  late bool _nearbyPushEnabled;

  static const _modes = [
    ('online', '线上'),
    ('offline', '线下'),
    ('both', '都可以'),
  ];

  static const _durationTypes = [
    ('one_time', '一次性'),
    ('long_term', '长期'),
    ('both', '都可以'),
  ];

  static const _rewardPreferences = [
    ('high_freq_low_amount', '高频小额'),
    ('low_freq_high_amount', '低频高价'),
    ('no_preference', '无偏好'),
  ];

  static const _timeSlots = [
    ('weekday_daytime', '工作日白天'),
    ('weekday_evening', '工作日晚上'),
    ('weekend', '周末'),
    ('anytime', '全天'),
  ];

  @override
  void initState() {
    super.initState();
    _mode = widget.currentPreference.mode;
    _durationType = widget.currentPreference.durationType;
    _rewardPreference = widget.currentPreference.rewardPreference;
    _preferredTimeSlots =
        Set.from(widget.currentPreference.preferredTimeSlots);
    _nearbyPushEnabled = widget.currentPreference.nearbyPushEnabled;
  }

  void _toggleTimeSlot(String slot) {
    setState(() {
      if (_preferredTimeSlots.contains(slot)) {
        _preferredTimeSlots.remove(slot);
      } else {
        _preferredTimeSlots.add(slot);
      }
    });
  }

  void _save() {
    context.read<UserProfileBloc>().add(
          UserProfileUpdatePreferences(
            preferences: {
              'mode': _mode,
              'duration_type': _durationType,
              'reward_preference': _rewardPreference,
              'preferred_time_slots': _preferredTimeSlots.toList(),
              'preferred_categories':
                  widget.currentPreference.preferredCategories,
              'preferred_helper_types':
                  widget.currentPreference.preferredHelperTypes,
              'nearby_push_enabled': _nearbyPushEnabled,
            },
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('偏好设置'),
      ),
      body: BlocConsumer<UserProfileBloc, UserProfileState>(
        listener: (context, state) {
          if (state.status == UserProfileStatus.loaded) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('偏好已保存')),
            );
            Navigator.of(context).pop();
          } else if (state.status == UserProfileStatus.error) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.localizeError(state.errorMessage)),
                backgroundColor: AppColors.error,
              ),
            );
          }
        },
        builder: (context, state) {
          final isSaving = state.status == UserProfileStatus.loading;

          return SingleChildScrollView(
            padding: AppSpacing.allMd,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 协作方式
                _PreferenceSection(
                  title: '协作方式',
                  description: '你更倾向于线上还是线下完成任务？',
                  child: _SingleChoiceChips(
                    options: _modes,
                    selected: _mode,
                    onChanged: (val) => setState(() => _mode = val),
                  ),
                ),
                AppSpacing.vMd,

                // 任务周期
                _PreferenceSection(
                  title: '任务周期',
                  description: '你偏好一次性还是长期合作任务？',
                  child: _SingleChoiceChips(
                    options: _durationTypes,
                    selected: _durationType,
                    onChanged: (val) => setState(() => _durationType = val),
                  ),
                ),
                AppSpacing.vMd,

                // 报酬偏好
                _PreferenceSection(
                  title: '报酬偏好',
                  description: '你更倾向于哪种报酬模式？',
                  child: _SingleChoiceChips(
                    options: _rewardPreferences,
                    selected: _rewardPreference,
                    onChanged: (val) =>
                        setState(() => _rewardPreference = val),
                  ),
                ),
                AppSpacing.vMd,

                // 可用时段（多选）
                _PreferenceSection(
                  title: '可用时段',
                  description: '你通常什么时候有空？（可多选）',
                  child: Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: _timeSlots.map((slot) {
                      final isSelected =
                          _preferredTimeSlots.contains(slot.$1);
                      return _ToggleChip(
                        label: slot.$2,
                        isSelected: isSelected,
                        onTap: () => _toggleTimeSlot(slot.$1),
                      );
                    }).toList(),
                  ),
                ),
                AppSpacing.vMd,

                // 附近任务提醒
                _PreferenceSection(
                  title: context.l10n.nearbyPushEnabled,
                  description: context.l10n.nearbyPushDescription,
                  child: Switch.adaptive(
                    value: _nearbyPushEnabled,
                    activeThumbColor: AppColors.primary,
                    onChanged: (val) async {
                      if (val) {
                        final messenger = ScaffoldMessenger.of(context);
                        final permission = await Geolocator.checkPermission();
                        if (permission == LocationPermission.denied) {
                          final result = await Geolocator.requestPermission();
                          if (result == LocationPermission.denied ||
                              result == LocationPermission.deniedForever) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              const SnackBar(content: Text('需要定位权限才能开启附近任务提醒')),
                            );
                            return;
                          }
                        } else if (permission == LocationPermission.deniedForever) {
                          if (!mounted) return;
                          messenger.showSnackBar(
                            const SnackBar(content: Text('请在系统设置中开启定位权限')),
                          );
                          return;
                        }
                      }
                      setState(() => _nearbyPushEnabled = val);
                    },
                  ),
                ),
                AppSpacing.vXl,

                // 保存按钮
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.large),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '保存设置',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),
                AppSpacing.vLg,
              ],
            ),
          );
        },
      ),
    );
  }
}

// ======================== 通用组件 ========================

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
      padding: AppSpacing.allMd,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _SingleChoiceChips extends StatelessWidget {
  const _SingleChoiceChips({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<(String, String)> options;
  final String selected;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: options.map((opt) {
        final isSelected = selected == opt.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: _ToggleChip(
              label: opt.$2,
              isSelected: isSelected,
              onTap: () => onChanged(opt.$1),
            ),
          ),
        );
      }).toList(),
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: Border.all(
            color:
                isSelected ? AppColors.primary : AppColors.separator,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: isSelected ? AppColors.primary : AppColors.textPrimary,
            fontWeight:
                isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
