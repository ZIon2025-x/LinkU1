import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/adaptive_dialogs.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../data/models/message.dart';
import '../../../data/models/task_application.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/repositories/notification_repository.dart';
import '../../../data/repositories/question_repository.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/api_service.dart';
import '../../../core/constants/api_endpoints.dart';
import '../../../core/router/page_transitions.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/utils/helpers.dart';
import '../../task_expert/bloc/task_expert_bloc.dart';
import '../bloc/task_detail_bloc.dart';
import 'approval_payment_page.dart';
import 'consultation/consultation_base.dart';

export 'consultation/consultation_base.dart' show ConsultationType;

/// Application-scoped chat view for chat-before-payment flow.
/// Accessed via /tasks/:taskId/applications/:applicationId/chat
class ApplicationChatView extends StatelessWidget {
  const ApplicationChatView({
    super.key,
    required this.taskId,
    required this.applicationId,
    this.isConsultation = false,
    this.consultationType = ConsultationType.service,
    this.readOnly = false,
  });

  final int taskId;
  final int applicationId;
  final bool isConsultation;
  final ConsultationType consultationType;
  /// 只读模式：成交后从主任务聊天跳转回来查看议价历史时为 true
  /// 隐藏输入框、报价修改、确认支付、拒绝、咨询操作按钮
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final taskRepository = context.read<TaskRepository>();
    final notificationRepository = context.read<NotificationRepository>();

    Widget child = BlocProvider(
      create: (_) => TaskDetailBloc(
        taskRepository: taskRepository,
        notificationRepository: notificationRepository,
        questionRepository: context.read<QuestionRepository>(),
      )..add(TaskDetailLoadRequested(taskId)),
      child: _ApplicationChatContent(
        taskId: taskId,
        applicationId: applicationId,
        isConsultation: isConsultation,
        consultationType: consultationType,
        readOnly: readOnly,
      ),
    );

    // In consultation mode, also provide TaskExpertBloc
    if (isConsultation) {
      child = BlocProvider(
        create: (_) => TaskExpertBloc(
          taskExpertRepository: context.read<TaskExpertRepository>(),
          activityRepository: context.read<ActivityRepository>(),
          questionRepository: context.read<QuestionRepository>(),
        ),
        child: child,
      );
    }

    return child;
  }
}

class _ApplicationChatContent extends StatefulWidget {
  const _ApplicationChatContent({
    required this.taskId,
    required this.applicationId,
    this.isConsultation = false,
    this.consultationType = ConsultationType.service,
    this.readOnly = false,
  });

  final int taskId;
  final int applicationId;
  final bool isConsultation;
  final ConsultationType consultationType;
  final bool readOnly;

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

  // Consultation mode state
  Map<String, dynamic>? _consultationApp;
  bool _isLoadingConsultation = false;
  ConsultationActions? _consultationActions;

  @override
  void initState() {
    super.initState();
    _currentUserId = StorageService.instance.getUserId();
    if (widget.isConsultation) {
      _consultationActions = ConsultationActions.of(
        type: widget.consultationType,
        applicationId: widget.applicationId,
        taskId: widget.taskId,
      );
    }
    _loadMessages();
    if (widget.isConsultation) {
      _loadConsultationStatus();
    }
  }

  String _getCurrencySymbol() {
    final currency = _consultationApp?['currency'] as String? ?? 'GBP';
    return Helpers.currencySymbolFor(currency);
  }

  /// 咨询模式下的 AppBar 标题：将后端"咨询: xxx"替换为"类型咨询: xxx"
  String _consultationTitle(TaskDetailState state) {
    final task = state.task;
    if (task == null) return context.l10n.taskChat;
    final locale = Localizations.localeOf(context);
    final title = task.displayTitle(locale);
    final typeLabel = _consultationTypeLabel();

    // 后端标题格式为 "咨询: xxx" 或 "团队咨询: xxx"，剥离前缀后加上本地化类型标签
    for (final prefix in [
      '团队咨询: ', '团队咨询：', '团队咨询:',
      'Team Consultation: ', 'Team Consultation:',
      '咨询: ', '咨询：', '咨询:',
      'Consultation: ', 'Consultation:',
    ]) {
      if (title.startsWith(prefix)) {
        return '$typeLabel${context.l10n.consultExpert}: ${title.substring(prefix.length).trim()}';
      }
    }
    return '$typeLabel${context.l10n.consultExpert}: $title';
  }

  /// 根据 consultationType 返回本地化类型名称
  String _consultationTypeLabel() {
    switch (widget.consultationType) {
      case ConsultationType.fleaMarket:
        return context.l10n.taskSourceFleaMarket;
      case ConsultationType.service:
        final hasExpert = _consultationApp?['expert_id'] != null
            || _consultationApp?['new_expert_id'] != null;
        return hasExpert
            ? context.l10n.taskSourceExpertService
            : context.l10n.discoveryFeedTypePersonalSkill;
      case ConsultationType.task:
        return context.l10n.taskSourceNormal;
    }
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
          if (_consultationActions?.needsApplicationIdInMessages ?? true)
            'application_id': widget.applicationId,
          'limit': 50,
        },
      );

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final messages =
            MessageRepository.parseTaskChatMessagesResponse(response.data!)
                .reversed.toList();
        setState(() {
          _messages = messages;
          _isLoadingMessages = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _isLoadingMessages = false;
          _messagesError = 'chat_load_more_failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingMessages = false;
        _messagesError = 'chat_load_more_failed';
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

    setState(() => _isSendingMessage = true);

    try {
      final apiService = context.read<ApiService>();
      final response = await apiService.post<Map<String, dynamic>>(
        ApiEndpoints.taskChatSend(widget.taskId),
        data: {
          'content': content,
          'message_type': 'text',
          if (_consultationActions?.needsApplicationIdInMessages ?? true)
            'application_id': widget.applicationId,
        },
      );

      if (!mounted) return;

      if (response.isSuccess && response.data != null) {
        final message = Message.fromJson(response.data!);
        _messageController.clear();
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
                content: Text(context.localizeError('task_send_message_failed'))),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingMessage = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.localizeError('task_send_message_failed'))),
      );
    }
  }

  /// Poster rejects the application from inside the chat view.
  /// Shows a confirm dialog, dispatches reject, then pops back to task detail.
  Future<void> _confirmRejectFromChat() async {
    final confirmed = await AdaptiveDialogs.showConfirmDialog<bool>(
      context: context,
      title: context.l10n.taskDetailRejectApplication,
      content: context.l10n.taskDetailRejectApplicationConfirm,
      confirmText: context.l10n.commonConfirm,
      cancelText: context.l10n.commonCancel,
      isDestructive: true,
      onConfirm: () => true,
      onCancel: () => false,
    );
    if (confirmed != true || !mounted) return;
    AppHaptics.medium();
    final navigator = Navigator.of(context);
    context
        .read<TaskDetailBloc>()
        .add(TaskDetailRejectApplicant(widget.applicationId));
    if (navigator.canPop()) navigator.pop();
  }

  void _showProposePriceDialog() {
    final priceController = TextEditingController();
    final bloc = context.read<TaskDetailBloc>();
    String? errorText;
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(context.l10n.proposeNewPrice),
          content: TextField(
            controller: priceController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              hintText: context.l10n.enterPrice,
              prefixText: '\u00a3',
              errorText: errorText,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child:
                  Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            TextButton(
              onPressed: () {
                final price =
                    double.tryParse(priceController.text.trim());
                if (price == null || price <= 0) {
                  setDialogState(() {
                    errorText = context.l10n.enterPrice;
                  });
                  return;
                }
                if (price > 50000) {
                  setDialogState(() {
                    errorText = context.l10n.priceExceedsMaximum(Helpers.currencySymbolFor(bloc.state.task?.currency ?? 'GBP'));
                  });
                  return;
                }
                Navigator.pop(dialogContext);
                bloc.add(
                  TaskDetailProposePrice(widget.applicationId, price),
                );
              },
              child: Text(MaterialLocalizations.of(context).okButtonLabel),
            ),
          ],
        ),
      ),
    ).whenComplete(() => priceController.dispose());
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

  // ── Consultation mode helpers ───────────────────────────────────────

  Future<void> _loadConsultationStatus() async {
    if (!widget.isConsultation) return;
    setState(() => _isLoadingConsultation = true);
    try {
      final apiService = context.read<ApiService>();
      final endpoint = _consultationActions!.statusEndpoint;
      final response = await apiService.get<Map<String, dynamic>>(
        endpoint,
      );
      if (!mounted) return;
      if (response.isSuccess && response.data != null) {
        setState(() {
          _consultationApp = response.data;
          _isLoadingConsultation = false;
        });
      } else {
        setState(() => _isLoadingConsultation = false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingConsultation = false);
    }
  }

  /// Get application status - works in both regular and consultation modes
  String? _getAppStatus(TaskDetailState state) {
    if (widget.isConsultation) {
      return _consultationApp?['status'] as String?;
    }
    return _findApplication(state)?.status;
  }

  bool _isApplicantInConsultation() {
    if (!widget.isConsultation || _consultationActions == null) return false;
    return _consultationActions!.isApplicant(_currentUserId, _consultationApp);
  }

  bool _isChatActiveForStatus(String? appStatus) {
    if (appStatus == null) return false;
    return ['chatting', 'consulting', 'negotiating', 'price_agreed', 'pending']
        .contains(appStatus);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isConsultation) {
      return BlocListener<TaskExpertBloc, TaskExpertState>(
        listenWhen: (prev, curr) =>
            prev.actionMessage != curr.actionMessage ||
            prev.errorMessage != curr.errorMessage,
        listener: (context, expertState) {
          // Handle errors
          if (expertState.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(expertState.errorMessage))),
            );
            return;
          }

          // Handle success actions
          final action = expertState.actionMessage;
          if (action == null) return;

          // Reload messages and status on any successful action
          if (action == 'negotiation_sent' ||
              action == 'quote_sent' ||
              action == 'formal_apply_submitted' ||
              action == 'consultation_closed' ||
              action == 'application_approved' ||
              action.startsWith('negotiate_response_')) {
            _loadMessages();
            _loadConsultationStatus();

            // Reload task detail to reflect status change
            context
                .read<TaskDetailBloc>()
                .add(TaskDetailLoadRequested(widget.taskId));
            context.read<TaskDetailBloc>().add(
                  TaskDetailLoadApplications(currentUserId: _currentUserId),
                );

            // Show success message
            String? msg;
            if (action == 'negotiation_sent') msg = context.l10n.negotiationSent;
            if (action == 'quote_sent') msg = context.l10n.quoteSent;
            if (action == 'formal_apply_submitted') msg = context.l10n.formalApplySubmitted;
            if (action == 'consultation_closed') msg = context.l10n.consultationClosed;
            if (action == 'application_approved') msg = context.l10n.expertApplicationApproved;
            if (action == 'negotiate_response_price_agreed') msg = context.l10n.priceAgreed;
            if (action == 'negotiate_response_consulting') msg = context.l10n.negotiationRejected;
            if (action == 'negotiate_response_negotiating') msg = context.l10n.negotiationSent;

            if (msg != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(msg)),
              );
            }
          }
        },
        child: _buildMainContent(),
      );
    }
    return _buildMainContent();
  }

  Widget _buildMainContent() {
    return BlocConsumer<TaskDetailBloc, TaskDetailState>(
      listenWhen: (prev, curr) =>
          prev.actionMessage != curr.actionMessage ||
          prev.errorMessage != curr.errorMessage ||
          prev.acceptPaymentData != curr.acceptPaymentData ||
          (prev.status != curr.status && curr.status == TaskDetailStatus.loaded),
      listener: (context, state) {
        // Dispatch LoadApplications after task is loaded (avoid race condition)
        if (state.status == TaskDetailStatus.loaded && state.task != null) {
          final bloc = context.read<TaskDetailBloc>();
          if (state.applications.isEmpty && !state.isLoadingApplications) {
            bloc.add(TaskDetailLoadApplications(
              currentUserId: _currentUserId,
            ));
          }
        }
        // Handle price proposed — reload messages
        if (state.actionMessage == 'price_proposed') {
          _loadMessages();
        }
        // Handle payment: open ApprovalPaymentPage (same pattern as task_detail_view)
        if (state.actionMessage == 'open_payment' &&
            state.acceptPaymentData != null) {
          final data = state.acceptPaymentData!;
          final taskId = widget.taskId;
          final bloc = context.read<TaskDetailBloc>();
          bloc.add(const TaskDetailClearAcceptPaymentData());
          pushWithSwipeBack<bool>(
            context,
            ApprovalPaymentPage(paymentData: data),
            fullscreenDialog: true,
          ).then((result) {
            if (!context.mounted) return;
            if (result == true) {
              context
                  .read<TaskDetailBloc>()
                  .add(TaskDetailLoadRequested(taskId));
              context.read<TaskDetailBloc>().add(TaskDetailLoadApplications(
                    currentUserId: _currentUserId,
                  ));
              _loadMessages();
            }
          });
          return;
        }
        // Handle errors
        if (state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.localizeError(state.errorMessage))),
          );
        }
      },
      builder: (context, state) {
        final application = widget.isConsultation ? null : _findApplication(state);
        final isPoster = _isPoster(state);
        final appStatus = _getAppStatus(state);
        final isChatActive = widget.isConsultation
            ? _isChatActiveForStatus(appStatus)
            : (application?.isChatting == true ||
                application?.isConsulting == true ||
                application?.isNegotiating == true ||
                application?.isPriceAgreed == true ||
                application?.isPending == true);
        final isLoaded = state.status == TaskDetailStatus.loaded;
        final isConsultingOrNeg =
            appStatus == 'consulting' || appStatus == 'negotiating';
        final showServiceCard = !_isLoadingConsultation &&
            (appStatus == 'consulting' ||
                appStatus == 'negotiating' ||
                appStatus == 'price_agreed' ||
                appStatus == 'pending');

        return Scaffold(
          backgroundColor:
              AppColors.backgroundFor(Theme.of(context).brightness),
          appBar: AppBar(
            title: Text(
              widget.isConsultation
                  ? _consultationTitle(state)
                  : (application?.applicantName ?? context.l10n.taskChat),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          body: Column(
            children: [
              // Read-only banner (成交后历史查看)
              if (widget.readOnly) _buildReadOnlyBanner(),

              // Service info card (consulting/negotiating/price_agreed mode)
              if (isLoaded && showServiceCard)
                _buildServiceInfoCard(state),

              // Price bar (non-consulting mode — keep existing behavior)
              if (isLoaded && !showServiceCard && !widget.isConsultation)
                _buildPriceBar(state, application),

              // Closed channel banner
              if (isLoaded && !isChatActive) _buildClosedBanner(),

              // Message list
              Expanded(child: _buildMessageList()),

              // Consulting action buttons
              if (!widget.readOnly &&
                  widget.isConsultation &&
                  isChatActive &&
                  (isConsultingOrNeg || appStatus == 'price_agreed' || appStatus == 'pending'))
                _consultationActions!.buildActions(
                  context: context,
                  appStatus: appStatus,
                  isSubmitting: context.watch<TaskExpertBloc>().state.isSubmitting,
                  isApplicant: _isApplicantInConsultation(),
                  getCurrencySymbol: _getCurrencySymbol,
                  consultationApp: _consultationApp,
                  onActionCompleted: () {
                    _loadMessages();
                    _loadConsultationStatus();
                  },
                ),

              // Confirm & Pay button (poster only, chatting mode — not consulting)
              if (!widget.readOnly &&
                  !widget.isConsultation &&
                  application?.isChatting == true &&
                  isPoster)
                _buildConfirmAndPayButton(state),

              // Input bar (when chat is active)
              if (!widget.readOnly && isChatActive) _buildInputBar(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPriceBar(TaskDetailState state, TaskApplication? application) {
    final price = application?.proposedPrice ?? state.task?.displayReward;
    final priceDisplay = price != null ? price.toStringAsFixed(2) : '--';
    final isChatActive = application?.isChatting ?? false;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.monetization_on_outlined,
              size: 20, color: AppColors.primary),
          AppSpacing.hSm,
          Expanded(
            child: Text(
              context.l10n.currentPrice(priceDisplay, Helpers.currencySymbolFor(state.task?.currency ?? 'GBP')),
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
          if (isChatActive && !widget.readOnly)
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

  Widget _buildReadOnlyBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: AppColors.info.withValues(alpha: isDark ? 0.14 : 0.10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.history, size: 16, color: AppColors.info),
          const SizedBox(width: 6),
          Text(
            context.l10n.taskChatHistoryReadOnlyBanner,
            style: const TextStyle(fontSize: 13, color: AppColors.info),
          ),
        ],
      ),
    );
  }

  Widget _buildClosedBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tertiaryColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: tertiaryColor.withValues(alpha: 0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 16, color: tertiaryColor),
          const SizedBox(width: 6),
          Text(
            context.l10n.chatChannelClosed,
            style: TextStyle(fontSize: 13, color: tertiaryColor),
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
      final isDark = Theme.of(context).brightness == Brightness.dark;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 48,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight),
            AppSpacing.vMd,
            Text(
              context.l10n.typeMessage,
              style: TextStyle(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
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

        // Negotiation status messages (accepted/rejected)
        if (message.isNegotiationAccepted || message.isNegotiationRejected) {
          return _buildNegotiationStatusMessage(message);
        }

        // Negotiation/quote/counter_offer cards
        if (message.isNegotiation || message.isQuote || message.isCounterOffer) {
          // Only show action buttons on the latest negotiation-type message
          final isLatestNegotiation = _isLatestNegotiationMessage(message);
          return _buildNegotiationCard(message, isMe, isLatestNegotiation: isLatestNegotiation);
        }

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
                (message.senderName?.isNotEmpty == true
                        ? message.senderName!
                        : '?')
                    .characters
                    .first,
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
    final priceText = message.content;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 260),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A2340), const Color(0xFF1E2A4A)]
                  : [const Color(0xFFF0F4FF), const Color(0xFFE8EEFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSystemMessage(Message message) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tertiaryColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: tertiaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.small),
          ),
          child: Text(
            message.content,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: tertiaryColor),
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
                  fillColor: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : AppColors.skeletonBase,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
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
            // 拒绝按钮（轮廓样式）
            OutlinedButton.icon(
              onPressed: state.isSubmitting ? null : _confirmRejectFromChat,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: Text(context.l10n.taskDetailReject),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                side: const BorderSide(color: AppColors.error),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.medium),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            // 同意并支付按钮（主按钮）
            Expanded(
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
          ],
        ),
      ),
    );
  }

  // ── Consulting Mode Widgets ──────────────────────────────────────────

  Widget _buildServiceInfoCard(TaskDetailState state) {

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final application = widget.isConsultation ? null : _findApplication(state);
    final consultationPrice = widget.isConsultation
        ? (_consultationApp?['final_price'] as num? ??
            _consultationApp?['negotiated_price'] as num?)
            ?.toDouble()
        : null;
    final price =
        consultationPrice ?? application?.proposedPrice ?? state.task?.displayReward;
    final priceDisplay = price != null ? price.toStringAsFixed(2) : '--';
    final currencySymbol =
        Helpers.currencySymbolFor(state.task?.currency ?? 'GBP');

    return GestureDetector(
      onTap: () => _navigateToDetailPage(),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          border: Border(
            bottom: BorderSide(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
          ),
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(AppRadius.small),
            bottomRight: Radius.circular(AppRadius.small),
          ),
        ),
        child: Row(
          children: [
            Icon(
              widget.consultationType == ConsultationType.fleaMarket
                  ? Icons.shopping_bag
                  : Icons.design_services,
              size: 20,
              color: AppColors.primary,
            ),
            AppSpacing.hSm,
            Expanded(
              child: Text(
                state.task != null
                    ? _consultationTitle(state)
                    : context.l10n.serviceInfoCard,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '$currencySymbol$priceDisplay',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.hSm,
            Icon(Icons.chevron_right, size: 18,
              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }

  /// 咨询 info card 点击：跳转到达人团队或服务详情页
  void _navigateToDetailPage() {
    final serviceId = _consultationApp?['service_id'];
    final expertId = _consultationApp?['new_expert_id'] as String?;

    if (serviceId != null) {
      // 服务咨询 → 跳转到服务详情
      context.push('/service/$serviceId');
    } else if (expertId != null) {
      // 团队咨询 → 跳转到达人团队详情
      context.push('/expert-teams/$expertId');
    }
  }

  /// Check if a message is the last negotiation-type message in the list
  bool _isLatestNegotiationMessage(Message message) {
    for (int i = _messages.length - 1; i >= 0; i--) {
      final m = _messages[i];
      if (m.isNegotiation || m.isQuote || m.isCounterOffer) {
        return m.id == message.id;
      }
    }
    return false;
  }

  Widget _buildNegotiationCard(Message message, bool isMe, {bool isLatestNegotiation = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final price = message.negotiationPrice;
    final currency = message.negotiationCurrency ?? 'GBP';
    final currencySymbol = Helpers.currencySymbolFor(currency);

    String title;
    IconData icon;
    if (message.isQuote) {
      title = context.l10n.quotePrice;
      icon = Icons.request_quote;
    } else if (message.isCounterOffer) {
      title = context.l10n.counterOffer;
      icon = Icons.swap_horiz;
    } else {
      title = context.l10n.negotiatePrice;
      icon = Icons.local_offer;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 280),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A2340), const Color(0xFF1E2A4A)]
                  : [const Color(0xFFF0F4FF), const Color(0xFFE8EEFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(AppRadius.medium),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: isDark ? 0.4 : 0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    title,
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
                price != null
                    ? '$currencySymbol${price.toStringAsFixed(2)}'
                    : message.content,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.textPrimaryLight,
                ),
              ),
              if (message.content.isNotEmpty &&
                  price != null &&
                  !message.content.startsWith(currencySymbol))
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
              // Action buttons for incoming negotiation (only on latest, consultation mode, and active negotiation status)
              if (!isMe && isLatestNegotiation && _consultationActions != null &&
                  (_consultationApp?['status'] == 'consulting' || _consultationApp?['status'] == 'negotiating')) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    NegotiationActionButton(
                      label: context.l10n.acceptPrice,
                      color: AppColors.success,
                      onPressed: () => _consultationActions!.handleNegotiationResponse(context, 'accept'),
                    ),
                    const SizedBox(width: 8),
                    NegotiationActionButton(
                      label: context.l10n.rejectPrice,
                      color: AppColors.error,
                      onPressed: () => _consultationActions!.handleNegotiationResponse(context, 'reject'),
                    ),
                    const SizedBox(width: 8),
                    NegotiationActionButton(
                      label: context.l10n.counterOffer,
                      color: AppColors.info,
                      onPressed: () => _consultationActions!.showCounterOfferDialog(
                        context,
                        getCurrencySymbol: _getCurrencySymbol,
                        expertId: (_consultationApp != null && _consultationApp!['service_id'] == null)
                            ? _consultationApp!['new_expert_id'] as String?
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNegotiationStatusMessage(Message message) {
    final isAccepted = message.isNegotiationAccepted;
    final color = isAccepted ? AppColors.success : AppColors.error;
    final icon = isAccepted ? Icons.check_circle : Icons.cancel;
    final text = isAccepted
        ? context.l10n.negotiationAccepted
        : context.l10n.negotiationRejected;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 32),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppRadius.small),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

}

