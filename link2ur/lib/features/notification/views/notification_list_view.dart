import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/notification.dart' as model;
import '../../../data/repositories/notification_repository.dart';
import '../bloc/notification_bloc.dart';

/// 通知列表页
/// 参考iOS NotificationListView.swift
class NotificationListView extends StatelessWidget {
  const NotificationListView({
    super.key,
    this.type,
  });

  final String? type; // "system", "task", "forum" 等

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => NotificationBloc(
        notificationRepository: context.read<NotificationRepository>(),
      )..add(NotificationLoadRequested(type: type)),
      child: _NotificationListViewContent(type: type),
    );
  }
}

class _NotificationListViewContent extends StatelessWidget {
  const _NotificationListViewContent({this.type});

  final String? type;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, state) {
        final notifications = state.notifications;

        return Scaffold(
          appBar: AppBar(
            title: Text(_getTitle(l10n)),
            actions: [
              if (notifications.isNotEmpty)
                TextButton(
                  onPressed: () => context
                      .read<NotificationBloc>()
                      .add(const NotificationMarkAllAsRead()),
                  child: Text(l10n.notificationMarkAllRead),
                ),
            ],
          ),
          body: state.isLoading
              ? const LoadingView()
              : notifications.isEmpty
                  ? EmptyStateView(
                      icon: Icons.notifications_none,
                      title: l10n.notificationEmpty,
                      message: l10n.notificationEmptyMessage,
                    )
                  : RefreshIndicator(
                      onRefresh: () async {
                        context
                            .read<NotificationBloc>()
                            .add(NotificationLoadRequested(type: type));
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: notifications.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          final notification = notifications[index];
                          return _NotificationCard(
                            notification: notification,
                            onTap: () =>
                                _handleNotificationTap(context, notification),
                          );
                        },
                      ),
                    ),
        );
      },
    );
  }

  String _getTitle(dynamic l10n) {
    switch (type) {
      case 'system':
        return l10n.notificationSystem;
      case 'task':
        return l10n.notificationTask;
      case 'forum':
        return l10n.notificationForum;
      default:
        return l10n.notificationAll;
    }
  }

  void _handleNotificationTap(
      BuildContext context, model.AppNotification notification) {
    // 标记为已读
    if (!notification.isRead) {
      context
          .read<NotificationBloc>()
          .add(NotificationMarkAsRead(notification.id));
    }

    // 根据通知类型跳转到对应页面
    switch (notification.type) {
      case 'task_applied':
      case 'task_accepted':
      case 'task_completed':
      case 'task_confirmed':
      case 'task_cancelled':
      case 'task_update':
        final taskId = notification.taskId ?? notification.relatedId;
        if (taskId != null) {
          context.push('/tasks/$taskId');
        }
        break;
      case 'message':
      case 'task_chat':
        final taskId = notification.taskId;
        if (taskId != null) {
          context.push('/task-chat/$taskId');
        }
        break;
      case 'forum_reply':
      case 'forum_like':
        final postId = notification.relatedId;
        if (postId != null) {
          context.push('/forum/posts/$postId');
        }
        break;
      case 'payment':
      case 'payment_success':
      case 'payment_failed':
        context.push('/wallet');
        break;
      case 'flea_market':
        final itemId = notification.relatedId;
        if (itemId != null) {
          context.push('/flea-market/$itemId');
        }
        break;
      case 'activity':
        final activityId = notification.relatedId;
        if (activityId != null) {
          context.push('/activities/$activityId');
        }
        break;
      case 'leaderboard':
        final leaderboardId = notification.relatedId;
        if (leaderboardId != null) {
          context.push('/leaderboard/$leaderboardId');
        }
        break;
      default:
        break;
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    this.onTap,
  });

  final model.AppNotification notification;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: notification.isRead
              ? Theme.of(context).cardColor
              : AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(AppRadius.medium),
          border: !notification.isRead
              ? Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2), width: 1)
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图标
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _getIconColor().withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_getIcon(), color: _getIconColor(), size: 20),
            ),
            const SizedBox(width: AppSpacing.md),

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  if (notification.content.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.content,
                      style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 6),
                  Text(
                    notification.createdAt?.toString().split('.').first ?? '',
                    style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiary),
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
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon() {
    switch (notification.type) {
      case 'task':
        return Icons.assignment;
      case 'forum':
        return Icons.forum;
      case 'system':
        return Icons.info;
      case 'payment':
        return Icons.payment;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor() {
    switch (notification.type) {
      case 'task':
        return AppColors.primary;
      case 'forum':
        return Colors.blue;
      case 'system':
        return Colors.orange;
      case 'payment':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }
}
