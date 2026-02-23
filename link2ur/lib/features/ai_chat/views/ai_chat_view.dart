import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_router.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/services/ai_chat_service.dart';
import '../../tasks/views/create_task_view.dart';
import '../bloc/ai_chat_bloc.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/task_draft_card.dart';
import '../widgets/tool_call_card.dart';

/// AI 聊天页面
class AIChatView extends StatelessWidget {
  const AIChatView({
    super.key,
    this.conversationId,
  });

  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    final aiChatService = context.read<AIChatService>();

    return BlocProvider(
      create: (_) {
        final bloc = AIChatBloc(aiChatService: aiChatService);
        if (conversationId != null) {
          bloc.add(AIChatLoadHistory(conversationId!));
        } else {
          bloc.add(const AIChatCreateConversation());
        }
        return bloc;
      },
      child: const _AIChatContent(),
    );
  }
}

class _AIChatContent extends StatefulWidget {
  const _AIChatContent();

  @override
  State<_AIChatContent> createState() => _AIChatContentState();
}

class _AIChatContentState extends State<_AIChatContent> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isEmpty) return;

    context.read<AIChatBloc>().add(AIChatSendMessage(content));
    _messageController.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.aiChatTitle),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            onPressed: () {
              context.read<AIChatBloc>().add(const AIChatCreateConversation());
            },
            tooltip: context.l10n.aiChatNewConversation,
          ),
        ],
      ),
      body: Column(
        children: [
          // 消息列表
          Expanded(
            child: BlocConsumer<AIChatBloc, AIChatState>(
              listenWhen: (prev, curr) =>
                  prev.messages.length != curr.messages.length ||
                  prev.isReplying != curr.isReplying,
              listener: (context, state) => _scrollToBottom(),
              builder: (context, state) {
                if (state.status == AIChatStatus.loading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (state.messages.isEmpty && !state.isReplying) {
                  return _WelcomeView(isDark: isDark);
                }

                final hasToolCall = state.activeToolCall != null;
                final hasDraft = state.taskDraft != null;
                final extraItems = (state.isReplying ? 1 : 0) +
                    (hasToolCall ? 1 : 0) +
                    (hasDraft ? 1 : 0);

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(
                    top: AppSpacing.md,
                    bottom: AppSpacing.sm,
                  ),
                  itemCount: state.messages.length + extraItems,
                  itemBuilder: (context, index) {
                    if (index < state.messages.length) {
                      return AIMessageBubble(
                        key: ValueKey(state.messages[index].id ?? index),
                        message: state.messages[index],
                      );
                    }

                    final adjustedIndex = index - state.messages.length;
                    int cursor = 0;

                    if (hasToolCall && adjustedIndex == cursor) {
                      return ToolCallCard(
                        toolName: state.activeToolCall!,
                      );
                    }
                    if (hasToolCall) cursor++;

                    if (state.isReplying && adjustedIndex == cursor) {
                      return StreamingBubble(
                        content: state.streamingContent,
                      );
                    }
                    if (state.isReplying) cursor++;

                    if (hasDraft && adjustedIndex == cursor) {
                      return TaskDraftCard(
                        draft: state.taskDraft!,
                        onConfirm: () {
                          final draftData = TaskDraftData.fromJson(state.taskDraft!);
                          context.read<AIChatBloc>().add(const AIChatClearTaskDraft());
                          context.push(AppRoutes.createTask, extra: draftData);
                        },
                      );
                    }

                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          ),

          // 错误提示
          BlocBuilder<AIChatBloc, AIChatState>(
            buildWhen: (prev, curr) =>
                prev.errorMessage != curr.errorMessage,
            builder: (context, state) {
              if (state.errorMessage == null) {
                return const SizedBox.shrink();
              }
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                color: Colors.red.withAlpha(25),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 13,
                  ),
                ),
              );
            },
          ),

          // 输入框
          _InputBar(
            controller: _messageController,
            onSend: _sendMessage,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

/// 欢迎区域：Linker 自我介绍 + 快捷问题，以聊天气泡形式展示
class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bubbleBg = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFF2F2F7);

    return ListView(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LinkerAvatar(isDark: isDark),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppRadius.large),
                    topRight: Radius.circular(AppRadius.large),
                    bottomLeft: Radius.circular(AppRadius.tiny),
                    bottomRight: Radius.circular(AppRadius.large),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.l10n.aiChatWelcomeTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      context.l10n.aiChatWelcomeIntro,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        height: 1.45,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.l10n.aiChatQuickStart,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _QuickAction(
                          label: context.l10n.aiChatViewMyTasks,
                          onTap: () => _sendQuickMessage(context, context.l10n.aiChatViewMyTasks),
                        ),
                        _QuickAction(
                          label: context.l10n.aiChatSearchTasks,
                          onTap: () => _sendQuickMessage(context, context.l10n.aiChatSearchTasks),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _sendQuickMessage(BuildContext context, String message) {
    context.read<AIChatBloc>().add(AIChatSendMessage(message));
  }
}

/// Linker 头像（使用 any 图标）
class _LinkerAvatar extends StatelessWidget {
  const _LinkerAvatar({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      child: Image.asset(
        AppAssets.any,
        width: 36,
        height: 36,
        fit: BoxFit.cover,
      ),
    );
  }
}

/// 快捷操作按钮
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.large),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
      ),
    );
  }
}

/// 输入框
class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.isDark,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.sm,
        top: AppSpacing.sm,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white12 : Colors.black.withAlpha(15),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: BlocBuilder<AIChatBloc, AIChatState>(
              buildWhen: (prev, curr) =>
                  prev.isReplying != curr.isReplying,
              builder: (context, state) {
                return TextField(
                  controller: controller,
                  enabled: !state.isReplying,
                  maxLines: 4,
                  minLines: 1,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: state.isReplying ? context.l10n.aiChatReplying : context.l10n.aiChatInputHint,
                    hintStyle: TextStyle(
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadius.large),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF2C2C2E)
                        : const Color(0xFFF2F2F7),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: 10,
                    ),
                    isDense: true,
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          BlocBuilder<AIChatBloc, AIChatState>(
            buildWhen: (prev, curr) =>
                prev.isReplying != curr.isReplying,
            builder: (context, state) {
              return IconButton(
                onPressed: state.isReplying ? null : onSend,
                icon: Icon(
                  Icons.send_rounded,
                  color: state.isReplying
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
