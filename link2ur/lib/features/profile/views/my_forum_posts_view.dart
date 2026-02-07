import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/forum.dart';
import '../../../data/repositories/forum_repository.dart';

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

  List<ForumPost> _myPosts = [];
  List<ForumPost> _favoritedPosts = [];
  List<ForumPost> _likedPosts = [];

  bool _isLoadingMy = true;
  bool _isLoadingFavorited = true;
  bool _isLoadingLiked = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMyPosts();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      switch (_tabController.index) {
        case 0:
          if (_myPosts.isEmpty && !_isLoadingMy) _loadMyPosts();
          break;
        case 1:
          if (_favoritedPosts.isEmpty && !_isLoadingFavorited) {
            _loadFavoritedPosts();
          }
          break;
        case 2:
          if (_likedPosts.isEmpty && !_isLoadingLiked) {
            _loadLikedPosts();
          }
          break;
      }
    }
  }

  Future<void> _loadMyPosts() async {
    setState(() => _isLoadingMy = true);
    try {
      final repo = context.read<ForumRepository>();
      final posts = await repo.getMyPosts();
      if (mounted) setState(() { _myPosts = posts.posts; _isLoadingMy = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingMy = false);
    }
  }

  Future<void> _loadFavoritedPosts() async {
    setState(() => _isLoadingFavorited = true);
    try {
      final repo = context.read<ForumRepository>();
      final posts = await repo.getFavoritePosts();
      if (mounted) setState(() { _favoritedPosts = posts.posts; _isLoadingFavorited = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingFavorited = false);
    }
  }

  Future<void> _loadLikedPosts() async {
    setState(() => _isLoadingLiked = true);
    try {
      final repo = context.read<ForumRepository>();
      final posts = await repo.getLikedPosts();
      if (mounted) setState(() { _likedPosts = posts.posts; _isLoadingLiked = false; });
    } catch (_) {
      if (mounted) setState(() => _isLoadingLiked = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

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
          _buildPostList(_myPosts, _isLoadingMy, l10n.forumMyPostsEmptyPosted,
              _loadMyPosts),
          _buildPostList(_favoritedPosts, _isLoadingFavorited,
              l10n.forumMyPostsEmptyFavorited, _loadFavoritedPosts),
          _buildPostList(_likedPosts, _isLoadingLiked,
              l10n.forumMyPostsEmptyLiked, _loadLikedPosts),
        ],
      ),
    );
  }

  Widget _buildPostList(List<ForumPost> posts, bool isLoading,
      String emptyMessage, Future<void> Function() onRefresh) {
    if (isLoading && posts.isEmpty) return const LoadingView();
    if (posts.isEmpty) {
      return EmptyStateView(
        icon: Icons.article_outlined,
        title: context.l10n.forumNoPosts,
        message: emptyMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: posts.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          final post = posts[index];
          return _MyPostCard(
            post: post,
            onTap: () => context.push('/forum/posts/${post.id}'),
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
              color: Colors.black.withOpacity(0.04),
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
                post.content!,
                style: TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Icon(Icons.visibility,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${post.viewCount}',
                    style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiary)),
                const SizedBox(width: 12),
                Icon(Icons.chat_bubble_outline,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text('${post.replyCount}',
                    style: TextStyle(
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
                    style: TextStyle(
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
