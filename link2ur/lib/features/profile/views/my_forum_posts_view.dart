import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/forum.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../bloc/profile_bloc.dart';

/// 我的论坛帖子页（发布/收藏/喜欢）
/// 参考iOS MyForumPostsView.swift
class MyForumPostsView extends StatefulWidget {
  const MyForumPostsView({super.key});

  @override
  State<MyForumPostsView> createState() => _MyForumPostsViewState();
}

class _MyForumPostsViewState extends State<MyForumPostsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _blocProviderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final context = _blocProviderKey.currentContext;
    if (context == null) return;
    final bloc = context.read<ProfileBloc>();
    final state = bloc.state;
    switch (_tabController.index) {
      case 0:
        if (state.myForumPosts.isEmpty) {
          bloc.add(const ProfileLoadMyForumActivity(type: 'posts', page: 1));
        }
        break;
      case 1:
        if (state.favoritedPosts.isEmpty) {
          bloc.add(const ProfileLoadMyForumActivity(type: 'favorited', page: 1));
        }
        break;
      case 2:
        if (state.likedPosts.isEmpty) {
          bloc.add(const ProfileLoadMyForumActivity(type: 'liked', page: 1));
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      )..add(const ProfileLoadMyForumActivity(type: 'posts', page: 1)),
      child: BlocBuilder<ProfileBloc, ProfileState>(
        key: _blocProviderKey,
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(l10n.forumMyPosts),
              bottom: TabBar(
                controller: _tabController,
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(
                    icon: const Icon(Icons.article, size: 18),
                    text: l10n.forumMyPostsPosted,
                  ),
                  Tab(
                    icon: const Icon(Icons.star, size: 18),
                    text: l10n.forumMyPostsFavorited,
                  ),
                  Tab(
                    icon: const Icon(Icons.favorite, size: 18),
                    text: l10n.forumMyPostsLiked,
                  ),
                ],
              ),
            ),
            body: TabBarView(
              controller: _tabController,
              children: [
                _buildPostList(
                  context,
                  state.myForumPosts,
                  state.myForumPosts.isEmpty && state.status == ProfileStatus.loading,
                  l10n.forumMyPostsEmptyPosted,
                  'posts',
                ),
                _buildPostList(
                  context,
                  state.favoritedPosts,
                  state.favoritedPosts.isEmpty && state.status == ProfileStatus.loading,
                  l10n.forumMyPostsEmptyFavorited,
                  'favorited',
                ),
                _buildPostList(
                  context,
                  state.likedPosts,
                  state.likedPosts.isEmpty && state.status == ProfileStatus.loading,
                  l10n.forumMyPostsEmptyLiked,
                  'liked',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostList(
    BuildContext context,
    List<ForumPost> posts,
    bool isLoading,
    String emptyMessage,
    String type,
  ) {
    if (isLoading && posts.isEmpty) return const SkeletonList();
    if (posts.isEmpty) {
      return EmptyStateView(
        icon: Icons.article_outlined,
        title: context.l10n.forumNoPosts,
        message: emptyMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProfileBloc>().add(
              ProfileLoadMyForumActivity(type: type, page: 1),
            );
      },
      child: ListView.separated(
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final post = posts[index];
          return RepaintBoundary(
            key: ValueKey(post.id),
            child: _MyPostCard(
              post: post,
              onTap: () => context.safePush('/forum/posts/${post.id}'),
            ),
          );
        },
      ),
    );
  }
}

class _MyPostCard extends StatelessWidget {
  const _MyPostCard({required this.post, this.onTap});

  final ForumPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.content != null && post.content!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                Helpers.normalizeContentNewlines(post.content!),
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                const Icon(Icons.visibility,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${post.viewCount}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary)),
                const SizedBox(width: 12),
                const Icon(Icons.chat_bubble_outline,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${post.replyCount}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary)),
                const SizedBox(width: 12),
                Icon(
                    post.isLiked
                        ? Icons.favorite
                        : Icons.favorite_border,
                    size: 14,
                    color: post.isLiked
                        ? AppColors.error
                        : AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${post.likeCount}',
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
