import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/leaderboard.dart';
import '../bloc/forum_bloc.dart';
import '../../leaderboard/bloc/leaderboard_bloc.dart';

/// 论坛页
/// 参考iOS ForumView.swift
class ForumView extends StatelessWidget {
  const ForumView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('社区'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '论坛'),
              Tab(text: '排行榜'),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryLight,
            indicatorColor: AppColors.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _ForumTab(),
            _LeaderboardTab(),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            context.push('/forum/posts/create');
          },
          backgroundColor: AppColors.primary,
          child: const Icon(Icons.edit, color: Colors.white),
        ),
      ),
    );
  }
}

class _ForumTab extends StatelessWidget {
  const _ForumTab();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )..add(const ForumLoadPosts()),
      child: BlocBuilder<ForumBloc, ForumState>(
        builder: (context, state) {
          if (state.status == ForumStatus.loading && state.posts.isEmpty) {
            return const LoadingView();
          }

          if (state.status == ForumStatus.error && state.posts.isEmpty) {
            return ErrorStateView.loadFailed(
              message: state.errorMessage ?? '加载失败',
              onRetry: () {
                context.read<ForumBloc>().add(const ForumLoadPosts());
              },
            );
          }

          if (state.posts.isEmpty) {
            return EmptyStateView.noData(
              title: '暂无帖子',
              description: '还没有帖子，点击下方按钮发布第一个帖子',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ForumBloc>().add(const ForumRefreshRequested());
            },
            child: ListView.separated(
              padding: AppSpacing.allMd,
              itemCount: state.posts.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (context, index) => AppSpacing.vMd,
              itemBuilder: (context, index) {
                if (index == state.posts.length) {
                  // Load more trigger
                  context.read<ForumBloc>().add(const ForumLoadMorePosts());
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: LoadingIndicator(),
                    ),
                  );
                }
                return _PostCard(post: state.posts[index]);
              },
            ),
          );
        },
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      )..add(const LeaderboardLoadRequested()),
      child: BlocBuilder<LeaderboardBloc, LeaderboardState>(
        builder: (context, state) {
          if (state.status == LeaderboardStatus.loading &&
              state.leaderboards.isEmpty) {
            return const LoadingView();
          }

          if (state.status == LeaderboardStatus.error &&
              state.leaderboards.isEmpty) {
            return ErrorStateView.loadFailed(
              message: state.errorMessage ?? '加载失败',
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
              itemCount: state.leaderboards.length +
                  (state.hasMore ? 1 : 0),
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
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/forum/posts/${post.id}');
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primary,
                  backgroundImage: post.author?.avatar != null
                      ? NetworkImage(post.author!.avatar!)
                      : null,
                  child: post.author?.avatar == null
                      ? const Icon(Icons.person, color: Colors.white, size: 20)
                      : null,
                ),
                AppSpacing.hSm,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author?.name ?? '用户 ${post.authorId}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            AppSpacing.vMd,

            // 标题
            Text(
              post.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            AppSpacing.vSm,

            // 内容
            if (post.content != null)
              Text(
                post.content!,
                style: TextStyle(color: AppColors.textSecondaryLight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            AppSpacing.vMd,

            // 互动
            Row(
              children: [
                Icon(
                  post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 16,
                  color: post.isLiked
                      ? AppColors.primary
                      : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.comment_outlined,
                  size: 16,
                  color: AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.replyCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}天前';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}小时前';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}分钟前';
    } else {
      return '刚刚';
    }
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
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: AppRadius.allMedium,
              ),
              child: const Icon(Icons.leaderboard, color: AppColors.primary),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leaderboard.displayName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${leaderboard.itemCount} 个竞品',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryLight,
                    ),
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
