import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/message.dart';
import '../../../data/repositories/common_repository.dart';

/// 消息气泡方向
enum BubbleDirection { incoming, outgoing }

/// 气泡在分组中的位置
enum BubblePiecePosition { single, top, middle, bottom }

/// 消息分组
/// 参考iOS MessageGroupBubble.swift
class MessageGroup {
  const MessageGroup({
    required this.messages,
    required this.direction,
    this.senderId,
    this.senderName,
    this.senderAvatar,
    this.isSystem = false,
  });

  final List<Message> messages;
  final BubbleDirection direction;
  final String? senderId;
  final String? senderName;
  final String? senderAvatar;
  final bool isSystem;
}

/// 将消息按发送者和时间间隔分组
/// 参考iOS groupMessages() + system message handling
List<MessageGroup> groupMessages(
    List<Message> messages, String? currentUserId) {
  if (messages.isEmpty) return [];

  final groups = <MessageGroup>[];
  var currentGroup = <Message>[];
  String? currentSenderId;
  BubbleDirection? currentDirection;
  DateTime? lastMessageTime;
  String? currentSenderName;
  String? currentSenderAvatar;
  const timeThreshold = Duration(minutes: 3);

  void flushGroup() {
    if (currentGroup.isNotEmpty && currentDirection != null) {
      groups.add(MessageGroup(
        messages: List.from(currentGroup),
        direction: currentDirection,
        senderId: currentSenderId,
        senderName: currentSenderName,
        senderAvatar: currentSenderAvatar,
      ));
      currentGroup = [];
    }
  }

  // 规范化当前用户 ID（与后端 sender_id 一致为字符串，避免 iOS 等平台类型差异导致对方消息被误判为自己）
  final normalizedCurrentUserId = currentUserId?.trim();
  final currentUserIdNotEmpty = normalizedCurrentUserId != null && normalizedCurrentUserId.isNotEmpty;

  for (final message in messages) {
    // 系统消息：作为独立组渲染（对齐iOS TaskChatSystemMessageBubble）
    if (message.isSystem) {
      flushGroup();
      groups.add(MessageGroup(
        messages: [message],
        direction: BubbleDirection.incoming,
        isSystem: true,
      ));
      continue;
    }

    final senderIdTrimmed = message.senderId.trim();
    final isMe = currentUserIdNotEmpty && senderIdTrimmed == normalizedCurrentUserId;
    final direction =
        isMe ? BubbleDirection.outgoing : BubbleDirection.incoming;

    bool shouldStartNewGroup;
    if (currentGroup.isEmpty) {
      shouldStartNewGroup = true;
    } else if (senderIdTrimmed != (currentSenderId?.trim() ?? '')) {
      shouldStartNewGroup = true;
    } else if (direction != currentDirection) {
      shouldStartNewGroup = true;
    } else if (message.isImage) {
      // 图片消息独立成组（对齐iOS）
      shouldStartNewGroup = true;
    } else if (message.createdAt != null && lastMessageTime != null) {
      shouldStartNewGroup =
          message.createdAt!.difference(lastMessageTime).abs() >
              timeThreshold;
    } else {
      shouldStartNewGroup = false;
    }

    if (shouldStartNewGroup) {
      flushGroup();
      currentGroup = [message];
      currentSenderId = senderIdTrimmed.isEmpty ? message.senderId : senderIdTrimmed;
      currentDirection = direction;
      currentSenderName = message.senderName;
      currentSenderAvatar = message.senderAvatar;
      lastMessageTime = message.createdAt;
    } else {
      currentGroup.add(message);
      lastMessageTime = message.createdAt;
    }
  }

  flushGroup();
  return groups;
}

/// 分组气泡视图
/// 参考iOS MessageGroupBubbleView
class MessageGroupBubbleView extends StatelessWidget {
  const MessageGroupBubbleView({
    super.key,
    required this.group,
    this.onAvatarTap,
    this.onImageTap,
  });

  final MessageGroup group;
  final VoidCallback? onAvatarTap;
  final void Function(String imageUrl)? onImageTap;

  @override
  Widget build(BuildContext context) {
    // 系统消息：居中渲染
    if (group.isSystem) {
      return _SystemMessageBubble(
        message: group.messages.first,
        onImageTap: onImageTap,
      );
    }

    final isOutgoing = group.direction == BubbleDirection.outgoing;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment:
            isOutgoing ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isOutgoing) ...[
            GestureDetector(
              onTap: onAvatarTap,
              child: AvatarView(
                imageUrl: group.senderAvatar,
                name: group.senderName,
                size: 36,
              ),
            ),
            AppSpacing.hSm,
          ],
          // 气泡列
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.72,
              ),
              child: Column(
                crossAxisAlignment: isOutgoing
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // 发送者名称
                  if (!isOutgoing &&
                      group.senderName != null &&
                      group.senderName!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Text(
                        group.senderName!,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ),

                  // 消息气泡
                  ...List.generate(group.messages.length, (index) {
                    final message = group.messages[index];
                    final position =
                        _piecePosition(index, group.messages.length);
                    return _GroupBubbleItem(
                      message: message,
                      position: position,
                      direction: group.direction,
                      onImageTap: onImageTap,
                    );
                  }),

                  // 时间戳（仅最后一条显示）
                  if (group.messages.last.createdAt != null)
                    Padding(
                      padding:
                          const EdgeInsets.only(top: 2, left: 4, right: 4),
                      child: Text(
                        DateFormatter.formatMessageTime(
                            group.messages.last.createdAt!),
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textTertiaryLight,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isOutgoing) AppSpacing.hSm,
        ],
      ),
    );
  }

  BubblePiecePosition _piecePosition(int index, int count) {
    if (count <= 1) return BubblePiecePosition.single;
    if (index == 0) return BubblePiecePosition.top;
    if (index == count - 1) return BubblePiecePosition.bottom;
    return BubblePiecePosition.middle;
  }
}

// ==================== 系统消息气泡 ====================
// 对齐iOS TaskChatSystemMessageBubble

class _SystemMessageBubble extends StatelessWidget {
  const _SystemMessageBubble({
    required this.message,
    this.onImageTap,
  });

  final Message message;
  final void Function(String imageUrl)? onImageTap;

  /// 是否是退款相关系统消息
  bool get _isRefundMessage {
    final content = message.content.toLowerCase();
    return content.contains('refund') ||
        content.contains('refund_request') ||
        content.contains('dispute') ||
        content.contains('chargeback');
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
      child: Column(
        children: [
          // 时间戳
          if (message.createdAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                DateFormatter.formatMessageTime(message.createdAt!),
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textTertiaryLight,
                ),
              ),
            ),
          // 系统消息卡片
          if (_isRefundMessage)
            _buildRefundCard(context)
          else
            _buildInfoCard(context),
          // 附件图片（证据）
          if (message.hasImageAttachments) ...[
            const SizedBox(height: 6),
            _buildAttachmentImages(),
          ],
        ],
      ),
    );
  }

  /// 退款/争议相关消息 - 特殊卡片样式（对齐iOS）
  Widget _buildRefundCard(BuildContext context) {
    final normalizedContent = message.content.toLowerCase();
    final isCompleted = normalizedContent.contains('completed') ||
        normalizedContent.contains('resolved') ||
        normalizedContent.contains('succeeded') ||
        normalizedContent.contains('success');
    final color = isCompleted ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isCompleted ? Icons.check_circle : Icons.monetization_on,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              message.content,
              style: TextStyle(
                fontSize: 13,
                color: color,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// 普通系统消息 - info样式
  Widget _buildInfoCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.textTertiaryLight.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.info_outline,
            size: 14,
            color: AppColors.textSecondaryLight,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              message.content,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondaryLight,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  /// 附件图片（证据）
  Widget _buildAttachmentImages() {
    final imageUrls = message.allImageUrls;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: imageUrls.map((url) {
        return GestureDetector(
          onTap: () => onImageTap?.call(url),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: AsyncImageView(
              imageUrl: url,
              width: 80,
              height: 80,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 全局唯一选中消息 — 保证同一时刻只有一条消息处于选中态
final ValueNotifier<int?> _selectedMessageId = ValueNotifier<int?>(null);

/// 单条气泡项（支持分组圆角 + 长按反馈 + 内联操作栏）
class _GroupBubbleItem extends StatefulWidget {
  const _GroupBubbleItem({
    required this.message,
    required this.position,
    required this.direction,
    this.onImageTap,
  });

  final Message message;
  final BubblePiecePosition position;
  final BubbleDirection direction;
  final void Function(String imageUrl)? onImageTap;

  @override
  State<_GroupBubbleItem> createState() => _GroupBubbleItemState();
}

class _GroupBubbleItemState extends State<_GroupBubbleItem>
    with SingleTickerProviderStateMixin {
  bool _isSelected = false;
  String? _translatedText;
  bool _isTranslating = false;
  bool _showTranslation = false;

  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
      reverseDuration: const Duration(milliseconds: 250),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.92).animate(
      CurvedAnimation(
        parent: _scaleController,
        curve: Curves.easeInOut,
        reverseCurve: Curves.elasticOut,
      ),
    );
    _selectedMessageId.addListener(_onGlobalSelectionChanged);
  }

  @override
  void dispose() {
    _selectedMessageId.removeListener(_onGlobalSelectionChanged);
    _scaleController.dispose();
    super.dispose();
  }

  /// 监听全局选中变化 — 当其他消息被选中时自动取消自己
  void _onGlobalSelectionChanged() {
    final myId = widget.message.id;
    if (_isSelected && _selectedMessageId.value != myId) {
      setState(() => _isSelected = false);
    }
  }

  void _onLongPressStart(LongPressStartDetails _) {
    _scaleController.forward();
  }

  void _onLongPress() {
    AppHaptics.medium();
    _scaleController.reverse();
    setState(() => _isSelected = true);
    // 通知全局：我被选中了，其它消息应取消
    _selectedMessageId.value = widget.message.id;
  }

  void _onLongPressCancel() {
    _scaleController.reverse();
  }

  void _onLongPressEnd(LongPressEndDetails _) {
    // 已在 onLongPress 中处理
  }

  void _dismiss() {
    setState(() => _isSelected = false);
    // 清除全局选中
    if (_selectedMessageId.value == widget.message.id) {
      _selectedMessageId.value = null;
    }
  }

  void _handleCopy() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    AppHaptics.light();
    _dismiss();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.chatCopied),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _handleTranslate() {
    AppHaptics.light();
    _dismiss();

    // If already translated, toggle display
    if (_translatedText != null) {
      setState(() => _showTranslation = !_showTranslation);
      return;
    }

    setState(() => _isTranslating = true);

    final locale = Localizations.localeOf(context);
    final targetLang = locale.languageCode == 'zh' ? 'zh' : 'en';

    context
        .read<CommonRepository>()
        .translate(
          text: widget.message.content,
          targetLang: targetLang,
        )
        .then((result) {
      if (!mounted) return;
      final translated = result['translated_text'] as String? ?? '';
      setState(() {
        _isTranslating = false;
        if (translated.isNotEmpty) {
          _translatedText = translated;
          _showTranslation = true;
        }
      });
    }).catchError((e) {
      if (!mounted) return;
      setState(() => _isTranslating = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.translationFailed),
          backgroundColor: AppColors.error,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOutgoing = widget.direction == BubbleDirection.outgoing;
    final borderRadius = _getBorderRadius(widget.position, widget.direction);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 图片消息：含 message_type==image 或 带图片附件的消息（任务聊天后端返回 normal + attachments）
    final showAsImage = widget.message.isImage || widget.message.hasImageAttachments;
    if (showAsImage) {
      final imageUrls = widget.message.allImageUrls;
      final displayUrl =
          imageUrls.isNotEmpty ? imageUrls.first : widget.message.imageUrl;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        return _buildInteractiveWrapper(
          isOutgoing: isOutgoing,
          isDark: isDark,
          child: ClipRRect(
            borderRadius: borderRadius,
            child: GestureDetector(
              onTap: _isSelected ? _dismiss : () => widget.onImageTap?.call(displayUrl),
              child: AsyncImageView(
                imageUrl: displayUrl,
                width: 200,
                height: 200,
                borderRadius: borderRadius,
              ),
            ),
          ),
        );
      }
    }

    // 文本消息
    return _buildInteractiveWrapper(
      isOutgoing: isOutgoing,
      isDark: isDark,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isOutgoing
              ? const LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isOutgoing ? null : (isDark
              ? Colors.white.withValues(alpha: 0.1)
              : AppColors.skeletonBase),
          borderRadius: borderRadius,
        ),
        child: Text(
          widget.message.content,
          style: TextStyle(
            color: isOutgoing
                ? Colors.white
                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
            fontSize: 15,
          ),
          softWrap: true,
          overflow: TextOverflow.visible,
        ),
      ),
    );
  }

  /// 交互包装器：缩放反馈 + 高亮遮罩 + 内联操作栏
  Widget _buildInteractiveWrapper({
    required bool isOutgoing,
    required bool isDark,
    required Widget child,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Column(
        crossAxisAlignment:
            isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // ── 气泡主体（缩放 + 高亮） ──
          GestureDetector(
            onLongPressStart: _onLongPressStart,
            onLongPress: _onLongPress,
            onLongPressCancel: _onLongPressCancel,
            onLongPressEnd: _onLongPressEnd,
            onTap: _isSelected ? _dismiss : null,
            child: AnimatedBuilder(
              animation: _scaleAnimation,
              builder: (context, builtChild) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: builtChild,
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: _isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  children: [
                    child,
                    // 选中高亮遮罩
                    if (_isSelected)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // ── 内联操作栏（选中后显示） ──
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            alignment: isOutgoing ? Alignment.centerRight : Alignment.centerLeft,
            child: _isSelected
                ? _InlineActionBar(
                    isDark: isDark,
                    isOutgoing: isOutgoing,
                    isImage: widget.message.isImage,
                    onCopy: _handleCopy,
                    onTranslate: _handleTranslate,
                  )
                : const SizedBox.shrink(),
          ),

          // ── 翻译结果（翻译中/已翻译时显示） ──
          if (_isTranslating)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.l10n.translationTranslating,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else if (_translatedText != null && _showTranslation)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: GestureDetector(
                onTap: () => setState(() => _showTranslation = false),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : AppColors.primary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: isOutgoing
                        ? CrossAxisAlignment.end
                        : CrossAxisAlignment.start,
                    children: [
                      Text(
                        _translatedText!,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.l10n.chatTranslate,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
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

  BorderRadius _getBorderRadius(
      BubblePiecePosition position, BubbleDirection direction) {
    const r = 18.0;
    const s = 4.0;
    final isIncoming = direction == BubbleDirection.incoming;

    switch (position) {
      case BubblePiecePosition.single:
        return BorderRadius.circular(r);
      case BubblePiecePosition.top:
        return BorderRadius.only(
          topLeft: const Radius.circular(r),
          topRight: const Radius.circular(r),
          bottomLeft: Radius.circular(isIncoming ? s : r),
          bottomRight: Radius.circular(isIncoming ? r : s),
        );
      case BubblePiecePosition.middle:
        return BorderRadius.only(
          topLeft: Radius.circular(isIncoming ? s : r),
          topRight: Radius.circular(isIncoming ? r : s),
          bottomLeft: Radius.circular(isIncoming ? s : r),
          bottomRight: Radius.circular(isIncoming ? r : s),
        );
      case BubblePiecePosition.bottom:
        return BorderRadius.only(
          topLeft: Radius.circular(isIncoming ? s : r),
          topRight: Radius.circular(isIncoming ? r : s),
          bottomLeft: const Radius.circular(r),
          bottomRight: const Radius.circular(r),
        );
    }
  }
}

// ==================== 内联操作栏 ====================

class _InlineActionBar extends StatelessWidget {
  const _InlineActionBar({
    required this.isDark,
    required this.isOutgoing,
    required this.isImage,
    required this.onCopy,
    required this.onTranslate,
  });

  final bool isDark;
  final bool isOutgoing;
  final bool isImage;
  final VoidCallback onCopy;
  final VoidCallback onTranslate;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.grey[800]
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 复制
            _ActionButton(
              icon: Icons.copy_rounded,
              label: context.l10n.chatCopy,
              onTap: onCopy,
              isDark: isDark,
            ),
            // 翻译（仅文本消息）
            if (!isImage) ...[
              Container(
                width: 1,
                height: 20,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                color: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.1),
              ),
              _ActionButton(
                icon: Icons.translate_rounded,
                label: context.l10n.chatTranslate,
                onTap: onTranslate,
                isDark: isDark,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
