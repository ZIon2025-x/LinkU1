import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/message.dart';
import '../../../data/models/task_application.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/services/api_service.dart';
import '../../../data/services/storage_service.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../bloc/task_detail_bloc.dart';

/// Application-scoped chat view for chat-before-payment flow.
/// Accessed via /tasks/:taskId/applications/:applicationId/chat
class ApplicationChatView extends StatelessWidget {
  const ApplicationChatView({
    super.key,
    required this.taskId,
    required this.applicationId,
  });

  final int taskId;
  final int applicationId;

  @override
  Widget build(BuildContext context) {
    final taskRepository = context.read<TaskRepository>();
    final notificationRepository = context.read<NotificationRepository>();

    return BlocProvider(
      create: (_) => TaskDetailBloc(
        taskRepository: taskRepository,
        notificationRepository: notificationRepository,
      )
        ..add(TaskDetailLoadRequested(taskId))
        ..add(TaskDetailLoadApplications(
          currentUserId: StorageService.instance.getUserId(),
        )),
      child: _ApplicationChatContent(
        taskId: taskId,
        applicationId: applicationId,
      ),
    );
  }
}

class _ApplicationChatContent extends StatefulWidget {
  const _ApplicationChatContent({
    required this.taskId,
    required this.applicationId,
  });

  final int taskId;
  final int applicationId;

  @override
  State<_ApplicationChatContent> createState() =>
      _ApplicationChatContentState();
}

class _ApplicationChatContentState extends State<_ApplicationChatContent> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  String? _currentUserId;
  List<Message> _messages = [];
  bool _isLoadingMessages = true;
  String? _messagesError;
  bool _isSendingMessage = false;

  @override
  void initState() {
    super.initState();
    _currentUserId = StorageService.instance.getUserId();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    setState(() {
      _isLoadingMessages = true;
      _messagesError = null;
    });

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.get<Map<String, dynamic>>(
        ApiEndpoints.taskChatMessages(widget.taskId),
        queryParameters: {
          'application_id': widget.applicationId,
          'limit': 50,
        },
      );

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final messages =
            MessageRepository.parseTaskChatMessagesResponse(response.data!);
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _isLoadingMessages = false;
          _messagesError = response.message ?? 'Failed to load messages';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMessages = false;
        _messagesError = e.toString();
      });
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSendingMessage) return;

    _messageController.clear();
    setState(() => _isSendingMessage = true);

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.post<Map<String, dynamic>>(
        ApiEndpoints.taskChatSend(widget.taskId),
        data: {
          'content': content,
          'message_type': 'text',
          'application_id': widget.applicationId,
        },
      );

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final message = Message.fromJson(response.data!);
        setState(() {
          _messages = [..._messages, message];
          _isSendingMessage = false;
        });
        _scrollToBottom();
      } else {
        setState(() => _isSendingMessage = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(response.message ?? 'Failed to send message')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingMessage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  void _showProposePriceDialog() {
    final priceController = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.proposeNewPrice),
        content: TextField(
          controller: priceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: context.l10n.enterPrice,
            prefixText: '\u00a3',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              final price = double.tryParse(priceController.text.trim());
              if (price != null && price > 0) {
                Navigator.pop(dialogContext);
                context.read<TaskDetailBloc>().add(
                      TaskDetailProposePrice(widget.applicationId, price),
                    );
              }
            },
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      ),
    ).then((_) => priceController.dispose());
  }

  TaskApplication? _findApplication(TaskDetailState state) {
    try {
      return state.applications
          .firstWhere((a) => a.id == widget.applicationId);
    } catch (_) {
      return null;
    }
  }

  bool _isPoster(TaskDetailState state) {
    if (_currentUserId == null || state.task == null) return false;
    return _currentUserId == state.task!.posterId;
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TaskDetailBloc, TaskDetailState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage ||
          prev.errorMessage != curr.errorMessage ||
          prev.acceptPaymentData != curr.acceptPaymentData,
      listener: (context, state) {
        // Handle price proposed — reload messages
        if (state.actionMessage == 'price_proposed') {
          _loadMessages();
        }
        // Handle payment data
        if (state.acceptPaymentData != null) {
          // Payment flow triggered — navigate to payment page
          // The parent router handles this via acceptPaymentData
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment initiated')),
          );
        }
        // Handle errors
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage))),
          );
        }
      },
      builder: (context, state) {
        final application = _findApplication(state);
        final isPoster = _isPoster(state);
        final isChatActive = application?.isChatting ?? false;
        final isLoaded = state.status == TaskDetailStatus.loaded;

        return Scaffold(
          backgroundColor:
              AppColors.backgroundFor(Theme.of(context).brightness),
          appBar: AppBar(
            title: Text(
              application?.applicantName ?? context.l10n.taskChat,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Column(
            children: [
              // Price bar
              if (isLoaded) _buildPriceBar(state, application),

              // Closed channel banner
              if (isLoaded && !isChatActive) _buildClosedBanner(),

              // Message list
              Expanded(child: _buildMessageList()),

              // Input bar (only when chat is active)
              if (isChatActive) _buildInputBar(),

              // Confirm & Pay button (poster only, chat active)
              if (isChatActive && isPoster)
                _buildConfirmAndPayButton(state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceBar(TaskDetailState state, TaskApplication? application) {
    final price = application?.proposedPrice ?? state.task?.reward;
    final priceDisplay = price != null ? price.toStringAsFixed(2) : '--';
    final isChatActive = application?.isChatting ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: const Border(
          bottom: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_outlined,
              size: 20, color: AppColors.primary),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              context.l10n.currentPrice(priceDisplay),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (isChatActive)
            TextButton.icon(
              onPressed: _showProposePriceDialog,
              icon: const Icon(Icons.edit, size: 16),
              label: Text(context.l10n.modifyQuote),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                textStyle: const TextStyle(fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner() {
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
            context.l10n.chatChannelClosed,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_isLoadingMessages) {
      return const LoadingView();
    }

    if (_messagesError != null && _messages.isEmpty) {
      return ErrorStateView.loadFailed(
        message: context.localizeError(_messagesError ?? ''),
        onRetry: _loadMessages,
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.chat_bubble_outline,
                size: 48, color: AppColors.textTertiaryLight),
            AppSpacing.vMd,
            Text(
              context.l10n.typeMessage,
              style: const TextStyle(color: AppColors.textSecondaryLight),
            ),
          ],
        ),
      );
    }

    // Messages are chronological (oldest first); no reverse needed
    final currentUserId = _currentUserId ?? '';

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isMe = message.senderId == currentUserId;

        // Special rendering for price_proposal messages
        if (message.messageType == 'price_proposal') {
          return _buildPriceProposalBubble(message, isMe);
        }

        // System messages
        if (message.isSystem) {
          return _buildSystemMessage(message);
        }

        // Normal message bubble using existing grouping
        return _buildMessageBubble(message, isMe);
      },
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isMe
        ? AppColors.primary
        : (isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight);
    final textColor = isMe
        ? Colors.white
        : (isDark ? Colors.white : AppColors.textPrimaryLight);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.15),
              child: Text(
                (message.senderName ?? '?').characters.first,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.medium),
                  topRight: const Radius.circular(AppRadius.medium),
                  bottomLeft: isMe
                      ? const Radius.circular(AppRadius.medium)
                      : const Radius.circular(AppRadius.tiny),
                  bottomRight: isMe
                      ? const Radius.circular(AppRadius.tiny)
                      : const Radius.circular(AppRadius.medium),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Text(
                message.content,
                style: TextStyle(fontSize: 15, color: textColor),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildPriceProposalBubble(Message message, bool isMe) {
    // Parse price from message content or metadata
    final priceText = message.content;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF0F4FF), Color(0xFFE8EEFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.local_offer,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    context.l10n.proposeNewPrice,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                priceText,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(Message message) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.textTertiaryLight.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textTertiaryLight,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                enabled: !_isSendingMessage,
                maxLines: 4,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: context.l10n.typeMessage,
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
              ),
            ),
            AppSpacing.hSm,
            if (_isSendingMessage)
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              ValueListenableBuilder<TextEditingValue>(
                valueListenable: _messageController,
                builder: (context, value, child) {
                  return IconButton(
                    icon: const Icon(Icons.send),
                    onPressed:
                        value.text.trim().isEmpty ? null : _sendMessage,
                    color: AppColors.primary,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfirmAndPayButton(TaskDetailState state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: const Border(
          top: BorderSide(color: AppColors.dividerLight),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: state.isSubmitting
                ? null
                : () {
                    context.read<TaskDetailBloc>().add(
                          TaskDetailConfirmAndPay(widget.applicationId),
                        );
                  },
            icon: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.payment),
            label: Text(context.l10n.confirmAndPay),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.medium),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
