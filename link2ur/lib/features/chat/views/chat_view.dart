import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/message_group_bubble.dart';

/// 私信聊天页
/// 参考iOS ChatView.swift
/// 增强版本：支持消息分组、图片发送、头像点击
class ChatView extends StatefulWidget {
  const ChatView({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  State<ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<ChatView> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  String? _currentUserId;
  bool _showAttachMenu = false;

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
    setState(() => _showAttachMenu = false);
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

  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (image != null && mounted) {
      context.read<ChatBloc>().add(
            ChatSendImage(filePath: image.path),
          );
      setState(() => _showAttachMenu = false);
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
                IconButton(
                  icon: const Icon(Icons.person_outline),
                  onPressed: () => context.push('/user/${widget.userId}'),
                ),
              ],
            ),
            body: Column(
              children: [
                // 消息列表（使用分组气泡）
                Expanded(child: _buildGroupedMessageList(state)),

                // 附件选项
                if (_showAttachMenu) _buildAttachMenu(),

                // 输入区域
                _buildInputArea(state),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildGroupedMessageList(ChatState state) {
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 48, color: AppColors.textTertiaryLight),
            AppSpacing.vMd,
            Text(
              '还没有消息，开始对话吧',
              style: TextStyle(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      );
    }

    // 使用消息分组
    final groups = groupMessages(state.messages, _currentUserId);

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: groups.length,
      itemBuilder: (context, index) {
        final group = groups[index];
        return MessageGroupBubbleView(
          group: group,
          onAvatarTap: () {
            if (group.senderId != null) {
              context.push('/user/${group.senderId}');
            }
          },
          onImageTap: (url) {
            FullScreenImageView.show(
              context,
              images: [url],
              initialIndex: 0,
            );
          },
        );
      },
    );
  }

  Widget _buildAttachMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(
          top: BorderSide(color: AppColors.dividerLight, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          _AttachOption(
            icon: Icons.photo_library,
            label: '图片',
            color: AppColors.success,
            onTap: _pickImage,
          ),
          const SizedBox(width: 24),
          _AttachOption(
            icon: Icons.camera_alt,
            label: '拍照',
            color: AppColors.primary,
            onTap: () async {
              final image = await _imagePicker.pickImage(
                source: ImageSource.camera,
                imageQuality: 80,
              );
              if (image != null && mounted) {
                context.read<ChatBloc>().add(
                      ChatSendImage(filePath: image.path),
                    );
                setState(() => _showAttachMenu = false);
              }
            },
          ),
        ],
      ),
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
              icon: AnimatedRotation(
                turns: _showAttachMenu ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add_circle_outline),
              ),
              onPressed: () {
                setState(() => _showAttachMenu = !_showAttachMenu);
              },
              color: _showAttachMenu
                  ? AppColors.primary
                  : AppColors.textSecondaryLight,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !state.isSending,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: '输入消息...',
                  filled: true,
                  fillColor: AppColors.skeletonBase,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.allPill,
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                onTap: () {
                  if (_showAttachMenu) {
                    setState(() => _showAttachMenu = false);
                  }
                },
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

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: AppRadius.allMedium,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondaryLight,
            ),
          ),
        ],
      ),
    );
  }
}
