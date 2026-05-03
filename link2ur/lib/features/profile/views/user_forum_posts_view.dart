import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../data/models/user.dart' show UserProfileForumPost;
import '../../../data/repositories/user_repository.dart';
import 'widgets/forum_post_row.dart';

/// 「TA 的论坛动态」独立页 — 分页加载用户全部论坛帖子(按热度排序)。
class UserForumPostsView extends StatefulWidget {
  const UserForumPostsView({
    super.key,
    required this.userId,
    this.totalPosts,
  });

  final String userId;
  final int? totalPosts;

  @override
  State<UserForumPostsView> createState() => _UserForumPostsViewState();
}

class _UserForumPostsViewState extends State<UserForumPostsView> {
  static const _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<UserProfileForumPost> _posts = [];

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_hasMore || _loadingMore) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _posts.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final repo = context.read<UserRepository>();
      final data = await repo.getUserHotForumPosts(widget.userId);
      if (!mounted) return;
      setState(() {
        _posts.addAll(data);
        _hasMore = data.length >= _pageSize;
        _initialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _initialLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    try {
      final repo = context.read<UserRepository>();
      final next = _page + 1;
      final data = await repo.getUserHotForumPosts(
        widget.userId,
        page: next,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _posts.addAll(data);
        _hasMore = data.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = (widget.totalPosts ?? 0) > 0
        ? l10n.profileForumPostsCount(widget.totalPosts!)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileRecentPosts,
              style:
                  const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                ),
              ),
          ],
        ),
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_initialLoading) {
      return const SkeletonList(itemCount: 6, hasImage: false);
    }
    if (_error != null) {
      return ErrorStateView(message: _error!, onRetry: _loadInitial);
    }
    if (_posts.isEmpty) {
      return EmptyStateView.noData(
        context,
        title: context.l10n.profileNoRecentPosts,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _posts.length + 1,
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            if (_hasMore) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  context.l10n.profileNoMorePosts,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9FA5),
                  ),
                ),
              ),
            );
          }
          final p = _posts[index];
          return ForumPostRow(
            key: ValueKey('post_${p.id}'),
            post: p,
            colorIndex: index,
            showDivider: index > 0,
          );
        },
      ),
    );
  }
}
