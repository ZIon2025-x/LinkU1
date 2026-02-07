import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/loading_view.dart';

/// 客服消息模型
class CustomerServiceMessage {
  final String id;
  final String content;
  final String? senderType; // 'user', 'agent', 'system'
  final String? messageType;
  final String? createdAt;

  const CustomerServiceMessage({
    required this.id,
    required this.content,
    this.senderType,
    this.messageType,
    this.createdAt,
  });
}

/// 客服聊天模型
class CustomerServiceChat {
  final String chatId;
  final int isEnded;
  final int? totalMessages;
  final String? createdAt;

  const CustomerServiceChat({
    required this.chatId,
    this.isEnded = 0,
    this.totalMessages,
    this.createdAt,
  });
}

/// 客服视图
/// 参考iOS CustomerServiceView.swift
class CustomerServiceView extends StatefulWidget {
  const CustomerServiceView({
    super.key,
    this.isModal = false,
  });

  final bool isModal;

  @override
  State<CustomerServiceView> createState() => _CustomerServiceViewState();
}

class _CustomerServiceViewState extends State<CustomerServiceView> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  List<CustomerServiceMessage> _messages = [];
  CustomerServiceChat? _chat;
  bool _isSending = false;
  bool _isConnecting = false;
  String? _errorMessage;

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
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  void _showChatHistory() {
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
                '聊天历史',
                style: AppTypography.title3.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (_messages.isEmpty)
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
                        '暂无聊天记录',
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
                    shrinkWrap: true,
                    itemCount: _messages.length,
                    itemBuilder: (_, index) {
                      final msg = _messages[index];
                      final isUser = msg.senderType == 'user';
                      return ListTile(
                        dense: true,
                        leading: Icon(
                          isUser ? Icons.person : Icons.support_agent,
                          color: isUser ? AppColors.primary : AppColors.accent,
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

  void _connectToService() {
    setState(() {
      _isConnecting = true;
      _errorMessage = null;
    });

    // 模拟连接 - 实际应用中替换为API调用
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _chat = const CustomerServiceChat(
            chatId: 'demo-chat',
            isEnded: 0,
          );
          _messages = [
            const CustomerServiceMessage(
              id: 'welcome',
              content: '您好！我是客服小助手，请问有什么可以帮您？',
              senderType: 'agent',
              createdAt: '',
            ),
          ];
        });
        _scrollToBottom();
      }
    });
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending || _chat == null) return;
    if (_chat!.isEnded == 1) return;

    setState(() {
      _isSending = true;
      _messages.add(CustomerServiceMessage(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        content: text,
        senderType: 'user',
        createdAt: DateTime.now().toIso8601String(),
      ));
    });
    _messageController.clear();
    _focusNode.unfocus();
    _scrollToBottom();

    // 模拟回复
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _isSending = false;
          _messages.add(CustomerServiceMessage(
            id: 'reply_${DateTime.now().millisecondsSinceEpoch}',
            content: '感谢您的反馈，我们会尽快处理。',
            senderType: 'agent',
            createdAt: DateTime.now().toIso8601String(),
          ));
        });
        _scrollToBottom();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
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
                '完成',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          if (_chat != null)
            IconButton(
              icon: const Icon(Icons.history),
              onPressed: _showChatHistory,
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // 消息列表
              Expanded(
                child: _buildMessageList(isDark),
              ),

              // 输入区域
              _buildInputArea(isDark),
            ],
          ),

          // 连接中覆盖层
          if (_isConnecting)
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
                        '正在连接客服...',
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
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    if (_messages.isEmpty && _chat == null) {
      return _buildWelcomeState(isDark);
    }

    return GestureDetector(
      onTap: () => _focusNode.unfocus(),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        itemCount: _messages.length,
        itemBuilder: (context, index) {
          final message = _messages[index];
          final isFromUser = message.senderType == 'user';
          final isSystem =
              message.senderType == 'system' || message.messageType == 'system';

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
              '欢迎使用客服',
              style: AppTypography.title3.copyWith(
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            AppSpacing.vSm,
            Text(
              '发送消息开始与客服对话',
              style: AppTypography.subheadline.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
            AppSpacing.vXl,
            if (_errorMessage != null)
              Padding(
                padding: AppSpacing.allMd,
                child: Text(
                  _errorMessage!,
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSystemMessage(CustomerServiceMessage message, bool isDark) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
              Text(
                message.content,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
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
      padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        mainAxisAlignment:
            isFromUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isFromUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              child: const Icon(
                Icons.support_agent,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.hSm,
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
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
    final chatEnded = _chat?.isEnded == 1;

    if (chatEnded) {
      return Container(
        padding: EdgeInsets.symmetric(
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
                '对话已结束',
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _chat = null;
                  _messages.clear();
                });
              },
              child: Text(
                '新对话',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
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
            if (_chat == null)
              IconButton(
                onPressed: _isConnecting ? null : _connectToService,
                icon: _isConnecting
                    ? const LoadingIndicator(size: 20)
                    : const Icon(Icons.phone, color: AppColors.primary),
              ),

            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _focusNode,
                enabled: !_isSending && _chat != null,
                decoration: InputDecoration(
                  hintText: '输入消息...',
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
              onPressed: _messageController.text.isEmpty ||
                      _isSending ||
                      _chat == null
                  ? null
                  : _sendMessage,
              icon: _isSending
                  ? const LoadingIndicator(size: 20)
                  : Icon(
                      Icons.arrow_upward,
                      color: _messageController.text.isEmpty || _chat == null
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
