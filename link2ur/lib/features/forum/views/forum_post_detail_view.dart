import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/system_context_menu.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/router/app_router.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/publisher_identity.dart';
import '../../../core/utils/share_util.dart';
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
  final ScrollController _scrollController = ScrollController();
  final Map<int, GlobalKey> _replyKeys = {};
  final StreamController<int> _highlightStream =
      StreamController<int>.broadcast();
  int? _replyToId;
  String? _replyToName;

  @override
  void dispose() {
    _replyController.dispose();
    _replyFocusNode.dispose();
    _scrollController.dispose();
    _highlightStream.close();
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

  void _pruneReplyKeys(List<ForumReply> replies) {
    final liveIds = replies.map((r) => r.id).toSet();
    _replyKeys.removeWhere((id, _) => !liveIds.contains(id));
  }

  void _showReportDialog(BuildContext context) async {
    final bloc = context.read<ForumBloc>();
    final reason = await AdaptiveDialogs.showInputDialog(
      context: context,
      title: context.l10n.commonReport,
      placeholder: context.l10n.commonReportReason,
      maxLines: 3,
      confirmText: context.l10n.commonConfirm,
      cancelText: context.l10n.commonCancel,
    );
    if (reason != null && reason.trim().isNotEmpty) {
      bloc.add(ForumReportPost(widget.postId, reason: reason.trim()));
    }
  }

  void _showDeletePostDialog(BuildContext context) {
    final bloc = context.read<ForumBloc>();
    final messenger = ScaffoldMessenger.of(context);
    final deletedText = context.l10n.forumPostDeleted;
    AdaptiveDialogs.showConfirmDialog(
      context: context,
      title: context.l10n.commonDelete,
      content: context.l10n.forumDeletePostConfirm,
      confirmText: context.l10n.commonDelete,
      cancelText: context.l10n.commonCancel,
      isDestructive: true,
      onConfirm: () {
        bloc.add(ForumDeletePost(widget.postId));
        // 确认弹窗由 AdaptiveDialogs 自动关闭，这里直接 pop 详情页
        if (mounted) context.pop();
        messenger.showSnackBar(SnackBar(content: Text(deletedText)));
      },
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
          return MultiBlocListener(
            listeners: [
              BlocListener<ForumBloc, ForumState>(
                listenWhen: (prev, curr) =>
                    prev.isReplying &&
                    !curr.isReplying &&
                    curr.replies.length > prev.replies.length,
                listener: (context, state) {
                  _pruneReplyKeys(state.replies);
                  _replyController.clear();
                  _clearReplyTo();
                },
              ),
              BlocListener<ForumBloc, ForumState>(
                listenWhen: (prev, curr) =>
                    curr.replies.length < prev.replies.length,
                listener: (context, state) {
                  _pruneReplyKeys(state.replies);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.forumReplyDeleted)),
                  );
                },
              ),
              BlocListener<ForumBloc, ForumState>(
                listenWhen: (prev, curr) =>
                    !prev.reportSuccess && curr.reportSuccess ||
                    prev.errorMessage != curr.errorMessage &&
                        curr.errorMessage != null,
                listener: (context, state) {
                  if (state.reportSuccess) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(context.l10n.commonReportSubmitted)),
                    );
                  } else if (state.errorMessage != null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content:
                              Text(context.localizeError(state.errorMessage))),
                    );
                  }
                },
              ),
            ],
            child: Scaffold(
              resizeToAvoidBottomInset: true,
              backgroundColor:
                  AppColors.backgroundFor(Theme.of(context).brightness),
              appBar: AppBar(
                titleSpacing: 0,
                title: BlocBuilder<ForumBloc, ForumState>(
                  buildWhen: (prev, curr) =>
                      prev.selectedPost != curr.selectedPost,
                  builder: (context, state) {
                    final post = state.selectedPost;
                    if (post == null) return Text(context.l10n.forumPostDetail);
                    // 管理员发帖跳 /about（goToUserProfile 的 isAdmin 语义），PublisherIdentity
                    // 当前不支持 isAdmin 路由，因此管理员帖保留旧实现；其他发布者（个人 / 达人团队）统一走新组件
                    final isAdminPost = post.author?.isAdmin ?? false;
                    final timeText = Text(
                      _PostHeader.formatTime(context, post.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    );
                    if (isAdminPost) {
                      return Semantics(
                        button: true,
                        label: 'View author profile',
                        child: GestureDetector(
                          onTap: () {
                            final userId = post.author?.id ?? post.authorId;
                            if (userId.isNotEmpty) {
                              context.goToUserProfile(userId, isAdmin: true);
                            }
                          },
                          child: Row(
                            children: [
                              AvatarView(
                                imageUrl: post.author?.avatar,
                                name: post.author?.name,
                                size: 32,
                                isAnonymous: post.author == null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            post.author?.name ??
                                                context.l10n.forumUserFallback(
                                                    post.authorId),
                                            style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (post.author?.displayedBadge !=
                                            null) ...[
                                          const SizedBox(width: 4),
                                          InlineBadgeTag(
                                              badge:
                                                  post.author!.displayedBadge!),
                                        ],
                                      ],
                                    ),
                                    timeText,
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: PublisherIdentity(
                                      ownerType: post.ownerType,
                                      ownerId:
                                          (post.ownerId?.isNotEmpty ?? false)
                                              ? post.ownerId
                                              : post.author?.id,
                                      displayName: post.displayName,
                                      displayAvatar: post.displayAvatar,
                                      fallbackName: post.author?.name ??
                                          context.l10n
                                              .forumUserFallback(post.authorId),
                                      fallbackAvatar: post.author?.avatar,
                                      isAnonymous: post.author == null,
                                      nameStyle: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      subtitle: timeText,
                                    ),
                                  ),
                                  if (post.author?.displayedBadge != null) ...[
                                    const SizedBox(width: 4),
                                    InlineBadgeTag(
                                        badge: post.author!.displayedBadge!),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                actions: [
                  // 收藏 + 分享 + 更多：用 BlocBuilder 包裹，帖子加载后/收藏切换时重建，顶部栏才能显示星标
                  BlocBuilder<ForumBloc, ForumState>(
                    buildWhen: (prev, curr) =>
                        prev.selectedPost != curr.selectedPost,
                    builder: (context, state) {
                      final post = state.selectedPost;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (post != null)
                            IconButton(
                              icon: Icon(
                                post.isFavorited
                                    ? Icons.star
                                    : Icons.star_border,
                                color: post.isFavorited ? AppColors.gold : null,
                              ),
                              onPressed: () => requireAuth(context, () {
                                AppHaptics.selection();
                                context
                                    .read<ForumBloc>()
                                    .add(ForumFavoritePost(widget.postId));
                              }),
                              tooltip: context.l10n.forumFavorite,
                            ),
                          IconButton(
                            icon: const Icon(Icons.share_outlined),
                            tooltip: 'Share',
                            onPressed: () {
                              AppHaptics.selection();
                              final p = state.selectedPost;
                              final locale = Localizations.localeOf(context);
                              final shareTitle = p != null
                                  ? p.displayTitle(locale)
                                  : context.l10n.forumPostDetail;
                              final contentForDesc = p != null
                                  ? (p.displayContent(locale) ?? p.content)
                                  : null;
                              final rawDesc = Helpers.normalizeContentNewlines(
                                contentForDesc
                                        ?.replaceAll(RegExp(r'<[^>]*>'), '')
                                        .trim() ??
                                    '',
                              );
                              final description = rawDesc.length > 200
                                  ? '${rawDesc.substring(0, 200)}...'
                                  : rawDesc;
                              final imageUrl = p?.images.isNotEmpty == true
                                  ? p!.images.first
                                  : null;
                              ShareUtil.share(
                                title: shareTitle,
                                description: description,
                                url: ShareUtil.forumPostUrl(widget.postId),
                                imageUrl: imageUrl,
                              );
                            },
                          ),
                          PopupMenuButton<String>(
                            icon: const Icon(Icons.more_vert),
                            onSelected: (value) {
                              if (value == 'report') {
                                _showReportDialog(context);
                              } else if (value == 'edit') {
                                final forumBloc = context.read<ForumBloc>();
                                final post = forumBloc.state.selectedPost;
                                if (post != null) {
                                  context.push('/forum/posts/${post.id}/edit',
                                      extra: {
                                        'post': post,
                                        'bloc': forumBloc,
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
                              final errorColor =
                                  Theme.of(context).colorScheme.error;
                              return [
                                if (isAuthor) ...[
                                  PopupMenuItem<String>(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit_outlined,
                                            size: 20),
                                        AppSpacing.hSm,
                                        Text(context.l10n.commonEdit),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        Icon(Icons.delete_outline,
                                            size: 20, color: errorColor),
                                        AppSpacing.hSm,
                                        Text(context.l10n.commonDelete,
                                            style:
                                                TextStyle(color: errorColor)),
                                      ],
                                    ),
                                  ),
                                ],
                                PopupMenuItem<String>(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.flag_outlined, size: 20),
                                      AppSpacing.hSm,
                                      Text(context.l10n.commonReport),
                                    ],
                                  ),
                                ),
                              ];
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              body: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                      maxWidth: ResponsiveUtils.detailMaxWidth(context)),
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
                          message: context.localizeError(state.errorMessage),
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
                      final isDark =
                          Theme.of(context).brightness == Brightness.dark;
                      final keyboardInset =
                          MediaQuery.of(context).viewInsets.bottom;

                      // 使用 CustomScrollView + Sliver 替代 SingleChildScrollView + Column
                      // 评论区使用 SliverList 懒加载，避免一次性构建所有评论 widget
                      return CustomScrollView(
                        controller: _scrollController,
                        keyboardDismissBehavior:
                            ScrollViewKeyboardDismissBehavior.onDrag,
                        slivers: [
                          // 图片轮播（顶部）
                          if (post.images.isNotEmpty)
                            SliverToBoxAdapter(
                              child: _PostImageCarousel(images: post.images),
                            ),

                          // 帖子头部 + 内容
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _PostHeader(post: post, isDark: isDark),
                                const Divider(height: 1),
                                _PostContent(post: post, isDark: isDark),
                                if (post.attachments.isNotEmpty ||
                                    (post.linkedItemType != null &&
                                        post.linkedItemType!.isNotEmpty &&
                                        post.linkedItemId != null &&
                                        post.linkedItemId!.isNotEmpty))
                                  _PostExtrasRow(
                                    attachments: post.attachments,
                                    linkedItemType: post.linkedItemType,
                                    linkedItemId: post.linkedItemId,
                                    linkedItemName: post.linkedItemName,
                                    isDark: isDark,
                                  ),
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
                                AppSpacing.vSm,
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
                                padding:
                                    const EdgeInsets.symmetric(vertical: 60),
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
                                      AppSpacing.vSm,
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
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
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
                                  final reply = state.replies[index];
                                  final key = _replyKeys.putIfAbsent(
                                      reply.id, () => GlobalKey());
                                  final parentReply =
                                      reply.parentReplyId != null
                                          ? state.replies
                                              .where((r) =>
                                                  r.id == reply.parentReplyId)
                                              .firstOrNull
                                          : null;
                                  return _ReplyCard(
                                    key: key,
                                    reply: reply,
                                    parentReply: parentReply,
                                    isDark: isDark,
                                    postId: widget.postId,
                                    onReplyTo: _setReplyTo,
                                    scrollController: _scrollController,
                                    replyKeys: _replyKeys,
                                    onHighlightTarget: (id) =>
                                        _highlightStream.add(id),
                                    highlightStream: _highlightStream.stream,
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
                    horizontal: AppSpacing.md, vertical: 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // 回复目标提示条
                    if (_replyToName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md, vertical: 6),
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
                            Semantics(
                              button: true,
                              label: 'Clear reply',
                              child: GestureDetector(
                                onTap: _clearReplyTo,
                                child: const Icon(Icons.close,
                                    size: 16,
                                    color: AppColors.textTertiaryLight),
                              ),
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
                            onTap: () => requireAuth(context, () {
                              context
                                  .read<ForumBloc>()
                                  .add(ForumLikePost(widget.postId));
                            }),
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
                                      contentPadding: AppSpacing.horizontalMd,
                                    ),
                                  ),
                                ),
                                // 发送按钮
                                ValueListenableBuilder<TextEditingValue>(
                                  valueListenable: _replyController,
                                  builder: (context, value, child) {
                                    if (value.text.trim().isEmpty)
                                      return const SizedBox.shrink();
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 4),
                                      child: Semantics(
                                        button: true,
                                        label: 'Send reply',
                                        child: GestureDetector(
                                          onTap: state.isReplying
                                              ? null
                                              : () => requireAuth(context, () {
                                                    AppHaptics.selection();
                                                    context
                                                        .read<ForumBloc>()
                                                        .add(
                                                          ForumReplyPost(
                                                            postId:
                                                                widget.postId,
                                                            content:
                                                                _replyController
                                                                    .text
                                                                    .trim(),
                                                            parentReplyId:
                                                                _replyToId,
                                                          ),
                                                        );
                                                    // 输入框在回复成功后再清空（由 BlocListener 监听 replies 增加后执行）
                                                  }),
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
                                                    padding: AppSpacing.allSm,
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

  static String formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0)
      return context.l10n.timeDaysAgo(difference.inDays);
    if (difference.inHours > 0)
      return context.l10n.timeHoursAgo(difference.inHours);
    if (difference.inMinutes > 0)
      return context.l10n.timeMinutesAgo(difference.inMinutes);
    return context.l10n.timeJustNow;
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标签行 (pinned, category)
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
                          horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
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

          // 标题
          SelectableText(
            post.displayTitle(locale),
            contextMenuBuilder: systemContextMenuBuilder,
            style: AppTypography.title2.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
        ],
      ),
    );
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
        contextMenuBuilder: systemContextMenuBuilder,
        style: AppTypography.body.copyWith(
          color:
              isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
          AppSpacing.hLg,
          // 点赞已移至底部回复栏，此处仅显示计数
          _StatLabel(
            icon: post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
            value: '${post.likeCount}',
            label: context.l10n.forumLike,
            color: post.isLiked ? AppColors.accentPink : null,
          ),
          AppSpacing.hLg,
          // 收藏 (交互)
          Semantics(
            button: true,
            label: 'Toggle favorite',
            child: GestureDetector(
              onTap: () => requireAuth(context, () {
                AppHaptics.selection();
                context.read<ForumBloc>().add(ForumFavoritePost(postId));
              }),
              child: _StatLabel(
                icon: post.isFavorited ? Icons.bookmark : Icons.bookmark_border,
                value: '',
                label: context.l10n.forumFavorite,
                color: post.isFavorited ? AppColors.gold : null,
              ),
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
    final defaultColor =
        isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final c = color ?? defaultColor;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: c),
            if (value.isNotEmpty) ...[
              AppSpacing.hXs,
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
          AppSpacing.hSm,
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

class _ReplyCard extends StatefulWidget {
  const _ReplyCard({
    super.key,
    required this.reply,
    required this.isDark,
    required this.postId,
    required this.onReplyTo,
    this.parentReply,
    this.scrollController,
    this.replyKeys,
    this.onHighlightTarget,
    this.highlightStream,
  });

  final ForumReply reply;
  final bool isDark;
  final int postId;
  final void Function(int replyId, String authorName) onReplyTo;
  final ForumReply? parentReply;
  final ScrollController? scrollController;
  final Map<int, GlobalKey>? replyKeys;
  final void Function(int replyId)? onHighlightTarget;
  final Stream<int>? highlightStream;

  @override
  State<_ReplyCard> createState() => _ReplyCardState();
}

class _ReplyCardState extends State<_ReplyCard> {
  StreamSubscription<int>? _highlightSub;
  bool _highlight = false;

  @override
  void initState() {
    super.initState();
    _highlightSub = widget.highlightStream?.listen((id) {
      if (id == widget.reply.id && mounted) {
        setState(() => _highlight = true);
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) setState(() => _highlight = false);
        });
      }
    });
  }

  @override
  void dispose() {
    _highlightSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reply = widget.reply;
    final isDark = widget.isDark;
    final postId = widget.postId;
    final onReplyTo = widget.onReplyTo;
    final parentReply = widget.parentReply;
    final replyKeys = widget.replyKeys;
    final isSubReply = reply.isSubReply;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _highlight
            ? Colors.yellow.withValues(alpha: 0.3)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 头像 — 点击跳转个人主页（优先使用 author.id 与后端一致，避免 authorId 与 author 不一致时跳错人）
            Semantics(
              button: true,
              label: 'View user profile',
              child: GestureDetector(
                onTap: () {
                  final userId = reply.author?.id ?? reply.authorId;
                  if (userId.isEmpty) return;
                  context.goToUserProfile(userId,
                      isAdmin: reply.author?.isAdmin ?? false);
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
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quote block for nested replies
                  if (parentReply != null) ...[
                    _ReplyQuoteBlock(
                      parentReply: parentReply,
                      isDark: isDark,
                      onTap: () {
                        final key = replyKeys?[parentReply.id];
                        if (key?.currentContext != null) {
                          Scrollable.ensureVisible(
                            key!.currentContext!,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOut,
                            alignment: 0.2,
                          );
                          widget.onHighlightTarget?.call(parentReply.id);
                        }
                      },
                    ),
                    const SizedBox(height: 6),
                  ] else if (reply.isSubReply) ...[
                    Text(
                      context.l10n.forumReplyFallbackParent,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  // 作者行
                  Row(
                    children: [
                      Semantics(
                        button: true,
                        label: 'View author',
                        child: GestureDetector(
                          onTap: () {
                            final userId = reply.author?.id ?? reply.authorId;
                            if (userId.isEmpty) return;
                            context.goToUserProfile(userId,
                                isAdmin: reply.author?.isAdmin ?? false);
                          },
                          child: Text(
                            reply.author?.name ??
                                context.l10n.forumUserFallback(reply.authorId),
                            style: TextStyle(
                              fontSize: isSubReply ? 13 : 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                      ),
                      if (reply.author?.displayedBadge != null) ...[
                        const SizedBox(width: 4),
                        InlineBadgeTag(badge: reply.author!.displayedBadge!),
                      ],
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
                      // 点赞回复（评论有点赞功能，点击调用后端并更新状态）
                      AppSpacing.hSm,
                      Tooltip(
                        message: context.l10n.forumLikeReply,
                        child: Semantics(
                          button: true,
                          label: 'Like reply',
                          child: GestureDetector(
                            onTap: () => requireAuth(context, () {
                              AppHaptics.selection();
                              context
                                  .read<ForumBloc>()
                                  .add(ForumLikeReply(reply.id));
                            }),
                            behavior: HitTestBehavior.opaque,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpacing.sm,
                                  vertical: AppSpacing.xs),
                              decoration: BoxDecoration(
                                color: reply.isLiked
                                    ? AppColors.accentPink
                                        .withValues(alpha: 0.1)
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
                                        : (isDark
                                            ? AppColors.textTertiaryDark
                                            : AppColors.textTertiaryLight),
                                  ),
                                  if (reply.likeCount > 0) ...[
                                    const SizedBox(width: 3),
                                    Text(
                                      '${reply.likeCount}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: reply.isLiked
                                            ? AppColors.accentPink
                                            : (isDark
                                                ? AppColors.textTertiaryDark
                                                : AppColors.textTertiaryLight),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),
                  // 内容（支持后端返回的字面量 \n 换行），可框选复制
                  Padding(
                    padding: const EdgeInsets.only(right: 42),
                    child: SelectableText(
                      Helpers.normalizeContentNewlines(reply.content),
                      contextMenuBuilder: systemContextMenuBuilder,
                      style: (isSubReply
                              ? AppTypography.footnote
                              : AppTypography.subheadline)
                          .copyWith(
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
                      Semantics(
                        button: true,
                        label: 'Reply',
                        child: GestureDetector(
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
                      ),
                      Builder(builder: (ctx) {
                        final currentUserId =
                            ctx.read<AuthBloc>().state.user?.id;
                        final isAuthor = currentUserId != null &&
                            reply.authorId.toString() == currentUserId;
                        if (!isAuthor) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.only(left: AppSpacing.sm),
                          child: Semantics(
                            button: true,
                            label: 'Delete reply',
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                AdaptiveDialogs.showConfirmDialog(
                                  context: ctx,
                                  title: ctx.l10n.commonDelete,
                                  content: ctx.l10n.forumDeleteReplyConfirm,
                                  confirmText: ctx.l10n.commonDelete,
                                  cancelText: ctx.l10n.commonCancel,
                                  isDestructive: true,
                                  onConfirm: () {
                                    ctx.read<ForumBloc>().add(ForumDeleteReply(
                                        reply.id,
                                        postId: postId));
                                  },
                                );
                              },
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 4),
                                child: Icon(Icons.delete_outline,
                                    size: 16,
                                    color: Theme.of(ctx).colorScheme.error),
                              ),
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
      ),
    );
  }

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);
    if (difference.inDays > 0)
      return context.l10n.timeDaysAgo(difference.inDays);
    if (difference.inHours > 0)
      return context.l10n.timeHoursAgo(difference.inHours);
    if (difference.inMinutes > 0)
      return context.l10n.timeMinutesAgo(difference.inMinutes);
    return context.l10n.timeJustNow;
  }
}

// ==================== 帖子图片轮播 ====================
// 顶部全宽图片容器，左右滑动切换，带页码指示器，点击全屏查看

class _PostImageCarousel extends StatefulWidget {
  const _PostImageCarousel({required this.images});
  final List<String> images;

  @override
  State<_PostImageCarousel> createState() => _PostImageCarouselState();
}

class _PostImageCarouselState extends State<_PostImageCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _openFullScreen(BuildContext context, int index) {
    pushWithSwipeBack(
      context,
      FullScreenImageView(
        images: widget.images,
        initialIndex: index,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final imageHeight = screenWidth * 1.05;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? Colors.black : const Color(0xFFF5F5F5),
      child: Stack(
        children: [
          SizedBox(
            height: imageHeight,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (page) => setState(() => _currentPage = page),
              itemBuilder: (context, index) {
                return Semantics(
                  button: true,
                  label: 'View full image',
                  child: GestureDetector(
                    onTap: () => _openFullScreen(context, index),
                    child: AsyncImageView(
                      imageUrl: Helpers.getThumbnailUrl(widget.images[index],
                          size: 'large'),
                      fallbackUrl: Helpers.getImageUrl(widget.images[index]),
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          if (widget.images.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.images.length, (i) {
                  final isActive = i == _currentPage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: isActive ? 18 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isActive
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

/// 附件 + 关联内容，紧凑一行展示
class _PostExtrasRow extends StatelessWidget {
  const _PostExtrasRow({
    required this.attachments,
    this.linkedItemType,
    this.linkedItemId,
    this.linkedItemName,
    required this.isDark,
  });

  final List<ForumPostAttachment> attachments;
  final String? linkedItemType;
  final String? linkedItemId;
  final String? linkedItemName;
  final bool isDark;

  bool get _hasLink =>
      linkedItemType != null &&
      linkedItemType!.isNotEmpty &&
      linkedItemId != null &&
      linkedItemId!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          ...attachments
              .map((att) => _AttachmentChip(att: att, isDark: isDark)),
          if (_hasLink)
            _LinkedChip(
                type: linkedItemType!,
                id: linkedItemId!,
                name: linkedItemName,
                isDark: isDark),
        ],
      ),
    );
  }
}

class _AttachmentChip extends StatelessWidget {
  const _AttachmentChip({required this.att, required this.isDark});
  final ForumPostAttachment att;
  final bool isDark;

  void _open(BuildContext context) {
    if (att.url.isEmpty) return;
    if (att.isPdf) {
      context.push(
        AppRoutes.forumPdfPreview,
        extra: {'url': att.url, 'title': att.filename},
      );
      return;
    }
    launchUrl(Uri.parse(att.url), mode: LaunchMode.externalApplication)
        .catchError((e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(context.l10n.forumAttachmentOpenFailed(e.toString()))),
        );
      }
      return false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final icon = att.isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file;
    final color = att.isPdf ? const Color(0xFFE53935) : AppColors.primary;
    return Semantics(
      button: true,
      label: 'Open attachment',
      child: GestureDetector(
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : color.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  att.filename,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: color, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedChip extends StatelessWidget {
  const _LinkedChip({
    required this.type,
    required this.id,
    this.name,
    required this.isDark,
  });

  final String type;
  final String id;
  final String? name;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View linked item',
      child: GestureDetector(
        onTap: () => _navigate(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.purple.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.10)
                  : AppColors.purple.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_iconData, size: 16, color: AppColors.purple),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  name ?? _typeLabel(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.purple,
                      fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.chevron_right,
                  size: 14, color: AppColors.purple.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context) {
    switch (type) {
      case 'product':
        context.push('/flea-market/$id');
      case 'service':
        final intId = int.tryParse(id);
        if (intId != null) context.push('/service/$intId');
      case 'expert':
        context.push('/task-experts/$id');
      case 'activity':
        context.push('/activities/$id');
      case 'ranking':
        final intId = int.tryParse(id);
        if (intId != null) context.push('/leaderboard/$intId');
      case 'forum_post':
        final intId = int.tryParse(id);
        if (intId != null) context.push('/forum/posts/$intId');
    }
  }

  String _typeLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (type) {
      case 'product':
        return l10n.discoveryFeedTypeProduct;
      case 'service':
      case 'expert':
        return l10n.discoveryFeedTypeService;
      case 'activity':
        return l10n.homeHotEvents;
      case 'ranking':
        return l10n.discoveryFeedTypeRanking;
      case 'forum_post':
        return l10n.discoveryFeedTypePost;
      default:
        return type;
    }
  }

  IconData get _iconData {
    switch (type) {
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'service':
      case 'expert':
        return Icons.school_outlined;
      case 'activity':
        return Icons.event_outlined;
      case 'ranking':
        return Icons.emoji_events_outlined;
      case 'forum_post':
        return Icons.forum_outlined;
      default:
        return Icons.link;
    }
  }
}

class _ReplyQuoteBlock extends StatelessWidget {
  const _ReplyQuoteBlock({
    required this.parentReply,
    required this.isDark,
    required this.onTap,
  });

  final ForumReply parentReply;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final authorName = parentReply.author?.name ?? parentReply.authorId;
    final content = parentReply.content;
    final bgColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.04);
    final borderColor = isDark
        ? AppColors.textTertiaryDark.withValues(alpha: 0.4)
        : AppColors.textTertiaryLight.withValues(alpha: 0.4);
    final textColor =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    return Semantics(
      button: true,
      label: 'Jump to parent',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(6),
            border: Border(
              left: BorderSide(color: borderColor, width: 2.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      '↩ $authorName',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (parentReply.author?.displayedBadge != null) ...[
                    const SizedBox(width: 4),
                    InlineBadgeTag(badge: parentReply.author!.displayedBadge!),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                Helpers.normalizeContentNewlines(content),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
