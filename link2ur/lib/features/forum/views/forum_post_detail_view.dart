import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/models/forum.dart';
import '../bloc/forum_bloc.dart';

/// 帖子详情页 - 对标iOS ForumPostDetailView.swift
class ForumPostDetailView extends StatefulWidget {
  const ForumPostDetailView({
    super.key,
    required this.postId,
  });

  final int postId;

  @override
  State<ForumPostDetailView> createState() => _ForumPostDetailViewState();
}

class _ForumPostDetailViewState extends State<ForumPostDetailView> {
  final _replyController = TextEditingController();

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )
        ..add(ForumLoadPostDetail(widget.postId))
        ..add(ForumLoadReplies(widget.postId)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('帖子详情'),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                HapticFeedback.selectionClick();
              },
            ),
          ],
        ),
        body: BlocBuilder<ForumBloc, ForumState>(
          builder: (context, state) {
            if (state.status == ForumStatus.loading &&
                state.selectedPost == null) {
              return const SkeletonDetail();
            }

            if (state.status == ForumStatus.error &&
                state.selectedPost == null) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? '加载失败',
                onRetry: () {
                  context.read<ForumBloc>()
                    ..add(ForumLoadPostDetail(widget.postId))
                    ..add(ForumLoadReplies(widget.postId));
                },
              );
            }

            if (state.selectedPost == null) {
              return ErrorStateView.notFound();
            }

            final post = state.selectedPost!;
            final isDark = Theme.of(context).brightness == Brightness.dark;

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 帖子头部 - 对标iOS postHeader
                  _PostHeader(post: post, isDark: isDark),

                  const Divider(height: 1),

                  // 帖子内容 - 对标iOS postContent
                  _PostContent(post: post, isDark: isDark),

                  // 互动统计 - 对标iOS postStats
                  _PostStats(
                    post: post,
                    isDark: isDark,
                    postId: widget.postId,
                  ),

                  Divider(
                    height: 1,
                    indent: 20,
                    endIndent: 20,
                    color: (isDark
                            ? AppColors.separatorDark
                            : AppColors.separatorLight)
                        .withValues(alpha: 0.5),
                  ),
                  const SizedBox(height: 8),

                  // 评论区 - 对标iOS replySection
                  _ReplySection(
                    replies: state.replies,
                    isDark: isDark,
                    postId: widget.postId,
                  ),

                  const SizedBox(height: 120),
                ],
              ),
            );
          },
        ),
        // 底部回复栏 - 对标iOS bottomReplyBar with ultraThinMaterial
        bottomNavigationBar: _buildBottomReplyBar(context),
      ),
    );
  }

  Widget _buildBottomReplyBar(BuildContext context) {
    return BlocBuilder<ForumBloc, ForumState>(
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final post = state.selectedPost;

        return ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                color: (isDark
                        ? AppColors.cardBackgroundDark
                        : AppColors.cardBackgroundLight)
                    .withValues(alpha: 0.85),
                border: Border(
                  top: BorderSide(
                    color: (isDark
                            ? AppColors.separatorDark
                            : AppColors.separatorLight)
                        .withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      // 点赞按钮 - 对标iOS like button
                      if (post != null)
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context
                                .read<ForumBloc>()
                                .add(ForumLikePost(widget.postId));
                          },
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(
                              post.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 22,
                              color: post.isLiked
                                  ? AppColors.error
                                  : (isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight),
                            ),
                          ),
                        ),

                      // 回复输入框 - 对标iOS ReplyInputView (pill shape)
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : AppColors.skeletonBase,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _replyController,
                                  enabled: !state.isReplying,
                                  style: const TextStyle(fontSize: 15),
                                  decoration: const InputDecoration(
                                    hintText: '写评论...',
                                    hintStyle: TextStyle(fontSize: 15),
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16),
                                  ),
                                  onChanged: (_) => setState(() {}),
                                ),
                              ),
                              // 发送按钮 - 对标iOS send circle
                              if (_replyController.text.trim().isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(right: 4),
                                  child: GestureDetector(
                                    onTap: state.isReplying
                                        ? null
                                        : () {
                                            HapticFeedback.selectionClick();
                                            context.read<ForumBloc>().add(
                                                  ForumReplyPost(
                                                    postId: widget.postId,
                                                    content: _replyController
                                                        .text
                                                        .trim(),
                                                  ),
                                                );
                                            _replyController.clear();
                                            setState(() {});
                                          },
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: state.isReplying
                                          ? const Padding(
                                              padding: EdgeInsets.all(8),
                                              child:
                                                  CircularProgressIndicator(
                                                      strokeWidth: 2),
                                            )
                                          : const Icon(
                                              Icons.send,
                                              size: 18,
                                              color: AppColors.primary,
                                            ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ==================== 帖子头部 ====================

class _PostHeader extends StatelessWidget {
  const _PostHeader({required this.post, required this.isDark});
  final ForumPost post;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签行 - 对标iOS tags (pinned, category)
          if (post.isPinned || post.category != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (post.isPinned)
                    _TagChip(
                      text: '置顶',
                      color: AppColors.error,
                      icon: Icons.push_pin,
                    ),
                  if (post.category != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        post.category!.name,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // 标题 - 对标iOS 22pt bold
          Text(
            post.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // 作者行 - 对标iOS author row (avatar + name + time)
          Row(
            children: [
              // 头像
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  backgroundImage: post.author?.avatar != null
                      ? NetworkImage(post.author!.avatar!)
                      : null,
                  child: post.author?.avatar == null
                      ? const Icon(Icons.person,
                          color: Colors.white, size: 20)
                      : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          post.author?.name ?? '用户 ${post.authorId}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(post.createdAt),
                      style: TextStyle(
                        fontSize: 12,
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
        ],
      ),
    );
  }

  String _formatTime(DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) return '${difference.inDays}天前';
    if (difference.inHours > 0) return '${difference.inHours}小时前';
    if (difference.inMinutes > 0) return '${difference.inMinutes}分钟前';
    return '刚刚';
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({
    required this.text,
    required this.color,
    required this.icon,
  });

  final String text;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            text,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== 帖子内容 ====================

class _PostContent extends StatelessWidget {
  const _PostContent({required this.post, required this.isDark});
  final ForumPost post;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    if (post.content == null || post.content!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Text(
        post.content!,
        style: TextStyle(
          fontSize: 17,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
          height: 1.8,
        ),
      ),
    );
  }
}

// ==================== 互动统计 ====================

class _PostStats extends StatelessWidget {
  const _PostStats({
    required this.post,
    required this.isDark,
    required this.postId,
  });

  final ForumPost post;
  final bool isDark;
  final int postId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Row(
        children: [
          // 浏览量 (非交互)
          _StatLabel(
            icon: Icons.visibility_outlined,
            value: '${post.viewCount}',
            label: '浏览',
          ),
          const SizedBox(width: 24),
          // 点赞 (交互)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<ForumBloc>().add(ForumLikePost(postId));
            },
            child: _StatLabel(
              icon: post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
              value: '${post.likeCount}',
              label: '点赞',
              color: post.isLiked ? AppColors.error : null,
            ),
          ),
          const SizedBox(width: 24),
          // 收藏 (交互)
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              context.read<ForumBloc>().add(ForumFavoritePost(postId));
            },
            child: _StatLabel(
              icon: post.isFavorited
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              value: '',
              label: '收藏',
              color: post.isFavorited ? Colors.orange : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatLabel extends StatelessWidget {
  const _StatLabel({
    required this.icon,
    required this.value,
    required this.label,
    this.color,
  });

  final IconData icon;
  final String value;
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColors.textTertiaryLight;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            if (value.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: c,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 10, color: AppColors.textTertiaryLight),
        ),
      ],
    );
  }
}

// ==================== 评论区 ====================

class _ReplySection extends StatelessWidget {
  const _ReplySection({
    required this.replies,
    required this.isDark,
    required this.postId,
  });

  final List<ForumReply> replies;
  final bool isDark;
  final int postId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题行 - 对标iOS "All replies" + count capsule
          Row(
            children: [
              Text(
                '全部评论',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.skeletonBase,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${replies.length}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (replies.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 60),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 40,
                      color: AppColors.textTertiaryLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '暂无评论',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...replies.asMap().entries.map((entry) {
              final index = entry.key;
              final reply = entry.value;
              return Column(
                children: [
                  _ReplyCard(reply: reply, isDark: isDark, postId: postId),
                  if (index < replies.length - 1)
                    Divider(
                      height: 1,
                      indent: 42,
                      color: (isDark
                              ? AppColors.separatorDark
                              : AppColors.separatorLight)
                          .withValues(alpha: 0.3),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }
}

// ==================== 评论卡片 ====================

class _ReplyCard extends StatelessWidget {
  const _ReplyCard({
    required this.reply,
    required this.isDark,
    required this.postId,
  });

  final ForumReply reply;
  final bool isDark;
  final int postId;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.skeletonBase,
              backgroundImage: reply.author?.avatar != null
                  ? NetworkImage(reply.author!.avatar!)
                  : null,
              child: reply.author?.avatar == null
                  ? const Icon(Icons.person,
                      size: 14, color: AppColors.textTertiaryLight)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 作者行
                Row(
                  children: [
                    Text(
                      reply.author?.name ?? '用户 ${reply.authorId}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(reply.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                    // 点赞
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: reply.isLiked
                            ? AppColors.error.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            reply.isLiked
                                ? Icons.thumb_up
                                : Icons.thumb_up_outlined,
                            size: 12,
                            color: reply.isLiked
                                ? AppColors.error
                                : AppColors.textTertiaryLight,
                          ),
                          if (reply.likeCount > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '${reply.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: reply.isLiked
                                    ? AppColors.error
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // 内容
                Padding(
                  padding: const EdgeInsets.only(right: 42),
                  child: Text(
                    reply.content,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 回复按钮 - 对标iOS "Reply" pill
                GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '回复',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
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
    if (difference.inDays > 0) return '${difference.inDays}天前';
    if (difference.inHours > 0) return '${difference.inHours}小时前';
    if (difference.inMinutes > 0) return '${difference.inMinutes}分钟前';
    return '刚刚';
  }
}
