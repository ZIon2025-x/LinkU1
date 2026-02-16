import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/utils/date_formatter.dart';
import '../../notification/bloc/notification_bloc.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/task_type_helper.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/swipe_action_cell.dart';
import '../../../data/models/message.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../customer_service/views/customer_service_view.dart';
import '../bloc/message_bloc.dart';

/// 消息列表页
/// BLoC 在 MainTabView 中创建
class MessageView extends StatelessWidget {
  const MessageView({super.key});

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (isDesktop) {
      return Scaffold(
        backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 桌面端标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Text(
                context.l10n.messagesMessages,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.desktopTextLight,
                ),
              ),
            ),
            const Expanded(
              child: _MessageContent(),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
      appBar: AppBar(
        title: Text(context.l10n.messagesMessages),
      ),
      body: const _MessageContent(),
    );
  }
}

class _MessageContent extends StatelessWidget {
  const _MessageContent();

  @override
  Widget build(BuildContext context) {
    final currentUserId = context.select<AuthBloc, String?>(
      (bloc) => bloc.state.user?.id,
    );
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return BlocBuilder<MessageBloc, MessageState>(
      buildWhen: (previous, current) =>
          previous.displayTaskChats != current.displayTaskChats ||
          previous.pinnedTaskIds != current.pinnedTaskIds,
      builder: (context, state) {
        final displayChats = state.displayTaskChats;
        final pinnedIds = state.pinnedTaskIds;

        final listView = ListView.builder(
            padding: EdgeInsets.only(
              left: isDesktop ? 24.0 : AppSpacing.md,
              right: isDesktop ? 24.0 : AppSpacing.md,
              top: AppSpacing.md,
              // extendBody: true 时手动 padding 会覆盖 ListView 自动的 MediaQuery padding
              // MediaQuery.padding.bottom 已包含底部导航栏+系统安全区高度
              bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            itemCount: 2 + (displayChats.isNotEmpty
                ? displayChats.length
                : 1),
            itemBuilder: (context, index) {
              if (index == 0) return const _QuickActionBar();
              if (index == 1) return const SizedBox(height: 16);

              if (displayChats.isNotEmpty) {
                final taskChat = displayChats[index - 2];
                final isPinned = pinnedIds.contains(taskChat.taskId);

                return RepaintBoundary(
                  child: SwipeActionCell(
                    key: ValueKey('swipe_${taskChat.taskId}'),
                    actionMargin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    actions: [
                      // 置顶/取消置顶
                      SwipeAction(
                        icon: Icons.push_pin_rounded,
                        label: isPinned
                            ? context.l10n.chatUnpin
                            : context.l10n.chatPinToTop,
                        color: AppColors.primary,
                        onTap: () {
                          final bloc = context.read<MessageBloc>();
                          if (isPinned) {
                            bloc.add(MessageUnpinTaskChat(taskChat.taskId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.chatUnpinnedHint),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          } else {
                            bloc.add(MessagePinTaskChat(taskChat.taskId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(context.l10n.chatPinnedHint),
                                duration: const Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                      // 删除（软隐藏）
                      SwipeAction(
                        icon: Icons.delete_outline_rounded,
                        label: context.l10n.chatDeleteChat,
                        color: AppColors.error,
                        onTap: () {
                          context.read<MessageBloc>()
                              .add(MessageHideTaskChat(taskChat.taskId));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(context.l10n.chatDeletedHint),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                      ),
                    ],
                    child: _TaskChatItem(
                      taskChat: taskChat,
                      currentUserId: currentUserId,
                      isPinned: isPinned,
                    ),
                  ),
                );
              }

              if (state.status == MessageStatus.loading) {
                return const Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: SkeletonList(imageSize: 56),
                );
              }
              return Column(
                children: [
                  const SizedBox(height: 40),
                  Center(
                    child: Column(
                      children: [
                        const Icon(
                          Icons.message,
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
              );
            },
        );
        return RefreshIndicator(
          onRefresh: () async {
            final messageBloc = context.read<MessageBloc>();
            messageBloc.add(const MessageRefreshRequested());
            context.read<NotificationBloc>()
                .add(const NotificationLoadUnreadNotificationCount());
            await messageBloc.stream
                .firstWhere(
                  (s) => !s.isRefreshing,
                  orElse: () => state,
                )
                .timeout(
                  const Duration(seconds: 15),
                  onTimeout: () => state,
                );
          },
          child: isDesktop ? ContentConstraint(child: listView) : listView,
        );
      },
    );
  }
}

/// 顶部快捷入口栏：三个圆形图标按钮一行排列
class _QuickActionBar extends StatelessWidget {
  const _QuickActionBar();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<NotificationBloc, NotificationState>(
      buildWhen: (previous, current) =>
          previous.unreadCount != current.unreadCount,
      builder: (context, notifState) {
        final systemUnread = notifState.unreadCount.count;
        final interactionUnread = notifState.unreadCount.forumCount;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // 系统消息
            _QuickActionButton(
              icon: Icons.notifications,
              label: context.l10n.notificationSystemMessages,
              color: AppColors.primary,
              unreadCount: systemUnread,
              isDark: isDark,
              onTap: () {
                AppHaptics.selection();
                context.push('/notifications/system');
              },
            ),
            // 客服中心
            _QuickActionButton(
              icon: Icons.headset_mic,
              label: context.l10n.messagesCustomerService,
              color: AppColors.success,
              unreadCount: 0,
              isDark: isDark,
              onTap: () {
                AppHaptics.selection();
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CustomerServiceView(),
                  ),
                );
              },
            ),
            // 互动信息
            _QuickActionButton(
              icon: Icons.favorite,
              label: context.l10n.messagesInteractionInfo,
              color: AppColors.warning,
              unreadCount: interactionUnread,
              isDark: isDark,
              onTap: () {
                AppHaptics.selection();
                context.push('/notifications/interaction');
              },
            ),
          ],
        );
      },
    );
  }
}

/// 单个圆形快捷入口按钮（带未读徽章）
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.unreadCount,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final int unreadCount;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 圆形图标 + 未读徽章
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        color.withValues(alpha: 0.85),
                        color,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 28),
                ),
                // 未读计数徽章
                if (unreadCount > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: unreadCount > 9 ? 5 : 0,
                        vertical: 0,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 20,
                        minHeight: 20,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isDark
                              ? AppColors.cardBackgroundDark
                              : Colors.white,
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // 标签文字
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}


/// 任务聊天项 - 对齐iOS TaskChatRow (卡片式, 图片/图标, 角色标签, 消息预览)
class _TaskChatItem extends StatelessWidget {
  const _TaskChatItem({
    required this.taskChat,
    this.currentUserId,
    this.isPinned = false,
  });

  final TaskChat taskChat;
  final String? currentUserId;
  final bool isPinned;

  // ==================== iOS 对齐: taskTypeIcons ====================

  /// 按 taskSource / taskType 获取图标 (对齐iOS getTaskIcon)
  IconData get _taskIcon {
    final source = taskChat.taskSource ?? 'normal';
    switch (source) {
      case 'flea_market':
        return Icons.shopping_bag;
      case 'expert_service':
        return Icons.star;
      case 'expert_activity':
        return Icons.groups;
      default:
        if (taskChat.taskType != null) {
          return TaskTypeHelper.getIcon(taskChat.taskType!);
        }
        return Icons.chat_bubble;
    }
  }

  /// 根据任务状态返回渐变颜色
  List<Color> get _statusGradient {
    switch (taskChat.taskStatus) {
      case AppConstants.taskStatusOpen:
        return AppColors.gradientBlueTeal;
      case 'assigned':
      case AppConstants.taskStatusInProgress:
        return AppColors.gradientOrange;
      case AppConstants.taskStatusCompleted:
        return [AppColors.success, const Color(0xFF30D158)];
      case AppConstants.taskStatusPendingConfirmation:
      case AppConstants.taskStatusPendingPayment:
        return AppColors.gradientOrange;
      default:
        return [AppColors.primary, const Color(0xFF5856D6)];
    }
  }

  /// 本地化任务状态
  String _localizedStatus(BuildContext context) {
    final l10n = context.l10n;
    switch (taskChat.taskStatus) {
      case AppConstants.taskStatusOpen:
        return l10n.taskStatusOpen;
      case AppConstants.taskStatusInProgress:
      case 'assigned':
        return l10n.taskStatusInProgress;
      case AppConstants.taskStatusCompleted:
        return l10n.taskStatusCompleted;
      case AppConstants.taskStatusCancelled:
        return l10n.taskStatusCancelled;
      case AppConstants.taskStatusPendingConfirmation:
        return l10n.taskStatusPendingConfirmation;
      case AppConstants.taskStatusPendingPayment:
        return l10n.taskStatusPendingPayment;
      default:
        return taskChat.taskStatus ?? '';
    }
  }

  /// 角色标签 (对齐iOS roleLabel)
  String? _roleLabel(BuildContext context) {
    if (currentUserId == null) return null;
    final l10n = context.l10n;
    final source = taskChat.taskSource ?? 'normal';

    if (taskChat.posterId == currentUserId) {
      switch (source) {
        case 'flea_market':
          return l10n.taskDetailBuyer;
        case 'expert_service':
          return l10n.myTasksRoleUser;
        case 'expert_activity':
          return l10n.myTasksRoleParticipant;
        default:
          return l10n.notificationPoster;
      }
    }
    if (taskChat.takerId == currentUserId) {
      switch (source) {
        case 'flea_market':
          return l10n.taskDetailSeller;
        case 'expert_service':
          return l10n.myTasksRoleExpert;
        case 'expert_activity':
          return l10n.myTasksRoleOrganizer;
        default:
          return l10n.notificationTaker;
      }
    }
    if (taskChat.expertCreatorId != null &&
        taskChat.expertCreatorId == currentUserId) {
      switch (source) {
        case 'expert_activity':
          return l10n.myTasksRoleOrganizer;
        case 'expert_service':
          return l10n.myTasksRoleExpert;
        default:
          return l10n.notificationExpert;
      }
    }
    return l10n.notificationParticipant;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasUnread = taskChat.unreadCount > 0;
    final gradient = _statusGradient;
    final l10n = context.l10n;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        // 进入前先本地标记已读，列表立即去红点；进入后 ChatBloc 会请求后端标记已读
        if (taskChat.unreadCount > 0) {
          context.read<MessageBloc>().add(MessageMarkTaskChatRead(taskChat.taskId));
        }
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
          // 单层阴影：减少列表滑动时 GPU 模糊开销
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 对齐iOS: 任务图片/渐变图标 (56px) + 未读红点
            _buildTaskIcon(gradient, hasUnread),
            const SizedBox(width: AppSpacing.md),

            // 内容区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 第一行: 置顶图标 + 标题 + 时间 + 未读数
                  Row(
                    children: [
                      if (isPinned) ...[
                        Icon(
                          Icons.push_pin_rounded,
                          size: 14,
                          color: AppColors.primary.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          taskChat.displayTitle(Localizations.localeOf(context)),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight:
                                hasUnread ? FontWeight.bold : FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 时间 + 未读数 (对齐iOS: 同一行)
                      ..._buildTimeAndUnread(isDark, hasUnread),
                    ],
                  ),

                  // 第二行: 角色标签 (对齐iOS roleLabel)
                  _buildRoleLabel(context, isDark),

                  const SizedBox(height: 2),

                  // 第三行: 消息预览 + 状态标签
                  Row(
                    children: [
                      Expanded(
                        child: _buildMessagePreview(
                            context, isDark, hasUnread, l10n),
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
                            _localizedStatus(context),
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

  /// 对齐iOS: 有任务图片时显示图片，无图片时渐变背景+动态图标
  Widget _buildTaskIcon(List<Color> gradient, bool hasUnread) {
    const double imageSize = 56;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // 有图片: 显示第一张任务图片 (对齐iOS AsyncImageView)
        if (taskChat.images.isNotEmpty)
          AsyncImageView(
            imageUrl: taskChat.images.first,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            borderRadius: BorderRadius.circular(16),
            placeholder: Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_taskIcon, color: Colors.white, size: 24),
            ),
            errorWidget: Container(
              width: imageSize,
              height: imageSize,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_taskIcon, color: Colors.white, size: 24),
            ),
          )
        else
          // 无图片: 渐变背景 + 动态图标 (对齐iOS gradientPrimary + getTaskIcon)
          Container(
            width: imageSize,
            height: imageSize,
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
            child: Icon(_taskIcon, color: Colors.white, size: 24),
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
    );
  }

  /// 时间 + 未读计数胶囊
  List<Widget> _buildTimeAndUnread(bool isDark, bool hasUnread) {
    return [
      // 时间
      Text(
        taskChat.lastMessageTime != null
            ? DateFormatter.formatSmart(taskChat.lastMessageTime!)
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
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error,
            borderRadius: AppRadius.allPill,
          ),
          child: Text(
            taskChat.unreadCount > 99 ? '99+' : '${taskChat.unreadCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ];
  }

  /// 对齐iOS: 角色标签行 (person.fill + 角色文本)
  Widget _buildRoleLabel(BuildContext context, bool isDark) {
    final role = _roleLabel(context);
    if (role == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        children: [
          Icon(
            Icons.person,
            size: 12,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          const SizedBox(width: 4),
          Text(
            role,
            style: TextStyle(
              fontSize: 12,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  /// 对齐iOS: 消息预览 ("发送者: 消息内容" 格式)
  Widget _buildMessagePreview(
      BuildContext context, bool isDark, bool hasUnread, dynamic l10n) {
    final lastMsg = taskChat.lastMessageObj;
    final previewColor = hasUnread
        ? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight)
        : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight);
    final previewWeight = hasUnread ? FontWeight.w500 : FontWeight.normal;

    // 有 lastMessageObj 时使用结构化消息预览
    if (lastMsg != null) {
      final senderPrefix = (lastMsg.senderName != null &&
              lastMsg.senderName!.isNotEmpty)
          ? '${lastMsg.senderName}: '
          : '${l10n.notificationSystem}: ';
      final content =
          lastMsg.content?.isNotEmpty == true ? lastMsg.content! : '';

      return Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: senderPrefix,
              style: TextStyle(
                fontSize: 13,
                fontWeight: previewWeight,
                color: previewColor,
              ),
            ),
            TextSpan(
              text: content,
              style: TextStyle(
                fontSize: 13,
                fontWeight: previewWeight,
                color: previewColor,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    // 降级：使用纯文本 lastMessage
    return Text(
      taskChat.lastMessage ?? l10n.messagesNoTaskChats,
      style: TextStyle(
        fontSize: 13,
        fontWeight: previewWeight,
        color: previewColor,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
