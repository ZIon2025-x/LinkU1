import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/models/forum.dart';
import '../bloc/forum_bloc.dart';

/// 帖子详情页
/// 参考iOS ForumPostDetailView.swift
class ForumPostDetailView extends StatelessWidget {
  const ForumPostDetailView({
    super.key,
    required this.postId,
  });

  final int postId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )
        ..add(ForumLoadPostDetail(postId))
        ..add(ForumLoadReplies(postId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('帖子详情'),
          actions: [
            IconButton(icon: const Icon(Icons.share_outlined), onPressed: () {}),
          ],
        ),
        body: BlocBuilder<ForumBloc, ForumState>(
          builder: (context, state) {
            if (state.status == ForumStatus.loading &&
                state.selectedPost == null) {
              return const LoadingView();
            }

            if (state.status == ForumStatus.error &&
                state.selectedPost == null) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '加载失败',
                onRetry: () {
                  context.read<ForumBloc>()
                    ..add(ForumLoadPostDetail(postId))
                    ..add(ForumLoadReplies(postId));
                },
              );
            }

            if (state.selectedPost == null) {
              return ErrorStateView.notFound();
            }

            final post = state.selectedPost!;

            return SingleChildScrollView(
              padding: AppSpacing.allMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 用户信息
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: AppColors.primary,
                        backgroundImage: post.author?.avatar != null
                            ? NetworkImage(post.author!.avatar!)
                            : null,
                        child: post.author?.avatar == null
                            ? const Icon(Icons.person, color: Colors.white)
                            : null,
                      ),
                      AppSpacing.hMd,
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.author?.name ?? '用户 ${post.authorId}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              _formatTime(post.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  AppSpacing.vLg,

                  // 标题
                  Text(
                    post.title,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  AppSpacing.vMd,

                  // 内容
                  if (post.content != null)
                    Text(
                      post.content!,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondaryLight,
                        height: 1.6,
                      ),
                    ),
                  AppSpacing.vXl,

                  // 互动栏
                  Row(
                    children: [
                      _ActionButton(
                        icon: post.isLiked
                            ? Icons.thumb_up
                            : Icons.thumb_up_outlined,
                        label: '点赞',
                        count: post.likeCount,
                        isActive: post.isLiked,
                        onTap: () {
                          context.read<ForumBloc>().add(ForumLikePost(postId));
                        },
                      ),
                      AppSpacing.hLg,
                      _ActionButton(
                        icon: post.isFavorited
                            ? Icons.favorite
                            : Icons.favorite_outline,
                        label: '收藏',
                        count: 0,
                        isActive: post.isFavorited,
                        onTap: () {
                          context.read<ForumBloc>().add(ForumFavoritePost(postId));
                        },
                      ),
                      AppSpacing.hLg,
                      _ActionButton(
                        icon: Icons.comment_outlined,
                        label: '评论',
                        count: post.replyCount,
                        onTap: () {},
                      ),
                    ],
                  ),
                  AppSpacing.vXl,

                  // 评论列表
                  const Divider(),
                  AppSpacing.vMd,
                  const Text('评论', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                  AppSpacing.vMd,
                  if (state.replies.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Text(
                        '暂无评论',
                        style: TextStyle(
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    )
                  else
                    ...state.replies.map((reply) => _CommentItem(reply: reply)),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: BlocBuilder<ForumBloc, ForumState>(
          builder: (context, state) {
            final replyController = TextEditingController();
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: TextField(
                  controller: replyController,
                  enabled: !state.isReplying,
                  decoration: InputDecoration(
                    hintText: '写评论...',
                    suffixIcon: state.isReplying
                        ? const Padding(
                            padding: EdgeInsets.all(12.0),
                            child: LoadingIndicator(size: 20),
                          )
                        : IconButton(
                            icon: const Icon(Icons.send, color: AppColors.primary),
                            onPressed: () {
                              if (replyController.text.trim().isNotEmpty) {
                                context.read<ForumBloc>().add(
                                      ForumReplyPost(
                                        postId: postId,
                                        content: replyController.text.trim(),
                                      ),
                                    );
                                replyController.clear();
                              }
                            },
                          ),
                  ),
                ),
              ),
            );
          },
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.count,
    this.isActive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final int count;
  final bool isActive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive
                ? AppColors.primary
                : AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: isActive
                  ? AppColors.primary
                  : AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentItem extends StatelessWidget {
  const _CommentItem({required this.reply});

  final ForumReply reply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.skeletonBase,
            backgroundImage: reply.author?.avatar != null
                ? NetworkImage(reply.author!.avatar!)
                : null,
            child: reply.author?.avatar == null
                ? const Icon(Icons.person, size: 18, color: AppColors.textTertiaryLight)
                : null,
          ),
          AppSpacing.hSm,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      reply.author?.name ?? '用户 ${reply.authorId}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(reply.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply.content,
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
        ],
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
