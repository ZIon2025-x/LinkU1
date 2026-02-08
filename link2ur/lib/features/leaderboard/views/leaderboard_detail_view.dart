import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/models/leaderboard.dart';
import '../bloc/leaderboard_bloc.dart';

/// 排行榜详情页 - 对标iOS LeaderboardDetailView.swift
class LeaderboardDetailView extends StatelessWidget {
  const LeaderboardDetailView({
    super.key,
    required this.leaderboardId,
  });

  final int leaderboardId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      )..add(LeaderboardLoadDetail(leaderboardId)),
      child: _LeaderboardDetailContent(leaderboardId: leaderboardId),
    );
  }
}

class _LeaderboardDetailContent extends StatelessWidget {
  const _LeaderboardDetailContent({required this.leaderboardId});
  final int leaderboardId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardBloc, LeaderboardState>(
      builder: (context, state) {
        final lb = state.selectedLeaderboard;
        final hasHero = lb?.coverImage != null;

        return Scaffold(
          extendBodyBehindAppBar: hasHero,
          appBar: _buildAppBar(context, state, hasHero),
          body: _buildBody(context, state),
          floatingActionButton: lb != null
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      context.push('/leaderboard/$leaderboardId/submit'),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('提交竞品',
                      style: TextStyle(color: Colors.white)),
                )
              : null,
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, LeaderboardState state, bool hasHero) {
    if (!hasHero) {
      return AppBar(
        title: Text(
            state.selectedLeaderboard?.displayName ?? '排行榜详情'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
              HapticFeedback.selectionClick();
            },
          ),
        ],
      );
    }

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      forceMaterialTransparency: true,
      leading: Padding(
        padding: const EdgeInsets.all(4),
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back_ios_new,
                size: 18, color: Colors.white),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.share_outlined,
                  size: 18, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, LeaderboardState state) {
    if (state.status == LeaderboardStatus.loading &&
        state.selectedLeaderboard == null) {
      return const SkeletonDetail();
    }

    if (state.status == LeaderboardStatus.error &&
        state.selectedLeaderboard == null) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage ?? '加载失败',
        onRetry: () {
          context
              .read<LeaderboardBloc>()
              .add(LeaderboardLoadDetail(leaderboardId));
        },
      );
    }

    if (state.selectedLeaderboard == null) {
      return ErrorStateView.notFound();
    }

    final lb = state.selectedLeaderboard!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Sort items
    final sortedItems = List<LeaderboardItem>.from(state.items)
      ..sort((a, b) => b.netVotes.compareTo(a.netVotes));

    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<LeaderboardBloc>()
            .add(LeaderboardLoadDetail(leaderboardId));
      },
      child: CustomScrollView(
        slivers: [
          // Hero 区域 - 对标iOS hero section (240pt)
          SliverToBoxAdapter(
            child: _HeroSection(leaderboard: lb),
          ),

          // 描述
          if (lb.displayDescription != null &&
              lb.displayDescription!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: Text(
                  lb.displayDescription!,
                  style: AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
              ),
            ),

          // 统计栏 - 对标iOS stats bar
          SliverToBoxAdapter(
            child: _StatsBar(leaderboard: lb, isDark: isDark),
          ),

          // 列表或空状态
          if (sortedItems.isEmpty)
            SliverFillRemaining(
              child: EmptyStateView.noData(
                title: '暂无竞品',
                description: '还没有竞品，点击下方按钮提交第一个竞品',
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = sortedItems[index];
                    return Padding(
                      padding:
                          const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: GestureDetector(
                        onTap: () =>
                            context.push('/leaderboard/item/${item.id}'),
                        child: _RankItemCard(
                          item: item,
                          rank: index + 1,
                          isDark: isDark,
                        ),
                      ),
                    );
                  },
                  childCount: sortedItems.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== Hero 区域 ====================

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.leaderboard});
  final Leaderboard leaderboard;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图或渐变
          if (leaderboard.coverImage != null)
            AsyncImageView(
              imageUrl: leaderboard.coverImage!,
              width: double.infinity,
              height: 240,
              fit: BoxFit.cover,
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.8),
                    AppColors.primary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),

          // 底部渐变叠层 - 对标iOS black 60% → transparent
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: 0.6),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          // 标题文字 - 对标iOS bottom-left title
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 20,
            child: Text(
              leaderboard.displayName,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    color: Colors.black38,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 统计栏 ====================

class _StatsBar extends StatelessWidget {
  const _StatsBar({required this.leaderboard, required this.isDark});
  final Leaderboard leaderboard;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: 14),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _StatColumn(
              icon: Icons.list_alt,
              value: '${leaderboard.itemCount}',
              label: '竞品数',
            ),
            _StatDivider(isDark: isDark),
            _StatColumn(
              icon: Icons.how_to_vote,
              value: '${leaderboard.voteCount}',
              label: '投票数',
            ),
            _StatDivider(isDark: isDark),
            _StatColumn(
              icon: Icons.visibility_outlined,
              value: '${leaderboard.viewCount}',
              label: '浏览量',
            ),
          ],
        ),
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  const _StatColumn({
    required this.icon,
    required this.value,
    required this.label,
  });
  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: AppTypography.caption
              .copyWith(color: AppColors.textSecondaryLight),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 30,
      color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
          .withValues(alpha: 0.3),
    );
  }
}

// ==================== 排名条目卡片 ====================

class _RankItemCard extends StatelessWidget {
  const _RankItemCard({
    required this.item,
    required this.rank,
    required this.isDark,
  });

  final LeaderboardItem item;
  final int rank;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // 排名圆圈 - 对标iOS 36px for top3, 32px for others
          Container(
            width: isTop3 ? 36 : 32,
            height: isTop3 ? 36 : 32,
            decoration: BoxDecoration(
              color: isTop3
                  ? _getRankColor(rank)
                  : AppColors.skeletonBase,
              shape: BoxShape.circle,
              boxShadow: isTop3
                  ? [
                      BoxShadow(
                        color: _getRankColor(rank)
                            .withValues(alpha: 0.4),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isTop3
                      ? Colors.white
                      : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: isTop3 ? 16 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // 图片 - 对标iOS 64x64 medium radius
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: AppRadius.allMedium,
            ),
            child: item.firstImage != null
                ? ClipRRect(
                    borderRadius: AppRadius.allMedium,
                    child: AsyncImageView(
                      imageUrl: item.firstImage!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                    ),
                  )
                : const Icon(Icons.image,
                    color: AppColors.textTertiaryLight),
          ),
          const SizedBox(width: AppSpacing.md),

          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: AppTypography.bodyBold.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // 投票统计行 - 对标iOS vote line
                Row(
                  children: [
                    Icon(Icons.thumb_up, size: 12, color: AppColors.success),
                    const SizedBox(width: 3),
                    Text(
                      '${item.upvotes}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.success),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.thumb_down, size: 12, color: AppColors.error),
                    const SizedBox(width: 3),
                    Text(
                      '${item.downvotes}',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.error),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '·',
                      style: AppTypography.caption
                          .copyWith(color: AppColors.textTertiaryLight),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '净 ${item.netVotes}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 投票按钮 - 对标iOS 32px circle vote buttons
          Column(
            children: [
              _VoteCircle(
                icon: Icons.thumb_up,
                isActive: item.hasUpvoted,
                color: AppColors.success,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context
                      .read<LeaderboardBloc>()
                      .add(LeaderboardVoteItem(item.id));
                },
              ),
              const SizedBox(height: 4),
              _VoteCircle(
                icon: Icons.thumb_down,
                isActive: item.hasDownvoted,
                color: AppColors.error,
                onTap: () {
                  HapticFeedback.selectionClick();
                  context
                      .read<LeaderboardBloc>()
                      .add(LeaderboardVoteItem(item.id));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return AppColors.gold;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AppColors.textSecondaryLight;
    }
  }
}

class _VoteCircle extends StatelessWidget {
  const _VoteCircle({
    required this.icon,
    required this.isActive,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final bool isActive;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: isActive ? color : AppColors.textTertiaryLight,
            width: 1.5,
          ),
        ),
        child: Icon(
          icon,
          size: 14,
          color: isActive ? color : AppColors.textTertiaryLight,
        ),
      ),
    );
  }
}
