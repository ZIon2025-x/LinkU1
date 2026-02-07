import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/models/message.dart';
import '../bloc/message_bloc.dart';

/// 消息列表页
/// 参考iOS MessageView.swift
class MessageView extends StatelessWidget {
  const MessageView({super.key});

  @override
  Widget build(BuildContext context) {
    final messageRepository = context.read<MessageRepository>();

    return BlocProvider(
      create: (context) => MessageBloc(messageRepository: messageRepository)
        ..add(const MessageLoadContacts())
        ..add(const MessageLoadTaskChats()),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('消息'),
            bottom: const TabBar(
              tabs: [
                Tab(text: '任务消息'),
                Tab(text: '私信'),
              ],
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondaryLight,
              indicatorColor: AppColors.primary,
            ),
          ),
          body: const TabBarView(
            children: [
              _TaskChatList(),
              _PrivateChatList(),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskChatList extends StatelessWidget {
  const _TaskChatList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessageBloc, MessageState>(
      builder: (context, state) {
        if (state.status == MessageStatus.loading && state.taskChats.isEmpty) {
          return const LoadingView();
        }

        if (state.status == MessageStatus.error && state.taskChats.isEmpty) {
          return ErrorStateView.loadFailed(
            message: state.errorMessage,
            onRetry: () {
              context.read<MessageBloc>().add(const MessageLoadTaskChats());
            },
          );
        }

        if (state.taskChats.isEmpty) {
          return EmptyStateView.noMessages();
        }

        return ListView.separated(
          padding: AppSpacing.allMd,
          itemCount: state.taskChats.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final taskChat = state.taskChats[index];
            return _TaskChatItem(taskChat: taskChat);
          },
        );
      },
    );
  }
}

class _PrivateChatList extends StatelessWidget {
  const _PrivateChatList();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MessageBloc, MessageState>(
      builder: (context, state) {
        if (state.status == MessageStatus.loading && state.contacts.isEmpty) {
          return const LoadingView();
        }

        if (state.status == MessageStatus.error && state.contacts.isEmpty) {
          return ErrorStateView.loadFailed(
            message: state.errorMessage,
            onRetry: () {
              context.read<MessageBloc>().add(const MessageLoadContacts());
            },
          );
        }

        if (state.contacts.isEmpty) {
          return EmptyStateView.noMessages();
        }

        return ListView.separated(
          padding: AppSpacing.allMd,
          itemCount: state.contacts.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final contact = state.contacts[index];
            return _PrivateChatItem(contact: contact);
          },
        );
      },
    );
  }
}

class _TaskChatItem extends StatelessWidget {
  const _TaskChatItem({
    required this.taskChat,
  });

  final TaskChat taskChat;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/task-chat/${taskChat.taskId}');
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            // 头像 - 使用任务图标或第一个参与者头像
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
                        taskChat.unreadCount > 99 ? '99+' : '${taskChat.unreadCount}',
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
                            ? DateFormatter.formatSmart(taskChat.lastMessageTime!)
                            : '',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          taskChat.lastMessage ?? '暂无消息',
                          style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (taskChat.taskStatus != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: AppRadius.allSmall,
                          ),
                          child: Text(
                            taskChat.taskStatus!,
                            style: TextStyle(
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

class _PrivateChatItem extends StatelessWidget {
  const _PrivateChatItem({
    required this.contact,
  });

  final ChatContact contact;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.push('/chat/${contact.id}');
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
                  backgroundImage: contact.user.avatar != null
                      ? NetworkImage(contact.user.avatar!)
                      : null,
                  child: contact.user.avatar == null
                      ? const Icon(Icons.person, color: AppColors.primary)
                      : null,
                ),
                if (contact.isOnline)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.success,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                if (contact.unreadCount > 0 && !contact.isOnline)
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
                        contact.unreadCount > 99 ? '99+' : '${contact.unreadCount}',
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
                          contact.user.name.isNotEmpty ? contact.user.name : '用户${contact.user.id}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        contact.lastMessageTime != null
                            ? DateFormatter.formatSmart(contact.lastMessageTime!)
                            : '',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    contact.lastMessage ?? '暂无消息',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryLight,
                      fontWeight: contact.unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
