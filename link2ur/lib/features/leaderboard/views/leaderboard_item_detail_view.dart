import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../bloc/leaderboard_bloc.dart';

/// 排行榜条目详情页
/// 参考iOS LeaderboardItemDetailView.swift
class LeaderboardItemDetailView extends StatelessWidget {
  const LeaderboardItemDetailView({super.key, required this.itemId});

  final int itemId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      )..add(LeaderboardLoadItemDetail(itemId)),
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.leaderboardItemDetail),
        ),
        body: BlocBuilder<LeaderboardBloc, LeaderboardState>(
          builder: (context, state) {
            if (state.isLoading) {
              return const LoadingView();
            }

            if (state.errorMessage != null) {
              return ErrorStateView(
                message: state.errorMessage!,
                onRetry: () => context
                    .read<LeaderboardBloc>()
                    .add(LeaderboardLoadItemDetail(itemId)),
              );
            }

            final item = state.itemDetail;
            if (item == null) {
              return const SizedBox.shrink();
            }

            return SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 排名与得分
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius:
                          BorderRadius.circular(AppRadius.large),
                    ),
                    child: Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildRankInfo(
                          l10n.leaderboardRank,
                          '#${item['rank'] ?? '-'}',
                        ),
                        Container(
                          width: 1,
                          height: 40,
                          color: Colors.white.withValues(alpha: 0.3),
                        ),
                        _buildRankInfo(
                          l10n.leaderboardScore,
                          '${item['score'] ?? 0}',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // 用户信息
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius:
                          BorderRadius.circular(AppRadius.large),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundImage:
                              item['avatar'] != null
                                  ? NetworkImage(
                                      item['avatar'] as String)
                                  : null,
                          child: item['avatar'] == null
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'] as String? ??
                                    '',
                                style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight:
                                        FontWeight.w600),
                              ),
                              if (item['description'] !=
                                  null)
                                Text(
                                  item['description']
                                      as String,
                                  style: const TextStyle(
                                      fontSize: 13,
                                      color: AppColors
                                          .textSecondary),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRankInfo(String label, String value) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white)),
        const SizedBox(height: 4),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.8))),
      ],
    );
  }
}
