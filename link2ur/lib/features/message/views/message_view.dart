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

/// 任务聊天项 - 对齐iOS TaskChatRow (卡片式, 渐变图标, 角色标签)
class _TaskChatItem extends StatelessWidget {
  const _TaskChatItem({
    required this.taskChat,
  });

  final TaskChat taskChat;

  /// 根据任务状态返回不同的渐变颜色
  List<Color> get _statusGradient {
    switch (taskChat.taskStatus) {
      case 'open':
        return [AppColors.primary, const Color(0xFF5AC8FA)];
      case 'assigned':
      case 'in_progress':
        return [const Color(0xFFFF9500), const Color(0xFFFF6B00)];
      case 'completed':
        return [AppColors.success, const Color(0xFF30D158)];
      default:
        return [AppColors.primary, const Color(0xFF5856D6)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = taskChat.unreadCount > 0;
    final gradient = _statusGradient;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/task-chat/${taskChat.taskId}');
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppSpacing.sm),
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            // 对齐iOS: 渐变图标 (56px) + 未读红点
            Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: gradient,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: gradient.first.withValues(alpha: 0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.chat_bubble,
                      color: Colors.white, size: 24),
                ),
                // 对齐iOS: 未读红点 (12px, 右上角, 白色边框)
                if (hasUnread)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppSpacing.md),

            // 内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行: 标题 + 时间 + 未读数
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          taskChat.taskTitle,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w500,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 时间
                      Text(
                        taskChat.lastMessageTime != null
                            ? DateFormatter.formatSmart(
                                taskChat.lastMessageTime!)
                            : '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                      // 对齐iOS: 未读计数胶囊 (在时间旁边)
                      if (hasUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFF3B30), Color(0xFFFF6B6B)],
                            ),
                            borderRadius: AppRadius.allPill,
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
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),

                  // 第二行: 预览消息 + 状态标签
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          taskChat.lastMessage ?? '暂无消息',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: hasUnread
                                ? FontWeight.w500
                                : FontWeight.normal,
                            color: hasUnread
                                ? (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight)
                                : (isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (taskChat.taskStatus != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: gradient.first.withValues(alpha: 0.1),
                            borderRadius: AppRadius.allPill,
                          ),
                          child: Text(
                            taskChat.taskStatus!,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: gradient.first,
                            ),
                          ),
                        ),
                      ],
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
