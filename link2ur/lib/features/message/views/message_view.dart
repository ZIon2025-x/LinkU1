import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/empty_state_view.dart';

/// 消息列表页
/// 参考iOS MessageView.swift
class MessageView extends StatelessWidget {
  const MessageView({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
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
    );
  }
}

class _TaskChatList extends StatelessWidget {
  const _TaskChatList();

  @override
  Widget build(BuildContext context) {
    final chats = List.generate(5, (index) => index);

    if (chats.isEmpty) {
      return EmptyStateView.noMessages();
    }

    return ListView.separated(
      padding: AppSpacing.allMd,
      itemCount: chats.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        return _ChatItem(
          index: index,
          isTaskChat: true,
        );
      },
    );
  }
}

class _PrivateChatList extends StatelessWidget {
  const _PrivateChatList();

  @override
  Widget build(BuildContext context) {
    final chats = List.generate(3, (index) => index);

    if (chats.isEmpty) {
      return EmptyStateView.noMessages();
    }

    return ListView.separated(
      padding: AppSpacing.allMd,
      itemCount: chats.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        return _ChatItem(
          index: index,
          isTaskChat: false,
        );
      },
    );
  }
}

class _ChatItem extends StatelessWidget {
  const _ChatItem({
    required this.index,
    required this.isTaskChat,
  });

  final int index;
  final bool isTaskChat;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (isTaskChat) {
          context.push('/task-chat/${index + 1}');
        } else {
          context.push('/chat/${index + 1}');
        }
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
                  child: const Icon(Icons.person, color: AppColors.primary),
                ),
                if (index == 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
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
                          isTaskChat ? '任务: 示例任务 ${index + 1}' : '用户 ${index + 1}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${index + 1}小时前',
                        style: TextStyle(fontSize: 12, color: AppColors.textTertiaryLight),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '最后一条消息内容...',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondaryLight),
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
