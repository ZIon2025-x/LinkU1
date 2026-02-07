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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Scaffold(
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
                final bloc = context.read<ForumBloc>();
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (mounted && _searchController.text == value) {
                    bloc.add(ForumSearchChanged(value.isEmpty ? '' : value));
                  }
                });
              },
            ),
          ),

          // 内容
          Expanded(
            child: BlocBuilder<ForumBloc, ForumState>(
              builder: (context, state) {
                final posts = state.posts;
                final isLoading = state.status == ForumStatus.loading;
                final errorMessage = state.errorMessage;

                if (isLoading && posts.isEmpty) {
                  return const LoadingView();
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
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return _PostCard(
                        post: post,
                        onTap: () =>
                            context.push('/forum/posts/${post.id}'),
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
  const _PostCard({required this.post, this.onTap});

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

            // 内容预览
            if (post.content != null && post.content!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                post.content!,
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
                  CircleAvatar(
                    radius: 10,
                    backgroundImage: post.author!.avatar != null
                        ? NetworkImage(post.author!.avatar!)
                        : null,
                    child: post.author!.avatar == null
                        ? const Icon(Icons.person, size: 12)
                        : null,
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
