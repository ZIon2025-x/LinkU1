import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../bloc/notification_bloc.dart';
import '../../../data/models/notification.dart' as models;

/// 通知中心页
/// 参考iOS NotificationCenterView.swift
class NotificationCenterView extends StatefulWidget {
  const NotificationCenterView({super.key});

  @override
  State<NotificationCenterView> createState() => _NotificationCenterViewState();
}

class _NotificationCenterViewState extends State<NotificationCenterView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  /// 切换 tab 时重新加载对应类型的通知，避免两个 tab 共享同一份列表导致空白
  void _onTabChanged() {
    if (_tabController.indexIsChanging) return; // 只在动画结束后触发
    final type = _tabController.index == 0 ? 'system' : 'interaction';
    context.read<NotificationBloc>().add(NotificationLoadRequested(type: type));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationsNotifications),
        actions: [
          BlocBuilder<NotificationBloc, NotificationState>(
            buildWhen: (previous, current) =>
                previous.notifications.isEmpty !=
                current.notifications.isEmpty,
            builder: (context, state) {
              return TextButton(
                onPressed: state.notifications.isEmpty
                    ? null
                    : () {
                        context.read<NotificationBloc>().add(
                              const NotificationMarkAllAsRead(),
                            );
                      },
                child: Text(context.l10n.notificationMarkAllRead),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            BlocBuilder<NotificationBloc, NotificationState>(
              buildWhen: (prev, curr) =>
                  prev.unreadCount.count != curr.unreadCount.count,
              builder: (context, state) {
                final count = state.unreadCount.count;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.l10n.notificationSystemNotifications,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        _UnreadBadge(count: count),
                      ],
                    ],
                  ),
                );
              },
            ),
            BlocBuilder<NotificationBloc, NotificationState>(
              buildWhen: (prev, curr) =>
                  prev.unreadCount.forumCount != curr.unreadCount.forumCount,
              builder: (context, state) {
                final count = state.unreadCount.forumCount;
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          context.l10n.notificationInteractionMessages,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        _UnreadBadge(count: count),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _SystemNotificationList(),
          _InteractionNotificationList(),
        ],
      ),
    );
  }
}

/// Tab 上的未读数角标
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _SystemNotificationList extends StatefulWidget {
  const _SystemNotificationList();

  @override
  State<_SystemNotificationList> createState() => _SystemNotificationListState();
}

class _SystemNotificationListState extends State<_SystemNotificationList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load system notifications when tab is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationBloc>().add(
            const NotificationLoadRequested(type: 'system'),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.notifications != current.notifications ||
          previous.selectedType != current.selectedType ||
          previous.hasMore != current.hasMore,
      builder: (context, state) {
        // Show only when selectedType matches
        if (state.selectedType != 'system' &&
            state.status != NotificationStatus.loading) {
          return const SizedBox.shrink();
        }

        if (state.status == NotificationStatus.loading &&
            state.notifications.isEmpty) {
          return const SkeletonList(imageSize: 44);
        }

        if (state.status == NotificationStatus.error &&
            state.notifications.isEmpty) {
          return ErrorStateView.loadFailed(
            message: context.localizeError(state.errorMessage),
            onRetry: () {
              context.read<NotificationBloc>().add(
                    const NotificationLoadRequested(type: 'system'),
                  );
            },
          );
        }

        if (state.notifications.isEmpty) {
          return EmptyStateView.noNotifications(context);
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<NotificationBloc>().add(
                  const NotificationLoadRequested(type: 'system'),
                );
          },
          child: ListView.separated(
            padding: AppSpacing.allMd,
            itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              if (index == state.notifications.length) {
                context.read<NotificationBloc>().add(
                      const NotificationLoadMore(),
                    );
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: LoadingIndicator(),
                  ),
                );
              }
              return AnimatedListItem(
                key: ValueKey(state.notifications[index].id),
                index: index,
                maxAnimatedIndex: 11,
                child: _NotificationItem(
                  notification: state.notifications[index],
                  isSystem: true,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _InteractionNotificationList extends StatefulWidget {
  const _InteractionNotificationList();

  @override
  State<_InteractionNotificationList> createState() =>
      _InteractionNotificationListState();
}

class _InteractionNotificationListState
    extends State<_InteractionNotificationList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    // Load interaction notifications when tab is first shown
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationBloc>().add(
            const NotificationLoadRequested(type: 'interaction'),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (previous, current) =>
          previous.status != current.status ||
          previous.notifications != current.notifications ||
          previous.selectedType != current.selectedType ||
          previous.hasMore != current.hasMore,
      builder: (context, state) {
        // Show only when selectedType matches
        if (state.selectedType != 'interaction' &&
            state.status != NotificationStatus.loading) {
          return const SizedBox.shrink();
        }

        if (state.status == NotificationStatus.loading &&
            state.notifications.isEmpty) {
          return const SkeletonList(imageSize: 44);
        }

        if (state.status == NotificationStatus.error &&
            state.notifications.isEmpty) {
          return ErrorStateView.loadFailed(
            message: context.localizeError(state.errorMessage),
            onRetry: () {
              context.read<NotificationBloc>().add(
                    const NotificationLoadRequested(type: 'interaction'),
                  );
            },
          );
        }

        if (state.notifications.isEmpty) {
          return EmptyStateView.noNotifications(context);
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<NotificationBloc>().add(
                  const NotificationLoadRequested(type: 'interaction'),
                );
          },
          child: ListView.separated(
            padding: AppSpacing.allMd,
            itemCount: state.notifications.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              if (index == state.notifications.length) {
                context.read<NotificationBloc>().add(
                      const NotificationLoadMore(),
                    );
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: LoadingIndicator(),
                  ),
                );
              }
              return AnimatedListItem(
                key: ValueKey(state.notifications[index].id),
                index: index,
                maxAnimatedIndex: 11,
                child: _NotificationItem(
                  notification: state.notifications[index],
                  isSystem: false,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.notification,
    required this.isSystem,
  });

  final models.AppNotification notification;
  final bool isSystem;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'View details',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: () {
        if (!notification.isRead) {
          context.read<NotificationBloc>().add(
                NotificationMarkAsRead(notification.id),
              );
        }
        // 根据通知类型跳转到相关页面
        _navigateToRelated(context, notification);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: (isSystem ? AppColors.primary : AppColors.accentPink)
                    .withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isSystem ? Icons.notifications_outlined : Icons.favorite_outline,
                color: isSystem ? AppColors.primary : AppColors.accentPink,
              ),
            ),
            AppSpacing.hMd,

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.displayTitle(Localizations.localeOf(context)),
                    style: TextStyle(
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.displayContent(Localizations.localeOf(context)),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(context, notification.createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),

            // 未读标记
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }

  void _navigateToRelated(
      BuildContext context, models.AppNotification notification) {
    final type = notification.type;
    final relatedId = notification.relatedId;
    final taskId = notification.taskId;

    // 论坛
    if (type.startsWith('forum_')) {
      if (type == 'forum_category_approved') {
        context.safePush('/forum');
        return;
      }
      if (type == 'forum_category_rejected') return;
      if (relatedId != null) context.safePush('/forum/posts/$relatedId');
      return;
    }

    // 排行榜
    if (type.startsWith('leaderboard_')) {
      if (relatedId == null) return;
      if (type == 'leaderboard_approved' || type == 'leaderboard_rejected') {
        context.safePush('/leaderboard/$relatedId');
      } else {
        context.goToLeaderboardItemDetail(relatedId);
      }
      return;
    }

    // 其他系统通知
    if (relatedId == null && taskId == null) return;
    switch (notification.relatedType) {
      case 'task_id':
        context.safePush('/tasks/$relatedId');
        break;
      case 'forum_post_id':
        context.safePush('/forum/posts/$relatedId');
        break;
      case 'flea_market_id':
        context.safePush('/flea-market/$relatedId');
        break;
      default:
        final id = taskId ?? relatedId;
        if (id != null) context.safePush('/tasks/$id');
        break;
    }
  }

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return context.l10n.timeDaysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return context.l10n.timeHoursAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return context.l10n.timeMinutesAgo(difference.inMinutes);
    } else {
      return context.l10n.timeJustNow;
    }
  }
}
