import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/decorative_background.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/leaderboard.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/models/trending_search.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/follow_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/repositories/trending_search_repository.dart';
import '../bloc/discover_bloc.dart';

// ==================== Gradient palettes ====================

const _cardGradients = <List<Color>>[
  [Color(0xFF007AFF), Color(0xFF409CFF)], // blue
  [Color(0xFFFF2D55), Color(0xFFFF6B8A)], // pink
  [Color(0xFF26BF73), Color(0xFF5ED99F)], // green
  [Color(0xFF7359F2), Color(0xFFA78BFA)], // purple
  [Color(0xFFFF8033), Color(0xFFFFA600)], // orange
  [Color(0xFF1C1C1E), Color(0xFF3A3A3C)], // dark
];

List<Color> _gradientAt(int index) => _cardGradients[index % _cardGradients.length];

// ==================== DiscoverView ====================

class DiscoverView extends StatelessWidget {
  const DiscoverView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DiscoverBloc>(
      create: (ctx) => DiscoverBloc(
        trendingSearchRepository: ctx.read<TrendingSearchRepository>(),
        forumRepository: ctx.read<ForumRepository>(),
        leaderboardRepository: ctx.read<LeaderboardRepository>(),
        taskExpertRepository: ctx.read<TaskExpertRepository>(),
        activityRepository: ctx.read<ActivityRepository>(),
        followRepository: ctx.read<FollowRepository>(),
      )..add(const DiscoverLoadRequested()),
      child: const _DiscoverContent(),
    );
  }
}

class _DiscoverContent extends StatelessWidget {
  const _DiscoverContent();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
      appBar: AppBar(
        backgroundColor: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        toolbarHeight: 56,
        titleSpacing: AppSpacing.md,
        title: GestureDetector(
          onTap: () => context.push('/search'),
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.secondaryBackgroundDark
                  : AppColors.backgroundLight,
              borderRadius: AppRadius.allPill,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  size: 20,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
                AppSpacing.hSm,
                Expanded(
                  child: Text(
                    context.l10n.discoverSearchHint,
                    style: AppTypography.subheadline.copyWith(
                      color: isDark
                          ? AppColors.textPlaceholderDark
                          : AppColors.textPlaceholderLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: Stack(
        children: [
          const RepaintBoundary(child: DecorativeBackground()),
          BlocBuilder<DiscoverBloc, DiscoverState>(
      builder: (context, state) {
        switch (state.status) {
          case DiscoverStatus.initial:
          case DiscoverStatus.loading:
            return const _LoadingIndicator();
          case DiscoverStatus.error:
            return ErrorStateView(
              message: context.localizeError(state.errorMessage ?? ''),
              onRetry: () => context.read<DiscoverBloc>().add(const DiscoverLoadRequested()),
            );
          case DiscoverStatus.loaded:
            return RefreshIndicator(
              onRefresh: () async {
                final bloc = context.read<DiscoverBloc>();
                bloc.add(const DiscoverRefreshRequested());
                await bloc.stream
                    .firstWhere((s) => s.status == DiscoverStatus.loaded || s.status == DiscoverStatus.error)
                    .timeout(const Duration(seconds: 10), onTimeout: () => bloc.state);
              },
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(child: _TrendingSection(items: state.trendingSearches)),
                  if (state.boards.isNotEmpty)
                    SliverToBoxAdapter(child: _BoardsSection(boards: state.boards)),
                  if (state.leaderboards.isNotEmpty)
                    SliverToBoxAdapter(child: _LeaderboardsSection(leaderboards: state.leaderboards)),
                  if (state.skillCategories.isNotEmpty)
                    SliverToBoxAdapter(child: _SkillCategoriesSection(categories: state.skillCategories)),
                  if (state.experts.isNotEmpty)
                    SliverToBoxAdapter(child: _ExpertsSection(experts: state.experts)),
                  if (state.activities.isNotEmpty)
                    SliverToBoxAdapter(child: _ActivitiesSection(activities: state.activities)),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
        }
      },
    ),
        ],
      ),
    );
  }
}

// ==================== 2. Trending Section ====================

class _TrendingSection extends StatelessWidget {
  const _TrendingSection({required this.items});
  final List<TrendingSearchItem> items;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '\u{1F525} ${context.l10n.discoverTrending}',
              style: AppTypography.bodyBold.copyWith(
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            AppSpacing.vSm,
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Center(
                  child: Text(
                    context.l10n.discoverNoTrending,
                    style: AppTypography.footnote.copyWith(
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              )
            else
              ...items.take(5).map((item) => _TrendingRow(item: item)),
          ],
        ),
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({required this.item});
  final TrendingSearchItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTop3 = item.rank <= 3;
    final heatSuffix = context.l10n.trendingHeatSuffix;

    return InkWell(
      onTap: () => context.push('/search?q=${Uri.encodeComponent(item.keyword)}'),
      borderRadius: AppRadius.allSmall,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            // Rank number
            SizedBox(
              width: 28,
              child: Text(
                '${item.rank}',
                style: AppTypography.bodyBold.copyWith(
                  color: isTop3 ? AppColors.error : AppColors.textSecondaryLight,
                  fontWeight: isTop3 ? FontWeight.w800 : FontWeight.w600,
                  fontSize: isTop3 ? 18 : 16,
                ),
              ),
            ),
            AppSpacing.hSm,
            // Keyword
            Expanded(
              child: Text(
                item.keyword,
                style: AppTypography.subheadline.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  fontWeight: isTop3 ? FontWeight.w600 : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Tag badge
            if (item.tag != null) ...[
              AppSpacing.hSm,
              _TagBadge(tag: item.tag!),
            ],
            AppSpacing.hSm,
            // Heat display
            Text(
              item.localizedHeatDisplay(heatSuffix),
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  const _TagBadge({required this.tag});
  final String tag;

  @override
  Widget build(BuildContext context) {
    Color bgColor;
    String label;
    switch (tag) {
      case 'hot':
        bgColor = AppColors.accentPink;
        label = context.l10n.trendingTagHot;
        break;
      case 'new':
        bgColor = AppColors.primary;
        label = context.l10n.trendingTagNew;
        break;
      case 'up':
        bgColor = AppColors.success;
        label = context.l10n.trendingTagUp;
        break;
      default:
        return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor.withValues(alpha: 0.15),
        borderRadius: AppRadius.allTiny,
      ),
      child: Text(
        label,
        style: AppTypography.caption2.copyWith(
          color: bgColor,
          fontWeight: FontWeight.w600,
          fontSize: 10,
        ),
      ),
    );
  }
}

// ==================== 3. Boards Section ====================

class _BoardsSection extends StatelessWidget {
  const _BoardsSection({required this.boards});
  final List<ForumCategory> boards;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _SectionContainer(
      title: '\u{1F3F7}\uFE0F ${context.l10n.discoverBoards}',
      showViewAll: true,
      onViewAll: () => context.push('/forum'),
      child: SizedBox(
        height: 120,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: boards.length,
          separatorBuilder: (_, __) => AppSpacing.hSm,
          itemBuilder: (context, index) {
            final board = boards[index];
            final gradient = _gradientAt(index);
            return GestureDetector(
              onTap: () {
                if (board.skillType != null && board.skillType!.isNotEmpty) {
                  context.push('/forum/skill/${board.id}', extra: board);
                } else {
                  context.push('/forum/category/${board.id}', extra: board);
                }
              },
              child: Container(
                width: 140,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.allMedium,
                ),
                child: Stack(
                  children: [
                    // Centered emoji icon
                    Center(
                      child: Text(
                        board.icon ?? '\u{1F4CC}',
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                    // Bottom overlay with name + count
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(10, 24, 10, 10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              board.displayName(locale),
                              style: AppTypography.subheadlineBold.copyWith(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${board.postCount} ${context.l10n.skillFeedDiscussionLabel}',
                              style: AppTypography.caption2.copyWith(
                                color: Colors.white.withValues(alpha: 0.7),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================== 4. Leaderboards Section ====================

class _LeaderboardsSection extends StatelessWidget {
  const _LeaderboardsSection({required this.leaderboards});
  final List<Leaderboard> leaderboards;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _SectionContainer(
      title: '\u{1F3C6} ${context.l10n.discoverLeaderboards}',
      showViewAll: true,
      onViewAll: () => context.push('/leaderboard'),
      child: SizedBox(
        height: 160,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: leaderboards.length,
          separatorBuilder: (_, __) => AppSpacing.hSm,
          itemBuilder: (context, index) {
            final lb = leaderboards[index];
            final gradient = _gradientAt(index);
            final hasCover = lb.coverImage != null && lb.coverImage!.isNotEmpty;
            return GestureDetector(
              onTap: () => context.push('/leaderboard/${lb.id}'),
              child: Container(
                width: 200,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: hasCover ? null : LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.allMedium,
                  image: hasCover ? DecorationImage(
                    image: NetworkImage(lb.coverImage!),
                    fit: BoxFit.cover,
                  ) : null,
                ),
                child: Container(
                  padding: AppSpacing.allMd,
                  decoration: hasCover ? BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Spacer(),
                          if (lb.location.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: AppRadius.allTiny,
                              ),
                              child: Text(
                                lb.location,
                                style: AppTypography.caption2.copyWith(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        lb.displayName(locale),
                        style: AppTypography.subheadlineBold.copyWith(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      AppSpacing.vXs,
                      Row(
                        children: [
                          _StatChip(icon: Icons.list, value: '${lb.itemCount}'),
                          AppSpacing.hSm,
                          _StatChip(icon: Icons.thumb_up_alt_outlined, value: '${lb.voteCount}'),
                          AppSpacing.hSm,
                          _StatChip(icon: Icons.visibility_outlined, value: '${lb.viewCount}'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: Colors.white.withValues(alpha: 0.7)),
        const SizedBox(width: 2),
        Text(
          value,
          style: AppTypography.caption2.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ==================== 5. Skill Categories Section ====================

class _SkillCategoriesSection extends StatelessWidget {
  const _SkillCategoriesSection({required this.categories});
  final List<ForumCategory> categories;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _SectionContainer(
      title: '\u{1F4C2} ${context.l10n.discoverSkillCategories}',
      showViewAll: true,
      onViewAll: () => context.push('/forum'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: AppSpacing.sm,
            crossAxisSpacing: AppSpacing.sm,
            childAspectRatio: 2.2,
          ),
          itemCount: categories.length > 6 ? 6 : categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final gradient = _gradientAt(index);
            return GestureDetector(
              onTap: () => context.push('/forum/skill/${cat.id}', extra: cat),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.allMedium,
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        Text(
                          cat.icon ?? '\u{1F4A1}',
                          style: const TextStyle(fontSize: 20),
                        ),
                        AppSpacing.hSm,
                        Expanded(
                          child: Text(
                            cat.displayName(locale),
                            style: AppTypography.subheadlineBold.copyWith(
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    AppSpacing.vXs,
                    Text(
                      '${cat.postCount}${context.l10n.skillFeedDiscussionLabel}'
                      ' \u00B7 ${cat.serviceCount}${context.l10n.skillFeedServiceLabel}'
                      ' \u00B7 ${cat.taskCount}${context.l10n.skillFeedTaskLabel}',
                      style: AppTypography.caption2.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ==================== 6. Experts Section ====================

class _ExpertsSection extends StatelessWidget {
  const _ExpertsSection({required this.experts});
  final List<TaskExpert> experts;

  @override
  Widget build(BuildContext context) {
    return _SectionContainer(
      title: '\u2728 ${context.l10n.discoverExperts}',
      showViewAll: true,
      onViewAll: () => context.push('/task-experts'),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Column(
          children: experts
              .take(3)
              .map((expert) => _ExpertRow(expert: expert))
              .toList(),
        ),
      ),
    );
  }
}

class _ExpertRow extends StatelessWidget {
  const _ExpertRow({required this.expert});
  final TaskExpert expert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final bio = expert.displayBio(locale);
    final skills = expert.displayFeaturedSkills(locale);
    final isFollowing = context.select<DiscoverBloc, bool>(
      (bloc) => bloc.state.followedExpertIds.contains(expert.id),
    );

    return GestureDetector(
      onTap: () => context.push('/task-experts/${expert.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: AppColors.backgroundLight,
              backgroundImage: expert.avatar != null && expert.avatar!.isNotEmpty
                  ? CachedNetworkImageProvider(expert.avatar!)
                  : null,
              child: expert.avatar == null || expert.avatar!.isEmpty
                  ? const Icon(Icons.person, size: 24, color: AppColors.textSecondaryLight)
                  : null,
            ),
            AppSpacing.hSm,
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expert.displayName,
                          style: AppTypography.subheadlineBold.copyWith(
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (expert.isVerified) ...[
                        AppSpacing.hXs,
                        const Icon(Icons.verified, size: 16, color: AppColors.primary),
                      ],
                    ],
                  ),
                  if (bio != null && bio.isNotEmpty) ...[
                    AppSpacing.vXs,
                    Text(
                      bio,
                      style: AppTypography.caption.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (skills.isNotEmpty) ...[
                    AppSpacing.vXs,
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: skills.take(3).map((skill) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: AppRadius.allTiny,
                        ),
                        child: Text(
                          skill,
                          style: AppTypography.caption2.copyWith(
                            color: AppColors.primary,
                            fontSize: 10,
                          ),
                        ),
                      )).toList(),
                    ),
                  ],
                ],
              ),
            ),
            AppSpacing.hSm,
            // Follow button
            GestureDetector(
              onTap: () => context.read<DiscoverBloc>().add(
                DiscoverToggleFollowExpert(expert.id),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isFollowing
                      ? AppColors.backgroundLight
                      : AppColors.primary,
                  borderRadius: AppRadius.allPill,
                  border: isFollowing
                      ? Border.all(color: AppColors.dividerLight)
                      : null,
                ),
                child: Text(
                  isFollowing
                      ? context.l10n.discoverFollowing
                      : context.l10n.discoverFollow,
                  style: AppTypography.caption.copyWith(
                    color: isFollowing
                        ? AppColors.textSecondaryLight
                        : Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== 7. Activities Section ====================

class _ActivitiesSection extends StatelessWidget {
  const _ActivitiesSection({required this.activities});
  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return _SectionContainer(
      title: '\u{1F3AA} ${context.l10n.discoverActivities}',
      showViewAll: true,
      onViewAll: () => context.push('/activities'),
      child: SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          itemCount: activities.length,
          separatorBuilder: (_, __) => AppSpacing.hSm,
          itemBuilder: (context, index) {
            final activity = activities[index];
            final gradient = _gradientAt(index);
            final hasImage = activity.firstImage != null;
            return GestureDetector(
              onTap: () => context.push('/activities/${activity.id}'),
              child: Container(
                width: 220,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  gradient: hasImage ? null : LinearGradient(
                    colors: gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: AppRadius.allMedium,
                  image: hasImage ? DecorationImage(
                    image: NetworkImage(activity.firstImage!),
                    fit: BoxFit.cover,
                  ) : null,
                ),
                child: Container(
                  padding: AppSpacing.allMd,
                  decoration: hasImage ? BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.7)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ) : null,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!hasImage)
                        const Text('\u{1F389}', style: TextStyle(fontSize: 24)),
                      if (!hasImage) AppSpacing.vSm,
                      Text(
                        activity.displayTitle(locale),
                        style: AppTypography.subheadlineBold.copyWith(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Spacer(),
                      // Date
                      if (activity.deadline != null) ...[
                        Text(
                          DateFormat('MM/dd').format(activity.deadline!),
                          style: AppTypography.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                        AppSpacing.vXs,
                      ],
                      // Bottom row: participants + price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.people_outline,
                                size: 14,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                                style: AppTypography.caption2.copyWith(
                                  color: Colors.white.withValues(alpha: 0.7),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                          _PriceButton(activity: activity),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PriceButton extends StatelessWidget {
  const _PriceButton({required this.activity});
  final Activity activity;

  @override
  Widget build(BuildContext context) {
    final price = activity.discountedPricePerParticipant
        ?? activity.originalPricePerParticipant;
    final isFree = price == null || price <= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: AppRadius.allPill,
      ),
      child: Text(
        isFree
            ? context.l10n.discoverFree
            : '\u00A3${price.toStringAsFixed(2)}',
        style: AppTypography.caption.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

// ==================== Shared: Section Container ====================

class _SectionContainer extends StatelessWidget {
  const _SectionContainer({
    required this.title,
    required this.child,
    this.showViewAll = false,
    this.onViewAll,
  });

  final String title;
  final Widget child;
  final bool showViewAll;
  final VoidCallback? onViewAll;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                if (showViewAll)
                  GestureDetector(
                    onTap: onViewAll,
                    child: Text(
                      '${context.l10n.discoverViewAll} \u203A',
                      style: AppTypography.footnote.copyWith(
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          AppSpacing.vSm,
          child,
        ],
      ),
    );
  }
}

// ==================== Loading Skeleton ====================

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: AppColors.primary),
    );
  }
}
