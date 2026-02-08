import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/models/forum.dart';
import '../bloc/profile_bloc.dart';

/// 我的帖子视图
/// 参考iOS MyForumPostsView.swift
class MyPostsView extends StatefulWidget {
  const MyPostsView({super.key});

  @override
  State<MyPostsView> createState() => _MyPostsViewState();
}

class _MyPostsViewState extends State<MyPostsView> {
  final ScrollController _scrollController = ScrollController();
  ProfileState? _currentState;
  bool _scrollListenerAttached = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_currentState == null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_currentState!.forumPostsHasMore) {
        context.read<ProfileBloc>().add(
              ProfileLoadMyForumPosts(
                page: _currentState!.forumPostsPage + 1,
              ),
            );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      )..add(const ProfileLoadMyForumPosts(page: 1)),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('我的帖子'),
        ),
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            // Update current state for scroll listener
            _currentState = state;
            // Ensure scroll listener is attached once
            if (!_scrollListenerAttached) {
              _scrollListenerAttached = true;
              _scrollController.addListener(_onScroll);
            }

            return _buildBody(context, state);
          },
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, ProfileState state) {
    final isLoading = state.myForumPosts.isEmpty && state.status == ProfileStatus.loading;

    if (isLoading) {
      return const SkeletonList();
    }

    if (state.errorMessage != null && state.myForumPosts.isEmpty) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage!,
        onRetry: () {
          context.read<ProfileBloc>().add(
                const ProfileLoadMyForumPosts(page: 1),
              );
        },
      );
    }

    if (state.myForumPosts.isEmpty) {
      return EmptyStateView.noData(
        title: '暂无帖子',
        description: '您还没有发布过帖子',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProfileBloc>().add(
              const ProfileLoadMyForumPosts(page: 1),
            );
      },
      child: ListView.separated(
        controller: _scrollController,
        clipBehavior: Clip.none,
        padding: AppSpacing.allMd,
        itemCount: state.myForumPosts.length + (state.forumPostsHasMore ? 1 : 0),
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) {
          if (index >= state.myForumPosts.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _PostCard(post: state.myForumPosts[index]);
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
                style: const TextStyle(color: AppColors.textSecondaryLight),
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
                const SizedBox(width: 16),
                const Icon(
                  Icons.comment_outlined,
                  size: 16,
                  color: AppColors.textTertiaryLight,
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.replyCount}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatTime(post.createdAt),
                  style: const TextStyle(
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
