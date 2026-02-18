import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/router/app_router.dart';
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
/// 修复：WebSocket过滤、发送/已读API、系统消息、字符限制、分页、滚动
class TaskChatView extends StatelessWidget {
  const TaskChatView({
    super.key,
    required this.taskId,
  });

  final int taskId;

  @override
  Widget build(BuildContext context) {
    final messageRepository = context.read<MessageRepository>();

    return BlocProvider(
      create: (_) => ChatBloc(messageRepository: messageRepository)
        ..add(ChatLoadMessages(userId: '', taskId: taskId)),
      child: _TaskChatContent(taskId: taskId),
    );
  }
}

/// 任务聊天内容（在 BlocProvider 内部，context 可访问 ChatBloc）
class _TaskChatContent extends StatefulWidget {
  const _TaskChatContent({required this.taskId});

  final int taskId;

  @override
  State<_TaskChatContent> createState() => _TaskChatContentState();
}

class _TaskChatContentState extends State<_TaskChatContent> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  String? _currentUserId;
  bool _showActionMenu = false;

  /// 字符限制 - 对齐iOS (500字符)
  static const int _maxCharacters = 500;
  static const int _showCounterThreshold = 400;

  @override
  void initState() {
    super.initState();
    _currentUserId = StorageService.instance.getUserId();
    _scrollController.addListener(_onScroll);
    _messageController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// reverse 模式下，往上滚动（远离 0）= 查看历史消息
  /// maxScrollExtent 方向是旧消息，接近 0 是最新消息
  void _onScroll() {
    if (!_scrollController.hasClients) return;

    // 滚动到历史消息方向 → 加载更多
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 50) {
      context.read<ChatBloc>().add(const ChatLoadMore());
    }
  }

  void _onTextChanged() {
    // 强制限制字符数
    if (_messageController.text.length > _maxCharacters) {
      _messageController.text =
          _messageController.text.substring(0, _maxCharacters);
      _messageController.selection = TextSelection.fromPosition(
        const TextPosition(offset: _maxCharacters),
      );
    }
    // setState(() {}); // 刷新字符计数器
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text.trim();
    context.read<ChatBloc>().add(
          ChatSendMessage(content: content),
        );
    _messageController.clear();
    setState(() => _showActionMenu = false);
    // reverse: true 模式下，新消息自动出现在底部（position 0），无需手动滚动
  }


  Future<void> _pickImage() async {
    final image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (image != null && mounted) {
      context.read<ChatBloc>().add(
            ChatSendImage(filePath: image.path),
          );
      setState(() => _showActionMenu = false);
      // reverse: true 模式下，新消息自动出现在 position 0
    }
  }

  void _toggleActionMenu() {
    setState(() => _showActionMenu = !_showActionMenu);
    // 对齐iOS：展开操作菜单时关闭键盘
    if (_showActionMenu) {
      FocusScope.of(context).unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ChatBloc, ChatState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        // reverse: true 模式下，最新消息始终在底部（position 0），无需手动滚动
      },
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.messages != curr.messages ||
          prev.isSending != curr.isSending ||
          prev.isLoadingMore != curr.isLoadingMore ||
          prev.taskStatus != curr.taskStatus,
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
          appBar: AppBar(
            title: Text(context.l10n.chatTaskTitle(widget.taskId)),
            actions: [
              // 任务详情按钮
              IconButton(
                icon: const Icon(Icons.info_outline),
                onPressed: () {
                  context.safePush('/tasks/${widget.taskId}');
                },
              ),
              // 更多菜单 - 对齐iOS toolbar menu
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'task_detail') {
                    context.safePush('/tasks/${widget.taskId}');
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'task_detail',
                    child: Row(
                      children: [
                        const Icon(Icons.assignment_outlined, size: 20),
                        const SizedBox(width: 8),
                        Text(context.l10n.chatViewDetail),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: Column(
            children: [
              // 任务信息卡片
              _buildTaskInfoCard(state),

              // 消息列表（使用分组）
              Expanded(child: _buildGroupedMessageList(state)),

              // 任务关闭状态提示 - 对齐iOS closedTaskBar
              if (state.isTaskClosed) _buildClosedTaskBar(context),

              // 快捷操作（仅任务进行中显示）
              if (!state.isTaskClosed) _buildQuickActions(),

              // 操作菜单（可展开）
              if (!state.isTaskClosed)
                TaskChatActionMenu(
                  isExpanded: _showActionMenu,
                  onImagePicker: _pickImage,
                  onTaskDetail: () {
                    context.safePush('/tasks/${widget.taskId}');
                  },
                ),

              // 输入区域
              if (!state.isTaskClosed) _buildInputArea(state),
            ],
          ),
        );
      },
    );
  }


  Widget _buildTaskInfoCard(ChatState state) {
    return Container(
      padding: AppSpacing.allMd,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: const Border(
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
            child:
                const Icon(Icons.task_alt, color: AppColors.primary, size: 20),
          ),
          AppSpacing.hMd,
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.chatTaskTitle(widget.taskId),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  state.isTaskClosed
                      ? context.l10n.chatTaskClosed
                      : context.l10n.chatInProgress,
                  style: TextStyle(
                    fontSize: 12,
                    color: state.isTaskClosed
                        ? AppColors.textTertiaryLight
                        : AppColors.success,
                  ),
                ),
              ],
            ),
          ),
          SmallActionButton(
            text: context.l10n.chatViewDetail,
            onPressed: () {
              context.safePush('/tasks/${widget.taskId}');
            },
          ),
        ],
      ),
    );
  }

  /// 任务已关闭提示栏 - 对齐iOS closedTaskStatusBar
  Widget _buildClosedTaskBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.textTertiaryLight.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.info_outline,
              size: 16, color: AppColors.textTertiaryLight),
          const SizedBox(width: 6),
          Text(
            context.l10n.chatTaskClosedHint,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiaryLight,
            ),
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
              label: context.l10n.chatTaskCompleted,
              icon: Icons.check_circle_outline,
              onTap: () {
                _messageController.text =
                    context.l10n.chatTaskCompletedConfirm;
              },
            ),
            AppSpacing.hSm,
            _QuickActionChip(
              label: context.l10n.chatHasIssue,
              icon: Icons.error_outline,
              onTap: () {
                _messageController.text = context.l10n.chatHasIssueMessage;
              },
            ),
            AppSpacing.hSm,
            _QuickActionChip(
              label: context.l10n.chatRequestRefund,
              icon: Icons.money_off,
              onTap: () {
                _messageController.text = context.l10n.chatRequestRefund;
              },
            ),
            AppSpacing.hSm,
            _QuickActionChip(
              label: context.l10n.chatUploadProof,
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
                ChatLoadMessages(userId: '', taskId: widget.taskId),
              );
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

    // 消息分组：state.messages 已是后端「最新在前」，groups[0]=最新
    // reverse: true 时 index 0 在底部，故直接用 groups 即可：最新在底部，往上滑是更早的消息
    final currentUserId = _currentUserId ?? StorageService.instance.getUserId();
    final groups = groupMessages(state.messages, currentUserId);

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.symmetric(vertical: 12),
      addAutomaticKeepAlives: false,
      itemCount: groups.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        // 加载更多指示器（reverse 模式下 index 最大 = 视觉顶部）
        if (state.isLoadingMore && index == groups.length) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Center(child: LoadingIndicator(size: 20)),
          );
        }
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
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(ChatState state) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 使用半透明容器替代 BackdropFilter，减少滚动时的重绘开销
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark.withValues(alpha: 0.85)
            : AppColors.cardBackgroundLight.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.04),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
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
                    maxLines: 5,
                    minLines: 1,
                    maxLength: _maxCharacters,
                    buildCounter: (context,
                            {required currentLength,
                            required isFocused,
                            required maxLength}) =>
                        null, // 自定义计数器位置
                    decoration: InputDecoration(
                      hintText: context.l10n.chatInputHint,
                      filled: true,
                      fillColor: AppColors.skeletonBase,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
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
                    child: LoadingIndicator(),
                  )
                else
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _messageController,
                    builder: (context, value, child) {
                      return IconButton(
                        icon: const Icon(Icons.send),
                        onPressed: value.text.trim().isEmpty
                            ? null
                            : _sendMessage,
                        color: AppColors.primary,
                      );
                    },
                  ),
              ],
            ),
            // 字符计数器 - 对齐iOS (400+显示)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final charCount = value.text.length;
                final showCounter = charCount >= _showCounterThreshold;
                if (!showCounter) return const SizedBox.shrink();

                return Padding(
                  padding: const EdgeInsets.only(top: 4, right: 8),
                  child: Text(
                    '$charCount/$_maxCharacters',
                    style: TextStyle(
                      fontSize: 11,
                      color: charCount >= _maxCharacters
                          ? AppColors.error
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                );
              },
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
