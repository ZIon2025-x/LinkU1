import 'package:flutter/material.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/widgets/empty_state_view.dart';

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
          title: const Text('通知'),
          actions: [
            TextButton(
              onPressed: () {},
              child: const Text('全部已读'),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: '系统通知'),
              Tab(text: '互动消息'),
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

class _SystemNotificationList extends StatelessWidget {
  const _SystemNotificationList();

  @override
  Widget build(BuildContext context) {
    final notifications = List.generate(5, (index) => index);

    if (notifications.isEmpty) {
      return EmptyStateView.noNotifications();
    }

    return ListView.separated(
      padding: AppSpacing.allMd,
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        return _NotificationItem(index: index, isSystem: true);
      },
    );
  }
}

class _InteractionNotificationList extends StatelessWidget {
  const _InteractionNotificationList();

  @override
  Widget build(BuildContext context) {
    final notifications = List.generate(3, (index) => index);

    if (notifications.isEmpty) {
      return EmptyStateView.noNotifications();
    }

    return ListView.separated(
      padding: AppSpacing.allMd,
      itemCount: notifications.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        return _NotificationItem(index: index, isSystem: false);
      },
    );
  }
}

class _NotificationItem extends StatelessWidget {
  const _NotificationItem({
    required this.index,
    required this.isSystem,
  });

  final int index;
  final bool isSystem;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (isSystem ? AppColors.primary : AppColors.accentPink).withValues(alpha: 0.1),
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
                  isSystem ? '系统通知标题 ${index + 1}' : '用户 ${index + 1} 点赞了你的帖子',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  '通知内容详情...',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${index + 1}小时前',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          
          // 未读标记
          if (index == 0)
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
    );
  }
}
