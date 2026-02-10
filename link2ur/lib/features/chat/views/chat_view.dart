import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
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
class ChatView extends StatelessWidget {
  const ChatView({
    super.key,
    required this.userId,
  });

  final String userId;

  @override
  Widget build(BuildContext context) {
    final messageRepository = context.read<MessageRepository>();

    return BlocProvider(
      create: (_) => ChatBloc(messageRepository: messageRepository)
        ..add(ChatLoadMessages(userId: userId)),
      child: _ChatContent(userId: userId),
    );
  }
}

/// 私信聊天内容（在 BlocProvider 内部，context 可访问 ChatBloc）
class _ChatContent extends StatefulWidget {
  const _ChatContent({required this.userId});

  final String userId;

  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
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
    return BlocConsumer<ChatBloc, ChatState>(
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
            title: Text(context.l10n.chatUserTitle(widget.userId)),
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
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 48, color: AppColors.textTertiaryLight),
            AppSpacing.vMd,
            Text(
              context.l10n.chatNoMessages,
              style: const TextStyle(color: AppColors.textSecondaryLight),
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
        final isOutgoing = group.direction == BubbleDirection.outgoing;

        return _MessageBubbleAnimation(
          index: index,
          isOutgoing: isOutgoing,
          child: MessageGroupBubbleView(
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
          ),
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
            label: context.l10n.chatImageLabel,
            color: AppColors.success,
            onTap: _pickImage,
          ),
          const SizedBox(width: 24),
          _AttachOption(
            icon: Icons.camera_alt,
            label: context.l10n.chatCameraLabel,
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
                  hintText: context.l10n.chatInputHint,
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
              // 渐变发送按钮 - 与iOS对齐
              GestureDetector(
                onTap: _sendMessage,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: AppColors.gradientPrimary,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
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

/// 消息气泡入场动画
/// 自己的消息从右侧滑入，对方的从左侧滑入，带弹簧效果
class _MessageBubbleAnimation extends StatefulWidget {
  const _MessageBubbleAnimation({
    required this.index,
    required this.isOutgoing,
    required this.child,
  });

  final int index;
  final bool isOutgoing;
  final Widget child;

  @override
  State<_MessageBubbleAnimation> createState() =>
      _MessageBubbleAnimationState();
}

class _MessageBubbleAnimationState extends State<_MessageBubbleAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    final slideX = widget.isOutgoing ? 30.0 : -30.0;
    _slideAnimation = Tween<Offset>(
      begin: Offset(slideX, 10),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    ));

    _scaleAnimation = Tween<double>(begin: 0.9, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 限制动画只对最近的消息播放
    final clampedIndex = widget.index.clamp(0, 10);
    final delay = Duration(milliseconds: clampedIndex * 30);
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: _slideAnimation.value,
        child: Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: child,
          ),
        ),
      ),
      child: widget.child,
    );
  }
}
