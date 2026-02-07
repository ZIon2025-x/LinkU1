import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/utils/date_formatter.dart';
import '../../notification/widgets/notification_menu.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/models/message.dart';
import '../../customer_service/views/customer_service_view.dart';
import '../bloc/message_bloc.dart';

/// 消息列表页
/// 参考iOS MessageView.swift - 单列表布局
class MessageView extends StatelessWidget {
  const MessageView({super.key});

  @override
  Widget build(BuildContext context) {
    final messageRepository = context.read<MessageRepository>();

    return BlocProvider(
      create: (context) => MessageBloc(messageRepository: messageRepository)
        ..add(const MessageLoadContacts())
        ..add(const MessageLoadTaskChats()),
      child: Scaffold(
        appBar: AppBar(
          title: Text(context.l10n.messagesMessages),
          actions: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              onPressed: () => NotificationMenu.show(context),
            ),
          ],
        ),
        body: const _MessageContent(),
      ),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessageBloc, MessageState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<MessageBloc>()
              ..add(const MessageLoadContacts())
              ..add(const MessageLoadTaskChats());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView(
            padding: AppSpacing.allMd,
            children: [
              // 系统消息卡片
              _SystemMessageCard(
                onTap: () => context.push('/notifications'),
              ),
              AppSpacing.vMd,

              // 客服卡片
              _CustomerServiceCard(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerServiceView(),
                  ),
                ),
              ),
              AppSpacing.vMd,

              // 互动消息卡片
              _InteractionMessageCard(
                onTap: () => context.push('/notifications'),
              ),
              AppSpacing.vMd,

              // 任务消息分隔
              if (state.taskChats.isNotEmpty) ...[
                const SizedBox(height: 8),
                // 任务聊天列表
                ...state.taskChats.map(
                  (taskChat) => _TaskChatItem(taskChat: taskChat),
                ),
              ] else if (state.status != MessageStatus.loading) ...[
                const SizedBox(height: 40),
                Center(
                  child: Column(
                    children: [
                      const Icon(
                        Icons.message,              // message.fill
                        size: 48,
                        color: AppColors.textTertiaryLight,
                      ),
                      AppSpacing.vSm,
                      Text(
                        context.l10n.messagesNoTaskChats,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              if (state.status == MessageStatus.loading &&
                  state.taskChats.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: LoadingView(),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 系统消息卡片 - 对齐iOS SystemMessageCard
class _SystemMessageCard extends StatelessWidget {
  const _SystemMessageCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications,            // bell.fill (filled)
                color: AppColors.primary,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '系统消息',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '查看系统通知',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}

/// 客服卡片 - 对齐iOS CustomerServiceCard (带渐变背景)
class _CustomerServiceCard extends StatelessWidget {
  const _CustomerServiceCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.success.withValues(alpha: 0.8),
              AppColors.success,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: AppColors.success.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.headset_mic,
                color: AppColors.success,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.messagesCustomerService,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.messagesContactService,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

/// 互动消息卡片 - 对齐iOS InteractionMessageCard (带渐变背景)
class _InteractionMessageCard extends StatelessWidget {
  const _InteractionMessageCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        height: 80,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.warning.withValues(alpha: 0.8),
              AppColors.warning,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: AppColors.warning.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // 图标
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite,
                color: AppColors.warning,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            // 文字
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.messagesInteractionInfo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.messagesViewForumInteractions,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: Colors.white70,
            ),
          ],
        ),
      ),
    );
  }
}

/// 任务聊天项 - 对齐iOS TaskChatRow
class _TaskChatItem extends StatelessWidget {
  const _TaskChatItem({
    required this.taskChat,
  });

  final TaskChat taskChat;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        context.push('/task-chat/${taskChat.taskId}');
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // 头像
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                  child: const Icon(Icons.task, color: AppColors.primary),
                ),
                if (taskChat.unreadCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 18,
                        minHeight: 18,
                      ),
                      child: Text(
                        taskChat.unreadCount > 99
                            ? '99+'
                            : '${taskChat.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            AppSpacing.hMd,

            // 内容
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          taskChat.taskTitle,
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        taskChat.lastMessageTime != null
                            ? DateFormatter.formatSmart(
                                taskChat.lastMessageTime!)
                            : '',
                        style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiaryLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          taskChat.lastMessage ?? '暂无消息',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (taskChat.taskStatus != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.allSmall,
                          ),
                          child: Text(
                            taskChat.taskStatus!,
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
