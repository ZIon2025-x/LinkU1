import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/router/app_routes.dart';
import '../../../core/utils/auth_guard.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/ai_chat.dart';
import '../../../data/models/customer_service.dart';
import '../../../data/repositories/common_repository.dart';
import '../../../data/services/ai_chat_service.dart';
import '../../tasks/views/create_task_view.dart' show TaskDraftData;
import '../bloc/unified_chat_bloc.dart';
import '../widgets/ai_message_bubble.dart';
import '../widgets/service_draft_card.dart';
import '../widgets/task_draft_card.dart';
import '../widgets/task_result_cards.dart';
import '../widgets/tool_call_card.dart';

/// 统一 AI + 人工客服聊天页面（唯一 AI 聊天入口，替代原 AI 页）
class UnifiedChatView extends StatelessWidget {
  const UnifiedChatView({super.key, this.conversationId});

  /// 若传入则加载该对话历史，否则创建新对话
  final String? conversationId;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) {
        final bloc = UnifiedChatBloc(
          aiChatService: context.read<AIChatService>(),
          commonRepository: context.read<CommonRepository>(),
        );
        if (conversationId != null && conversationId!.isNotEmpty) {
          bloc.add(UnifiedChatLoadHistory(conversationId!));
        } else {
          bloc.add(const UnifiedChatInit());
        }
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
    if (!requireAuth(context)) return;

    context.read<UnifiedChatBloc>().add(UnifiedChatSendMessage(text));
    _messageController.clear();
    _focusNode.unfocus();
    _scrollToBottom();
  }

  /// 历史记录：包含 AI 对话 + 客服记录，底部 sheet 展示
  void _showHistorySheet(BuildContext context) {
    _focusNode.unfocus();
    final aiChatService = context.read<AIChatService>();
    final commonRepo = context.read<CommonRepository>();
    final blocContext = context;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 缓存 Future，避免 DraggableScrollableSheet 重建时反复发起请求
    final historyFuture = Future.wait([
      aiChatService.getConversations(),
      commonRepo.getCustomerServiceChats().catchError((_) => <Map<String, dynamic>>[]),
    ]).then((results) => (
      aiList: results[0] as List<AIConversation>,
      csList: results[1] as List<Map<String, dynamic>>,
    ));

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (sheetContext) {
        return SizedBox(
          height: screenHeight * 0.55,
          child: DraggableScrollableSheet(
            initialChildSize: 1,
            minChildSize: 0.5,
            builder: (_, scrollController) {
              return FutureBuilder<
                  ({List<AIConversation> aiList, List<Map<String, dynamic>> csList})>(
                future: historyFuture,
                builder: (ctx, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final aiList = snapshot.data?.aiList ?? [];
                  final csList = snapshot.data?.csList ?? [];
                  final hasAny = aiList.isNotEmpty || csList.isNotEmpty;

                  if (!hasAny) {
                    return Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            context.l10n.customerServiceNoChatHistory,
                            style: AppTypography.body.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    children: [
                      // AI 对话
                      if (aiList.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            context.l10n.aiChatTitle,
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...aiList.map((conv) {
                          final title = conv.title.isEmpty
                              ? context.l10n.aiChatNewConversation
                              : conv.title;
                          final timeStr = conv.updatedAt != null
                              ? _formatConvTime(conv.updatedAt!)
                              : '';
                          return ListTile(
                            leading: ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.medium),
                              child: Image.asset(
                                AppAssets.any,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                              ),
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              timeStr,
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () {
                              blocContext.read<UnifiedChatBloc>().add(
                                    UnifiedChatLoadHistory(conv.id),
                                  );
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                            },
                          );
                        }),
                        const Divider(height: 24),
                      ],
                      // 客服记录
                      if (csList.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.md,
                            vertical: AppSpacing.xs,
                          ),
                          child: Text(
                            context.l10n.customerServiceChatHistory,
                            style: AppTypography.caption.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        ...csList.map((chat) {
                          final chatId = chat['id']?.toString() ?? '';
                          final updatedAt = chat['updated_at']?.toString();
                          DateTime? dt;
                          if (updatedAt != null) dt = DateTime.tryParse(updatedAt);
                          final timeStr = dt != null ? _formatConvTime(dt) : '';
                          final titleStr = chat['title']?.toString();
                          final title = titleStr != null && titleStr.isNotEmpty
                              ? titleStr
                              : context.l10n.customerServiceCustomerService;
                          return ListTile(
                            leading: Icon(
                              Icons.support_agent,
                              size: 40,
                              color: AppColors.primary.withValues(alpha: 0.8),
                            ),
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              timeStr,
                              style: AppTypography.caption.copyWith(
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right, size: 20),
                            onTap: () {
                              if (chatId.isEmpty) return;
                              final isEnded = chat['is_ended'] == true;
                              blocContext.read<UnifiedChatBloc>().add(
                                UnifiedChatLoadCSHistory(
                                  chatId: chatId,
                                  isEnded: isEnded,
                                ),
                              );
                              if (sheetContext.mounted) Navigator.pop(sheetContext);
                            },
                          );
                        }),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  String _formatConvTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    final l10n = context.l10n;
    if (diff.inMinutes < 1) return l10n.timeJustNow;
    if (diff.inHours < 1) return l10n.timeMinutesAgo(diff.inMinutes);
    if (diff.inDays < 1) return l10n.timeHoursAgo(diff.inHours);
    if (diff.inDays < 7) return l10n.timeDaysAgo(diff.inDays);
    return '${time.month}/${time.day}';
  }

  void _showRatingDialog() {
    int selectedRating = 5;
    final commentController = TextEditingController();
    final isIOS = !kIsWeb && Platform.isIOS;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final ratingContent = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  return IconButton(
                    onPressed: () =>
                        setDialogState(() => selectedRating = index + 1),
                    tooltip: '${index + 1} star${index == 0 ? '' : 's'}',
                    icon: Icon(
                      index < selectedRating ? Icons.star : Icons.star_border,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              isIOS
                  ? CupertinoTextField(
                      controller: commentController,
                      maxLines: 3,
                      placeholder: context.l10n.customerServiceRatingContent,
                    )
                  : TextField(
                      controller: commentController,
                      maxLines: 3,
                      decoration: InputDecoration(
                        hintText: context.l10n.customerServiceRatingContent,
                        border: const OutlineInputBorder(),
                      ),
                    ),
            ],
          );

          if (isIOS) {
            return CupertinoAlertDialog(
              title: Text(context.l10n.customerServiceRateServiceTitle),
              content: ratingContent,
              actions: [
                CupertinoDialogAction(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(context.l10n.commonCancel),
                ),
                CupertinoDialogAction(
                  isDefaultAction: true,
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
            );
          }

          return AlertDialog(
            title: Text(context.l10n.customerServiceRateServiceTitle),
            content: ratingContent,
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
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<UnifiedChatBloc, UnifiedChatState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null ||
          curr.errorMessage != null ||
          prev.aiMessages.length != curr.aiMessages.length ||
          prev.csMessages.length != curr.csMessages.length ||
          prev.taskDraft != curr.taskDraft ||
          prev.serviceDraft != curr.serviceDraft,
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
        resizeToAvoidBottomInset: true,
        appBar: _buildAppBar(isDark),
        body: Column(
          children: [
            // CS 连接横幅
            _buildCSBanner(isDark),
            // 消息列表（键盘弹起时被顶起，不遮挡）；RepaintBoundary 减少点击输入框时整列表重绘
            Expanded(
              child: RepaintBoundary(child: _buildMessageList(isDark)),
            ),
            // 错误提示（与 AI 页一致）
            BlocBuilder<UnifiedChatBloc, UnifiedChatState>(
              buildWhen: (prev, curr) => prev.errorMessage != curr.errorMessage,
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
                  color: Colors.red.withValues(alpha: 0.1),
                  child: Text(
                    context.localizeError(state.errorMessage),
                    style: const TextStyle(
                      color: Colors.red,
                      fontSize: 13,
                    ),
                  ),
                );
              },
            ),
            // 输入区域；RepaintBoundary 隔离键盘/焦点引起的重绘，减轻卡顿
            RepaintBoundary(child: _buildInputArea(isDark)),
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
                    tooltip: 'New conversation',
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
                      AdaptiveDialogs.showConfirmDialog(
                        context: context,
                        title: context.l10n.customerServiceEndConversation,
                        content: context.l10n.customerServiceEndMessage,
                        confirmText:
                            context.l10n.customerServiceEndConversation,
                        cancelText: context.l10n.commonCancel,
                        isDestructive: true,
                        onConfirm: () {
                          context
                              .read<UnifiedChatBloc>()
                              .add(const UnifiedChatCSEndChat());
                        },
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
                    tooltip: 'Rate',
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

  /// 顶部仅展示人工客服在线状态（连接按钮已移至下方快捷操作行）
  Widget _buildCSBanner(bool isDark) {
    return BlocBuilder<UnifiedChatBloc, UnifiedChatState>(
      buildWhen: (prev, curr) =>
          prev.csOnlineStatus != curr.csOnlineStatus ||
          prev.mode != curr.mode,
      builder: (context, state) {
        if (state.mode != ChatMode.ai || state.csOnlineStatus != true) {
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
          prev.toolCallCompleted != curr.toolCallCompleted ||
          prev.taskDraft != curr.taskDraft ||
          prev.serviceDraft != curr.serviceDraft ||
          prev.mode != curr.mode,
      builder: (context, state) {
        // 构建虚拟列表项
        final items = <_ChatListItem>[];

        // AI 模式且无任何消息时：显示 Linker 欢迎气泡
        final showWelcome = state.mode == ChatMode.ai &&
            state.aiMessages.isEmpty &&
            state.activeToolCall == null &&
            !state.isTyping &&
            state.streamingContent.isEmpty;
        if (showWelcome) {
          items.add(_ChatListItem.welcome());
        }

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

        // 任务草稿卡片
        if (state.taskDraft != null) {
          items.add(_ChatListItem.draft(state.taskDraft!));
        }

        // 服务草稿卡片
        if (state.serviceDraft != null) {
          items.add(_ChatListItem.serviceDraft(state.serviceDraft!));
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

        final bottomPadding = MediaQuery.of(context).padding.bottom;
        return GestureDetector(
          onTap: () => _focusNode.unfocus(),
          child: ListView.builder(
            controller: _scrollController,
            cacheExtent: 400,
            padding: EdgeInsets.only(
              top: AppSpacing.sm,
              bottom: AppSpacing.sm + bottomPadding,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              switch (item.type) {
                case _ChatItemType.welcome:
                  return _buildLinkerWelcome(isDark);
                case _ChatItemType.ai:
                  final msg = item.aiMessage!;
                  final rd = msg.toolResultData;
                  final hasTaskCards = rd != null && const ['tasks', 'services', 'experts', 'items', 'posts']
                      .any((k) => rd[k] is List && (rd[k] as List).isNotEmpty);
                  if (hasTaskCards) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AIMessageBubble(
                          key: ValueKey('ai_${msg.id ?? 'local_${item.index}'}'),
                          message: msg,
                        ),
                        TaskResultCards(toolResult: msg.toolResultData!),
                      ],
                    );
                  }
                  return AIMessageBubble(
                    key: ValueKey('ai_${msg.id ?? 'local_${item.index}'}'),
                    message: msg,
                  );
                case _ChatItemType.tool:
                  return ToolCallCard(
                    key: ValueKey('tool_${item.toolName}'),
                    toolName: item.toolName!,
                    isLoading: !state.toolCallCompleted,
                  );
                case _ChatItemType.streaming:
                  return StreamingBubble(
                    key: const ValueKey('ai_streaming'),
                    content: item.streamingContent!,
                  );
                case _ChatItemType.taskDraft:
                  return TaskDraftCard(
                    key: const ValueKey('task_draft'),
                    draft: item.taskDraft!,
                    onConfirm: () {
                      final draftData = TaskDraftData.fromJson(state.taskDraft!);
                      context.read<UnifiedChatBloc>().add(const UnifiedChatClearTaskDraft());
                      context.push(AppRoutes.createTask, extra: draftData);
                    },
                  );
                case _ChatItemType.serviceDraftItem:
                  return ServiceDraftCard(
                    key: const ValueKey('service_draft'),
                    draft: item.serviceDraftData!,
                    onConfirm: () {
                      final draft = state.serviceDraft!;
                      context.read<UnifiedChatBloc>().add(const UnifiedChatClearServiceDraft());
                      context.push(AppRoutes.createService, extra: draft);
                    },
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

  /// Linker 欢迎气泡：自我介绍 + 快捷问题（与 ai_chat_view 一致）
  Widget _buildLinkerWelcome(bool isDark) {
    final theme = Theme.of(context);
    final bubbleBg = isDark
        ? const Color(0xFF2C2C2E)
        : const Color(0xFFF2F2F7);

    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            child: Image.asset(
              AppAssets.any,
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
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
                  Builder(builder: (context) {
                    final bloc = context.read<UnifiedChatBloc>();
                    return Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: [
                        _UnifiedQuickAction(
                          label: context.l10n.aiChatViewMyTasks,
                          onTap: () => requireAuth(context, () => bloc.add(
                              UnifiedChatSendMessage(
                                  context.l10n.aiChatViewMyTasks))),
                        ),
                        _UnifiedQuickAction(
                          label: context.l10n.aiChatSearchTasks,
                          onTap: () => requireAuth(context, () => bloc.add(
                              UnifiedChatSendMessage(
                                  context.l10n.aiChatSearchTasks))),
                        ),
                        _UnifiedQuickAction(
                          label: context.l10n.aiChatPostTask,
                          onTap: () => requireAuth(context, () => bloc.add(
                              UnifiedChatSendMessage(
                                  context.l10n.aiChatPostTask))),
                        ),
                        _UnifiedQuickAction(
                          label: context.l10n.aiChatMyPoints,
                          onTap: () => requireAuth(context, () => bloc.add(
                              UnifiedChatSendMessage(
                                  context.l10n.aiChatMyPoints))),
                        ),
                        _UnifiedQuickAction(
                          label: context.l10n.aiChatActivities,
                          onTap: () => requireAuth(context, () => bloc.add(
                              UnifiedChatSendMessage(
                                  context.l10n.aiChatActivities))),
                        ),
                        _UnifiedQuickAction(
                          label: context.l10n.aiChatContactSupport,
                          onTap: () => requireAuth(context, () => bloc.add(
                              UnifiedChatSendMessage(
                                  context.l10n.aiChatContactSupport))),
                        ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
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
          prev.mode != curr.mode ||
          prev.isTyping != curr.isTyping ||
          prev.taskDraft != curr.taskDraft ||
          prev.aiMessages.length != curr.aiMessages.length,
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

        // 与任务聊天框一致：快捷操作单独一行（无容器背景），输入区在下方
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.mode == ChatMode.ai) _buildQuickActionsRow(context),
            Container(
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
                  tooltip: 'Send',
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
        ),
          ],
        );
      },
    );
  }

  /// 快捷操作行：历史记录、连接人工（与任务聊天框一致：仅 padding，无容器背景）
  Widget _buildQuickActionsRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _UnifiedQuickActionChip(
              label: context.l10n.supportChatHistory,
              icon: Icons.history,
              onTap: () => _showHistorySheet(context),
            ),
            const SizedBox(width: 8),
            _UnifiedQuickActionChip(
              label: context.l10n.supportChatConnectButton,
              icon: Icons.support_agent,
              onTap: () => context
                  .read<UnifiedChatBloc>()
                  .add(const UnifiedChatRequestHumanCS()),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== ListView.builder helper ====================

enum _ChatItemType { welcome, ai, tool, streaming, taskDraft, serviceDraftItem, dividerItem, cs }

class _ChatListItem {
  const _ChatListItem._({
    required this.type,
    this.aiMessage,
    this.csMessage,
    this.toolName,
    this.streamingContent,
    this.taskDraft,
    this.serviceDraftData,
    this.index = 0,
  });

  final _ChatItemType type;
  final AIMessage? aiMessage;
  final CustomerServiceMessage? csMessage;
  final String? toolName;
  final String? streamingContent;
  final Map<String, dynamic>? taskDraft;
  final Map<String, dynamic>? serviceDraftData;
  final int index;

  factory _ChatListItem.welcome() =>
      const _ChatListItem._(type: _ChatItemType.welcome);

  factory _ChatListItem.ai(AIMessage msg, int index) =>
      _ChatListItem._(type: _ChatItemType.ai, aiMessage: msg, index: index);

  factory _ChatListItem.tool(String name) =>
      _ChatListItem._(type: _ChatItemType.tool, toolName: name);

  factory _ChatListItem.streaming(String content) =>
      _ChatListItem._(type: _ChatItemType.streaming, streamingContent: content);

  factory _ChatListItem.draft(Map<String, dynamic> draft) =>
      _ChatListItem._(type: _ChatItemType.taskDraft, taskDraft: draft);

  factory _ChatListItem.serviceDraft(Map<String, dynamic> draft) =>
      _ChatListItem._(type: _ChatItemType.serviceDraftItem, serviceDraftData: draft);

  factory _ChatListItem.divider() =>
      const _ChatListItem._(type: _ChatItemType.dividerItem);

  factory _ChatListItem.cs(CustomerServiceMessage msg, int index) =>
      _ChatListItem._(type: _ChatItemType.cs, csMessage: msg, index: index);
}

/// 输入框上快捷操作 Chip（与任务聊天 _QuickActionChip 样式一致）
class _UnifiedQuickActionChip extends StatelessWidget {
  const _UnifiedQuickActionChip({
    required this.label,
    required this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
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
      ),
    );
  }
}

/// 合并聊天页内的快捷问题按钮
class _UnifiedQuickAction extends StatelessWidget {
  const _UnifiedQuickAction({
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
