import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/message.dart';
import '../../../data/repositories/message_repository.dart';
import '../../message/bloc/message_bloc.dart';

/// 任务聊天列表页
/// 参考iOS TaskChatListView.swift
/// 显示所有任务相关的聊天会话
class TaskChatListView extends StatelessWidget {
  const TaskChatListView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => MessageBloc(
        messageRepository: context.read<MessageRepository>(),
      )..add(const MessageLoadTaskChats()),
      child: _TaskChatListViewContent(),
    );
  }
}

class _TaskChatListViewContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.notificationTaskChat),
      ),
      body: BlocBuilder<MessageBloc, MessageState>(
        builder: (context, state) {
          return _buildBody(context, state);
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, MessageState state) {
    if (state.status == MessageStatus.loading && state.taskChats.isEmpty) {
      return const LoadingView();
    }

    if (state.status == MessageStatus.error && state.taskChats.isEmpty) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage ?? context.l10n.activityLoadFailed,
        onRetry: () {
          context.read<MessageBloc>().add(const MessageLoadTaskChats());
        },
      );
    }

    if (state.taskChats.isEmpty) {
      return EmptyStateView.noData(
        title: context.l10n.notificationNoTaskChat,
        description: context.l10n.notificationNoTaskChatDesc,
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<MessageBloc>().add(const MessageRefreshRequested());
      },
      child: ListView.separated(
        padding: AppSpacing.allMd,
        itemCount: state.taskChats.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final chat = state.taskChats[index];
          return _TaskChatRow(
            chat: chat,
            onTap: () {
              context.push('/task-chat/${chat.taskId}');
            },
          );
        },
      ),
    );
  }
}

class _TaskChatRow extends StatelessWidget {
  const _TaskChatRow({
    required this.chat,
    required this.onTap,
  });

  final TaskChat chat;
  final VoidCallback onTap;

  String _formatTime(DateTime dateTime) {
    return DateFormatter.formatSmart(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final otherUser =
        chat.participants.isNotEmpty ? chat.participants.first : null;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      leading: Stack(
        children: [
          AvatarView(
            imageUrl: otherUser?.avatar,
            name: otherUser?.name ?? context.l10n.homeDefaultUser,
            size: 48,
          ),
          // 任务图标角标
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: const Icon(Icons.task_alt, size: 10, color: Colors.white),
            ),
          ),
        ],
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              chat.taskTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          if (chat.lastMessageTime != null)
            Text(
              _formatTime(chat.lastMessageTime!),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiaryLight,
              ),
            ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              chat.lastMessage ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
            ),
          ),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.error,
                borderRadius: AppRadius.allPill,
              ),
              child: Text(
                chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
