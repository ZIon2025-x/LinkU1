// 旧版 sections (_TrendingSection / _BoardsSection / _LeaderboardsSection /
// _SkillCategoriesSection / _ExpertsSection / _ActivitiesSection 等)目前未被
// 新布局引用。保留代码作为渐进过渡的备份;明确确认不回滚后可删除。
// ignore_for_file: unused_element

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
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/decorative_background.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/leaderboard.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/models/trending_search.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../../data/repositories/follow_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/repositories/trending_search_repository.dart';
import '../bloc/discover_bloc.dart';
// 复用首页 masonry feed (CommunityDiscoveryFeedSliver 走 DiscoverBloc 的
// communityFeedItems,scope=community,与首页发现流独立)
import '../../home/views/home_view.dart';

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
        discoveryRepository: ctx.read<DiscoveryRepository>(),
      )
        ..add(const DiscoverLoadRequested())
        ..add(const DiscoverLoadCommunityFeed()),
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
      body: Stack(
        children: [
          const RepaintBoundary(child: DecorativeBackground()),
          SafeArea(
            child: Column(
              children: [
                // 搜索栏
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.md, AppSpacing.sm),
                  child: GestureDetector(
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
                // 内容区
                Expanded(
                  child: BlocBuilder<DiscoverBloc, DiscoverState>(
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
                bloc.add(const DiscoverLoadCommunityFeed());
                // 等两条流都 settle (静态内容 + 社区 feed) 再收起下拉
                await bloc.stream
                    .firstWhere((s) =>
                        (s.status == DiscoverStatus.loaded ||
                            s.status == DiscoverStatus.error) &&
                        (s.communityFeedStatus == DiscoverFeedStatus.loaded ||
                            s.communityFeedStatus == DiscoverFeedStatus.error))
                    .timeout(const Duration(seconds: 10),
                        onTimeout: () => bloc.state);
              },
              child: CustomScrollView(
                slivers: [
                  // 1) 4 功能宫格(榜单/活动/板块/技能)
                  SliverToBoxAdapter(
                    child: _CommunityFeatureGrid(
                      leaderboards: state.leaderboards,
                      activities: state.activities,
                      boards: state.boards,
                      skillCategories: state.skillCategories,
                    ),
                  ),
                  // 2) 热搜榜(横滑)
                  if (state.trendingSearches.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _TrendingHorizontal(items: state.trendingSearches),
                    ),
                  // 3) "发现更多" 标题
                  const SliverToBoxAdapter(child: _DiscoverMoreHeader()),
                  // 4) Masonry 发现流(复用首页 HomeBloc.state.discoveryItems)
                  const SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    sliver: CommunityDiscoveryFeedSliver(),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                    ),
                  ),
                ],
              ),
            );
        }
      },
    ),
              ),
              ],
            ),
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
      onViewAll: () => context.push('/forum?filter=boards'),
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
      onViewAll: () => context.push('/forum?filter=skills'),
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
                  ? CachedNetworkImageProvider(Helpers.getImageUrl(expert.avatar!))
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

// ==================== 社区 tab 新布局 widgets (对齐 community-page-mockup.html) ====================

/// 4 功能宫格 (2x2): 榜单 / 活动 / 板块 / 技能
/// 每个宫格内部再嵌 2 张迷你卡(对齐 community-page-mockup.html)
class _CommunityFeatureGrid extends StatelessWidget {
  const _CommunityFeatureGrid({
    required this.leaderboards,
    required this.activities,
    required this.boards,
    required this.skillCategories,
  });

  final List<Leaderboard> leaderboards;
  final List<Activity> activities;
  final List<ForumCategory> boards;
  final List<ForumCategory> skillCategories;

  static const List<List<Color>> _leaderboardMiniGradients = [
    [Color(0xFFFFD84D), Color(0xFFFF9500)],
    [Color(0xFF56CCF2), Color(0xFF2F80ED)],
  ];
  static const List<List<Color>> _activityMiniGradients = [
    [Color(0xFFFF8033), Color(0xFFFFA600)],
    [Color(0xFFFF5E62), Color(0xFFFF9966)],
  ];
  static const List<List<Color>> _boardMiniGradients = [
    [Color(0xFF007AFF), Color(0xFF409CFF)],
    [Color(0xFF7359F2), Color(0xFFA78BFA)],
  ];
  static const List<List<Color>> _skillMiniGradients = [
    [Color(0xFF7359F2), Color(0xFFA78BFA)],
    [Color(0xFFFF2D55), Color(0xFFFF6B8A)],
  ];

  static const List<String> _leaderboardEmojis = ['🏆', '💎'];
  static const List<String> _activityEmojis = ['🎉', '🎟️'];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: GridView(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        // 锁定宫格高度而非纵横比 — 防止宽屏下 tile 跟随宽度等比拉高，
        // 底部出现大块多余渐变 (community-page-mockup.html tile min-height 154)
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          mainAxisExtent: 156,
        ),
        children: [
          _FeatureTile(
            title: l10n.communityTileLeaderboards,
            tag: l10n.communityTagLocalHot,
            tagColor: const Color(0xFFE09000),
            background: const LinearGradient(
              colors: [Color(0xFFFFFBEB), Color(0xFFFEF0C7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            fallbackEmoji: '🏆',
            fallbackText: l10n.communityFallbackLeaderboards,
            statColor: const Color(0xFFE09000),
            items: List.generate(
              leaderboards.length.clamp(0, 2),
              (i) {
                final lb = leaderboards[i];
                return _MiniItemData(
                  emoji: _leaderboardEmojis[i % _leaderboardEmojis.length],
                  gradient: _leaderboardMiniGradients[
                      i % _leaderboardMiniGradients.length],
                  imageUrl: lb.coverImage,
                  primaryText: lb.displayName(locale),
                  secondaryText: l10n.communityItemSeats(lb.itemCount),
                  onTap: () => context.push('/leaderboard/${lb.id}'),
                );
              },
            ),
            onTap: () => context.push('/leaderboard'),
          ),
          _FeatureTile(
            title: l10n.communityTileActivities,
            tag: l10n.communityTagLimitedTime,
            tagColor: const Color(0xFFFF6B35),
            background: const LinearGradient(
              colors: [Color(0xFFFFF8F3), Color(0xFFFFE9D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            fallbackEmoji: '🎉',
            fallbackText: l10n.communityFallbackActivities,
            statColor: const Color(0xFFFF2D55),
            // 活动迷你卡:倒计时在上(红色),标题在下
            items: List.generate(
              activities.length.clamp(0, 2),
              (i) {
                final a = activities[i];
                return _MiniItemData(
                  emoji: _activityEmojis[i % _activityEmojis.length],
                  gradient:
                      _activityMiniGradients[i % _activityMiniGradients.length],
                  primaryText: a.displayTitle(locale),
                  secondaryText: _formatCountdown(context, a.deadline),
                  secondaryFirst: true,
                  onTap: () => context.push('/activities/${a.id}'),
                );
              },
            ),
            onTap: () => context.push('/activities'),
          ),
          _FeatureTile(
            title: l10n.communityTileBoards,
            tag: l10n.communityTagDiscuss,
            tagColor: const Color(0xFF2F80ED),
            background: const LinearGradient(
              colors: [Color(0xFFF4F8FF), Color(0xFFE3EDFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            fallbackEmoji: '💬',
            fallbackText: l10n.communityFallbackBoards,
            statColor: const Color(0xFF2F80ED),
            items: List.generate(
              boards.length.clamp(0, 2),
              (i) {
                final b = boards[i];
                return _MiniItemData(
                  emoji: b.icon ?? '📌',
                  gradient: _boardMiniGradients[i % _boardMiniGradients.length],
                  primaryText: b.displayName(locale),
                  secondaryText: l10n.communityItemPosts(b.postCount),
                  onTap: () {
                    if (b.skillType != null && b.skillType!.isNotEmpty) {
                      context.push('/forum/skill/${b.id}', extra: b);
                    } else {
                      context.push('/forum/category/${b.id}', extra: b);
                    }
                  },
                );
              },
            ),
            onTap: () => context.push('/forum'),
          ),
          _FeatureTile(
            title: l10n.communityTileSkills,
            tag: l10n.communityTagDiscover,
            tagColor: const Color(0xFF7359F2),
            background: const LinearGradient(
              colors: [Color(0xFFF7F2FF), Color(0xFFEBE1FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            fallbackEmoji: '✨',
            fallbackText: l10n.communityFallbackSkills,
            statColor: const Color(0xFF7359F2),
            items: List.generate(
              skillCategories.length.clamp(0, 2),
              (i) {
                final c = skillCategories[i];
                return _MiniItemData(
                  emoji: c.icon ?? '💡',
                  gradient: _skillMiniGradients[i % _skillMiniGradients.length],
                  primaryText: c.displayName(locale),
                  secondaryText: l10n.communityItemServices(c.serviceCount),
                  onTap: () => context.push('/forum/skill/${c.id}', extra: c),
                );
              },
            ),
            onTap: () => context.push('/forum?filter=skills'),
          ),
        ],
      ),
    );
  }

  /// 倒计时格式化:支持天 / 时分 / 分 / 已结束
  static String _formatCountdown(BuildContext context, DateTime? deadline) {
    final l10n = context.l10n;
    if (deadline == null) return '';
    final diff = deadline.difference(DateTime.now());
    if (diff.isNegative) return l10n.communityCountdownEnded;
    if (diff.inDays >= 1) return l10n.communityCountdownDays(diff.inDays);
    if (diff.inHours >= 1) {
      return l10n.communityCountdownHM(
          diff.inHours, diff.inMinutes.remainder(60));
    }
    final mins = diff.inMinutes < 1 ? 1 : diff.inMinutes;
    return l10n.communityCountdownMin(mins);
  }
}

/// 单个迷你卡的数据
class _MiniItemData {
  const _MiniItemData({
    required this.emoji,
    required this.gradient,
    required this.primaryText,
    required this.secondaryText,
    this.imageUrl,
    this.secondaryFirst = false,
    this.onTap,
  });

  final String emoji;
  final List<Color> gradient;
  final String primaryText;
  final String secondaryText;
  // 有值时迷你卡顶部用真实封面图替代 emoji+渐变 (榜单自带 cover_image)
  final String? imageUrl;
  // true → 副文案放在主文案之前(用于活动倒计时高亮)
  final bool secondaryFirst;
  final VoidCallback? onTap;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.title,
    required this.tag,
    required this.tagColor,
    required this.background,
    required this.fallbackEmoji,
    required this.fallbackText,
    required this.statColor,
    required this.items,
    required this.onTap,
  });

  final String title;
  final String tag;
  final Color tagColor;
  final Gradient background;
  final String fallbackEmoji;
  final String fallbackText;
  final Color statColor;
  final List<_MiniItemData> items;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: background,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题 + tag chip
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1C1C1E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tagColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 内部 2 列迷你卡(或 fallback)
            Expanded(
              child: items.isEmpty
                  ? _buildFallback()
                  : _buildMiniItems(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallback() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(fallbackEmoji, style: const TextStyle(fontSize: 36)),
          const SizedBox(height: 4),
          Text(
            fallbackText,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMiniItems() {
    final children = <Widget>[];
    for (var i = 0; i < 2; i++) {
      if (i > 0) children.add(const SizedBox(width: 6));
      if (i < items.length) {
        children.add(
          Expanded(child: _MiniItem(data: items[i], statColor: statColor)),
        );
      } else {
        children.add(const Expanded(child: SizedBox.shrink()));
      }
    }
    // 顶端对齐 — 迷你卡自身用 mainAxisSize.min 决定高度，不被父 Row 拉伸
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: children);
  }
}

class _MiniItem extends StatelessWidget {
  const _MiniItem({required this.data, required this.statColor});
  final _MiniItemData data;
  final Color statColor;

  @override
  Widget build(BuildContext context) {
    final secondary = data.secondaryText.isEmpty
        ? null
        : Text(
            data.secondaryText,
            style: TextStyle(
              fontSize: 11,
              color: statColor,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );
    final primary = Text(
      data.primaryText,
      style: const TextStyle(
        fontSize: 11,
        color: Color(0xFF1C1C1E),
        fontWeight: FontWeight.w700,
        height: 1.2,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );

    final hasImage = data.imageUrl != null && data.imageUrl!.isNotEmpty;
    return GestureDetector(
      onTap: data.onTap,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        // mainAxisSize.min 让卡片高度由内容决定，不被父 Row 垂直拉伸
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 顶部图: 固定 64px 高度 (对齐 community-page-mockup.html ti-img height:70)
            // 用固定高度而非 AspectRatio，避免宽屏下宫格变宽时图也跟着变高拉伸
            // 有 imageUrl 时显示真实封面 (榜单 cover_image)，否则渐变背景 + emoji
            SizedBox(
              height: 64,
              child: hasImage
                  ? CachedNetworkImage(
                      imageUrl: Helpers.getImageUrl(data.imageUrl!),
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: data.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          data.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: data.gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          data.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: data.gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        data.emoji,
                        style: const TextStyle(fontSize: 26),
                      ),
                    ),
            ),
            // 底部文字
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: data.secondaryFirst
                    ? [
                        if (secondary != null) secondary,
                        if (secondary != null) const SizedBox(height: 2),
                        primary,
                      ]
                    : [
                        primary,
                        if (secondary != null) const SizedBox(height: 2),
                        if (secondary != null) secondary,
                      ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 热搜横滑(替代竖向 _TrendingSection)
class _TrendingHorizontal extends StatelessWidget {
  const _TrendingHorizontal({required this.items});
  final List<TrendingSearchItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                const Text('🔥', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  context.l10n.communityHotSearches,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1C1C1E),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: items.length.clamp(0, 10),
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _TrendingHorizontalCard(item: items[i]),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendingHorizontalCard extends StatelessWidget {
  const _TrendingHorizontalCard({required this.item});
  final TrendingSearchItem item;

  @override
  Widget build(BuildContext context) {
    final colors = _gradientAt(item.rank - 1);
    final heatSuffix = context.l10n.trendingHeatSuffix;
    return GestureDetector(
      onTap: () => context.push(
        '/search?q=${Uri.encodeComponent(item.keyword)}',
      ),
      child: Container(
        width: 200,
        height: 76,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '${item.rank} ${item.rank <= 3 ? "HOT" : ""}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1,
              ),
            ),
            Text(
              item.keyword,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white,
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '🔥 ${item.localizedHeatDisplay(heatSuffix)}',
              style: const TextStyle(fontSize: 10, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// "发现更多" 标题(masonry feed 之前)
class _DiscoverMoreHeader extends StatelessWidget {
  const _DiscoverMoreHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          const Text('✨', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            context.l10n.communityDiscoverMore,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1C1C1E),
            ),
          ),
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
