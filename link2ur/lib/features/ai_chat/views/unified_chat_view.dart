import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/ai_chat.dart';
import '../../../data/models/customer_service.dart';
import '../../../data/repositories/common_repository.dart';
import '../../../data/services/ai_chat_service.dart';
import '../bloc/unified_chat_bloc.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/tool_call_card.dart';

/// 统一 AI + 人工客服聊天页面
class UnifiedChatView extends StatelessWidget {
  const UnifiedChatView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = UnifiedChatBloc(
          aiChatService: context.read<AIChatService>(),
          commonRepository: context.read<CommonRepository>(),
        );
        bloc.add(const UnifiedChatInit());
        return bloc;
      },
      child: const _UnifiedChatContent(),
    );
  }
}

class _UnifiedChatContent extends StatefulWidget {
  const _UnifiedChatContent();

  @override
  State<_UnifiedChatContent> createState() => _UnifiedChatContentState();
}

class _UnifiedChatContentState extends State<_UnifiedChatContent> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && _scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    context.read<UnifiedChatBloc>().add(UnifiedChatSendMessage(text));
    _messageController.clear();
    _focusNode.unfocus();
    _scrollToBottom();
  }

  void _showRatingDialog() {
    int selectedRating = 5;
    final commentController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(context.l10n.customerServiceRateServiceTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1),
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.l10n.customerServiceRatingContent,
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(context.l10n.commonCancel),
            ),
            TextButton(
              onPressed: () {
                context.read<UnifiedChatBloc>().add(
                      UnifiedChatCSRateChat(
                        rating: selectedRating,
                        comment: commentController.text.trim().isNotEmpty
                            ? commentController.text.trim()
                            : null,
                      ),
                    );
                Navigator.pop(ctx);
              },
              child: Text(context.l10n.commonSubmit),
            ),
          ],
        ),
      ),
    ).then((_) => commentController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<UnifiedChatBloc, UnifiedChatState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null ||
          curr.errorMessage != null ||
          prev.aiMessages.length != curr.aiMessages.length ||
          prev.csMessages.length != curr.csMessages.length,
      listener: (context, state) {
        if (state.actionMessage != null) {
          final message = switch (state.actionMessage) {
            'conversation_ended' => context.l10n.actionConversationEnded,
            'end_conversation_failed' =>
              context.l10n.actionEndConversationFailed,
            'feedback_success' => context.l10n.actionFeedbackSuccess,
            'feedback_failed' => context.l10n.actionFeedbackFailed,
            _ => state.actionMessage!,
          };
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
        _scrollToBottom();
      },
      child: Scaffold(
        appBar: _buildAppBar(isDark),
        body: Column(
          children: [
            // CS 连接横幅
            _buildCSBanner(isDark),
            // 消息列表
            Expanded(child: _buildMessageList(isDark)),
            // 输入区域
            _buildInputArea(isDark),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: BlocBuilder<UnifiedChatBloc, UnifiedChatState>(
        buildWhen: (prev, curr) =>
            prev.mode != curr.mode ||
            prev.csServiceName != curr.csServiceName,
        builder: (context, state) {
          final (title, actions) = switch (state.mode) {
            ChatMode.ai => (
                context.l10n.supportChatTitle,
                [
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    onPressed: () => context
                        .read<UnifiedChatBloc>()
                        .add(const UnifiedChatInit()),
                  ),
                ]
              ),
            ChatMode.transferring => (
                context.l10n.supportChatConnecting,
                <Widget>[]
              ),
            ChatMode.csConnected => (
                '${context.l10n.supportChatConnected} — ${state.csServiceName ?? ""}',
                [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: context.l10n.customerServiceEndConversation,
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(
                              context.l10n.customerServiceEndConversation),
                          content:
                              Text(context.l10n.customerServiceEndMessage),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(context.l10n.commonCancel),
                            ),
                            TextButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                context
                                    .read<UnifiedChatBloc>()
                                    .add(const UnifiedChatCSEndChat());
                              },
                              child: Text(
                                context.l10n.customerServiceEndConversation,
                                style:
                                    const TextStyle(color: AppColors.error),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ]
              ),
            ChatMode.csEnded => (
                context.l10n.supportChatEnded,
                [
                  IconButton(
                    icon: const Icon(Icons.star_outline),
                    onPressed: _showRatingDialog,
                  ),
                ]
              ),
          };

          return AppBar(
            title: Text(title),
            centerTitle: true,
            actions: actions,
          );
        },
      ),
    );
  }

  /// CS 在线横幅
  Widget _buildCSBanner(bool isDark) {
    return BlocBuilder<UnifiedChatBloc, UnifiedChatState>(
      buildWhen: (prev, curr) =>
          prev.csOnlineStatus != curr.csOnlineStatus ||
          prev.mode != curr.mode,
      builder: (context, state) {
        if (state.csOnlineStatus != true || state.mode != ChatMode.ai) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AppColors.primary.withValues(alpha: 0.08),
          child: Row(
            children: [
              const Icon(Icons.support_agent, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  context.l10n.supportChatHumanOnline,
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context
                    .read<UnifiedChatBloc>()
                    .add(const UnifiedChatRequestHumanCS()),
                child: Text(context.l10n.supportChatConnectButton),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageList(bool isDark) {
    return BlocBuilder<UnifiedChatBloc, UnifiedChatState>(
      buildWhen: (prev, curr) =>
          prev.aiMessages != curr.aiMessages ||
          prev.csMessages != curr.csMessages ||
          prev.streamingContent != curr.streamingContent ||
          prev.isTyping != curr.isTyping ||
          prev.activeToolCall != curr.activeToolCall ||
          prev.mode != curr.mode,
      builder: (context, state) {
        // 构建虚拟列表项
        final items = <_ChatListItem>[];

        // AI 消息
        for (var i = 0; i < state.aiMessages.length; i++) {
          items.add(_ChatListItem.ai(state.aiMessages[i], i));
        }

        // 工具调用指示器
        if (state.activeToolCall != null) {
          items.add(_ChatListItem.tool(state.activeToolCall!));
        }

        // 流式回复（含等待中：isTyping 时显示三点动画，有内容时显示文字+光标）
        if (state.isTyping || state.streamingContent.isNotEmpty) {
          items.add(_ChatListItem.streaming(state.streamingContent));
        }

        // 分割线
        final showDivider = state.csMessages.isNotEmpty ||
            state.mode == ChatMode.csConnected ||
            state.mode == ChatMode.csEnded;
        if (showDivider) {
          items.add(_ChatListItem.divider());
        }

        // CS 消息
        for (var i = 0; i < state.csMessages.length; i++) {
          items.add(_ChatListItem.cs(state.csMessages[i], i));
        }

        return GestureDetector(
          onTap: () => _focusNode.unfocus(),
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              switch (item.type) {
                case _ChatItemType.ai:
                  return AIMessageBubble(
                    key: ValueKey('ai_${item.aiMessage!.id ?? 'local_${item.index}'}'),
                    message: item.aiMessage!,
                  );
                case _ChatItemType.tool:
                  return ToolCallCard(
                    key: ValueKey('tool_${item.toolName}'),
                    toolName: item.toolName!,
                  );
                case _ChatItemType.streaming:
                  return StreamingBubble(
                    key: const ValueKey('ai_streaming'),
                    content: item.streamingContent!,
                  );
                case _ChatItemType.dividerItem:
                  return _buildDivider(isDark);
                case _ChatItemType.cs:
                  return _buildCSMessageBubble(item.csMessage!, isDark);
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.lg,
      ),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              context.l10n.supportChatDivider,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCSMessageBubble(CustomerServiceMessage message, bool isDark) {
    final isFromUser = message.senderType == 'user';
    final isSystem = message.messageType == 'system';

    if (isSystem) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color:
                  (isDark ? AppColors.dividerDark : AppColors.separatorLight)
                      .withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              message.content,
              style: AppTypography.caption.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromUser) ...[
            ClipOval(
              child: Image.asset(
                AppAssets.logo,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
              ),
            ),
            AppSpacing.hSm,
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.7,
              ),
              padding: AppSpacing.allSm,
              decoration: BoxDecoration(
                gradient: isFromUser
                    ? const LinearGradient(
                        colors: AppColors.gradientPrimary,
                      )
                    : null,
                color: isFromUser
                    ? null
                    : (isDark
                        ? AppColors.cardBackgroundDark
                        : AppColors.cardBackgroundLight),
                borderRadius: AppRadius.allMedium,
                border: isFromUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : AppColors.dividerLight,
                        width: 0.5,
                      ),
              ),
              child: Text(
                message.content,
                style: AppTypography.body.copyWith(
                  color: isFromUser
                      ? Colors.white
                      : (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark) {
    return BlocBuilder<UnifiedChatBloc, UnifiedChatState>(
      buildWhen: (prev, curr) =>
          prev.mode != curr.mode || prev.isTyping != curr.isTyping,
      builder: (context, state) {
        // CS 结束状态：显示评价和返回按钮
        if (state.mode == ChatMode.csEnded) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.cardBackgroundLight,
              border: Border(
                top: BorderSide(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.supportChatEnded,
                      style: AppTypography.body.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _showRatingDialog,
                    child: Text(
                      context.l10n.customerServiceRateService,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context
                        .read<UnifiedChatBloc>()
                        .add(const UnifiedChatReturnToAI()),
                    child: Text(
                      context.l10n.supportChatReturnToAI,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 转接中
        if (state.mode == ChatMode.transferring) {
          return Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.cardBackgroundLight,
              border: Border(
                top: BorderSide(
                  color:
                      isDark ? AppColors.dividerDark : AppColors.dividerLight,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const LoadingIndicator(size: 16),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.supportChatConnecting,
                    style: AppTypography.body.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // 正常输入栏
        final bool isDisabled = state.isTyping;
        final String hintText;
        if (state.mode == ChatMode.csConnected) {
          hintText = context.l10n.customerServiceEnterMessage;
        } else if (state.isTyping) {
          hintText = 'AI ${context.l10n.supportChatConnecting}...';
        } else {
          hintText = context.l10n.customerServiceEnterMessage;
        }

        return Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            border: Border(
              top: BorderSide(
                color:
                    isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    focusNode: _focusNode,
                    enabled: !isDisabled,
                    decoration: InputDecoration(
                      hintText: hintText,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allSmall,
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppRadius.allSmall,
                        borderSide: BorderSide(
                          color: isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                        ),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      isDense: true,
                    ),
                    maxLines: 4,
                    minLines: 1,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                AppSpacing.hSm,
                IconButton(
                  onPressed: isDisabled ? null : _sendMessage,
                  icon: isDisabled
                      ? const LoadingIndicator(size: 20)
                      : const Icon(
                          Icons.arrow_upward,
                          color: AppColors.primary,
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ==================== ListView.builder helper ====================

enum _ChatItemType { ai, tool, streaming, dividerItem, cs }

class _ChatListItem {
  const _ChatListItem._({
    required this.type,
    this.aiMessage,
    this.csMessage,
    this.toolName,
    this.streamingContent,
    this.index = 0,
  });

  final _ChatItemType type;
  final AIMessage? aiMessage;
  final CustomerServiceMessage? csMessage;
  final String? toolName;
  final String? streamingContent;
  final int index;

  factory _ChatListItem.ai(AIMessage msg, int index) =>
      _ChatListItem._(type: _ChatItemType.ai, aiMessage: msg, index: index);

  factory _ChatListItem.tool(String name) =>
      _ChatListItem._(type: _ChatItemType.tool, toolName: name);

  factory _ChatListItem.streaming(String content) =>
      _ChatListItem._(type: _ChatItemType.streaming, streamingContent: content);

  factory _ChatListItem.divider() =>
      const _ChatListItem._(type: _ChatItemType.dividerItem);

  factory _ChatListItem.cs(CustomerServiceMessage msg, int index) =>
      _ChatListItem._(type: _ChatItemType.cs, csMessage: msg, index: index);
}
