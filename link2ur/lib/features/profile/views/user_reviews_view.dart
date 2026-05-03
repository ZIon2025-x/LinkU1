import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../data/models/user.dart' show UserProfileReview;
import '../../../data/repositories/user_repository.dart';
import 'widgets/review_mini.dart';

/// 「全部评价」独立页面 — 分页加载用户收到的所有评价。
///
/// 由他人主页评价 section 底部的「查看全部 N 条评价」按钮跳转进入。
class UserReviewsView extends StatefulWidget {
  const UserReviewsView({
    super.key,
    required this.userId,
    this.totalReviews,
    this.avgRating,
  });

  final String userId;

  /// 用于 AppBar 副标题展示，可选;实际数据来自分页 API。
  final int? totalReviews;
  final double? avgRating;

  @override
  State<UserReviewsView> createState() => _UserReviewsViewState();
}

class _UserReviewsViewState extends State<UserReviewsView> {
  static const _pageSize = 20;

  final ScrollController _scrollController = ScrollController();
  final List<UserProfileReview> _reviews = [];

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
      _reviews.clear();
      _page = 1;
      _hasMore = true;
    });
    try {
      final repo = context.read<UserRepository>();
      final data = await repo.getUserReviews(widget.userId);
      if (!mounted) return;
      setState(() {
        _reviews.addAll(data);
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
      final data = await repo.getUserReviews(
        widget.userId,
        page: next,
      );
      if (!mounted) return;
      setState(() {
        _page = next;
        _reviews.addAll(data);
        _hasMore = data.length >= _pageSize;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingMore = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizeError(e.toString()))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final subtitle = (widget.totalReviews ?? 0) > 0
        ? l10n.profileReviewsSubtitle(
            widget.avgRating != null
                ? widget.avgRating!.toStringAsFixed(1)
                : '-',
            widget.totalReviews!,
          )
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.profileUserReviews,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
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
    if (_reviews.isEmpty) {
      return EmptyStateView.noData(
        context,
        title: context.l10n.profileNoReviewsYet,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInitial,
      child: ListView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _reviews.length + 1,
        itemBuilder: (context, index) {
          if (index == _reviews.length) {
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
                  context.l10n.profileNoMoreReviews,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF9A9FA5),
                  ),
                ),
              ),
            );
          }
          final r = _reviews[index];
          return ReviewMini(
            key: ValueKey('review_${r.id}'),
            review: r,
            showDivider: index > 0,
          );
        },
      ),
    );
  }
}
