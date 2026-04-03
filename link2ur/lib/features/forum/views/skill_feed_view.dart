import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/feed_item.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/forum_bloc.dart';

/// 技能动态页：展示某技能分类下的帖子、任务、服务混合 feed
class SkillFeedView extends StatelessWidget {
  const SkillFeedView({
    super.key,
    this.category,
    this.categoryId,
  });

  final ForumCategory? category;
  final int? categoryId;

  @override
  Widget build(BuildContext context) {
    final effectiveId = category?.id ?? categoryId;
    if (effectiveId == null) {
      return Scaffold(
        body: Center(
          child: Text(context.l10n.forumInvalidPostId),
        ),
      );
    }

    return BlocProvider<ForumBloc>(
      create: (context) => ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      )..add(ForumLoadFeed(categoryId: effectiveId)),
      child: _SkillFeedContent(
        category: category,
        categoryId: effectiveId,
      ),
    );
  }
}

class _SkillFeedContent extends StatelessWidget {
  const _SkillFeedContent({
    this.category,
    required this.categoryId,
  });

  final ForumCategory? category;
  final int categoryId;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final categoryName = category?.displayName(locale) ?? context.l10n.forumAllPosts;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
      appBar: AppBar(
        title: Text(categoryName),
        actions: [
          IconButton(
            icon: const Icon(Icons.post_add, color: AppColors.primary),
            tooltip: context.l10n.forumCreatePostTitle,
            onPressed: () async {
              await context.push('/forum/posts/create?categoryId=$categoryId');
              if (context.mounted) {
                context.read<ForumBloc>().add(ForumLoadFeed(categoryId: categoryId));
              }
            },
          ),
        ],
      ),
      body: BlocBuilder<ForumBloc, ForumState>(
        buildWhen: (prev, curr) =>
            prev.feedStatus != curr.feedStatus ||
            prev.feedItems != curr.feedItems ||
            prev.isLoadingMoreFeed != curr.isLoadingMoreFeed ||
            prev.errorMessage != curr.errorMessage,
        builder: (context, state) {
          if (state.feedStatus == ForumStatus.loading && state.feedItems.isEmpty) {
            return const Center(child: LoadingIndicator());
          }
          if (state.feedStatus == ForumStatus.error && state.feedItems.isEmpty) {
            return ErrorStateView(
              message: context.localizeError(
                state.errorMessage ?? 'skill_feed_load_failed',
              ),
              onRetry: () => context
                  .read<ForumBloc>()
                  .add(ForumLoadFeed(categoryId: categoryId)),
            );
          }
          if (state.feedItems.isEmpty) {
            return EmptyStateView(
              icon: Icons.forum_outlined,
              title: context.l10n.forumNoPosts,
              message: context.l10n.forumNoPostsMessage,
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              context.read<ForumBloc>().add(ForumLoadFeed(categoryId: categoryId));
              await context
                  .read<ForumBloc>()
                  .stream
                  .firstWhere((s) => s.feedStatus != ForumStatus.loading);
            },
            child: NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is ScrollEndNotification &&
                    notification.metrics.extentAfter < 200 &&
                    !state.isLoadingMoreFeed &&
                    state.feedHasMore) {
                  context
                      .read<ForumBloc>()
                      .add(ForumLoadMoreFeed(categoryId: categoryId));
                }
                return false;
              },
              child: ListView.builder(
                clipBehavior: Clip.none,
                cacheExtent: 500,
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  top: AppSpacing.sm,
                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                ),
                itemCount: state.feedItems.length + (state.isLoadingMoreFeed ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= state.feedItems.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Center(child: LoadingIndicator()),
                    );
                  }
                  final item = state.feedItems[index];
                  return Padding(
                    key: ValueKey('feed_${item.itemType.name}_${item.createdAt.millisecondsSinceEpoch}'),
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _FeedItemCard(item: item),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==================== Feed Item Dispatcher ====================

class _FeedItemCard extends StatelessWidget {
  const _FeedItemCard({required this.item});
  final FeedItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.itemType) {
      FeedItemType.post => _PostFeedCard(post: item.data as ForumPost),
      FeedItemType.task => _TaskFeedCard(task: item.data as Task),
      FeedItemType.service => _ServiceFeedCard(service: item.data as TaskExpertService),
    };
  }
}

// ==================== Post Card ====================

class _PostFeedCard extends StatelessWidget {
  const _PostFeedCard({required this.post});
  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => context.push('/forum/posts/${post.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TypeBadge(
              label: _discussionLabel(context),
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              post.displayTitle(locale),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (post.displayContent(locale) != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                post.displayContent(locale)!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (post.author != null) ...[
                  Text(
                    post.author!.name,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                Icon(Icons.visibility, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Text(
                  '${post.viewCount}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(Icons.chat_bubble_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 2),
                Text(
                  '${post.replyCount}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Task Card ====================

class _TaskFeedCard extends StatelessWidget {
  const _TaskFeedCard({required this.task});
  final Task task;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final theme = Theme.of(context);
    const taskColor = Colors.orange;

    return GestureDetector(
      onTap: () => context.push('/tasks/${task.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(label: _taskLabel(context), color: taskColor),
                const Spacer(),
                Text(
                  '${task.currency} ${task.reward.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: taskColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              task.displayTitle(locale),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (task.location != null && task.location!.isNotEmpty) ...[
                  Icon(Icons.location_on, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Flexible(
                    child: Text(
                      task.location!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
                if (task.deadline != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                  const SizedBox(width: 2),
                  Text(
                    _formatDeadline(task.deadline!),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDeadline(DateTime deadline) {
    final diff = deadline.difference(DateTime.now());
    if (diff.inDays > 0) return '${diff.inDays}d';
    if (diff.inHours > 0) return '${diff.inHours}h';
    return 'Soon';
  }
}

// ==================== Service Card ====================

class _ServiceFeedCard extends StatelessWidget {
  const _ServiceFeedCard({required this.service});
  final TaskExpertService service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const serviceColor = Colors.green;

    return GestureDetector(
      onTap: () => context.push('/service/${service.id}'),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(AppRadius.large),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _TypeBadge(label: _serviceLabel(context), color: serviceColor),
                const Spacer(),
                Text(
                  service.priceDisplay,
                  style: const TextStyle(
                    fontSize: 14,
                    color: serviceColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              service.serviceName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (service.description.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                service.description,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                if (service.ownerName != null) ...[
                  Text(
                    service.ownerName!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(width: AppSpacing.md),
                ],
                if (service.ownerRating != null) ...[
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 2),
                  Text(
                    service.ownerRating!.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== Type Badge ====================

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ==================== Label helpers ====================

String _discussionLabel(BuildContext context) =>
    context.l10n.skillFeedDiscussionLabel;

String _taskLabel(BuildContext context) => context.l10n.skillFeedTaskLabel;

String _serviceLabel(BuildContext context) => context.l10n.skillFeedServiceLabel;
