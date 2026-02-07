import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/l10n_extension.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/leaderboard.dart';
import '../bloc/forum_bloc.dart';
import '../../leaderboard/bloc/leaderboard_bloc.dart';

/// 社区页 (论坛 + 排行榜)
/// 对标iOS CommunityView (MainTabView.swift)
/// 使用自定义居中TabButton + PageView滑动切换，与首页风格一致
class ForumView extends StatefulWidget {
  const ForumView({super.key});

  @override
  State<ForumView> createState() => _ForumViewState();
}

class _ForumViewState extends State<ForumView> {
  int _selectedTab = 0; // 0: 论坛, 1: 排行榜
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (_selectedTab != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedTab = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // 对标iOS CommunityView: 自定义顶部导航栏（类似首页样式）
            _buildCustomAppBar(isDark),

            // 内容区域 - 对标iOS TabView(.page)
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _selectedTab = index;
                  });
                },
                children: const [
                  _ForumTab(),
                  _LeaderboardTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/forum/posts/create');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  /// 对标iOS CommunityView: HStack自定义顶部导航栏
  Widget _buildCustomAppBar(bool isDark) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Row(
        children: [
          // 左侧占位（保持对称）
          const SizedBox(width: 44),

          const Spacer(),

          // 对标iOS: 中间两个标签
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _CommunityTabButton(
                title: context.l10n.communityForum,
                isSelected: _selectedTab == 0,
                onTap: () => _onTabChanged(0),
              ),
              _CommunityTabButton(
                title: context.l10n.communityLeaderboard,
                isSelected: _selectedTab == 1,
                onTap: () => _onTabChanged(1),
              ),
            ],
          ),

          const Spacer(),

          // 右侧占位（保持对称）
          const SizedBox(width: 44),
        ],
      ),
    );
  }
}

/// 对标iOS TabButton - 与首页风格一致
class _CommunityTabButton extends StatelessWidget {
  const _CommunityTabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              height: 3,
              width: isSelected ? 28 : 0,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.allPill,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 论坛Tab
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
              message: state.errorMessage ?? context.l10n.tasksLoadFailed,
              onRetry: () {
                context.read<ForumBloc>().add(const ForumLoadPosts());
              },
            );
          }

          if (state.posts.isEmpty) {
            return EmptyStateView.noData(
              title: context.l10n.forumNoPosts,
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

/// 排行榜Tab
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

/// 帖子卡片
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.push('/forum/posts/${post.id}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
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
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w500,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      Text(
                        _formatTime(post.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
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
              style: AppTypography.bodyBold.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            AppSpacing.vSm,

            // 内容
            if (post.content != null)
              Text(
                post.content!,
                style: AppTypography.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
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
                      : (isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.comment_outlined,
                  size: 16,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.replyCount}',
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
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

/// 排行榜卡片
class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.leaderboard});

  final Leaderboard leaderboard;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.push('/leaderboard/${leaderboard.id}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
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
              child: const Icon(Icons.emoji_events, color: AppColors.primary),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    leaderboard.displayName,
                    style: AppTypography.bodyBold.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${leaderboard.itemCount} 个竞品',
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
