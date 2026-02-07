import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/models/message.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/chat_bloc.dart';

/// 私信聊天页
/// 参考iOS ChatView.swift
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.userId,
  });

  final int userId;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
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
        ..add(ChatLoadMessages(userId: widget.userId)),
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
              title: Text('用户 ${widget.userId}'),
              actions: [
                IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
              ],
            ),
            body: Column(
              children: [
                // 消息列表
                Expanded(
                  child: _buildMessageList(state),
                ),
                
                // 输入区域
                _buildInputArea(state),
              ],
            ),
          );
        },
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
          context.read<ChatBloc>().add(ChatLoadMessages(userId: widget.userId));
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.skeletonBase,
              child: Icon(Icons.person, size: 18, color: AppColors.textTertiaryLight),
            ),
            AppSpacing.hSm,
          ],
          
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? AppColors.primary : AppColors.skeletonBase,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isMe ? 16 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 16),
                ),
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
          
          if (isMe) AppSpacing.hSm,
        ],
      ),
    );
  }
}
