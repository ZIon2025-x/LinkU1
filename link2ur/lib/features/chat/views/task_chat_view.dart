import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/full_screen_image_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/services/storage_service.dart';
import '../bloc/chat_bloc.dart';
import '../widgets/message_group_bubble.dart';
import '../widgets/task_chat_action_menu.dart';

/// 任务聊天页
/// 参考iOS TaskChatView.swift
/// 增强版本：支持消息分组、操作菜单、图片发送
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
  final _imagePicker = ImagePicker();
  int? _currentUserId;
  bool _showActionMenu = false;

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
    setState(() => _showActionMenu = false);
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
      setState(() => _showActionMenu = false);
    }
  }

  void _toggleActionMenu() {
    setState(() => _showActionMenu = !_showActionMenu);
  }

  @override
  Widget build(BuildContext context) {
    final messageRepository = context.read<MessageRepository>();

    return BlocProvider(
      create: (context) => ChatBloc(messageRepository: messageRepository)
        ..add(ChatLoadMessages(userId: 0, taskId: widget.taskId)),
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
              title: Text('任务 ${widget.taskId}'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    context.push('/tasks/${widget.taskId}');
                  },
                ),
              ],
            ),
            body: Column(
              children: [
                // 任务信息卡片
                _buildTaskInfoCard(state),

                // 消息列表（使用分组）
                Expanded(child: _buildGroupedMessageList(state)),

                // 快捷操作
                _buildQuickActions(),

                // 操作菜单（可展开）
                TaskChatActionMenu(
                  isExpanded: _showActionMenu,
                  onImagePicker: _pickImage,
                  onTaskDetail: () {
                    context.push('/tasks/${widget.taskId}');
                  },
                  onViewLocation: null,
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

  Widget _buildTaskInfoCard(ChatState state) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: AppRadius.allSmall,
            ),
            child: const Icon(Icons.task_alt, color: AppColors.primary, size: 20),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '任务 #${widget.taskId}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '进行中',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          SmallActionButton(
            text: '查看详情',
            onPressed: () {
              context.push('/tasks/${widget.taskId}');
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
            _QuickActionChip(
              label: '已完成',
              icon: Icons.check_circle_outline,
              onTap: () {
                _messageController.text = '任务已完成，请确认。';
              },
            ),
            AppSpacing.hSm,
            _QuickActionChip(
              label: '遇到问题',
              icon: Icons.error_outline,
              onTap: () {
                _messageController.text = '我遇到了一些问题：';
              },
            ),
            AppSpacing.hSm,
            _QuickActionChip(
              label: '申请退款',
              icon: Icons.money_off,
              onTap: () {},
            ),
            AppSpacing.hSm,
            _QuickActionChip(
              label: '上传凭证',
              icon: Icons.upload_file,
              onTap: _pickImage,
            ),
          ],
        ),
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
          context.read<ChatBloc>().add(
                ChatLoadMessages(userId: 0, taskId: widget.taskId),
              );
        },
      );
    }

    if (state.messages.isEmpty) {
      return Center(
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
            // 展开/收起操作菜单
            IconButton(
              icon: AnimatedRotation(
                turns: _showActionMenu ? 0.125 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.add_circle_outline),
              ),
              onPressed: _toggleActionMenu,
              color: _showActionMenu
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
                  if (_showActionMenu) {
                    setState(() => _showActionMenu = false);
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

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.5)),
          borderRadius: AppRadius.allPill,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.primary),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
