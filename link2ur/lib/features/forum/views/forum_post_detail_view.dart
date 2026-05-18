import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/widgets/user_identity_badges.dart';
import '../../../core/design/app_radius.dart';
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
import '../../../core/utils/share_util.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/services/storage_service.dart';
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

  /// UX audit #3: 长按删评论的入口不显眼, 在首次发现"有自己可删的评论"时
  /// 弹一次 SnackBar 提示, 整个 page 生命周期内不重复触发。
  bool _hasShownDeleteHint = false;

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

  /// C5: 互动条 "评论" 按钮 — 滚到评论输入栏并 focus
  void _scrollToCommentInput() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
    _replyFocusNode.requestFocus();
  }

  /// C5: 互动条 "分享" 按钮 — 沿用 _showMoreActions 里的 share 实现
  void _onShare(BuildContext context) {
    final post = context.read<ForumBloc>().state.selectedPost;
    if (post == null) return;
    final locale = Localizations.localeOf(context);
    AppHaptics.selection();
    final shareTitle = post.displayTitle(locale);
    final contentForDesc = post.displayContent(locale) ?? post.content;
    final rawDesc = Helpers.normalizeContentNewlines(
      contentForDesc?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
    );
    final description =
        rawDesc.length > 200 ? '${rawDesc.substring(0, 200)}...' : rawDesc;
    final imageUrl = post.images.isNotEmpty ? post.images.first : null;
    ShareUtil.share(
      title: shareTitle,
      description: description,
      url: ShareUtil.forumPostUrl(widget.postId),
      imageUrl: imageUrl,
    );
  }

  /// UX audit #3: 是否有任何"当前用户可删"的根/子评论, 用于决定首次 hint 是否触发
  bool _hasAnyDeletableComment(ForumState state) {
    final currentUserId = context.read<AuthBloc>().state.user?.id;
    if (currentUserId == null) return false;
    for (final root in state.replies) {
      if (root.authorId == currentUserId) return true;
      for (final c in root.previewChildren) {
        if (c.authorId == currentUserId) return true;
      }
      final loaded = state.loadedChildren[root.id];
      if (loaded != null) {
        for (final c in loaded) {
          if (c.authorId == currentUserId) return true;
        }
      }
    }
    return false;
  }

  void _pruneReplyKeys(ForumState state) {
    // 收集所有"在树里"的 id (root + preview_children + loadedChildren)
    final liveIds = <int>{};
    for (final root in state.replies) {
      liveIds.add(root.id);
      for (final c in root.previewChildren) {
        liveIds.add(c.id);
      }
      final loaded = state.loadedChildren[root.id];
      if (loaded != null) {
        for (final c in loaded) {
          liveIds.add(c.id);
        }
      }
    }
    _replyKeys.removeWhere((id, _) => !liveIds.contains(id));
  }

  /// 跳转到某条 reply (通常由 @ 引用块触发):
  /// 1. 若 target 已在已渲染列表 → 直接滚动 + 高亮
  /// 2. 若 target 是某根的 child 但还在折叠区 → 先 dispatch LoadMoreChildren,
  ///    等一帧让 widget 树更新后再滚动 + 高亮
  /// 3. 找不到 → 仅触发高亮(stream listener 命中即生效)
  Future<void> _handleMentionTap(int targetReplyId) async {
    // 立刻尝试滚动一次:已渲染则会命中
    final key = _replyKeys[targetReplyId];
    if (key?.currentContext != null) {
      await Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
      _highlightStream.add(targetReplyId);
      return;
    }

    // 未渲染 → 在 state 里搜 target 是不是某个根 (root) 自己,
    // 或者已经在 preview/loadedChildren 里(理论上 key 会命中,但 widget 还没构建时也可能漏)
    final state = context.read<ForumBloc>().state;
    int? ancestorRootId;
    bool targetIsRoot = false;
    for (final root in state.replies) {
      if (root.id == targetReplyId) {
        targetIsRoot = true;
        break;
      }
      if (root.previewChildren.any((c) => c.id == targetReplyId)) {
        ancestorRootId = root.id; // 已渲染,但 key 还没建好 → 等一帧
        break;
      }
      final loaded = state.loadedChildren[root.id];
      if (loaded != null && loaded.any((c) => c.id == targetReplyId)) {
        ancestorRootId = root.id;
        break;
      }
    }

    if (targetIsRoot) {
      // root 已经在 widget 树里,key 应该有 — 等一帧再试
      await Future.delayed(const Duration(milliseconds: 100));
    } else if (ancestorRootId != null) {
      // 已在某根的 child 列表 → 等 widget 重建即可
      await Future.delayed(const Duration(milliseconds: 100));
    } else {
      // 不在已知列表 → 可能在某根的折叠区,挨个尝试展开还有 more 的根。
      // 限制最多展开 5 根, 避免热门帖(20+ 根都未展开)时 8s+ 无响应。
      const int maxExpandAttempts = 5;
      int attempts = 0;
      for (final root in state.replies) {
        if (attempts >= maxExpandAttempts) break;
        final hasMore = state.hasMoreChildren[root.id] ??
            (root.hiddenChildrenCount > 0);
        if (hasMore && !state.loadingChildrenRoots.contains(root.id)) {
          attempts++;
          if (!mounted) return;
          context
              .read<ForumBloc>()
              .add(ForumLoadMoreChildren(root.id));
          await Future.delayed(const Duration(milliseconds: 400));
          if (!mounted) return;
          if (_replyKeys[targetReplyId]?.currentContext != null) {
            break; // 找到了,停止继续展开
          }
        }
      }
    }

    if (!mounted) return;
    final newKey = _replyKeys[targetReplyId];
    if (newKey?.currentContext != null) {
      await Scrollable.ensureVisible(
        newKey!.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        alignment: 0.2,
      );
    }
    // 兜底:广播高亮(已挂载的 _CommentItem listener 命中即生效)
    _highlightStream.add(targetReplyId);
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

  /// 紧凑 AppBar 的 三点更多 入口 — 把原 favorite / share / edit / delete / report 都收进 bottom sheet
  void _showMoreActions(BuildContext context) {
    final forumBloc = context.read<ForumBloc>();
    final post = forumBloc.state.selectedPost;
    if (post == null) return;
    final currentUserId = context.read<AuthBloc>().state.user?.id;
    final isAuthor =
        currentUserId != null && post.authorId.toString() == currentUserId;
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;
    final errorColor = Theme.of(context).colorScheme.error;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  post.isFavorited ? Icons.star : Icons.star_border,
                  color: post.isFavorited ? AppColors.gold : null,
                ),
                title: Text(l10n.forumFavorite),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  requireAuth(context, () {
                    AppHaptics.selection();
                    forumBloc.add(ForumFavoritePost(widget.postId));
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: Text(l10n.commonShare),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  AppHaptics.selection();
                  final shareTitle = post.displayTitle(locale);
                  final contentForDesc =
                      post.displayContent(locale) ?? post.content;
                  final rawDesc = Helpers.normalizeContentNewlines(
                    contentForDesc
                            ?.replaceAll(RegExp(r'<[^>]*>'), '')
                            .trim() ??
                        '',
                  );
                  final description = rawDesc.length > 200
                      ? '${rawDesc.substring(0, 200)}...'
                      : rawDesc;
                  final imageUrl =
                      post.images.isNotEmpty ? post.images.first : null;
                  ShareUtil.share(
                    title: shareTitle,
                    description: description,
                    url: ShareUtil.forumPostUrl(widget.postId),
                    imageUrl: imageUrl,
                  );
                },
              ),
              if (isAuthor) ...[
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(l10n.commonEdit),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    context.push('/forum/posts/${post.id}/edit', extra: {
                      'post': post,
                      'bloc': forumBloc,
                    });
                  },
                ),
                ListTile(
                  leading: Icon(Icons.delete_outline, color: errorColor),
                  title: Text(l10n.commonDelete,
                      style: TextStyle(color: errorColor)),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _showDeletePostDialog(context);
                  },
                ),
              ],
              ListTile(
                leading: const Icon(Icons.flag_outlined),
                title: Text(l10n.commonReport),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _showReportDialog(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = ForumBloc(
          forumRepository: context.read<ForumRepository>(),
        )..add(ForumLoadPostDetail(widget.postId));
        // 读取持久化的排序偏好。默认 'hot' 与 ForumState 默认值一致;
        // 不同值则走 ReplySortChanged (内部会先切 sort 再 dispatch LoadReplies)。
        final savedSort =
            StorageService.instance.getForumReplySort() ?? 'hot';
        if (savedSort != 'hot') {
          bloc.add(ForumReplySortChanged(widget.postId, savedSort));
        } else {
          bloc.add(ForumLoadReplies(widget.postId));
        }
        return bloc;
      },
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
                  _pruneReplyKeys(state);
                  _replyController.clear();
                  _clearReplyTo();
                },
              ),
              BlocListener<ForumBloc, ForumState>(
                listenWhen: (prev, curr) =>
                    curr.replies.length < prev.replies.length,
                listener: (context, state) {
                  _pruneReplyKeys(state);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.l10n.forumReplyDeleted)),
                  );
                },
              ),
              // UX audit #3: replies 加载完毕且有自己可删的评论 → 首次弹 hint
              BlocListener<ForumBloc, ForumState>(
                listenWhen: (prev, curr) =>
                    !_hasShownDeleteHint &&
                    curr.status == ForumStatus.loaded &&
                    curr.replies.isNotEmpty,
                listener: (context, state) {
                  if (_hasShownDeleteHint) return;
                  if (!_hasAnyDeletableComment(state)) return;
                  _hasShownDeleteHint = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.l10n.forumLongPressToDeleteHint,
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  });
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
              appBar: PreferredSize(
                preferredSize: const Size.fromHeight(52),
                child: BlocBuilder<ForumBloc, ForumState>(
                  buildWhen: (prev, curr) =>
                      prev.selectedPost != curr.selectedPost,
                  builder: (context, state) {
                    final post = state.selectedPost;
                    if (post == null) {
                      return AppBar(
                        title: Text(context.l10n.forumPostDetail),
                      );
                    }
                    return _DetailCompactAppBar(
                      post: post,
                      isFollowing: false, // TODO: 接入 follow_repository, 当前 placeholder
                      onTapAuthor: () {
                        final userId = post.author?.id ?? post.authorId;
                        if (userId.isNotEmpty) {
                          context.goToUserProfile(
                            userId,
                            isAdmin: post.author?.isAdmin ?? false,
                          );
                        }
                      },
                      onToggleFollow: () =>
                          ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('关注功能待接入')),
                      ),
                      onMore: () => _showMoreActions(context),
                    );
                  },
                ),
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
                        previous.replies != current.replies ||
                        previous.replySort != current.replySort ||
                        previous.loadedChildren != current.loadedChildren ||
                        previous.hasMoreChildren != current.hasMoreChildren ||
                        previous.loadingChildrenRoots !=
                            current.loadingChildrenRoots,
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
                      return RefreshIndicator(
                        onRefresh: () async {
                          final bloc = context.read<ForumBloc>();
                          // 重拉根帖详情 + 重拉评论 (ForumLoadReplies 顺手清子回复缓存)
                          bloc
                            ..add(ForumLoadPostDetail(widget.postId))
                            ..add(ForumLoadReplies(widget.postId));
                          // 等 BLoC emit 完成 — 看到一个非 loading 状态即可结束动画
                          await bloc.stream.firstWhere(
                            (s) => s.status != ForumStatus.loading,
                          );
                        },
                        child: CustomScrollView(
                        controller: _scrollController,
                        // 让 RefreshIndicator 在空内容时也能下拉
                        physics: const AlwaysScrollableScrollPhysics(),
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
                                // C2: 作者大头条 (44 渐变头像 + 认证勾 + 时间)
                                _AuthorHeader(post: post),
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

                          // C5: 浏览/编辑统计行 + 4 键互动条 (心/评论/分享/收藏)
                          SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  _StatsRow(post: post),
                                  const SizedBox(height: 12),
                                  _EngagementBar(
                                    post: post,
                                    onLike: () => requireAuth(context, () {
                                      AppHaptics.selection();
                                      context
                                          .read<ForumBloc>()
                                          .add(ForumLikePost(widget.postId));
                                    }),
                                    onComment: _scrollToCommentInput,
                                    onShare: () => _onShare(context),
                                    onFavorite: () => requireAuth(context, () {
                                      AppHaptics.selection();
                                      context.read<ForumBloc>().add(
                                          ForumFavoritePost(widget.postId));
                                    }),
                                  ),
                                  const SizedBox(height: 16),
                                ],
                              ),
                            ),
                          ),

                          // 评论区标题 (含排序 chip)
                          SliverToBoxAdapter(
                            child: _ReplySectionHeader(
                              replyCount: state.replies.length,
                              isDark: isDark,
                              currentSort: state.replySort,
                              onSortChanged: (newSort) {
                                context.read<ForumBloc>().add(
                                      ForumReplySortChanged(
                                          widget.postId, newSort),
                                    );
                              },
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
                                      const SizedBox(height: 12),
                                      // UX audit #11: 空评论时一键 focus 输入框
                                      TextButton(
                                        onPressed: () => requireAuth(
                                          context,
                                          () => _replyFocusNode.requestFocus(),
                                        ),
                                        child: Text(
                                          context.l10n.forumBeFirstReply,
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
                                  final root = state.replies[index];
                                  final currentUserId = context
                                      .read<AuthBloc>()
                                      .state
                                      .user
                                      ?.id;
                                  return _RootReplyGroup(
                                    key: ValueKey('root_${root.id}'),
                                    root: root,
                                    loadedChildren:
                                        state.loadedChildren[root.id] ??
                                            const <ForumReply>[],
                                    hasMore: state.hasMoreChildren[root.id] ??
                                        (root.hiddenChildrenCount > 0),
                                    isLoading:
                                        state.loadingChildrenRoots.contains(
                                            root.id),
                                    isDark: isDark,
                                    postId: widget.postId,
                                    replyKeys: _replyKeys,
                                    onReplyTo: _setReplyTo,
                                    scrollController: _scrollController,
                                    highlightStream: _highlightStream.stream,
                                    onMentionTap: _handleMentionTap,
                                    currentUserId: currentUserId,
                                    onLoadMoreChildren: () {
                                      context.read<ForumBloc>().add(
                                            ForumLoadMoreChildren(root.id),
                                          );
                                    },
                                  );
                                },
                              ),
                            ),

                          // 底部间距：预留回复栏高度 + 键盘弹起时额外留白，避免输入框被遮挡、列表可滚动
                          SliverToBoxAdapter(
                            child: SizedBox(height: 88 + keyboardInset),
                          ),
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
        },
      ),
    );
  }

  Widget _buildBottomReplyBar(BuildContext context) {
    return BlocBuilder<ForumBloc, ForumState>(
      buildWhen: (previous, current) =>
          previous.isReplying != current.isReplying,
      builder: (context, state) {
        final authUser = context.read<AuthBloc>().state.user;
        final bottomInset = MediaQuery.of(context).viewInsets.bottom;

        // 键盘弹起时用 viewInsets.bottom 顶起整条回复栏,避免输入框被遮挡
        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: _BottomCommentInput(
            controller: _replyController,
            focusNode: _replyFocusNode,
            isSending: state.isReplying,
            replyingToName: _replyToName,
            onCancelReply: _clearReplyTo,
            currentUserName: authUser?.name ?? '',
            currentUserAvatar: authUser?.avatar,
            hintText: _replyToName != null
                ? '${context.l10n.forumReplyTo} @$_replyToName'
                : context.l10n.forumWriteComment,
            replyingToLabel: _replyToName != null
                ? '${context.l10n.forumReplyTo} @$_replyToName'
                : null,
            onSubmit: () => requireAuth(context, () {
              AppHaptics.selection();
              context.read<ForumBloc>().add(
                    ForumReplyPost(
                      postId: widget.postId,
                      content: _replyController.text.trim(),
                      parentReplyId: _replyToId,
                    ),
                  );
              // 输入框在回复成功后再清空(由 BlocListener 监听 replies 增加后执行)
            }),
          ),
        );
      },
    );
  }
}

/// C8: 底部评论输入条 — 对标 mockup `.comment-input`
/// - 圆头像 (32) + 圆角灰底输入条 + 右侧发送按钮 (32 圆形)
/// - 顶部 1px 分割线 + 半透明背景, SafeArea 防底部齐
/// - 文字非空时发送按钮变亮蓝,空时变浅蓝并禁用
/// - 回复某人时输入条上方显示 "回复 @xxx" + 取消按钮
class _BottomCommentInput extends StatefulWidget {
  const _BottomCommentInput({
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.replyingToName,
    required this.onCancelReply,
    required this.currentUserName,
    required this.currentUserAvatar,
    required this.hintText,
    required this.replyingToLabel,
    required this.isSending,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmit;

  /// null = 普通模式, 非 null = @ 回复某人
  final String? replyingToName;
  final VoidCallback onCancelReply;
  final String currentUserName;
  final String? currentUserAvatar;
  final String hintText;
  final String? replyingToLabel;
  final bool isSending;

  @override
  State<_BottomCommentInput> createState() => _BottomCommentInputState();
}

class _BottomCommentInputState extends State<_BottomCommentInput> {
  bool get _canSubmit =>
      !widget.isSending && widget.controller.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChange);
  }

  @override
  void didUpdateWidget(covariant _BottomCommentInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChange);
      widget.controller.addListener(_onChange);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = (isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight)
        .withValues(alpha: 0.85);
    final divider = (isDark ? AppColors.separatorDark : AppColors.separatorLight)
        .withValues(alpha: 0.3);
    final inputBg = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.04);
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(top: BorderSide(color: divider)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // "回复 @xxx" 提示条
              if (widget.replyingToLabel != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          widget.replyingToLabel!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // UX audit #4: 44x44 hit area, 视觉仍 16px icon (a11y 推荐 ≥44)
                      Semantics(
                        button: true,
                        label: 'Clear reply',
                        child: SizedBox.square(
                          dimension: 44,
                          child: GestureDetector(
                            onTap: widget.onCancelReply,
                            behavior: HitTestBehavior.opaque,
                            child: Center(
                              child: Icon(
                                Icons.close,
                                size: 16,
                                color: secondaryColor,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  // 圆形头像 (32x32)
                  ClipOval(
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: (widget.currentUserAvatar != null &&
                              widget.currentUserAvatar!.isNotEmpty)
                          ? AsyncImageView(
                              imageUrl: widget.currentUserAvatar,
                              width: 32,
                              height: 32,
                              errorWidget: _GradientAvatarFallback(
                                  name: widget.currentUserName),
                            )
                          : _GradientAvatarFallback(
                              name: widget.currentUserName),
                    ),
                  ),
                  const SizedBox(width: 10),
                  // 圆角灰底输入条
                  Expanded(
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 36),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: inputBg,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: TextField(
                        controller: widget.controller,
                        focusNode: widget.focusNode,
                        enabled: !widget.isSending,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                          hintStyle: TextStyle(
                            color: isDark
                                ? AppColors.textPlaceholderDark
                                : AppColors.textPlaceholderLight,
                            fontSize: 13,
                          ),
                          isCollapsed: true,
                          border: InputBorder.none,
                        ),
                        style: const TextStyle(fontSize: 13),
                        maxLines: 5,
                        minLines: 1,
                        textInputAction: TextInputAction.newline,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 右侧发送按钮 (视觉 32 圆形, hit area 44x44 满足 a11y, UX audit #4)
                  Semantics(
                    button: true,
                    label: 'Send reply',
                    enabled: _canSubmit,
                    child: SizedBox.square(
                      dimension: 44,
                      child: GestureDetector(
                        onTap: _canSubmit ? widget.onSubmit : null,
                        behavior: HitTestBehavior.opaque,
                        child: Center(
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: _canSubmit
                                  ? AppColors.primary
                                  : AppColors.primary.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: widget.isSending
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  )
                                : const Icon(
                                    Icons.send,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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

// ==================== 评论区标题（用于 CustomScrollView sliver 布局） ====================

class _ReplySectionHeader extends StatelessWidget {
  const _ReplySectionHeader({
    required this.replyCount,
    required this.isDark,
    required this.currentSort,
    required this.onSortChanged,
  });

  final int replyCount;
  final bool isDark;
  final String currentSort;
  final ValueChanged<String> onSortChanged;

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
          // 对齐 _ReplyCountChip 浅蓝底+主色字模式, 暗色 mode 下也可见 (UX audit #2)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary
                  .withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$replyCount',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
            ),
          ),
          const Spacer(),
          _SortChip(
            currentSort: currentSort,
            isDark: isDark,
            onChanged: onSortChanged,
          ),
        ],
      ),
    );
  }
}

/// 评论排序切换 chip:按热度/按时间
/// sort 取值: 'hot' (热度) | 'time' (时间倒序,即"按时间")
class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.currentSort,
    required this.isDark,
    required this.onChanged,
  });

  final String currentSort;
  final bool isDark;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final isHot = currentSort == 'hot';
    final label = isHot
        ? context.l10n.forumSortByHot
        : context.l10n.forumSortByTime;
    final borderColor = (isDark
            ? AppColors.separatorDark
            : AppColors.separatorLight)
        .withValues(alpha: 0.6);
    final textColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: () async {
        final newSort = await showModalBottomSheet<String>(
          context: context,
          builder: (sheetCtx) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(context.l10n.forumSortByHot),
                  trailing: currentSort == 'hot'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(sheetCtx, 'hot'),
                ),
                ListTile(
                  title: Text(context.l10n.forumSortByTime),
                  trailing: currentSort == 'time'
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(sheetCtx, 'time'),
                ),
              ],
            ),
          ),
        );
        if (newSort != null && newSort != currentSort) {
          onChanged(newSort);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 12, color: textColor),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 14, color: textColor),
          ],
        ),
      ),
    );
  }
}

// ==================== 根评论分组 (root + preview_children + loaded_children + 展开按钮) ====================

class _RootReplyGroup extends StatelessWidget {
  const _RootReplyGroup({
    super.key,
    required this.root,
    required this.loadedChildren,
    required this.hasMore,
    required this.isLoading,
    required this.isDark,
    required this.postId,
    required this.replyKeys,
    required this.onReplyTo,
    required this.scrollController,
    required this.highlightStream,
    required this.onMentionTap,
    required this.onLoadMoreChildren,
    required this.currentUserId,
  });

  final ForumReply root;
  final List<ForumReply> loadedChildren;
  final bool hasMore;
  final bool isLoading;
  final bool isDark;
  final int postId;
  final Map<int, GlobalKey> replyKeys;
  final void Function(int replyId, String authorName) onReplyTo;
  final ScrollController scrollController;
  final Stream<int> highlightStream;
  final Future<void> Function(int targetReplyId) onMentionTap;
  final VoidCallback onLoadMoreChildren;

  /// 当前登录用户 id (未登录 = null), 用于决定 _CommentItem 是否显示删除入口
  final String? currentUserId;

  /// 删除回复:确认 + dispatch 事件. 写成方法供 root + 每个 child 复用.
  Future<void> _confirmAndDelete(BuildContext context, ForumReply reply) async {
    final bloc = context.read<ForumBloc>();
    final l10n = context.l10n;
    final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
      context: context,
      title: l10n.commonDelete,
      content: l10n.forumDeleteReplyConfirm,
      isDestructive: true,
      onConfirm: () => true,
    );
    if (confirmed == true) {
      bloc.add(ForumDeleteReply(reply.id, postId: postId));
    }
  }

  bool _canDelete(ForumReply reply) =>
      currentUserId != null && currentUserId == reply.authorId;

  @override
  Widget build(BuildContext context) {
    final displayChildren = [...root.previewChildren, ...loadedChildren];
    final remaining = root.totalChildren - displayChildren.length;
    final showExpand = hasMore || remaining > 0;

    // C6: _CommentItem 直接读取 reply.parentReplyAuthor 渲染 "@xxx" 前缀,
    // 不再需要从兄弟节点解析 parentReply 来构建 quote block。

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 根评论 (C6 视觉重做 — _CommentItem)
        // 旧 Stack+Positioned overlay 改为 _CommentItem 内 footer 末尾 Spacer (audit C8 #2)
        _CommentItem(
          key: replyKeys.putIfAbsent(root.id, () => GlobalKey()),
          reply: root,
          isNested: false,
          onLike: () =>
              context.read<ForumBloc>().add(ForumLikeReply(root.id)),
          // audit C8 #3: 未登录先走登录页,避免输入框 focus 后无法 submit
          onReply: () => requireAuth(context, () {
            onReplyTo(
              root.id,
              root.author?.name ?? root.authorId.toString(),
            );
          }),
          onMentionTap: (id) => onMentionTap(id),
          highlightStream: highlightStream,
          canDelete: _canDelete(root),
          onDelete: () => _confirmAndDelete(context, root),
          replyCountBadge: root.totalChildren > 0
              ? _ReplyCountChip(count: root.totalChildren)
              : null,
        ),
        // 子回复 (preview + loaded),带左侧缩进
        for (final child in displayChildren)
          _CommentItem(
            key: replyKeys.putIfAbsent(child.id, () => GlobalKey()),
            reply: child,
            isNested: true,
            onLike: () =>
                context.read<ForumBloc>().add(ForumLikeReply(child.id)),
            // audit C8 #3: 同上,未登录先弹登录
            onReply: () => requireAuth(context, () {
              onReplyTo(
                child.id,
                child.author?.name ?? child.authorId.toString(),
              );
            }),
            onMentionTap: (id) => onMentionTap(id),
            highlightStream: highlightStream,
            canDelete: _canDelete(child),
            onDelete: () => _confirmAndDelete(context, child),
          ),
        // 展开剩余 N 条按钮 (C7: 18px 短线 + 蓝字, 对齐 mockup .show-more-replies)
        if (showExpand)
          Padding(
            padding: const EdgeInsets.only(left: 46, top: 4, bottom: 4),
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: isLoading ? null : onLoadMoreChildren,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 18,
                      height: 1,
                      color: AppColors.primary.withValues(alpha: 0.4),
                    ),
                    const SizedBox(width: 6),
                    if (isLoading)
                      const SizedBox(
                        width: 12,
                        height: 12,
                        child: CircularProgressIndicator(strokeWidth: 1.5),
                      )
                    else
                      Text(
                        context.l10n.forumExpandMoreReplies(
                            remaining > 0 ? remaining : 1),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
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

/// 附件 + 关联内容: C4 详情页大卡 (PDF 下载 + 紫色关联).
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final att in attachments) ...[
            _PostFileCard(
              attachment: att,
              onDownload: () => _openAttachment(context, att),
            ),
            const SizedBox(height: 8),
          ],
          if (_hasLink)
            _LinkedItemCard(
              itemType: linkedItemType!,
              itemId: linkedItemId!,
              itemName: linkedItemName,
              isDark: isDark,
            ),
        ],
      ),
    );
  }

  void _openAttachment(BuildContext context, ForumPostAttachment att) {
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
}

/// 详情页 PDF/文件卡片: 红渐变 PDF 角标 + 文件名 + 大小 + 蓝色"下载"药丸
class _PostFileCard extends StatelessWidget {
  const _PostFileCard({
    required this.attachment,
    required this.onDownload,
  });

  final ForumPostAttachment attachment;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPdf = attachment.isPdf;
    final iconColor = isPdf ? const Color(0xFFF24D4D) : AppColors.primary;
    return Semantics(
      button: true,
      label: 'Open attachment',
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allMedium,
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              offset: const Offset(0, 2),
              blurRadius: 8,
              spreadRadius: -3,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPdf
                      ? const [Color(0xFFF24D4D), Color(0xFFFF7A7A)]
                      : [iconColor, iconColor.withValues(alpha: 0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.35),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                    spreadRadius: -2,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                isPdf ? 'PDF' : 'FILE',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attachment.formattedSize,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            InkWell(
              onTap: onDownload,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.download_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      context.l10n.forumDownload,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 详情页紫色关联内容卡: 渐变方块图标 + tag + 名称 + chevron
class _LinkedItemCard extends StatelessWidget {
  const _LinkedItemCard({
    required this.itemType,
    required this.itemId,
    required this.itemName,
    required this.isDark,
  });

  final String itemType;
  final String itemId;
  final String? itemName;
  final bool isDark;

  static const _purpleGradient = [Color(0xFF7359F2), Color(0xFFA18BFF)];

  @override
  Widget build(BuildContext context) {
    final purple = _purpleGradient[0];
    return Semantics(
      button: true,
      label: 'View linked item',
      child: InkWell(
        onTap: () => _navigate(context),
        borderRadius: AppRadius.allMedium,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: purple.withValues(alpha: isDark ? 0.14 : 0.08),
            border: Border.all(color: purple.withValues(alpha: 0.30)),
            borderRadius: AppRadius.allMedium,
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: _purpleGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: Icon(_iconData, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _typeLabel(context),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: purple,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      itemName?.isNotEmpty == true
                          ? itemName!
                          : _typeLabel(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w500),
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
      ),
    );
  }

  void _navigate(BuildContext context) {
    switch (itemType) {
      case 'product':
        context.push('/flea-market/$itemId');
      case 'service':
        final intId = int.tryParse(itemId);
        if (intId != null) context.push('/service/$intId');
      case 'expert':
        context.push('/task-experts/$itemId');
      case 'activity':
        context.push('/activities/$itemId');
      case 'ranking':
        final intId = int.tryParse(itemId);
        if (intId != null) context.push('/leaderboard/$intId');
      case 'forum_post':
        final intId = int.tryParse(itemId);
        if (intId != null) context.push('/forum/posts/$intId');
    }
  }

  String _typeLabel(BuildContext context) {
    final l10n = context.l10n;
    switch (itemType) {
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
        return itemType;
    }
  }

  IconData get _iconData {
    switch (itemType) {
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
        return Icons.dashboard;
    }
  }
}

// ─────────────────────────────────────────────────────────────
// C1: 紧凑顶部 AppBar (返回 + 30 px 圆头像作者卡 + 关注 pill + 三点更多)
// ─────────────────────────────────────────────────────────────

class _DetailCompactAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const _DetailCompactAppBar({
    required this.post,
    required this.isFollowing,
    required this.onTapAuthor,
    required this.onToggleFollow,
    required this.onMore,
  });

  final ForumPost post;
  final bool isFollowing;
  final VoidCallback onTapAuthor;
  final VoidCallback onToggleFollow;
  final VoidCallback onMore;

  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = post.author;
    final displayName = post.displayName?.isNotEmpty == true
        ? post.displayName!
        : (author?.name ?? context.l10n.commonAnonymous);
    final displayAvatar = post.displayAvatar?.isNotEmpty == true
        ? post.displayAvatar
        : author?.avatar;
    final hasAuthorId =
        (author?.id.isNotEmpty ?? false) || post.authorId.isNotEmpty;
    return AppBar(
      backgroundColor: AppColors.backgroundFor(
        isDark ? Brightness.dark : Brightness.light,
      ),
      elevation: 0,
      scrolledUnderElevation: 0,
      titleSpacing: 0,
      title: InkWell(
        onTap: onTapAuthor,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              ClipOval(
                child: SizedBox(
                  width: 30,
                  height: 30,
                  child:
                      (displayAvatar != null && displayAvatar.isNotEmpty)
                          ? AsyncImageView(
                              imageUrl: displayAvatar,
                              width: 30,
                              height: 30,
                              errorWidget:
                                  _GradientAvatarFallback(name: displayName),
                            )
                          : _GradientAvatarFallback(name: displayName),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (author?.displayedBadge != null) ...[
                const SizedBox(width: 4),
                InlineBadgeTag(badge: author!.displayedBadge!),
              ],
            ],
          ),
        ),
      ),
      actions: [
        if (hasAuthorId) ...[
          _FollowPill(isFollowing: isFollowing, onTap: onToggleFollow),
          const SizedBox(width: 4),
        ],
        IconButton(
          icon: const Icon(Icons.more_horiz, size: 20),
          onPressed: onMore,
        ),
        const SizedBox(width: 4),
      ],
    );
  }
}

class _FollowPill extends StatelessWidget {
  const _FollowPill({required this.isFollowing, required this.onTap});
  final bool isFollowing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: isFollowing ? AppColors.primary : Colors.transparent,
            border: Border.all(color: AppColors.primary, width: 1.5),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            isFollowing
                ? context.l10n.commonFollowing
                : context.l10n.commonFollow,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isFollowing ? Colors.white : AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}

/// 渐变占位头像 — 同一 name 永远同一渐变色，供 C1/C2/C6/C8 复用
class _GradientAvatarFallback extends StatelessWidget {
  const _GradientAvatarFallback({required this.name});
  final String name;

  /// 4 套渐变,按 name hash 选 1 套保证同一作者颜色稳定
  static const _gradients = <List<Color>>[
    [Color(0xFF7359F2), Color(0xFFA18BFF)], // 紫
    [Color(0xFFFF8033), Color(0xFFFFB84D)], // 橙
    [Color(0xFF26BF73), Color(0xFF5FD89A)], // 绿
    [Color(0xFFFF4D80), Color(0xFFFF8AAB)], // 粉
  ];

  @override
  Widget build(BuildContext context) {
    final idx = name.isEmpty ? 0 : name.codeUnitAt(0) % _gradients.length;
    final colors = _gradients[idx];
    final initial = name.isEmpty ? '?' : name[0];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// 详情页正文上方的"作者大头条" — C2:
/// 44x44 渐变头像 + 名字 15 + 蓝色 ✓ 认证徽章 + 元数据 "角色 · 时间 · 同城"。
/// 当前 ForumPost 模型无 cityName 字段、UserBrief 无 role 字段，城市/角色降级不渲染;
/// UserBrief.isVerified 存在时才显示蓝色认证勾。
class _AuthorHeader extends StatelessWidget {
  const _AuthorHeader({required this.post});
  final ForumPost post;

  String _formatTime(BuildContext context, DateTime? t) {
    if (t == null) return '';
    final now = DateTime.now();
    final diff = now.difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${t.year}-${t.month}-${t.day}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final author = post.author;

    final displayName = post.displayName?.isNotEmpty == true
        ? post.displayName!
        : (author?.name ?? context.l10n.commonAnonymous);
    final displayAvatar = post.displayAvatar?.isNotEmpty == true
        ? post.displayAvatar
        : author?.avatar;
    final timeStr = _formatTime(context, post.createdAt);
    final metaColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 44,
              height: 44,
              child: (displayAvatar != null && displayAvatar.isNotEmpty)
                  ? AsyncImageView(
                      imageUrl: displayAvatar,
                      width: 44,
                      height: 44,
                      errorWidget: _GradientAvatarFallback(name: displayName),
                    )
                  : _GradientAvatarFallback(name: displayName),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (author?.isVerified == true) ...[
                      const SizedBox(width: 4),
                      Container(
                        width: 16,
                        height: 16,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.check,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                if (timeStr.isNotEmpty)
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 12, color: metaColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== C5: _StatsRow + _EngagementBar + _EngageBtn ====================

/// 12px 灰字 "浏览数 · 编辑时间" 行
class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.post});
  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;
    final wasEdited = post.updatedAt != null &&
        post.createdAt != null &&
        post.updatedAt!
            .isAfter(post.createdAt!.add(const Duration(seconds: 5)));
    return Row(
      children: [
        Icon(Icons.remove_red_eye_outlined, size: 13, color: color),
        const SizedBox(width: 4),
        Text(
          '${post.viewCount} 浏览',
          style: TextStyle(fontSize: 12, color: color),
        ),
        if (wasEdited) ...[
          Text(' · ', style: TextStyle(color: color)),
          Text(
            '编辑于 ${_relativeTime(post.updatedAt!)}',
            style: TextStyle(fontSize: 12, color: color),
          ),
        ],
      ],
    );
  }

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    return '${diff.inDays} 天前';
  }
}

/// 跨满宽 4 键互动条: 心 / 评论 / 分享 / 收藏
/// 已点状态: 点赞 = 粉, 收藏 = 橙
class _EngagementBar extends StatelessWidget {
  const _EngagementBar({
    required this.post,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onFavorite,
  });

  final ForumPost post;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onFavorite;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divider =
        isDark ? AppColors.dividerDark : AppColors.dividerLight;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: divider),
          bottom: BorderSide(color: divider),
        ),
      ),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _EngageBtn(
            icon:
                post.isLiked ? Icons.favorite : Icons.favorite_outline,
            count: post.likeCount,
            tint: post.isLiked ? AppColors.accentPink : null,
            onTap: onLike,
          ),
          _EngageBtn(
            icon: Icons.chat_bubble_outline,
            count: post.replyCount,
            onTap: onComment,
          ),
          _EngageBtn(
            icon: Icons.share_outlined,
            count: 0, // 后端无 share count
            label: context.l10n.commonShare,
            onTap: onShare,
          ),
          _EngageBtn(
            icon: post.isFavorited
                ? Icons.bookmark
                : Icons.bookmark_outline,
            count: post.favoriteCount,
            tint: post.isFavorited ? AppColors.warning : null,
            onTap: onFavorite,
          ),
        ],
      ),
    );
  }
}

class _EngageBtn extends StatelessWidget {
  const _EngageBtn({
    required this.icon,
    required this.count,
    this.label,
    this.tint,
    required this.onTap,
  });

  final IconData icon;
  final int count;
  final String? label;
  final Color? tint;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = tint ??
        (isDark
            ? AppColors.textSecondaryDark
            : AppColors.textSecondaryLight);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 6),
              Text(
                label ?? (count > 0 ? '$count' : ''),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== C6: _CommentItem (mockup .comment / .comment.nested) ====================

/// 评论项视觉重做 (mockup `.comment`):
/// - 36x36 头像 (子回复 28x28),圆形,渐变 fallback (按 author name hash 选 4 套渐变之一,见 [_GradientAvatarFallback])
/// - 名字 13px / 600,内容 14px / line-height 1.55
/// - footer: 时间 · ❤️ count · 回复 (12px 灰字)
/// - 子回复 (isNested) 左缩进 46px,头像缩小到 28x28
/// - parentReplyAuthor 存在时,正文前插入 `@xxx ` 主色蓝可点击 (跳到引用源)
/// - 收到 highlightStream id == reply.id 时,触发 800ms 黄色脉冲背景高亮
class _CommentItem extends StatefulWidget {
  const _CommentItem({
    super.key,
    required this.reply,
    required this.isNested,
    required this.onLike,
    required this.onReply,
    required this.onMentionTap,
    this.highlightStream,
    this.canDelete = false,
    this.onDelete,
    this.replyCountBadge,
  });

  final ForumReply reply;
  final bool isNested;
  final VoidCallback onLike;
  final VoidCallback onReply;
  final void Function(int targetReplyId)? onMentionTap;
  final Stream<int>? highlightStream;

  /// 作者本人可见的删除入口 (audit C8 #1)
  final bool canDelete;
  final VoidCallback? onDelete;

  /// 可选只读 chip (例如 "N 条回复"), footer 行末尾用 Spacer 顶到右边
  /// (audit C8 #2 — 取代旧 Stack/Positioned overlay,避免遮挡长用户名 + 徽章)
  final Widget? replyCountBadge;

  @override
  State<_CommentItem> createState() => _CommentItemState();
}

class _CommentItemState extends State<_CommentItem> {
  bool _isPulsing = false;
  StreamSubscription<int>? _highlightSub;

  @override
  void initState() {
    super.initState();
    _highlightSub = widget.highlightStream?.listen((id) {
      if (id == widget.reply.id && mounted) {
        setState(() => _isPulsing = true);
        Future.delayed(const Duration(milliseconds: 1600), () {
          if (mounted) setState(() => _isPulsing = false);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final r = widget.reply;
    final avatarSize = widget.isNested ? 28.0 : 36.0;
    final authorName = r.author?.name ?? r.authorId;
    final hasAvatarUrl =
        r.author?.avatar != null && r.author!.avatar!.isNotEmpty;

    return GestureDetector(
      onLongPress: widget.canDelete ? widget.onDelete : null,
      child: AnimatedContainer(
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        color: _isPulsing
            ? const Color(0xFFFFDD57).withValues(alpha: 0.35)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: EdgeInsets.only(
        left: widget.isNested ? 46 : 0,
        right: widget.isNested ? 4 : 0,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipOval(
            child: SizedBox(
              width: avatarSize,
              height: avatarSize,
              child: hasAvatarUrl
                  ? AsyncImageView(
                      imageUrl: r.author!.avatar!,
                      width: avatarSize,
                      height: avatarSize,
                      errorWidget: _GradientAvatarFallback(name: authorName),
                    )
                  : _GradientAvatarFallback(name: authorName),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 名字行
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        authorName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                    if (r.author?.displayedBadge != null) ...[
                      const SizedBox(width: 4),
                      InlineBadgeTag(badge: r.author!.displayedBadge!),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                _ReplyContent(reply: r, onMentionTap: widget.onMentionTap),
                const SizedBox(height: 4),
                // footer 行: 时间 · ❤️ count · 回复
                Row(
                  children: [
                    Text(
                      _formatRelativeTime(context, r.createdAt),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: () =>
                          requireAuth(context, () => widget.onLike()),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 1),
                        child: Row(
                          children: [
                            Icon(
                              r.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_outline,
                              size: 13,
                              color: r.isLiked
                                  ? AppColors.accentPink
                                  : (isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '${r.likeCount}',
                              style: TextStyle(
                                fontSize: 12,
                                color: r.isLiked
                                    ? AppColors.accentPink
                                    : (isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    InkWell(
                      onTap: widget.onReply,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 1),
                        child: Text(
                          context.l10n.forumReply,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                      ),
                    ),
                    if (widget.replyCountBadge != null) ...[
                      const Spacer(),
                      widget.replyCountBadge!,
                    ],
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

  String _formatRelativeTime(BuildContext context, DateTime? t) {
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return context.l10n.timeJustNow;
    if (diff.inHours < 1) return context.l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return context.l10n.timeHoursAgo(diff.inHours);
    return context.l10n.timeDaysAgo(diff.inDays);
  }
}

/// _CommentItem 正文片段 — 有 parentReplyAuthor 时前置 `@xxx ` 蓝色可点击
class _ReplyContent extends StatelessWidget {
  const _ReplyContent({required this.reply, this.onMentionTap});
  final ForumReply reply;
  final void Function(int targetReplyId)? onMentionTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final normalized = Helpers.normalizeContentNewlines(reply.content);
    final bodyStyle = TextStyle(
      fontSize: 14,
      height: 1.55,
      color: isDark
          ? AppColors.textPrimaryDark
          : AppColors.textPrimaryLight,
    );

    if (reply.parentReplyAuthor != null) {
      return RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '@${reply.parentReplyAuthor!.name} ',
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                fontWeight: FontWeight.w500,
                color: AppColors.primary,
              ),
              recognizer: TapGestureRecognizer()
                ..onTap = () {
                  final pid = reply.parentReplyId;
                  if (pid != null) onMentionTap?.call(pid);
                },
            ),
            TextSpan(text: normalized, style: bodyStyle),
          ],
        ),
      );
    }
    return Text(normalized, style: bodyStyle);
  }
}

// ─────────────────────────────────────────────────────────────
// C7: _ReplyCountChip — mockup `.reply-count-tag`
// 浅蓝底 + 蓝字 + 内嵌 chat 图标 + 圆角药丸,挂在根评论右上角 (totalChildren > 0)
// ─────────────────────────────────────────────────────────────

class _ReplyCountChip extends StatelessWidget {
  const _ReplyCountChip({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.chat_bubble_outline,
            size: 10,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            '$count 条回复',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
