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
import '../widgets/linker_avatar.dart';
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
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChange);
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
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
                            leading: const LinkerAvatar(size: 40),
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
    final bloc = context.read<UnifiedChatBloc>();
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
                    final comment = commentController.text.trim();
                    bloc.add(
                      UnifiedChatCSRateChat(
                        rating: selectedRating,
                        comment: comment.isNotEmpty ? comment : null,
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
                  final comment = commentController.text.trim();
                  bloc.add(
                    UnifiedChatCSRateChat(
                      rating: selectedRating,
                      comment: comment.isNotEmpty ? comment : null,
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
    ).whenComplete(() => commentController.dispose());
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
            prev.csServiceName != curr.csServiceName ||
            prev.csOnlineStatus != curr.csOnlineStatus,
        builder: (context, state) {
          final (titleWidget, actions) = switch (state.mode) {
            ChatMode.ai => (
                _buildLinkerTitle(state.csOnlineStatus),
                <Widget>[
                  IconButton(
                    icon: const Icon(Icons.add_comment_outlined),
                    tooltip: 'New conversation',
                    onPressed: () => context
                        .read<UnifiedChatBloc>()
                        .add(const UnifiedChatInit()),
                  ),
                ],
              ),
            ChatMode.transferring => (
                Text(context.l10n.supportChatConnecting),
                <Widget>[],
              ),
            ChatMode.csConnected => (
                Text(
                    '${context.l10n.supportChatConnected} — ${state.csServiceName ?? ""}'),
                <Widget>[
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
                ],
              ),
            ChatMode.csEnded => (
                Text(context.l10n.supportChatEnded),
                <Widget>[
                  IconButton(
                    icon: const Icon(Icons.star_outline),
                    tooltip: 'Rate',
                    onPressed: _showRatingDialog,
                  ),
                ],
              ),
          };

          return AppBar(
            title: titleWidget,
            centerTitle: true,
            actions: actions,
          );
        },
      ),
    );
  }

  /// AI 模式下的渐变 "Linker" 标题；副标题始终显示「智能助手」，客服在线时追加「· 脉冲点 人工客服在线」
  Widget _buildLinkerTitle(bool? csOnline) {
    final showOnlineBadge = csOnline == true;
    const subtitleStyle = TextStyle(
      fontSize: 11,
      color: Color(0xFFA1A1A6),
      fontWeight: FontWeight.w500,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LinkerGradientText(
          context.l10n.supportChatTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 1),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.l10n.supportChatAssistantSubtitle, style: subtitleStyle),
            if (showOnlineBadge) ...[
              const SizedBox(width: 6),
              const Text('·', style: subtitleStyle),
              const SizedBox(width: 6),
              const _PulseDot(),
              const SizedBox(width: 5),
              Text(context.l10n.supportChatHumanOnline, style: subtitleStyle),
            ],
          ],
        ),
      ],
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

  /// Linker 欢迎区：发光头像 + 渐变标题 + 介绍 + 2×3 建议网格
  Widget _buildLinkerWelcome(bool isDark) {
    final theme = Theme.of(context);
    final bloc = context.read<UnifiedChatBloc>();
    final l10n = context.l10n;

    void send(String text) =>
        requireAuth(context, () => bloc.add(UnifiedChatSendMessage(text)));

    final suggestions = <_Suggestion>[
      _Suggestion(
        label: l10n.aiChatViewMyTasks,
        icon: Icons.task_alt,
        gradient: const [Color(0xFF007AFF), Color(0xFF5AC8FA)],
        onTap: () => send(l10n.aiChatViewMyTasks),
      ),
      _Suggestion(
        label: l10n.aiChatSearchTasks,
        icon: Icons.search,
        gradient: const [Color(0xFF7359F2), Color(0xFFFF4D80)],
        onTap: () => send(l10n.aiChatSearchTasks),
      ),
      _Suggestion(
        label: l10n.aiChatPostTask,
        icon: Icons.add_circle_outline,
        gradient: const [Color(0xFF3B82F6), Color(0xFF8B5CF6)],
        onTap: () => send(l10n.aiChatPostTask),
      ),
      _Suggestion(
        label: l10n.aiChatMyPoints,
        icon: Icons.monetization_on_outlined,
        gradient: const [Color(0xFFFF8033), Color(0xFFFFD700)],
        onTap: () => send(l10n.aiChatMyPoints),
      ),
      _Suggestion(
        label: l10n.aiChatActivities,
        icon: Icons.event_outlined,
        gradient: const [Color(0xFF26BF73), Color(0xFF5AC8FA)],
        onTap: () => send(l10n.aiChatActivities),
      ),
      _Suggestion(
        label: l10n.aiChatContactSupport,
        icon: Icons.support_agent,
        gradient: const [Color(0xFFFF8033), Color(0xFFFF4D80)],
        onTap: () => send(l10n.aiChatContactSupport),
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          const LinkerAvatar(size: 76, withGlow: true),
          const SizedBox(height: AppSpacing.md),
          LinkerGradientText(
            l10n.aiChatWelcomeTitle,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              l10n.aiChatWelcomeIntro,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.55,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: suggestions
                .map((s) => _SuggestionCard(s: s, isDark: isDark))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    final lineColor = isDark ? AppColors.dividerDark : AppColors.dividerLight;
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.md,
        horizontal: AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lineColor.withValues(alpha: 0), lineColor],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFF8033).withValues(alpha: 0.10),
                    const Color(0xFFFF4D80).withValues(alpha: 0.10),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFFFF8033).withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 11,
                    color: Color(0xFFB35628),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    context.l10n.supportChatDivider,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB35628),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Container(
              height: 0.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [lineColor, lineColor.withValues(alpha: 0)],
                ),
              ),
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
            const CSAvatar(),
            AppSpacing.hSm,
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                gradient: isFromUser
                    ? const LinearGradient(
                        colors: AppColors.gradientPrimary,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : (isDark
                        ? null
                        : const LinearGradient(
                            colors: [Color(0xFFFFF7E6), Color(0xFFFFF1D6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )),
                color: isFromUser
                    ? null
                    : (isDark ? AppColors.cardBackgroundDark : null),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.large),
                  topRight: const Radius.circular(AppRadius.large),
                  bottomLeft: isFromUser
                      ? const Radius.circular(AppRadius.large)
                      : const Radius.circular(AppRadius.tiny),
                  bottomRight: isFromUser
                      ? const Radius.circular(AppRadius.tiny)
                      : const Radius.circular(AppRadius.large),
                ),
                border: isFromUser
                    ? null
                    : Border.all(
                        color: isDark
                            ? AppColors.dividerDark
                            : const Color(0xFFFFD9A8),
                        width: 0.5,
                      ),
                boxShadow: isFromUser
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.22),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 1,
                          offset: const Offset(0, 1),
                        ),
                      ],
              ),
              child: Text(
                message.content,
                style: AppTypography.body.copyWith(
                  color: isFromUser
                      ? Colors.white
                      : isDark
                          ? AppColors.textPrimaryDark
                          : const Color(0xFF6B4500),
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
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2C2C2E)
                              : const Color(0xFFF2F2F7),
                          borderRadius: BorderRadius.circular(22),
                          boxShadow: _focusNode.hasFocus
                              ? [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.18),
                                    spreadRadius: 2,
                                  ),
                                ]
                              : null,
                        ),
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          enabled: !isDisabled,
                          maxLines: 4,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendMessage(),
                          decoration: InputDecoration(
                            hintText: hintText,
                            hintStyle: const TextStyle(
                              color: Color(0xFFA1A1A6),
                              fontSize: 15,
                            ),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 11,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _SendButton(
                      onTap: isDisabled ? null : _sendMessage,
                      isLoading: isDisabled,
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

  /// 快捷操作行：历史记录 / 连接人工（渐变主推） / 发任务
  Widget _buildQuickActionsRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
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
              featured: true,
              onTap: () => context
                  .read<UnifiedChatBloc>()
                  .add(const UnifiedChatRequestHumanCS()),
            ),
            const SizedBox(width: 8),
            _UnifiedQuickActionChip(
              label: context.l10n.aiChatPostTask,
              icon: Icons.add_circle_outline,
              onTap: () {
                if (!requireAuth(context)) return;
                context.read<UnifiedChatBloc>().add(
                      UnifiedChatSendMessage(context.l10n.aiChatPostTask),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 输入栏右侧渐变发送按钮
class _SendButton extends StatelessWidget {
  const _SendButton({required this.onTap, required this.isLoading});

  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Semantics(
      button: true,
      label: 'Send',
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: disabled
                ? null
                : const LinearGradient(
                    colors: AppColors.gradientPrimary,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            color: disabled ? const Color(0xFFD1D1D6) : null,
            boxShadow: disabled
                ? null
                : [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
                    ),
                  )
                : const Icon(
                    Icons.arrow_upward_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
          ),
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

/// 输入框上快捷操作 Chip（外观分两档：普通 outline / 主推 gradient featured）
class _UnifiedQuickActionChip extends StatelessWidget {
  const _UnifiedQuickActionChip({
    required this.label,
    required this.onTap,
    this.icon,
    this.featured = false,
  });

  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool featured;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: featured
                ? const LinearGradient(
                    colors: AppColors.taskTypeBadgeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: featured
                ? null
                : (isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight),
            border: featured
                ? null
                : Border.all(
                    color: isDark
                        ? Colors.white12
                        : const Color(0xFFE5E5EA),
                    width: 0.5,
                  ),
            borderRadius: AppRadius.allPill,
            boxShadow: featured
                ? [
                    BoxShadow(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: featured
                      ? Colors.white
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: featured
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 欢迎页建议条目数据
class _Suggestion {
  const _Suggestion({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback onTap;
}

/// 欢迎页建议卡片：左侧渐变小图标块 + 右侧文字
class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.s, required this.isDark});

  final _Suggestion s;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: s.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? Colors.white12 : const Color(0xFFE5E5EA),
              width: 0.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: s.gradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(s.icon, size: 16, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.3,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 脉冲呼吸圆点 — AppBar 副标题左侧的"在线"指示器。
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        // 0..0.7 期间环逐渐变大变淡，之后停顿
        final t = _ctrl.value;
        final ringScale = t < 0.7 ? 1.0 + (t / 0.7) * 1.6 : 2.6;
        final ringOpacity = t < 0.7 ? (1 - t / 0.7) * 0.55 : 0.0;
        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: ringScale,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.success.withValues(alpha: ringOpacity),
                  ),
                ),
              ),
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
