import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/models/message.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/chat_bloc.dart';

/// 任务聊天页
/// 参考iOS TaskChatView.swift
class TaskChatView extends StatefulWidget {
  const TaskChatView({
    super.key,
    required this.taskId,
  });

  final int taskId;

  @override
  State<TaskChatView> createState() => _TaskChatViewState();
}

class _TaskChatViewState extends State<TaskChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = StorageService.instance.getUserId();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    final content = _messageController.text.trim();
    context.read<ChatBloc>().add(
      ChatSendMessage(content: content),
    );
    _messageController.clear();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final messageRepository = context.read<MessageRepository>();

    return BlocProvider(
      create: (context) => ChatBloc(messageRepository: messageRepository)
        ..add(ChatLoadMessages(userId: 0, taskId: widget.taskId)),
      child: BlocConsumer<ChatBloc, ChatState>(
        listener: (context, state) {
          // 当消息发送成功或收到新消息时，滚动到底部
          if (state.status == ChatStatus.loaded) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _scrollToBottom();
            });
          }
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(
              title: Text('任务 ${widget.taskId}'),
              actions: [
                IconButton(icon: const Icon(Icons.info_outline), onPressed: () {
                  context.push('/task/${widget.taskId}');
                }),
              ],
            ),
            body: Column(
              children: [
                // 任务信息卡片
                _buildTaskInfoCard(state),
                
                // 消息列表
                Expanded(
                  child: _buildMessageList(state),
                ),
                
                // 快捷操作
                _buildQuickActions(),
                
                // 输入区域
                _buildInputArea(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTaskInfoCard(ChatState state) {
    // Try to get task info from state if available, otherwise show placeholder
    final taskTitle = state.taskId != null ? '任务: 任务 ${widget.taskId}' : '任务: 示例任务 ${widget.taskId}';
    
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        border: Border(
          bottom: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  taskTitle,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '状态: 进行中',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondaryLight),
                ),
              ],
            ),
          ),
          SmallActionButton(
            text: '查看详情',
            onPressed: () {
              context.push('/task/${widget.taskId}');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _QuickActionChip(label: '已完成', onTap: () {}),
            AppSpacing.hSm,
            _QuickActionChip(label: '遇到问题', onTap: () {}),
            AppSpacing.hSm,
            _QuickActionChip(label: '申请退款', onTap: () {}),
            AppSpacing.hSm,
            _QuickActionChip(label: '上传凭证', onTap: () {}),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageList(ChatState state) {
    if (state.status == ChatStatus.loading && state.messages.isEmpty) {
      return const LoadingView();
    }

    if (state.status == ChatStatus.error && state.messages.isEmpty) {
      return ErrorStateView.loadFailed(
        message: state.errorMessage,
        onRetry: () {
          context.read<ChatBloc>().add(ChatLoadMessages(userId: 0, taskId: widget.taskId));
        },
      );
    }

    if (state.messages.isEmpty) {
      return const Center(
        child: Text(
          '还没有消息，开始对话吧',
          style: TextStyle(color: AppColors.textSecondaryLight),
        ),
      );
    }

    // 反转消息列表，使最新的在底部
    final reversedMessages = state.messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: AppSpacing.allMd,
      itemCount: reversedMessages.length,
      itemBuilder: (context, index) {
        final message = reversedMessages[index];
        final isMe = _currentUserId != null && message.senderId == _currentUserId;
        return _MessageBubble(
          message: message,
          isMe: isMe,
        );
      },
    );
  }

  Widget _buildInputArea(ChatState state) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () {},
              color: AppColors.textSecondaryLight,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !state.isSending,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  filled: true,
                  fillColor: AppColors.skeletonBase,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.allPill,
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            AppSpacing.hSm,
            if (state.isSending)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: LoadingIndicator(size: 24),
              )
            else
              IconButton(
                icon: const Icon(Icons.send),
                onPressed: _sendMessage,
                color: AppColors.primary,
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary),
          borderRadius: AppRadius.allPill,
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.primary,
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
  });

  final Message message;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final timeText = message.createdAt != null
        ? DateFormatter.formatMessageTime(message.createdAt!)
        : '';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.skeletonBase,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (message.isImage && message.imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        message.imageUrl!,
                        width: 200,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 200,
                            height: 200,
                            color: AppColors.skeletonBase,
                            child: const Icon(Icons.broken_image),
                          );
                        },
                      ),
                    )
                  else
                    Text(
                      message.content,
                      style: TextStyle(
                        color: isMe ? Colors.white : AppColors.textPrimaryLight,
                      ),
                    ),
                  if (timeText.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 10,
                        color: isMe ? Colors.white70 : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
