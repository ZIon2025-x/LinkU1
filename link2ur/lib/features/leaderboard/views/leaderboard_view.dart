import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/leaderboard.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../bloc/leaderboard_bloc.dart';

/// 排行榜页
/// 参考iOS LeaderboardView.swift
class LeaderboardView extends StatelessWidget {
  const LeaderboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      )..add(const LeaderboardLoadRequested()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.leaderboardLeaderboard),
        ),
        body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
          builder: (context, state) {
            if (state.status == LeaderboardStatus.loading &&
                state.leaderboards.isEmpty) {
              return const SkeletonList(imageSize: 90);
            }

            if (state.status == LeaderboardStatus.error &&
                state.leaderboards.isEmpty) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? context.l10n.tasksLoadFailed,
                onRetry: () {
                  context.read<LeaderboardBloc>().add(
                        const LeaderboardLoadRequested(),
                      );
                },
              );
            }

            if (state.leaderboards.isEmpty) {
              return EmptyStateView.noData(
                context,
                title: context.l10n.leaderboardNoLeaderboards,
                description: context.l10n.leaderboardNoLeaderboardsMessage,
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<LeaderboardBloc>().add(
                      const LeaderboardRefreshRequested(),
                    );
              },
              child: ListView.separated(
                clipBehavior: Clip.none,
                cacheExtent: 500,
                padding: AppSpacing.allMd,
                itemCount: state.leaderboards.length + (state.hasMore ? 1 : 0),
                separatorBuilder: (context, index) => AppSpacing.vMd,
                itemBuilder: (context, index) {
                  if (index == state.leaderboards.length) {
                    context.read<LeaderboardBloc>().add(
                          const LeaderboardLoadMore(),
                        );
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: LoadingIndicator(),
                      ),
                    );
                  }
                  return RepaintBoundary(
                    child: _LeaderboardCard(
                      key: ValueKey(state.leaderboards[index].id),
                      leaderboard: state.leaderboards[index],
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 排行榜卡片 - 对标iOS LeaderboardCard样式
/// 封面图(90x90) + 标题 + 描述 + 位置 + 分隔线 + 统计行(项目/投票/浏览)
class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({super.key, required this.leaderboard});

  final Leaderboard leaderboard;

  List<Color> get _gradient {
    final hash = leaderboard.id.hashCode;
    final gradients = [
      AppColors.gradientCoral,
      AppColors.gradientPurple,
      AppColors.gradientEmerald,
      AppColors.gradientOrange,
      AppColors.gradientIndigo,
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _gradient;

    return GestureDetector(
      onTap: () {
        context.push('/leaderboard/${leaderboard.id}');
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
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
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          children: [
            // 封面 + 标题/描述/位置
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面图片或渐变占位 (对标iOS 100x100)
                leaderboard.coverImage != null &&
                        leaderboard.coverImage!.isNotEmpty
                    ? AsyncImageView(
                        imageUrl: leaderboard.coverImage,
                        width: 90,
                        height: 90,
                        borderRadius: BorderRadius.circular(14),
                        errorWidget: _buildPlaceholderIcon(colors),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildPlaceholderIcon(colors),
                      ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        leaderboard.displayName(Localizations.localeOf(context)),
                        style: AppTypography.bodyBold.copyWith(
                          fontSize: 17,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (leaderboard.displayDescription(Localizations.localeOf(context)) != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          leaderboard.displayDescription(Localizations.localeOf(context))!,
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      if (leaderboard.location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                leaderboard.location,
                                style: AppTypography.caption2.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // 分隔线
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(
                height: 1,
                color: (isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight)
                    .withValues(alpha: 0.3),
              ),
            ),

            // 统计行 (对标iOS CompactStatItem: items + votes + views)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _CompactStat(
                  icon: Icons.grid_view,
                  count: leaderboard.itemCount,
                  isDark: isDark,
                ),
                _CompactStat(
                  icon: Icons.thumb_up_outlined,
                  count: leaderboard.voteCount,
                  isDark: isDark,
                ),
                _CompactStat(
                  icon: Icons.visibility_outlined,
                  count: leaderboard.viewCount,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(
                  leaderboard.isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                  color: leaderboard.isFavorited ? AppColors.error : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
                onPressed: () {
                  AppHaptics.selection();
                  context.read<LeaderboardBloc>().add(
                    LeaderboardToggleFavorite(leaderboard.id),
                  );
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: context.l10n.forumFavorite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon(List<Color> colors) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.emoji_events, color: Colors.white, size: 36),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
    required this.icon,
    required this.count,
    required this.isDark,
  });

  final IconData icon;
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
