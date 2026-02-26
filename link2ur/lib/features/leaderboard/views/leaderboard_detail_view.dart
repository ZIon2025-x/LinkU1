import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/utils/native_share.dart';
import '../../../core/widgets/vote_comparison_bar.dart';
import '../../../core/widgets/gradient_text.dart';
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

class _LeaderboardDetailContent extends StatefulWidget {
  const _LeaderboardDetailContent({required this.leaderboardId});
  final int leaderboardId;

  @override
  State<_LeaderboardDetailContent> createState() =>
      _LeaderboardDetailContentState();
}

class _LeaderboardDetailContentState
    extends State<_LeaderboardDetailContent> {
  int get leaderboardId => widget.leaderboardId;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardBloc, LeaderboardState>(
      builder: (context, state) {
        final lb = state.selectedLeaderboard;
        final hasHero = lb?.coverImage != null;

        return Scaffold(
          extendBodyBehindAppBar: hasHero,
          appBar: _buildAppBar(context, state, hasHero),
          body: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  maxWidth: ResponsiveUtils.detailMaxWidth(context)),
              child: _buildBody(context, state),
            ),
          ),
          floatingActionButton: lb != null
              ? FloatingActionButton.extended(
                  onPressed: () =>
                      context.push('/leaderboard/$leaderboardId/submit'),
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: Text(context.l10n.leaderboardSubmitItem,
                      style: const TextStyle(color: Colors.white)),
                )
              : null,
        );
      },
    );
  }

  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final bloc = context.read<LeaderboardBloc>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.commonReport),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: context.l10n.commonReportReason,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                bloc.add(LeaderboardReport(leaderboardId, reason: reason));
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.commonReportSubmitted)),
                );
              },
              child: Text(context.l10n.commonConfirm),
            ),
          ],
        );
      },
    ).then((_) => reasonController.dispose());
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, LeaderboardState state, bool hasHero) {
    void onShare() async {
      final lb = state.selectedLeaderboard;
      if (lb == null) return;
      await NativeShare.share(
        title: lb.displayName(Localizations.localeOf(context)),
        description: lb.displayDescription(Localizations.localeOf(context)) ?? '',
        url: 'https://link2ur.com/leaderboard/${lb.id}',
        context: context,
      );
    }

    void onToggleFavorite() {
      AppHaptics.selection();
      context
          .read<LeaderboardBloc>()
          .add(LeaderboardToggleFavorite(leaderboardId));
    }

    if (!hasHero) {
      return AppBar(
        title: Text(state.selectedLeaderboard?.displayName(Localizations.localeOf(context)) ??
            context.l10n.leaderboardLeaderboard),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: onShare,
          ),
          IconButton(
            icon: Icon(
              state.isFavorited ? Icons.favorite : Icons.favorite_border,
              color: state.isFavorited ? AppColors.error : null,
            ),
            onPressed: onToggleFavorite,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'report') {
                _showReportDialog(context);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                value: 'report',
                child: Row(
                  children: [
                    const Icon(Icons.flag_outlined, size: 20),
                    const SizedBox(width: 8),
                    Text(context.l10n.commonReport),
                  ],
                ),
              ),
            ],
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
        _buildHeroCircleButton(
          context,
          icon: Icons.share_outlined,
          onTap: onShare,
        ),
        _buildHeroCircleButton(
          context,
          icon: state.isFavorited ? Icons.favorite : Icons.favorite_border,
          color: state.isFavorited ? AppColors.error : Colors.white,
          onTap: onToggleFavorite,
        ),
        _buildHeroCircleButton(
          context,
          icon: Icons.more_vert,
          onTap: () {
            final RenderBox button = context.findRenderObject() as RenderBox;
            final position = button.localToGlobal(Offset.zero);
            showMenu<String>(
              context: context,
              position: RelativeRect.fromLTRB(
                position.dx + button.size.width,
                position.dy + kToolbarHeight,
                0,
                0,
              ),
              items: [
                PopupMenuItem<String>(
                  value: 'report',
                  child: Row(
                    children: [
                      const Icon(Icons.flag_outlined, size: 20),
                      const SizedBox(width: 8),
                      Text(context.l10n.commonReport),
                    ],
                  ),
                ),
              ],
            ).then((value) {
              if (!mounted || value != 'report') return;
              _showReportDialog(this.context);
            });
          },
        ),
      ],
    );
  }

  Widget _buildHeroCircleButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: color ?? Colors.white),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, LeaderboardState state) {
    if (state.status == LeaderboardStatus.loading &&
        state.selectedLeaderboard == null) {
      return const SkeletonLeaderboardDetail();
    }

    if (state.status == LeaderboardStatus.error &&
        state.selectedLeaderboard == null) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage ?? context.l10n.leaderboardLoadFailed,
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
    final items = state.items;

    return RefreshIndicator(
      onRefresh: () async {
        context
            .read<LeaderboardBloc>()
            .add(LeaderboardLoadDetail(leaderboardId));
      },
      child: CustomScrollView(
        slivers: [
          // Hero 区域
          SliverToBoxAdapter(
            child: _HeroSection(leaderboard: lb),
          ),

          // 描述
          if (lb.displayDescription(Localizations.localeOf(context)) != null &&
              lb.displayDescription(Localizations.localeOf(context))!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: SelectableText(
                  lb.displayDescription(Localizations.localeOf(context))!,
                  style: AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
              ),
            ),

          // 排行榜规则
          if (lb.rules != null && lb.rules!.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.primary.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(AppRadius.medium),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.rule_rounded,
                            size: 16,
                            color: AppColors.primary.withValues(alpha: 0.8),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            context.l10n.leaderboardRules,
                            style: AppTypography.caption.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      SelectableText(
                        lb.rules!,
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // 统计栏
          SliverToBoxAdapter(
            child: _StatsBar(leaderboard: lb, isDark: isDark),
          ),

          // 排序筛选行
          SliverToBoxAdapter(
            child: _SortFilterRow(
              currentSort: state.sortBy,
              leaderboardId: leaderboardId,
            ),
          ),

          // 列表或空状态
          if (items.isEmpty)
            SliverFillRemaining(
              child: EmptyStateView.noData(
                context,
                title: context.l10n.leaderboardNoItems,
                description: context.l10n.leaderboardNoCompetitorsHint,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.sm, AppSpacing.md, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final item = items[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
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
                  childCount: items.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ==================== 排序筛选行 ====================

class _SortFilterRow extends StatelessWidget {
  const _SortFilterRow({
    required this.currentSort,
    required this.leaderboardId,
  });

  final String? currentSort;
  final int leaderboardId;

  @override
  Widget build(BuildContext context) {
    final sorts = [
      ('vote_score', context.l10n.leaderboardSortComprehensive),
      ('net_votes', context.l10n.leaderboardSortNetVotes),
      ('upvotes', context.l10n.leaderboardSortUpvotes),
      ('created_at', context.l10n.leaderboardSortLatest),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding:
          const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      child: Row(
        children: sorts.map((entry) {
          final isActive =
              currentSort == entry.$1 || (currentSort == null && entry.$1 == 'vote_score');
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                context.read<LeaderboardBloc>().add(
                      LeaderboardSortChanged(entry.$1,
                          leaderboardId: leaderboardId),
                    );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? AppColors.primary.withValues(alpha: 0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textTertiaryLight.withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  entry.$2,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive
                        ? AppColors.primary
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
        children: [
          Positioned.fill(
            child: leaderboard.coverImage != null
                ? AsyncImageView(
                    imageUrl: leaderboard.coverImage!,
                    width: 400,
                    height: 240,
                  )
                : Container(
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
          ),
          Positioned.fill(
            child: Container(
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
          ),
          Positioned(
            left: AppSpacing.md,
            right: AppSpacing.md,
            bottom: 20,
            child: SelectableText(
              leaderboard.displayName(Localizations.localeOf(context)),
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
              label: context.l10n.leaderboardItemCount,
            ),
            _StatDivider(isDark: isDark),
            _StatColumn(
              icon: Icons.how_to_vote,
              value: '${leaderboard.voteCount}',
              label: context.l10n.leaderboardTotalVotes,
            ),
            _StatDivider(isDark: isDark),
            _StatColumn(
              icon: Icons.visibility_outlined,
              value: '${leaderboard.viewCount}',
              label: context.l10n.leaderboardViewCount,
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
          // 排名圆圈
          Container(
            width: isTop3 ? 36 : 32,
            height: isTop3 ? 36 : 32,
            decoration: BoxDecoration(
              color: isTop3 ? _getRankColor(rank) : AppColors.skeletonBase,
              shape: BoxShape.circle,
              boxShadow: isTop3
                  ? [
                      BoxShadow(
                        color: _getRankColor(rank).withValues(alpha: 0.4),
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
                  color:
                      isTop3 ? Colors.white : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: isTop3 ? 16 : 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),

          // 图片
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
                isTop3
                    ? GradientText.medal(
                        text: item.name,
                        style: AppTypography.bodyBold,
                        rank: rank,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : SelectableText(
                        item.name,
                        style: AppTypography.bodyBold.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                      ),
                const SizedBox(height: 6),
                VoteComparisonBar(
                  upvotes: item.upvotes,
                  downvotes: item.downvotes,
                  height: 5,
                  showNetVotes: false,
                ),
              ],
            ),
          ),

          // 投票按钮 — 修正：分别传 upvote / downvote
          Column(
            children: [
              _VoteCircle(
                icon: Icons.thumb_up,
                isActive: item.hasUpvoted,
                color: AppColors.success,
                onTap: () {
                  AppHaptics.selection();
                  context.read<LeaderboardBloc>().add(
                        LeaderboardVoteItem(item.id, voteType: 'upvote'),
                      );
                },
              ),
              const SizedBox(height: 4),
              _VoteCircle(
                icon: Icons.thumb_down,
                isActive: item.hasDownvoted,
                color: AppColors.error,
                onTap: () {
                  AppHaptics.selection();
                  context.read<LeaderboardBloc>().add(
                        LeaderboardVoteItem(item.id, voteType: 'downvote'),
                      );
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
        return AppColors.silver;
      case 3:
        return AppColors.bronze;
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
          color:
              isActive ? color.withValues(alpha: 0.15) : Colors.transparent,
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
