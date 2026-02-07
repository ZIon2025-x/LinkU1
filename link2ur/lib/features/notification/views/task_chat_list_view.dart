import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/message.dart';
import '../../../data/repositories/message_repository.dart';

/// 任务聊天列表页
/// 参考iOS TaskChatListView.swift
/// 显示所有任务相关的聊天会话
class TaskChatListView extends StatefulWidget {
  const TaskChatListView({super.key});

  @override
  State<TaskChatListView> createState() => _TaskChatListViewState();
}

class _TaskChatListViewState extends State<TaskChatListView> {
  List<TaskChat> _chats = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadChats();
  }

  Future<void> _loadChats() async {
    try {
      final repo = context.read<MessageRepository>();
      final chats = await repo.getTaskChats();
      if (mounted) {
        setState(() {
          _chats = chats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务聊天'),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingView();

    if (_errorMessage != null) {
      return ErrorStateView.loadFailed(
        message: _errorMessage,
        onRetry: () {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
          _loadChats();
        },
      );
    }

    if (_chats.isEmpty) {
      return EmptyStateView.noData(
        title: '暂无任务聊天',
        description: '接取或发布任务后，可以在这里与对方沟通',
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        await _loadChats();
      },
      child: ListView.separated(
        padding: AppSpacing.allMd,
        itemCount: _chats.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final chat = _chats[index];
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
            name: otherUser?.name ?? '用户',
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
              style: TextStyle(
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
              style: TextStyle(
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
