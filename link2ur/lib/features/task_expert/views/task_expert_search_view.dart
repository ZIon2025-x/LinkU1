import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/expert_constants.dart';
import '../../../core/constants/uk_cities.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/app_select_sheet.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/question_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../bloc/task_expert_bloc.dart';

/// 任务达人搜索页
/// 参考iOS TaskExpertSearchView.swift
class TaskExpertSearchView extends StatelessWidget {
  const TaskExpertSearchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
        questionRepository: context.read<QuestionRepository>(),
      ),
      child: const _TaskExpertSearchContent(),
    );
  }
}

class _TaskExpertSearchContent extends StatefulWidget {
  const _TaskExpertSearchContent();

  @override
  State<_TaskExpertSearchContent> createState() =>
      _TaskExpertSearchContentState();
}

class _TaskExpertSearchContentState
    extends State<_TaskExpertSearchContent> {
  final TextEditingController _searchController = TextEditingController();
  bool _hasSearched = false;
  String _selectedCategory = 'all';
  String _selectedCity = 'all';
  String _selectedSort = 'rating_desc';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty &&
        _selectedCategory == 'all' &&
        _selectedCity == 'all') {
      return;
    }
    setState(() => _hasSearched = true);

    final bloc = context.read<TaskExpertBloc>();
    bloc.add(TaskExpertFilterChanged(
      category: _selectedCategory,
      city: _selectedCity,
      sort: _selectedSort,
    ));
    bloc.add(TaskExpertLoadRequested(
      skill: keyword.isEmpty ? null : keyword,
    ));
  }

  String _categoryLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'all':
        return l10n.expertCategoryAll;
      case 'programming':
        return l10n.expertCategoryProgramming;
      case 'translation':
        return l10n.expertCategoryTranslation;
      case 'tutoring':
        return l10n.expertCategoryTutoring;
      case 'food':
        return l10n.expertCategoryFood;
      case 'beverage':
        return l10n.expertCategoryBeverage;
      case 'cake':
        return l10n.expertCategoryCake;
      case 'errand_transport':
        return l10n.expertCategoryErrandTransport;
      case 'social_entertainment':
        return l10n.expertCategorySocialEntertainment;
      case 'beauty_skincare':
        return l10n.expertCategoryBeautySkincare;
      case 'handicraft':
        return l10n.expertCategoryHandicraft;
      case 'gaming':
        return l10n.expertCategoryGaming;
      case 'photography':
        return l10n.expertCategoryPhotography;
      case 'housekeeping':
        return l10n.expertCategoryHousekeeping;
      default:
        return key;
    }
  }

  String _cityLabel(BuildContext context, String key) {
    if (key == 'all') return context.l10n.commonAll;
    final locale = Localizations.localeOf(context);
    if (locale.languageCode == 'zh') {
      return UKCities.zhName[key] ?? key;
    }
    return key;
  }

  String _sortLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'rating_desc':
        return l10n.expertSearchSortRating;
      case 'completed_desc':
        return l10n.expertSearchSortCompleted;
      case 'newest':
        return l10n.expertSearchSortNewest;
      default:
        return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.taskExpertSearchHint,
            border: InputBorder.none,
          ),
          onSubmitted: (_) => _search(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: _search,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterRow(context, isDark),
          Expanded(
            child: BlocBuilder<TaskExpertBloc, TaskExpertState>(
              buildWhen: (prev, curr) =>
                  prev.isLoading != curr.isLoading ||
                  prev.experts != curr.experts,
              builder: (context, state) {
                final results = state.experts;

                if (state.isLoading) {
                  return const SkeletonList();
                }

                if (!_hasSearched) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search,
                            size: 64, color: AppColors.textTertiary),
                        const SizedBox(height: AppSpacing.md),
                        Text(l10n.taskExpertSearchPrompt,
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  );
                }

                if (results.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.search_off,
                    title: l10n.commonNoResults,
                    message: l10n.taskExpertNoResults,
                  );
                }

                return ListView.separated(
                  clipBehavior: Clip.none,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: results.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.md),
                  itemBuilder: (context, index) {
                    final expert = results[index];
                    return _ExpertCard(
                      expert: expert,
                      onTap: () =>
                          context.safePush('/task-experts/${expert.id}'),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, bool isDark) {
    final dropdownBg =
        isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight;
    final borderColor = (isDark ? AppColors.separatorDark : AppColors.separatorLight)
        .withValues(alpha: 0.5);
    final hintColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildFilterChip(
              label: _categoryLabel(context, _selectedCategory),
              isDefault: _selectedCategory == 'all',
              isDark: isDark,
              dropdownBg: dropdownBg,
              borderColor: borderColor,
              hintColor: hintColor,
              onTap: () => _showCategoryPicker(context),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildFilterChip(
              label: _cityLabel(context, _selectedCity),
              isDefault: _selectedCity == 'all',
              isDark: isDark,
              dropdownBg: dropdownBg,
              borderColor: borderColor,
              hintColor: hintColor,
              onTap: () => _showCityPicker(context),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: _buildFilterChip(
              label: _sortLabel(context, _selectedSort),
              isDefault: _selectedSort == 'rating_desc',
              isDark: isDark,
              dropdownBg: dropdownBg,
              borderColor: borderColor,
              hintColor: hintColor,
              onTap: () => _showSortPicker(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isDefault,
    required bool isDark,
    required Color dropdownBg,
    required Color borderColor,
    required Color hintColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDefault ? dropdownBg : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: AppRadius.allMedium,
          border: Border.all(
            color: isDefault ? borderColor : AppColors.primary.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.body.copyWith(
                  color: isDefault ? hintColor : AppColors.primary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: isDefault ? hintColor : AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCategoryPicker(BuildContext context) async {
    final options = ExpertConstants.categoryKeys
        .map((key) => SelectOption(value: key, label: _categoryLabel(context, key)))
        .toList();
    final result = await showAppSelectSheet<String>(
      context: context,
      options: options,
      value: _selectedCategory,
      title: context.l10n.taskExpertCategory,
    );
    if (result != null && result.value != _selectedCategory) {
      setState(() => _selectedCategory = result.value);
      if (_hasSearched) _search();
    }
  }

  Future<void> _showCityPicker(BuildContext context) async {
    final options = [
      SelectOption(value: 'all', label: context.l10n.commonAll),
      ...UKCities.all.map((city) =>
          SelectOption(value: city, label: _cityLabel(context, city))),
    ];
    final result = await showAppSelectSheet<String>(
      context: context,
      options: options,
      value: _selectedCity,
      title: context.l10n.taskFilterCity,
    );
    if (result != null && result.value != _selectedCity) {
      setState(() => _selectedCity = result.value);
      if (_hasSearched) _search();
    }
  }

  Future<void> _showSortPicker(BuildContext context) async {
    const sortKeys = ['rating_desc', 'completed_desc', 'newest'];
    final options = sortKeys
        .map((key) => SelectOption(value: key, label: _sortLabel(context, key)))
        .toList();
    final result = await showAppSelectSheet<String>(
      context: context,
      options: options,
      value: _selectedSort,
      title: context.l10n.expertSearchSortLabel,
    );
    if (result != null && result.value != _selectedSort) {
      setState(() => _selectedSort = result.value);
      if (_hasSearched) _search();
    }
  }
}

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.expert, this.onTap});

  final TaskExpert expert;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);

    return Semantics(
      button: true,
      label: 'View details',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          AppHaptics.selection();
          onTap?.call();
        },
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
            border: Border.all(
              color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Center(
                child: AvatarView(
                  imageUrl: expert.avatar,
                  name: expert.displayNameWith(context.l10n),
                  size: 54,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expert.displayNameWith(context.l10n),
                          style: AppTypography.bodyBold.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (expert.displaySpecialties(locale).isNotEmpty)
                    Text(
                      expert.displaySpecialties(locale).join(' · '),
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            if (expert.avgRating != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.allPill,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 12, color: AppColors.warning),
                    const SizedBox(width: 3),
                    Text(
                      expert.avgRating!.toStringAsFixed(1),
                      style: AppTypography.caption2.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}
