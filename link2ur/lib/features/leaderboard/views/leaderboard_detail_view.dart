import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/models/leaderboard.dart';
import '../bloc/leaderboard_bloc.dart';

/// 排行榜详情页
/// 参考iOS LeaderboardDetailView.swift
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
      child: Scaffold(
        appBar: AppBar(
          title: BlocBuilder<LeaderboardBloc, LeaderboardState>(
            builder: (context, state) {
              return Text(
                state.selectedLeaderboard?.displayName ?? '排行榜详情',
              );
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              tooltip: '申请排行榜',
              onPressed: () => context.push('/leaderboard/apply'),
            ),
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
          ],
        ),
        body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
          builder: (context, state) {
            if (state.status == LeaderboardStatus.loading &&
                state.selectedLeaderboard == null) {
              return const LoadingView();
            }

            if (state.status == LeaderboardStatus.error &&
                state.selectedLeaderboard == null) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '加载失败',
                onRetry: () {
                  context.read<LeaderboardBloc>().add(
                        LeaderboardLoadDetail(leaderboardId),
                      );
                },
              );
            }

            if (state.selectedLeaderboard == null) {
              return ErrorStateView.notFound();
            }

            if (state.items.isEmpty) {
              return EmptyStateView.noData(
                title: '暂无竞品',
                description: '还没有竞品，点击下方按钮提交第一个竞品',
              );
            }

            // Sort items by vote count (descending)
            final sortedItems = List<LeaderboardItem>.from(state.items)
              ..sort((a, b) => b.netVotes.compareTo(a.netVotes));

            return ListView.separated(
              padding: AppSpacing.allMd,
              itemCount: sortedItems.length,
              separatorBuilder: (context, index) => AppSpacing.vSm,
              itemBuilder: (context, index) {
                final item = sortedItems[index];
                return GestureDetector(
                  onTap: () => context.push('/leaderboard/item/${item.id}'),
                  child: _RankItem(
                    item: item,
                    rank: index + 1,
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => context.push('/leaderboard/$leaderboardId/submit'),
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add, color: Colors.white),
          label: const Text('提交竞品', style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }
}

class _RankItem extends StatelessWidget {
  const _RankItem({required this.item, required this.rank});

  final LeaderboardItem item;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final isTop3 = rank <= 3;

    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: AppRadius.allMedium,
        border: isTop3 ? Border.all(color: _getRankColor(rank).withValues(alpha: 0.5)) : null,
      ),
      child: Row(
        children: [
          // 排名
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isTop3 ? _getRankColor(rank) : AppColors.skeletonBase,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  color: isTop3 ? Colors.white : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          AppSpacing.hMd,

          // 图片
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.skeletonBase,
              borderRadius: AppRadius.allSmall,
            ),
            child: item.firstImage != null
                ? ClipRRect(
                    borderRadius: AppRadius.allSmall,
                    child: Image.network(
                      item.firstImage!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image, color: AppColors.textTertiaryLight);
                      },
                    ),
                  )
                : const Icon(Icons.image, color: AppColors.textTertiaryLight),
          ),
          AppSpacing.hMd,

          // 信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Text(
                  '${item.netVotes} 票',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),

          // 投票按钮
          Row(
            children: [
              IconButton(
                icon: Icon(
                  item.hasUpvoted ? Icons.thumb_up : Icons.thumb_up_outlined,
                ),
                onPressed: () {
                  context.read<LeaderboardBloc>().add(
                        LeaderboardVoteItem(item.id),
                      );
                },
                iconSize: 20,
                color: item.hasUpvoted ? AppColors.success : AppColors.textSecondaryLight,
              ),
              IconButton(
                icon: Icon(
                  item.hasDownvoted ? Icons.thumb_down : Icons.thumb_down_outlined,
                ),
                onPressed: () {
                  // Note: The current bloc only has one vote event
                  // You may need to add separate upvote/downvote events
                  context.read<LeaderboardBloc>().add(
                        LeaderboardVoteItem(item.id),
                      );
                },
                iconSize: 20,
                color: item.hasDownvoted ? AppColors.error : AppColors.textSecondaryLight,
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
