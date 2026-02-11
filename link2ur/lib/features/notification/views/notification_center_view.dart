import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
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
class NotificationCenterView extends StatelessWidget {
  const NotificationCenterView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.notificationsNotifications),
          actions: [
            BlocBuilder<NotificationBloc, NotificationState>(
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
            tabs: [
              Tab(text: context.l10n.notificationSystemNotifications),
              Tab(text: context.l10n.notificationInteractionMessages),
            ],
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondaryLight,
            indicatorColor: AppColors.primary,
          ),
        ),
        body: const TabBarView(
          children: [
            _SystemNotificationList(),
            _InteractionNotificationList(),
          ],
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

class _SystemNotificationListState extends State<_SystemNotificationList> {
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
    return BlocBuilder<NotificationBloc, NotificationState>(
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
            message: state.errorMessage ?? context.l10n.activityLoadFailed,
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
                index: index,
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
    extends State<_InteractionNotificationList> {
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
    return BlocBuilder<NotificationBloc, NotificationState>(
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
            message: state.errorMessage ?? context.l10n.activityLoadFailed,
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
                index: index,
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
    return GestureDetector(
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
                    notification.displayTitle,
                    style: TextStyle(
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    notification.displayContent,
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
    );
  }

  void _navigateToRelated(BuildContext context, models.AppNotification notification) {
    final relatedId = notification.relatedId;
    if (relatedId == null) return;

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
