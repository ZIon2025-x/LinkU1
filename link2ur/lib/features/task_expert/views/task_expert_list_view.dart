import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/constants/uk_cities.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/models/task_expert.dart';
import '../bloc/task_expert_bloc.dart';

/// 达人类型列表（与后端 models.py FeaturedTaskExpert.category 对齐）
const List<Map<String, String>> _expertCategories = [
  {'key': 'all'},
  {'key': 'programming'},
  {'key': 'translation'},
  {'key': 'tutoring'},
  {'key': 'food'},
  {'key': 'beverage'},
  {'key': 'cake'},
  {'key': 'errand_transport'},
  {'key': 'social_entertainment'},
  {'key': 'beauty_skincare'},
  {'key': 'handicraft'},
];

/// 任务达人列表页
/// 参考iOS TaskExpertListView.swift
class TaskExpertListView extends StatelessWidget {
  const TaskExpertListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )..add(const TaskExpertLoadRequested()),
      child: const _TaskExpertListViewContent(),
    );
  }
}

class _TaskExpertListViewContent extends StatefulWidget {
  const _TaskExpertListViewContent();

  @override
  State<_TaskExpertListViewContent> createState() =>
      _TaskExpertListViewContentState();
}

class _TaskExpertListViewContentState extends State<_TaskExpertListViewContent> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;
  bool _isSearching = false;

  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      context.read<TaskExpertBloc>().add(
            TaskExpertLoadRequested(skill: query.isEmpty ? null : query),
          );
    });
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _debounceTimer?.cancel();
        context.read<TaskExpertBloc>().add(const TaskExpertLoadRequested());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.l10n.taskExpertSearchPrompt,
                  border: InputBorder.none,
                ),
                onChanged: _onSearchChanged,
              )
            : Text(context.l10n.expertsExperts),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: _toggleSearch,
          ),
          // 筛选按钮（有激活筛选时显示小圆点）
          BlocBuilder<TaskExpertBloc, TaskExpertState>(
            buildWhen: (prev, curr) =>
                prev.hasActiveFilters != curr.hasActiveFilters,
            builder: (context, state) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.tune, size: 22),
                    onPressed: () => _showFilterPanel(context),
                  ),
                  if (state.hasActiveFilters)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<TaskExpertBloc, TaskExpertState>(
        buildWhen: (previous, current) =>
            previous.status != current.status ||
            previous.experts != current.experts ||
            previous.hasMore != current.hasMore,
        builder: (context, state) {
            // Loading state
            if (state.status == TaskExpertStatus.loading &&
                state.experts.isEmpty) {
              return const LoadingView();
            }

            // Error state
            if (state.status == TaskExpertStatus.error &&
                state.experts.isEmpty) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? context.l10n.tasksLoadFailed,
                onRetry: () {
                  context.read<TaskExpertBloc>().add(
                        const TaskExpertLoadRequested(),
                      );
                },
              );
            }

            // Empty state
            if (state.experts.isEmpty) {
              return EmptyStateView.noData(
                context,
                title: context.l10n.taskExpertNoExperts,
                description: context.l10n.taskExpertNoExpertsMessage,
              );
            }

            // List with pull-to-refresh and infinite scroll
            return RefreshIndicator(
              onRefresh: () async {
                final bloc = context.read<TaskExpertBloc>();
                bloc.add(const TaskExpertRefreshRequested());
                await bloc.stream.firstWhere(
                  (s) => !s.isLoading,
                  orElse: () => state,
                );
              },
              child: ListView.separated(
                padding: AppSpacing.allMd,
                itemCount: state.experts.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => AppSpacing.vMd,
                itemBuilder: (context, index) {
                  // Load more trigger
                  if (index == state.experts.length) {
                    context.read<TaskExpertBloc>().add(
                          const TaskExpertLoadMore(),
                        );
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: LoadingIndicator(),
                      ),
                    );
                  }

                  final expert = state.experts[index];
                  return _ExpertCard(key: ValueKey(expert.id), expert: expert);
                },
              ),
            );
          },
        ),
    );
  }

  /// 达人类型的本地化名称
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
      default:
        return key;
    }
  }

  void _showFilterPanel(BuildContext context) {
    final bloc = context.read<TaskExpertBloc>();
    final currentState = bloc.state;
    String tempCategory = currentState.selectedCategory;
    String tempCity = currentState.selectedCity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final l10n = ctx.l10n;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部拖拽条
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 标题行：筛选 + 重置
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.commonFilter,
                          style: AppTypography.title2.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempCategory = 'all';
                              tempCity = 'all';
                            });
                          },
                          child: Text(
                            l10n.commonReset,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 达人类型 ──
                    Text(
                      l10n.taskExpertCategory,
                      style: AppTypography.bodyBold,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _expertCategories.map((cat) {
                        final key = cat['key']!;
                        return _FilterChip(
                          label: _categoryLabel(ctx, key),
                          isSelected: tempCategory == key,
                          isDark: isDark,
                          onTap: () => setModalState(() => tempCategory = key),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // ── 城市筛选 ──
                    Text(
                      l10n.taskFilterCity,
                      style: AppTypography.bodyBold,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _FilterChip(
                              label: l10n.commonAll,
                              isSelected: tempCity == 'all',
                              isDark: isDark,
                              onTap: () => setModalState(() => tempCity = 'all'),
                            ),
                            ...UKCities.all.map((city) {
                              final zhName = UKCities.zhName[city];
                              final locale = Localizations.localeOf(ctx);
                              final displayName = locale.languageCode == 'zh'
                                  ? (zhName ?? city)
                                  : city;
                              return _FilterChip(
                                label: displayName,
                                isSelected: tempCity == city,
                                isDark: isDark,
                                onTap: () =>
                                    setModalState(() => tempCity = city),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── 确认按钮 ──
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          // 只在有变化时发送事件
                          if (tempCategory != currentState.selectedCategory ||
                              tempCity != currentState.selectedCity) {
                            bloc.add(TaskExpertFilterChanged(
                              category: tempCategory,
                              city: tempCity,
                            ));
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.commonConfirm,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// 筛选 Chip 组件
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: AppColors.gradientPrimary)
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? AppColors.surface2(Brightness.dark)
                  : AppColors.surface1(Brightness.light)),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: (isDark
                          ? AppColors.separatorDark
                          : AppColors.separatorLight)
                      .withValues(alpha: 0.3),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({super.key, required this.expert});

  final TaskExpert expert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        final expertId = int.tryParse(expert.id) ?? 0;
        if (expertId > 0) {
          context.safePush('/task-experts/$expertId');
        }
      },
      child: Container(
        padding: AppSpacing.allMd,
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
            // 头像 + 光晕 (对标iOS: 74背景圆 + 68头像 + shadow)
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AvatarView(
                  imageUrl: expert.avatar,
                  name: expert.displayName,
                  size: 68,
                ),
              ),
            ),
            AppSpacing.hMd,
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称 + 认证徽章
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expert.displayName,
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
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  // 简介 — 为空时显示占位文本
                  const SizedBox(height: 4),
                  Text(
                    (expert.displayBio != null && expert.displayBio!.isNotEmpty)
                        ? expert.displayBio!
                        : context.l10n.taskExpertNoIntro,
                    style: AppTypography.caption.copyWith(
                      color: (expert.displayBio != null && expert.displayBio!.isNotEmpty)
                          ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          : (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 统计行: 评分胶囊 + 完成数·服务数
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
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
                              expert.ratingDisplay,
                              style: AppTypography.caption2.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        context.l10n.leaderboardCompletedCount(
                            expert.completedTasks),
                        style: AppTypography.caption2.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      if (expert.totalServices > 0) ...[
                        Text(
                          ' · ',
                          style: AppTypography.caption2.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                        Text(
                          context.l10n.taskExpertServiceCount(
                              expert.totalServices),
                          style: AppTypography.caption2.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
