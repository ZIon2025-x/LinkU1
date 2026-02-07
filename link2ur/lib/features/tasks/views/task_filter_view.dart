import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/l10n_extension.dart';

/// 任务筛选页
/// 参考iOS TaskFilterView.swift
class TaskFilterView extends StatefulWidget {
  const TaskFilterView({
    super.key,
    this.selectedCategory,
    this.selectedCity,
  });

  final String? selectedCategory;
  final String? selectedCity;

  @override
  State<TaskFilterView> createState() => _TaskFilterViewState();
}

class _TaskFilterViewState extends State<TaskFilterView> {
  String? _selectedCategory;
  String? _selectedCity;

  static const _categories = [
    ('', 'All'),
    ('Housekeeping', 'Housekeeping'),
    ('Campus Life', 'Campus Life'),
    ('Second-hand & Rental', 'Second-hand & Rental'),
    ('Errand Running', 'Errand Running'),
    ('Skill Service', 'Skill Service'),
    ('Social Help', 'Social Help'),
    ('Transportation', 'Transportation'),
    ('Pet Care', 'Pet Care'),
    ('Life Convenience', 'Life Convenience'),
    ('Other', 'Other'),
  ];

  static const _cities = [
    'All', 'Online', 'London', 'Edinburgh', 'Manchester',
    'Birmingham', 'Glasgow', 'Bristol', 'Sheffield', 'Leeds',
    'Nottingham', 'Newcastle', 'Southampton', 'Liverpool',
    'Cardiff', 'Coventry', 'Exeter', 'Leicester', 'York',
    'Aberdeen', 'Bath', 'Dundee', 'Reading', 'St Andrews',
    'Belfast', 'Brighton', 'Durham', 'Norwich', 'Swansea',
    'Loughborough', 'Lancaster', 'Warwick', 'Cambridge',
    'Oxford', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.selectedCategory;
    _selectedCity = widget.selectedCity;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.commonFilter),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop({
                'category': _selectedCategory,
                'city': _selectedCity,
              });
            },
            child: Text(l10n.commonDone),
          ),
        ],
      ),
      body: ListView(
        children: [
          // 分类
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              l10n.taskFilterCategory,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ..._categories.map((cat) {
            final value = cat.$1.isEmpty ? null : cat.$1;
            final isSelected = _selectedCategory == value;
            return ListTile(
              title: Text(cat.$2),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => setState(() => _selectedCategory = value),
            );
          }),

          const Divider(),

          // 城市
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(
              l10n.taskFilterCity,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
          ..._cities.map((city) {
            final value = city == 'All' ? null : city;
            final isSelected = _selectedCity == value;
            return ListTile(
              title: Text(city),
              trailing: isSelected
                  ? const Icon(Icons.check, color: AppColors.primary)
                  : null,
              onTap: () => setState(() => _selectedCity = value),
            );
          }),
        ],
      ),
    );
  }
}
