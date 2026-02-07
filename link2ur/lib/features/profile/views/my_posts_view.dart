import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/models/forum.dart';

/// 我的帖子视图
/// 参考iOS MyForumPostsView.swift
class MyPostsView extends StatefulWidget {
  const MyPostsView({super.key});

  @override
  State<MyPostsView> createState() => _MyPostsViewState();
}

class _MyPostsViewState extends State<MyPostsView> {
  final List<ForumPost> _posts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasMore = true;
  final int _pageSize = 20;

  @override
  void initState() {
    super.initState();
    _loadPosts();
  }

  Future<void> _loadPosts({bool refresh = false}) async {
    if (_isLoading && !refresh) return;

    setState(() {
      _isLoading = refresh || _page == 1;
      _isLoadingMore = !refresh && _page > 1;
      _errorMessage = null;
    });

    try {
      final repository = context.read<ForumRepository>();
      final response = await repository.getMyPosts(
        page: refresh ? 1 : _page,
        pageSize: _pageSize,
      );

      setState(() {
        if (refresh || _page == 1) {
          _posts.clear();
          _posts.addAll(response.posts);
          _page = 1;
        } else {
          _posts.addAll(response.posts);
        }
        _hasMore = response.hasMore;
        _page = response.page;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _onRefresh() async {
    await _loadPosts(refresh: true);
  }

  void _loadMore() {
    if (!_isLoadingMore && _hasMore) {
      setState(() {
        _page++;
      });
      _loadPosts();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的帖子'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading && _posts.isEmpty) {
      return const LoadingView();
    }

    if (_errorMessage != null && _posts.isEmpty) {
      return ErrorStateView.loadFailed(
        message: _errorMessage!,
        onRetry: () => _loadPosts(refresh: true),
      );
    }

    if (_posts.isEmpty) {
      return EmptyStateView.noData(
        title: '暂无帖子',
        description: '您还没有发布过帖子',
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      child: ListView.separated(
        padding: AppSpacing.allMd,
        itemCount: _posts.length + (_hasMore ? 1 : 0),
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) {
          if (index == _posts.length) {
            // Load more trigger
            _loadMore();
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: LoadingIndicator(),
              ),
            );
          }
          return _PostCard(post: _posts[index]);
        },
      ),
    );
  }
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/forum/posts/${post.id}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题
            Text(
              post.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.vSm,

            // 内容预览
            if (post.content != null)
              Text(
                post.content!,
                style: TextStyle(color: AppColors.textSecondaryLight),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            AppSpacing.vMd,

            // 互动统计
            Row(
              children: [
                Icon(
                  post.isLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                  size: 16,
                  color: post.isLiked
                      ? AppColors.primary
                      : AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.likeCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(width: 16),
                Icon(
                  Icons.comment_outlined,
                  size: 16,
                  color: AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.replyCount}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(post.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ],
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
