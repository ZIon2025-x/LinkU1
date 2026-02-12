import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/forum.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/forum_bloc.dart';

/// 论坛帖子列表页（按分类筛选）
/// 参考iOS ForumPostListView.swift
class ForumPostListView extends StatelessWidget {
  const ForumPostListView({super.key, this.category});

  final ForumCategory? category;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )..add(ForumLoadPosts(categoryId: category?.id))
        ..add(ForumCategoryChanged(category?.id)),
      child: _ForumPostListViewContent(category: category),
    );
  }
}

class _ForumPostListViewContent extends StatefulWidget {
  const _ForumPostListViewContent({this.category});

  final ForumCategory? category;

  @override
  State<_ForumPostListViewContent> createState() =>
      _ForumPostListViewContentState();
}

class _ForumPostListViewContentState
    extends State<_ForumPostListViewContent> {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer();

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
      appBar: AppBar(
        title: Text(
            widget.category?.displayName ?? l10n.forumAllPosts),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle, color: AppColors.primary),
            onPressed: () => context.push('/forum/posts/create'),
          ),
        ],
      ),
      body: Column(
        children: [
          // 搜索栏
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.forumSearchPosts,
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.large),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.cardBackground,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                _debouncer.call(() {
                  if (!mounted) return;
                  context
                      .read<ForumBloc>()
                      .add(ForumSearchChanged(value.isEmpty ? '' : value));
                });
              },
            ),
          ),

          // 内容
          Expanded(
            child: BlocBuilder<ForumBloc, ForumState>(
                  buildWhen: (prev, curr) =>
                  prev.posts != curr.posts ||
                  prev.status != curr.status ||
                  prev.errorMessage != curr.errorMessage ||
                  prev.hasMore != curr.hasMore ||
                  prev.loadMoreError != curr.loadMoreError ||
                  prev.isLoadingMore != curr.isLoadingMore,
              builder: (context, state) {
                final posts = state.posts;
                final isLoading = state.status == ForumStatus.loading;
                final errorMessage = state.errorMessage;

                if (isLoading && posts.isEmpty) {
                  return const SkeletonList();
                }
                if (errorMessage != null && posts.isEmpty) {
                  return ErrorStateView(
                    message: errorMessage,
                    onRetry: () => context.read<ForumBloc>().add(
                        ForumLoadPosts(categoryId: widget.category?.id)),
                  );
                }
                if (posts.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.article_outlined,
                    title: l10n.forumNoPosts,
                    message: l10n.forumNoPostsMessage,
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    context.read<ForumBloc>().add(
                        ForumLoadPosts(categoryId: widget.category?.id));
                  },
                  child: ListView.separated(
                    clipBehavior: Clip.none,
                    cacheExtent: 500,
                    padding: EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.md,
                      top: AppSpacing.sm,
                      bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                    ),
                    itemCount: posts.length + (state.hasMore ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      if (index == posts.length) {
                        if (!state.isLoadingMore) {
                          context.read<ForumBloc>().add(
                              const ForumLoadMorePosts());
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: LoadingIndicator(),
                          ),
                        );
                      }
                      final post = posts[index];
                      return RepaintBoundary(
                        child: _PostCard(
                          key: ValueKey(post.id),
                          post: post,
                          onTap: () =>
                              context.safePush('/forum/posts/${post.id}'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({super.key, required this.post, this.onTap});

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
            // 标签
            if (post.isPinned)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.push_pin,
                        size: 12, color: AppColors.error),
                    const SizedBox(width: 4),
                    Text(context.l10n.forumPinned,
                        style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.error,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ),

            // 标题
            Text(
              post.title,
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // 内容预览（后端列表接口返回 content_preview，非 content）
            if (post.displayContent != null && post.displayContent!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post.displayContent!,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: AppSpacing.sm),

            // 底部信息
            Row(
              children: [
                // 作者
                if (post.author != null) ...[
                  AvatarView(
                    imageUrl: post.author!.avatar,
                    name: post.author!.name,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    post.author!.name,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary),
                  ),
                ],
                const Spacer(),
                // 统计
                _StatChip(
                    icon: Icons.visibility, count: post.viewCount),
                const SizedBox(width: 12),
                _StatChip(
                    icon: Icons.chat_bubble_outline,
                    count: post.replyCount),
                const SizedBox(width: 12),
                _StatChip(
                  icon: post.isLiked
                      ? Icons.favorite
                      : Icons.favorite_border,
                  count: post.likeCount,
                  isActive: post.isLiked,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.count,
    this.isActive = false,
  });

  final IconData icon;
  final int count;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.error : AppColors.textTertiary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 3),
        Text('$count',
            style: TextStyle(fontSize: 12, color: color)),
      ],
    );
  }
}
