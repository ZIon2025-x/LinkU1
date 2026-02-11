import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/custom_share_panel.dart';
import '../../../core/widgets/animated_like_button.dart';
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
  int? _replyToId;
  String? _replyToName;

  @override
  void dispose() {
    _replyController.dispose();
    super.dispose();
  }

  void _setReplyTo(int replyId, String authorName) {
    setState(() {
      _replyToId = replyId;
      _replyToName = authorName;
    });
    _replyController.clear();
    // TODO: Focus the text field
  }

  void _clearReplyTo() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
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
          title: Text(context.l10n.forumPostDetail),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () {
                AppHaptics.selection();
                CustomSharePanel.show(
                  context,
                  title: context.l10n.forumPostDetail,
                  description: '',
                  url: 'https://link2ur.com/forum/posts/${widget.postId}',
                );
              },
            ),
          ],
        ),
        body: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: ResponsiveUtils.detailMaxWidth(context)),
            child: BlocBuilder<ForumBloc, ForumState>(
              buildWhen: (previous, current) =>
                  previous.status != current.status ||
                  previous.selectedPost != current.selectedPost ||
                  previous.replies != current.replies,
              builder: (context, state) {
            if (state.status == ForumStatus.loading &&
                state.selectedPost == null) {
              return const SkeletonPostDetail();
            }

            if (state.status == ForumStatus.error &&
                state.selectedPost == null) {
              return ErrorStateView.loadFailed(
                message: state.errorMessage ?? context.l10n.forumLoadFailed,
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

                  // 图片区域
                  if (post.images.isNotEmpty)
                    _PostImages(images: post.images),

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
                    onReplyTo: _setReplyTo,
                  ),

                  const SizedBox(height: 88),
                ],
              ),
            );
          },
            ),
          ),
        ),
        // 底部回复栏 - 对标iOS bottomReplyBar with ultraThinMaterial
        bottomNavigationBar: _buildBottomReplyBar(context),
      ),
    );
  }

  Widget _buildBottomReplyBar(BuildContext context) {
    return BlocBuilder<ForumBloc, ForumState>(
      buildWhen: (previous, current) =>
          previous.selectedPost != current.selectedPost ||
          previous.isReplying != current.isReplying,
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 回复目标提示条
                      if (_replyToName != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 6),
                          color: AppColors.primary.withValues(alpha: 0.05),
                          child: Row(
                            children: [
                              Text(
                                '${context.l10n.forumReplyTo} @$_replyToName',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.primary,
                                ),
                              ),
                              const Spacer(),
                              GestureDetector(
                                onTap: _clearReplyTo,
                                child: const Icon(Icons.close,
                                    size: 16, color: AppColors.textTertiaryLight),
                              ),
                            ],
                          ),
                        ),
                      Row(
                        children: [
                          // 点赞按钮 — 带粒子爆炸动画
                          if (post != null) ...[
                            AnimatedLikeButton(
                              isLiked: post.isLiked,
                              size: 22,
                              likedColor: AppColors.accentPink,
                              onTap: () {
                                context
                                    .read<ForumBloc>()
                                    .add(ForumLikePost(widget.postId));
                              },
                            ),
                            const SizedBox(width: 12),
                          ],

                          // 回复输入框
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
                                      decoration: InputDecoration(
                                        hintText: _replyToName != null
                                            ? '${context.l10n.forumReplyTo} @$_replyToName'
                                            : context.l10n.forumWriteComment,
                                        hintStyle: const TextStyle(fontSize: 15),
                                        border: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                                horizontal: 16),
                                      ),
                                    ),
                                  ),
                                  // 发送按钮
                                  ValueListenableBuilder<TextEditingValue>(
                                    valueListenable: _replyController,
                                    builder: (context, value, child) {
                                      if (value.text.trim().isEmpty) return const SizedBox.shrink();
                                      return Padding(
                                        padding: const EdgeInsets.only(right: 4),
                                        child: GestureDetector(
                                          onTap: state.isReplying
                                              ? null
                                              : () {
                                                  AppHaptics.selection();
                                                  context.read<ForumBloc>().add(
                                                        ForumReplyPost(
                                                          postId: widget.postId,
                                                          content: _replyController
                                                              .text
                                                              .trim(),
                                                          parentReplyId: _replyToId,
                                                        ),
                                                      );
                                                  _replyController.clear();
                                                  _clearReplyTo();
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
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
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
                      text: context.l10n.forumPinned,
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
            style: AppTypography.title2.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          const SizedBox(height: 12),

          // 作者行 - 对标iOS author row (avatar + name + time)
          Row(
            children: [
              // 头像 — 点击跳转个人主页
              GestureDetector(
                onTap: () => context.goToUserProfile(post.authorId.toString()),
                child: Container(
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
                  child: AvatarView(
                    imageUrl: post.author?.avatar,
                    name: post.author?.name,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.goToUserProfile(post.authorId.toString()),
                          child: Text(
                            post.author?.name ?? context.l10n.forumUserFallback(post.authorId.toString()),
                            style: AppTypography.subheadlineBold.copyWith(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatTime(context, post.createdAt),
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

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) return context.l10n.timeDaysAgo(difference.inDays);
    if (difference.inHours > 0) return context.l10n.timeHoursAgo(difference.inHours);
    if (difference.inMinutes > 0) return context.l10n.timeMinutesAgo(difference.inMinutes);
    return context.l10n.timeJustNow;
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
        style: AppTypography.body.copyWith(
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
            label: context.l10n.forumBrowse,
          ),
          const SizedBox(width: 24),
          // 点赞已移至底部回复栏，此处仅显示计数
          _StatLabel(
            icon: post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
            value: '${post.likeCount}',
            label: context.l10n.forumLike,
            color: post.isLiked ? AppColors.accentPink : null,
          ),
          const SizedBox(width: 24),
          // 收藏 (交互)
          GestureDetector(
            onTap: () {
              AppHaptics.selection();
              context.read<ForumBloc>().add(ForumFavoritePost(postId));
            },
            child: _StatLabel(
              icon: post.isFavorited
                  ? Icons.bookmark
                  : Icons.bookmark_border,
              value: '',
              label: context.l10n.forumFavorite,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final c = color ?? defaultColor;
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
          style: TextStyle(fontSize: 10, color: defaultColor),
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
    required this.onReplyTo,
  });

  final List<ForumReply> replies;
  final bool isDark;
  final int postId;
  final void Function(int replyId, String authorName) onReplyTo;

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
                context.l10n.forumAllReplies,
                style: AppTypography.title3.copyWith(
                  fontSize: 18,
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
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.forumNoReplies,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
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
                  _ReplyCard(reply: reply, isDark: isDark, postId: postId, onReplyTo: onReplyTo),
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
    required this.onReplyTo,
  });

  final ForumReply reply;
  final bool isDark;
  final int postId;
  final void Function(int replyId, String authorName) onReplyTo;

  @override
  Widget build(BuildContext context) {
    final isSubReply = reply.isSubReply;

    return Padding(
      padding: EdgeInsets.only(
        top: 16,
        bottom: 16,
        left: isSubReply ? 32 : 0, // 子回复缩进
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头像 — 点击跳转个人主页
          GestureDetector(
            onTap: () => context.goToUserProfile(reply.authorId.toString()),
            child: Container(
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
              child: AvatarView(
                imageUrl: reply.author?.avatar,
                name: reply.author?.name,
                size: isSubReply ? 28 : 32,
              ),
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
                    GestureDetector(
                      onTap: () => context.goToUserProfile(reply.authorId.toString()),
                      child: Text(
                        reply.author?.name ?? context.l10n.forumUserFallback(reply.authorId.toString()),
                        style: TextStyle(
                          fontSize: isSubReply ? 13 : 14,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _formatTime(context, reply.createdAt),
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
                            ? AppColors.accentPink.withValues(alpha: 0.1)
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
                                ? AppColors.accentPink
                                : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                          ),
                          if (reply.likeCount > 0) ...[
                            const SizedBox(width: 3),
                            Text(
                              '${reply.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: reply.isLiked
                                    ? AppColors.accentPink
                                    : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                // 嵌套回复引用块 — "回复 @xxx"
                if (isSubReply)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.04)
                            : AppColors.skeletonBase.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        reply.parentReplyAuthor != null
                            ? '${context.l10n.forumReplyTo} @${reply.parentReplyAuthor!.name}'
                            : context.l10n.forumReplyTo,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.primary.withValues(alpha: 0.8),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ),

                const SizedBox(height: 6),
                // 内容
                Padding(
                  padding: const EdgeInsets.only(right: 42),
                  child: Text(
                    reply.content,
                    style: (isSubReply ? AppTypography.footnote : AppTypography.subheadline).copyWith(
                      fontSize: isSubReply ? 14 : null,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                // 回复按钮
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    AppHaptics.selection();
                    onReplyTo(
                      reply.id,
                      reply.author?.name ?? reply.authorId.toString(),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        context.l10n.forumReply,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
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

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0) return context.l10n.timeDaysAgo(difference.inDays);
    if (difference.inHours > 0) return context.l10n.timeHoursAgo(difference.inHours);
    if (difference.inMinutes > 0) return context.l10n.timeMinutesAgo(difference.inMinutes);
    return context.l10n.timeJustNow;
  }
}

// ==================== 帖子图片区域 ====================

class _PostImages extends StatelessWidget {
  const _PostImages({required this.images});
  final List<String> images;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: _buildImageLayout(context),
    );
  }

  Widget _buildImageLayout(BuildContext context) {
    if (images.length == 1) {
      // 单张全宽
      return GestureDetector(
        onTap: () => _openFullScreen(context, 0),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AsyncImageView(
            imageUrl: images[0],
            width: double.infinity,
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    if (images.length == 2) {
      // 2张并排
      return Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => _openFullScreen(context, 0),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
                child: AsyncImageView(
                  imageUrl: images[0],
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: GestureDetector(
              onTap: () => _openFullScreen(context, 1),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
                child: AsyncImageView(
                  imageUrl: images[1],
                  width: double.infinity,
                  height: 180,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ],
      );
    }

    // 3+ 张网格
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => _openFullScreen(context, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AsyncImageView(
              imageUrl: images[index],
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  void _openFullScreen(BuildContext context, int index) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => FullScreenImageView(
        images: images,
        initialIndex: index,
      ),
    ));
  }
}
