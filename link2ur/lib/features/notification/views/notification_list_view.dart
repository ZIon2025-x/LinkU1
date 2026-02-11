import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/notification.dart' as model;
import '../bloc/notification_bloc.dart';

/// 通知列表页
/// 参考iOS NotificationListView.swift
class NotificationListView extends StatefulWidget {
  const NotificationListView({
    super.key,
    this.type,
  });

  final String? type; // "system", "task", "forum" 等

  @override
  State<NotificationListView> createState() => _NotificationListViewState();
}

class _NotificationListViewState extends State<NotificationListView> {
  @override
  void initState() {
    super.initState();
    // 使用根级 NotificationBloc，加载指定类型的通知
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationBloc>().add(NotificationLoadRequested(type: widget.type));
    });
  }

  @override
  Widget build(BuildContext context) {
    return _NotificationListViewContent(type: widget.type);
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
              ? const SkeletonList(imageSize: 44)
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
      case 'interaction':
        return l10n.notificationInteraction;
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

    final type = notification.type;
    final relatedId = notification.relatedId;
    final taskId = notification.taskId;

    // 论坛相关 - 跳转到帖子详情
    if (type.startsWith('forum_')) {
      final postId = relatedId;
      if (postId != null) {
        context.safePush('/forum/posts/$postId');
      }
      return;
    }

    // 排行榜相关 - 跳转到排行榜项目详情
    if (type.startsWith('leaderboard_')) {
      final itemId = relatedId;
      if (itemId != null) {
        context.push('/leaderboard/$itemId');
      }
      return;
    }

    // 任务相关
    if (type.startsWith('task_')) {
      if (type == 'task_chat') {
        if (taskId != null) {
          context.push('/task-chat/$taskId');
        }
      } else {
        final id = taskId ?? relatedId;
        if (id != null) {
          context.safePush('/tasks/$id');
        }
      }
      return;
    }

    // 其他系统类型
    switch (type) {
      case 'message':
        if (taskId != null) {
          context.push('/task-chat/$taskId');
        }
        break;
      case 'payment':
      case 'payment_success':
      case 'payment_failed':
        context.push('/wallet');
        break;
      case 'flea_market':
        if (relatedId != null) {
          context.safePush('/flea-market/$relatedId');
        }
        break;
      case 'activity':
        if (relatedId != null) {
          context.push('/activities/$relatedId');
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
    final type = notification.type;
    // 论坛互动类型
    if (type.startsWith('forum_')) {
      if (type == 'forum_like') return Icons.favorite;
      if (type == 'forum_reply') return Icons.reply;
      if (type == 'forum_mention') return Icons.alternate_email;
      if (type == 'forum_favorite') return Icons.bookmark;
      if (type == 'forum_pin') return Icons.push_pin;
      if (type == 'forum_feature') return Icons.star;
      return Icons.forum;
    }
    // 排行榜互动类型
    if (type.startsWith('leaderboard_')) {
      if (type == 'leaderboard_vote') return Icons.how_to_vote;
      if (type == 'leaderboard_comment') return Icons.comment;
      if (type == 'leaderboard_like') return Icons.thumb_up;
      return Icons.leaderboard;
    }
    // 任务类型
    if (type.startsWith('task_')) return Icons.assignment;
    // 其他系统类型
    switch (type) {
      case 'payment':
      case 'payment_success':
      case 'payment_failed':
        return Icons.payment;
      case 'flea_market':
        return Icons.storefront;
      case 'activity':
        return Icons.event;
      case 'announcement':
        return Icons.campaign;
      case 'system':
        return Icons.info;
      default:
        return Icons.notifications;
    }
  }

  Color _getIconColor() {
    final type = notification.type;
    // 论坛互动类型 - 粉色系
    if (type.startsWith('forum_')) {
      if (type == 'forum_like') return AppColors.accentPink;
      return Colors.blue;
    }
    // 排行榜互动类型 - 橙色系
    if (type.startsWith('leaderboard_')) return Colors.orange;
    // 任务类型
    if (type.startsWith('task_')) return AppColors.primary;
    // 其他系统类型
    switch (type) {
      case 'payment':
      case 'payment_success':
        return AppColors.success;
      case 'payment_failed':
        return AppColors.error;
      case 'flea_market':
        return Colors.teal;
      case 'activity':
        return Colors.purple;
      case 'announcement':
        return Colors.orange;
      case 'system':
        return Colors.orange;
      default:
        return AppColors.textSecondary;
    }
  }
}
