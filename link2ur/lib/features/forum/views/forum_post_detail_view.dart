import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/utils/native_share.dart';
import '../../../core/widgets/animated_like_button.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/models/forum.dart';
import '../../auth/bloc/auth_bloc.dart';
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
  final _replyFocusNode = FocusNode();
  int? _replyToId;
  String? _replyToName;

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    super.dispose();
  }

  void _setReplyTo(int replyId, String authorName) {
    setState(() {
      _replyToId = replyId;
      _replyToName = authorName;
    });
    _replyController.clear();
    _replyFocusNode.requestFocus();
  }

  void _clearReplyTo() {
    setState(() {
      _replyToId = null;
      _replyToName = null;
    });
  }

  void _showReportDialog(BuildContext context) {
    final reasonController = TextEditingController();
    final bloc = context.read<ForumBloc>();

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(context.l10n.commonReport),
          content: TextField(
            controller: reasonController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: context.l10n.commonReportReason,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(context.l10n.commonCancel),
            ),
            FilledButton(
              onPressed: () {
                final reason = reasonController.text.trim();
                if (reason.isEmpty) return;
                bloc.add(ForumReportPost(widget.postId, reason: reason));
                Navigator.pop(dialogContext);
              },
              child: Text(context.l10n.commonConfirm),
            ),
          ],
        );
      },
    ).then((_) => reasonController.dispose());
  }

  void _showDeletePostDialog(BuildContext context) {
    final bloc = context.read<ForumBloc>();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.commonDelete),
        content: Text(context.l10n.forumDeletePostConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              bloc.add(ForumDeletePost(widget.postId));
              Navigator.pop(dialogContext);
              // 删除成功后再 pop 详情页、显示 SnackBar，由 BlocListener 监听 selectedPost 置空
            },
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )
        ..add(ForumLoadPostDetail(widget.postId))
        ..add(ForumLoadReplies(widget.postId)),
      child: Builder(
        builder: (context) {
          // context 此处才能拿到本页的 ForumBloc，AppBar 的分享/编辑/删除等依赖 selectedPost
          return BlocListener<ForumBloc, ForumState>(
            listenWhen: (prev, curr) =>
                !prev.reportSuccess && curr.reportSuccess ||
                prev.errorMessage != curr.errorMessage && curr.errorMessage != null ||
                (prev.selectedPost?.id == widget.postId && curr.selectedPost == null),
            listener: (context, state) {
              if (state.reportSuccess) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.l10n.commonReportSubmitted)),
                );
              } else if (state.selectedPost == null && state.errorMessage == null) {
                // 当前帖子已删除成功（listenWhen 已保证是本页帖子被删），返回上一页并提示
                if (context.mounted) Navigator.of(context).pop();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.forumPostDeleted)),
                  );
                }
              } else if (state.errorMessage != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(state.errorMessage!)),
                );
              }
            },
            child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
        appBar: AppBar(
          title: Text(context.l10n.forumPostDetail),
          actions: [
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: () async {
                AppHaptics.selection();
                final post = context.read<ForumBloc>().state.selectedPost;
                final locale = Localizations.localeOf(context);
                final shareTitle = post != null
                    ? post.displayTitle(locale)
                    : context.l10n.forumPostDetail;
                final contentForDesc = post != null
                    ? (post.displayContent(locale) ?? post.content)
                    : null;
                final rawDesc = contentForDesc?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '';
                final description = rawDesc.length > 200 ? '${rawDesc.substring(0, 200)}...' : rawDesc;
                final imageUrl = post?.images.isNotEmpty == true ? post!.images.first : null;
                final shareFiles = await NativeShare.fileFromFirstImageUrl(imageUrl);
                if (!context.mounted) return;
                await NativeShare.share(
                  title: shareTitle,
                  description: description,
                  url: 'https://link2ur.com/forum/posts/${widget.postId}',
                  files: shareFiles,
                  context: context,
                );
              },
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'report') {
                  _showReportDialog(context);
                } else if (value == 'edit') {
                  final post = context.read<ForumBloc>().state.selectedPost;
                  if (post != null) {
                    context.push('/forum/posts/${post.id}/edit', extra: {
                      'post': post,
                      'bloc': context.read<ForumBloc>(),
                    });
                  }
                } else if (value == 'delete') {
                  _showDeletePostDialog(context);
                }
              },
              itemBuilder: (context) {
                final currentUserId =
                    context.read<AuthBloc>().state.user?.id;
                final post =
                    context.read<ForumBloc>().state.selectedPost;
                final isAuthor = currentUserId != null &&
                    post != null &&
                    post.authorId.toString() == currentUserId;
                return [
                  if (isAuthor) ...[
                    PopupMenuItem<String>(
                      value: 'edit',
                      child: Row(
                        children: [
                          const Icon(Icons.edit_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(context.l10n.commonEdit),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20,
                              color: Theme.of(context).colorScheme.error),
                          const SizedBox(width: 8),
                          Text(context.l10n.commonDelete,
                              style: TextStyle(
                                  color: Theme.of(context).colorScheme.error)),
                        ],
                      ),
                    ),
                  ],
                  PopupMenuItem<String>(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.flag_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(context.l10n.commonReport),
                      ],
                    ),
                  ),
                ];
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
            final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

            // 使用 CustomScrollView + Sliver 替代 SingleChildScrollView + Column
            // 评论区使用 SliverList 懒加载，避免一次性构建所有评论 widget
            return CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                // 帖子头部 + 内容 + 图片（1-2张）
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PostHeader(post: post, isDark: isDark),
                      const Divider(height: 1),
                      _PostContent(post: post, isDark: isDark),
                      if (post.images.isNotEmpty)
                        _PostImageRow(images: post.images),
                    ],
                  ),
                ),

                // 统计 + 分隔线
                SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                    ],
                  ),
                ),

                // 评论区标题
                SliverToBoxAdapter(
                  child: _ReplySectionHeader(
                    replyCount: state.replies.length,
                    isDark: isDark,
                  ),
                ),

                // 评论列表 — SliverList 懒加载，仅构建可见区域的评论
                if (state.replies.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
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
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList.separated(
                      itemCount: state.replies.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        indent: 42,
                        color: (isDark
                                ? AppColors.separatorDark
                                : AppColors.separatorLight)
                            .withValues(alpha: 0.3),
                      ),
                      itemBuilder: (context, index) {
                        return _ReplyCard(
                          reply: state.replies[index],
                          isDark: isDark,
                          postId: widget.postId,
                          onReplyTo: _setReplyTo,
                        );
                      },
                    ),
                  ),

                // 底部间距：预留回复栏高度 + 键盘弹起时额外留白，避免输入框被遮挡、列表可滚动
                SliverToBoxAdapter(
                  child: SizedBox(height: 88 + keyboardInset),
                ),
              ],
            );
          },
        ),
        ),
        ),
        // 底部回复栏 - 对标iOS bottomReplyBar with ultraThinMaterial
        bottomNavigationBar: _buildBottomReplyBar(context),
          ),
        );
      },
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
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        // 使用半透明容器替代 BackdropFilter，减少输入区域重绘开销
        // 键盘弹起时用 viewInsets.bottom 顶起整条回复栏，避免输入框被遮挡
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
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
                                      focusNode: _replyFocusNode,
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
    final locale = Localizations.localeOf(context);
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
                        post.category!.displayName(locale),
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

          // 标题 - 对标iOS 22pt bold（双语），可框选复制
          SelectableText(
            post.displayTitle(locale),
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
                onTap: () {
                  final userId = post.author?.id ?? post.authorId;
                  if (userId.isEmpty) return;
                  context.goToUserProfile(userId);
                },
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
                    isAnonymous: post.author == null,
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
                          onTap: () {
                            final userId = post.author?.id ?? post.authorId;
                            if (userId.isEmpty) return;
                            context.goToUserProfile(userId);
                          },
                          child: Text(
                            post.author?.name ?? context.l10n.forumUserFallback(post.authorId),
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
    final content = post.displayContent(Localizations.localeOf(context));
    if (content == null || content.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: SelectableText(
        Helpers.normalizeContentNewlines(content),
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

// ==================== 评论区标题（用于 CustomScrollView sliver 布局） ====================

class _ReplySectionHeader extends StatelessWidget {
  const _ReplySectionHeader({
    required this.replyCount,
    required this.isDark,
  });

  final int replyCount;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
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
              '$replyCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
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
          // 头像 — 点击跳转个人主页（优先使用 author.id 与后端一致，避免 authorId 与 author 不一致时跳错人）
          GestureDetector(
            onTap: () {
              final userId = reply.author?.id ?? reply.authorId;
              if (userId.isEmpty) return;
              context.goToUserProfile(userId);
            },
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
                isAnonymous: reply.author == null,
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
                      onTap: () {
                        final userId = reply.author?.id ?? reply.authorId;
                        if (userId.isEmpty) return;
                        context.goToUserProfile(userId);
                      },
                      child: Text(
                        reply.author?.name ?? context.l10n.forumUserFallback(reply.authorId),
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
                // 内容（支持后端返回的字面量 \n 换行），可框选复制
                Padding(
                  padding: const EdgeInsets.only(right: 42),
                  child: SelectableText(
                    Helpers.normalizeContentNewlines(reply.content),
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
                Row(
                  children: [
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
                    Builder(builder: (ctx) {
                      final currentUserId =
                          ctx.read<AuthBloc>().state.user?.id;
                      final isAuthor = currentUserId != null &&
                          reply.authorId.toString() == currentUserId;
                      if (!isAuthor) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            showDialog<void>(
                              context: ctx,
                              builder: (d) => AlertDialog(
                                title: Text(ctx.l10n.commonDelete),
                                content: Text(
                                    ctx.l10n.forumDeleteReplyConfirm),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(d),
                                    child: Text(ctx.l10n.commonCancel),
                                  ),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor: Theme.of(ctx)
                                          .colorScheme
                                          .error,
                                    ),
                                    onPressed: () {
                                      ctx.read<ForumBloc>().add(
                                            ForumDeleteReply(reply.id,
                                                postId: postId));
                                      Navigator.pop(d);
                                      ScaffoldMessenger.of(ctx)
                                          .showSnackBar(SnackBar(
                                              content: Text(ctx.l10n
                                                  .forumReplyDeleted)));
                                    },
                                    child: Text(ctx.l10n.commonDelete),
                                  ),
                                ],
                              ),
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4),
                            child: Icon(Icons.delete_outline,
                                size: 16,
                                color:
                                    Theme.of(ctx).colorScheme.error),
                          ),
                        ),
                      );
                    }),
                  ],
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
// 对标iOS：水平滚动缩略图列表，点击全屏查看

class _PostImageRow extends StatelessWidget {
  const _PostImageRow({required this.images});
  final List<String> images;

  void _openFullScreen(BuildContext context, int index) {
    pushWithSwipeBack(
      context,
      FullScreenImageView(
        images: images,
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = images.length == 1 ? 200.0 : 120.0;

    return SizedBox(
      height: size,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        itemCount: images.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return GestureDetector(
            onTap: () => _openFullScreen(context, index),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AsyncImageView(
                imageUrl: images[index],
                width: size,
                height: size,
              ),
            ),
          );
        },
      ),
    );
  }
}
