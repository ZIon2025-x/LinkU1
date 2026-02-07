import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
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
              return const LoadingView();
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
                title: '暂无排行榜',
                description: '还没有排行榜',
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                context.read<LeaderboardBloc>().add(
                      const LeaderboardRefreshRequested(),
                    );
              },
              child: ListView.separated(
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
                  return _LeaderboardCard(
                    leaderboard: state.leaderboards[index],
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

class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.leaderboard});

  final Leaderboard leaderboard;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/leaderboard/${leaderboard.id}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.allMedium,
              ),
              child: const Icon(Icons.emoji_events, color: AppColors.primary, size: 32),   // trophy.fill
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leaderboard.displayName,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    leaderboard.displayDescription ?? '描述信息...',
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.thumb_up_outlined, size: 14, color: AppColors.textTertiaryLight),   // hand.thumbsup
                      const SizedBox(width: 4),
                      Text(
                        '${leaderboard.voteCount} 票',
                        style: const TextStyle(fontSize: 12, color: AppColors.textTertiaryLight),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }
}
