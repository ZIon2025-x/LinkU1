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

class _NotificationListViewContent extends StatefulWidget {
  const _NotificationListViewContent({this.type});

  final String? type;

  @override
  State<_NotificationListViewContent> createState() =>
      _NotificationListViewContentState();
}

class _NotificationListViewContentState
    extends State<_NotificationListViewContent> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    if (currentScroll >= maxScroll - 200) {
      final state = context.read<NotificationBloc>().state;
      if (state.hasMore && !state.isLoading) {
        context.read<NotificationBloc>().add(const NotificationLoadMore());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.notifications != curr.notifications ||
          prev.hasMore != curr.hasMore ||
          prev.errorMessage != curr.errorMessage,
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
          body: state.isLoading && notifications.isEmpty
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
                            .add(NotificationLoadRequested(type: widget.type));
                      },
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        itemCount: notifications.length + (state.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, index) {
                          if (index >= notifications.length) {
                            return const Padding(
                              padding: EdgeInsets.all(AppSpacing.md),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final notification = notifications[index];
                          return _NotificationCard(
                            key: ValueKey(notification.id),
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
    switch (widget.type) {
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

    // ==================== 论坛 ====================
    if (type.startsWith('forum_')) {
      // forum_category_* 的 related_id 是分类 id，不能当帖子 id 使用
      if (type == 'forum_category_approved') {
        context.safePush('/forum');
        return;
      }
      if (type == 'forum_category_rejected') return;
      // 其余 forum_* 类型：related_id 是帖子 id
      if (relatedId != null) context.safePush('/forum/posts/$relatedId');
      return;
    }

    // ==================== 排行榜 ====================
    if (type.startsWith('leaderboard_')) {
      if (relatedId == null) return;
      // leaderboard_approved/rejected：related_id 是大赛 id，跳大赛详情
      if (type == 'leaderboard_approved' || type == 'leaderboard_rejected') {
        context.safePush('/leaderboard/$relatedId');
      } else {
        // leaderboard_vote/comment/like 等：related_id 是条目 id，跳条目详情
        context.goToLeaderboardItemDetail(relatedId);
      }
      return;
    }

    // ==================== 跳蚤市场 ====================
    // 用 startsWith('flea_market') 同时覆盖旧 'flea_market' 与新 'flea_market_*' 类型
    if (type.startsWith('flea_market')) {
      // 这两个类型的 related_id 是 task_id（申请被接受后已创建任务）
      if (type == 'flea_market_purchase_accepted' ||
          type == 'flea_market_direct_purchase') {
        final id = taskId ?? relatedId;
        if (id != null) context.safePush('/tasks/$id');
      } else {
        // flea_market / flea_market_purchase_request / flea_market_sold /
        // flea_market_seller_counter_offer / flea_market_purchase_rejected：
        // related_id 是商品 id
        if (relatedId != null) context.safePush('/flea-market/$relatedId');
      }
      return;
    }

    // ==================== 任务 ====================
    if (type.startsWith('task_')) {
      if (type == 'task_chat' || type == 'task_message') {
        if (taskId != null) context.push('/task-chat/$taskId');
      } else {
        final id = taskId ?? relatedId;
        if (id != null) context.safePush('/tasks/$id');
      }
      return;
    }

    // ==================== 活动奖励 ====================
    if (type.startsWith('activity_reward_') || type == 'official_activity_won') {
      if (relatedId != null) context.push('/activities/$relatedId');
      return;
    }

    // ==================== 达人服务 ====================
    // 达人身份审核结果（related_id 为 null）→ 去服务申请列表
    if (type == 'expert_application_approved' ||
        type == 'expert_application_rejected') {
      context.push('/my-service-applications');
      return;
    }
    // 服务申请 / 议价类：related_id 是 service_id
    if (type == 'service_application' ||
        type == 'service_application_rejected' ||
        type == 'service_application_cancelled' ||
        type == 'counter_offer' ||
        type == 'counter_offer_accepted' ||
        type == 'counter_offer_accepted_to_applicant' ||
        type == 'counter_offer_rejected') {
      if (relatedId != null) context.safePush('/service/$relatedId');
      return;
    }

    // ==================== 其他系统类型 ====================
    switch (type) {
      case 'message':
        if (taskId != null) context.push('/task-chat/$taskId');
        break;
      case 'payment':
      case 'payment_success':
      case 'payment_failed':
        context.push('/wallet');
        break;
      case 'activity':
        if (relatedId != null) context.push('/activities/$relatedId');
        break;
      case 'negotiation_offer':
      case 'application_message':
        final nId = taskId ?? relatedId;
        if (nId != null) context.safePush('/tasks/$nId', extra: notification.id);
        break;
      // 申请状态类：related_id 是 application_id，必须用 taskId 跳任务详情
      case 'application_accepted':
      case 'application_rejected':
      case 'application_withdrawn':
      case 'negotiation_rejected':
      case 'application_message_reply':
        if (taskId != null) context.safePush('/tasks/$taskId');
        break;
      // 服务 / 支付 / 提醒类任务跳转
      case 'service_application_approved':
      case 'payment_reminder':
      // 任务提醒（这些类型 taskId 可能为 null，用 relatedId 作为 task_id 备用）
      case 'confirmation_reminder':
      case 'deadline_reminder':
      case 'auto_transfer_reminder':
      case 'auto_confirm_transfer':
      case 'cancel_request_approved':
      case 'cancel_request_rejected':
        {
          final id = taskId ?? relatedId;
          if (id != null) context.safePush('/tasks/$id');
        }
        break;
      default:
        break;
    }
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
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
                  color: AppColors.primary.withValues(alpha: 0.2))
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
                    notification.displayTitle(Localizations.localeOf(context)),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: notification.isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                    ),
                  ),
                  if (notification.displayContent(Localizations.localeOf(context)).isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      notification.displayContent(Localizations.localeOf(context)),
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
    // 谈判/申请类型
    if (type == 'negotiation_offer') return Icons.price_change;
    if (type == 'application_message') return Icons.message_outlined;
    // 任务类型
    if (type == 'task_direct_request') return Icons.person_add;
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
    // 谈判/申请类型
    if (type == 'negotiation_offer') return AppColors.warning;
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
