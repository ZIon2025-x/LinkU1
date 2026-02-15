import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../data/models/customer_service.dart';
import '../../../data/repositories/common_repository.dart';
import '../bloc/customer_service_bloc.dart';

/// 客服视图
/// 参考iOS CustomerServiceView.swift
class CustomerServiceView extends StatelessWidget {
  const CustomerServiceView({
    super.key,
    this.isModal = false,
  });

  final bool isModal;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CustomerServiceBloc(
        commonRepository: context.read<CommonRepository>(),
      ),
      child: _CustomerServiceContent(isModal: isModal),
    );
  }
}

class _CustomerServiceContent extends StatefulWidget {
  const _CustomerServiceContent({required this.isModal});

  final bool isModal;

  @override
  State<_CustomerServiceContent> createState() =>
      _CustomerServiceContentState();
}

class _CustomerServiceContentState extends State<_CustomerServiceContent> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

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

    context.read<CustomerServiceBloc>().add(CustomerServiceSendMessage(text));
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
                context.read<CustomerServiceBloc>().add(
                      CustomerServiceRateChat(
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

  void _showChatHistory() {
    final messages =
        context.read<CustomerServiceBloc>().state.messages;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.dividerLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                context.l10n.customerServiceChatHistory,
                style: AppTypography.title3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (messages.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(Icons.chat_bubble_outline,
                          size: 48,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight),
                      const SizedBox(height: 12),
                      Text(
                        context.l10n.customerServiceNoChatHistory,
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    itemCount: messages.length,
                    itemBuilder: (_, index) {
                      final msg = messages[index];
                      final isUser = msg.senderType == 'user';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isUser ? Icons.person : Icons.support_agent,
                          color:
                              isUser ? AppColors.primary : AppColors.accent,
                          size: 20,
                        ),
                        title: Text(
                          msg.content,
                          style: const TextStyle(fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: msg.createdAt != null &&
                                msg.createdAt!.isNotEmpty
                            ? Text(
                                msg.createdAt!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? AppColors.textTertiaryDark
                                      : AppColors.textTertiaryLight,
                                ),
                              )
                            : null,
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocListener<CustomerServiceBloc, CustomerServiceState>(
      listenWhen: (prev, curr) =>
          curr.actionMessage != null ||
          prev.messages.length != curr.messages.length,
      listener: (context, state) {
        if (state.actionMessage != null) {
          final message = switch (state.actionMessage) {
            'conversation_ended' => context.l10n.actionConversationEnded,
            'end_conversation_failed' => context.l10n.actionEndConversationFailed,
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
        appBar: AppBar(
          title: Text(context.l10n.customerServiceCustomerService),
          centerTitle: true,
          leading: widget.isModal
              ? null
              : IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => Navigator.of(context).pop(),
                ),
          actions: [
            if (widget.isModal)
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  context.l10n.commonDone,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ),
            BlocBuilder<CustomerServiceBloc, CustomerServiceState>(
              // 仅在连接/结束状态变化时重建 AppBar actions
              buildWhen: (prev, curr) =>
                  prev.isConnected != curr.isConnected ||
                  prev.isEnded != curr.isEnded,
              builder: (context, state) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (state.isConnected || state.isEnded)
                      IconButton(
                        icon: const Icon(Icons.history),
                        onPressed: _showChatHistory,
                      ),
                    if (state.isEnded)
                      IconButton(
                        icon: const Icon(Icons.star_outline),
                        onPressed: _showRatingDialog,
                      ),
                    if (state.isConnected)
                      IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: context.l10n.customerServiceEndConversation,
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(context.l10n.customerServiceEndConversation),
                              content: Text(context.l10n.customerServiceEndMessage),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: Text(context.l10n.commonCancel),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    context
                                        .read<CustomerServiceBloc>()
                                        .add(const CustomerServiceEndChat());
                                  },
                                  child: Text(context.l10n.customerServiceEndConversation,
                                      style:
                                          const TextStyle(color: AppColors.error)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<CustomerServiceBloc, CustomerServiceState>(
          buildWhen: (prev, curr) =>
              prev.status != curr.status ||
              prev.messages != curr.messages ||
              prev.queueStatus != curr.queueStatus ||
              prev.isConnecting != curr.isConnecting ||
              prev.isSending != curr.isSending,
          builder: (context, state) {
            return Stack(
              children: [
                Column(
                  children: [
                    // 排队信息
                    if (state.queueStatus != null &&
                        state.queueStatus!.status == 'waiting')
                      _buildQueueBanner(state.queueStatus!, isDark),

                    // 消息列表
                    Expanded(
                      child: _buildMessageList(state, isDark),
                    ),

                    // 输入区域
                    _buildInputArea(state, isDark),
                  ],
                ),

                // 连接中覆盖层
                if (state.isConnecting)
                  Container(
                    color: Colors.black.withValues(alpha: 0.3),
                    child: Center(
                      child: Container(
                        padding: AppSpacing.allLg,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.cardBackgroundDark
                              : AppColors.cardBackgroundLight,
                          borderRadius: AppRadius.allLarge,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const LoadingIndicator(),
                            AppSpacing.vMd,
                            Text(
                              context.l10n.customerServiceConnecting,
                              style: AppTypography.subheadline.copyWith(
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildQueueBanner(
      CustomerServiceQueueStatus queueStatus, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: AppColors.warning.withValues(alpha: 0.1),
      child: Row(
        children: [
          const Icon(Icons.access_time, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              queueStatus.position != null
                  ? context.l10n.customerServiceQueuePosition(queueStatus.position!)
                  : context.l10n.customerServiceConnecting,
              style: const TextStyle(fontSize: 13, color: AppColors.warning),
            ),
          ),
          TextButton(
            onPressed: () => context
                .read<CustomerServiceBloc>()
                .add(const CustomerServiceCheckQueue()),
            child: Text(context.l10n.successRefreshSuccess),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(CustomerServiceState state, bool isDark) {
    if (state.messages.isEmpty &&
        state.status == CustomerServiceStatus.initial) {
      return _buildWelcomeState(isDark);
    }

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollController,
        addAutomaticKeepAlives: false,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: state.messages.length,
        itemBuilder: (context, index) {
          final message = state.messages[index];
          final isFromUser = message.senderType == 'user';
          final isSystem = message.messageType == 'system';

          if (isSystem) {
            return _buildSystemMessage(message, isDark);
          }
          return _buildMessageBubble(message, isFromUser, isDark);
        },
      ),
    );
  }

  Widget _buildWelcomeState(bool isDark) {
    return Center(
      child: Padding(
        padding: AppSpacing.allXl,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.support_agent,
              size: 64,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
            AppSpacing.vLg,
            Text(
              context.l10n.customerServiceWelcome,
              style: AppTypography.title3.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            AppSpacing.vSm,
            Text(
              context.l10n.customerServiceStartConversation,
              style: AppTypography.subheadline.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vXl,
            BlocBuilder<CustomerServiceBloc, CustomerServiceState>(
              builder: (context, state) {
                if (state.errorMessage != null) {
                  return Padding(
                    padding: AppSpacing.allMd,
                    child: Text(
                      ErrorLocalizer.localize(context, state.errorMessage),
                      style: AppTypography.subheadline.copyWith(
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(CustomerServiceMessage message, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (isDark ? AppColors.dividerDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_outline,
                size: 12,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  message.content,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
      CustomerServiceMessage message, bool isFromUser, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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

  Widget _buildInputArea(CustomerServiceState state, bool isDark) {
    if (state.isEnded) {
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
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Icon(
                Icons.check_circle,
                size: 16,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              AppSpacing.hSm,
              Expanded(
                child: Text(
                  context.l10n.customerServiceConversationEnded,
                  style: AppTypography.body.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _showRatingDialog(),
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
                    .read<CustomerServiceBloc>()
                    .add(const CustomerServiceStartNew()),
                child: Text(
                  context.l10n.customerServiceNewConversation,
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
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // 连接按钮（仅在未连接时显示）
            if (!state.isConnected)
              IconButton(
                onPressed: state.isConnecting
                    ? null
                    : () => context
                        .read<CustomerServiceBloc>()
                        .add(const CustomerServiceConnectRequested()),
                icon: state.isConnecting
                    ? const LoadingIndicator(size: 20)
                    : const Icon(Icons.phone, color: AppColors.primary),
              ),

            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                enabled: !state.isSending && state.isConnected,
                decoration: InputDecoration(
                  hintText: state.isConnected ? context.l10n.customerServiceEnterMessage : context.l10n.customerServiceConnecting,
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
              onPressed: !state.isConnected || state.isSending
                  ? null
                  : _sendMessage,
              icon: state.isSending
                  ? const LoadingIndicator(size: 20)
                  : Icon(
                      Icons.arrow_upward,
                      color: !state.isConnected
                          ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          : AppColors.primary,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
