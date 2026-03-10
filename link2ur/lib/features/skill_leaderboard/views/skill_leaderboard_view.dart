import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/skill_category.dart';
import '../../../data/models/skill_leaderboard_entry.dart';
import '../../../data/repositories/skill_leaderboard_repository.dart';
import '../bloc/skill_leaderboard_bloc.dart';
import 'widgets/leaderboard_item_widget.dart';

/// Skill leaderboard page
class SkillLeaderboardView extends StatelessWidget {
  const SkillLeaderboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => SkillLeaderboardBloc(
        skillLeaderboardRepository:
            context.read<SkillLeaderboardRepository>(),
      )..add(const LeaderboardLoadRequested()),
      child: const _SkillLeaderboardBody(),
    );
  }
}

class _SkillLeaderboardBody extends StatelessWidget {
  const _SkillLeaderboardBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Skill Leaderboard'),
        centerTitle: true,
      ),
      body: BlocBuilder<SkillLeaderboardBloc, SkillLeaderboardState>(
        builder: (context, state) {
          switch (state.status) {
            case LeaderboardStatus.initial:
            case LeaderboardStatus.loading:
              if (state.categories.isEmpty) {
                return const LoadingView();
              }
              // Show content with loading indicator when switching categories
              return _buildContent(context, state, isLoading: true);
            case LeaderboardStatus.error:
              if (state.categories.isEmpty) {
                return ErrorStateView(
                  message: context.localizeError(state.errorMessage),
                  onRetry: () => context
                      .read<SkillLeaderboardBloc>()
                      .add(const LeaderboardLoadRequested()),
                );
              }
              return _buildContent(context, state);
            case LeaderboardStatus.loaded:
              if (state.categories.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.leaderboard_outlined,
                  title: 'No Categories',
                  description: 'No skill categories available yet.',
                );
              }
              return _buildContent(context, state);
          }
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    SkillLeaderboardState state, {
    bool isLoading = false,
  }) {
    return Column(
      children: [
        // Category tabs
        _CategoryTabs(
          categories: state.categories,
          selectedCategory: state.selectedCategory,
        ),

        // Leaderboard list
        Expanded(
          child: isLoading && state.entries.isEmpty
              ? const LoadingView()
              : _LeaderboardList(state: state),
        ),
      ],
    );
  }
}

/// Horizontally scrollable category tabs
class _CategoryTabs extends StatelessWidget {
  const _CategoryTabs({
    required this.categories,
    required this.selectedCategory,
  });

  final List<SkillCategory> categories;
  final String? selectedCategory;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 52,
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(13),
          ),
        ),
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.horizontalMd,
        itemCount: categories.length,
        separatorBuilder: (_, __) => AppSpacing.hSm,
        itemBuilder: (context, index) {
          final category = categories[index];
          // Use English name as the category key
          final isSelected = category.nameEn == selectedCategory;
          // Display localized name based on locale
          final locale = Localizations.localeOf(context);
          final displayName =
              locale.languageCode == 'zh' ? category.nameZh : category.nameEn;

          return Center(
            child: Semantics(
              button: true,
              label: 'Select category',
              child: GestureDetector(
                onTap: () {
                  if (!isSelected) {
                    context
                        .read<SkillLeaderboardBloc>()
                        .add(LeaderboardCategorySelected(category.nameEn));
                  }
                },
                child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : isDark
                          ? Colors.white.withAlpha(13)
                          : Colors.grey.withAlpha(30),
                  borderRadius: AppRadius.allPill,
                ),
                child: Text(
                  displayName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight:
                        isSelected ? FontWeight.w700 : FontWeight.w500,
                    color: isSelected
                        ? Colors.white
                        : theme.colorScheme.onSurface.withAlpha(180),
                  ),
                ),
              ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Top 10 list + optional "my rank" footer
class _LeaderboardList extends StatelessWidget {
  const _LeaderboardList({required this.state});

  final SkillLeaderboardState state;

  @override
  Widget build(BuildContext context) {
    if (state.entries.isEmpty) {
      return const EmptyStateView(
        icon: Icons.leaderboard_outlined,
        title: 'No Rankings Yet',
        description: 'No one has ranked in this category yet.',
      );
    }

    final theme = Theme.of(context);
    // Check if current user is already in the top list
    final myRank = state.myRank;
    final isInTopList = myRank != null &&
        state.entries.any((e) => e.userId == myRank.userId);

    return Column(
      children: [
        // Header row
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal + AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 32,
                child: Text(
                  '#',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ),
              AppSpacing.hMd,
              const SizedBox(width: 40), // avatar space
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  'Player',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withAlpha(120),
                  ),
                ),
              ),
              Text(
                'Rating',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
              AppSpacing.hMd,
              Text(
                'Score',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(120),
                ),
              ),
            ],
          ),
        ),

        // Top 10 list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            itemCount: state.entries.length,
            itemBuilder: (context, index) {
              return LeaderboardItemWidget(
                key: ValueKey(state.entries[index].userId),
                entry: state.entries[index],
                isCurrentUser: myRank != null &&
                    state.entries[index].userId == myRank.userId,
              );
            },
          ),
        ),

        // "My rank" section at bottom if user is not in top list
        if (myRank != null && !isInTopList) _MyRankFooter(myRank: myRank),
      ],
    );
  }
}

/// Sticky footer showing current user's rank when not in top 10
class _MyRankFooter extends StatelessWidget {
  const _MyRankFooter({required this.myRank});

  final SkillLeaderboardEntry myRank;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withAlpha(20)
                : Colors.black.withAlpha(13),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 40 : 13),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.screenHorizontal,
                top: AppSpacing.sm,
              ),
              child: Text(
                'My Ranking',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withAlpha(140),
                ),
              ),
            ),
            LeaderboardItemWidget(
              entry: myRank,
              isCurrentUser: true,
            ),
            AppSpacing.vXs,
          ],
        ),
      ),
    );
  }
}
