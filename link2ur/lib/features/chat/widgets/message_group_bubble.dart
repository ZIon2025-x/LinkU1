import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/message.dart';

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

    final isMe = currentUserId != null && message.senderId == currentUserId;
    final direction =
        isMe ? BubbleDirection.outgoing : BubbleDirection.incoming;

    bool shouldStartNewGroup;
    if (currentGroup.isEmpty) {
      shouldStartNewGroup = true;
    } else if (message.senderId != currentSenderId) {
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
      currentSenderId = message.senderId;
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
                maxWidth: MediaQuery.of(context).size.width * 0.72,
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
        content.contains('退款') ||
        content.contains('dispute') ||
        content.contains('争议');
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
    final isCompleted = message.content.contains('completed') ||
        message.content.contains('已完成') ||
        message.content.contains('resolved') ||
        message.content.contains('已解决');
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
              fit: BoxFit.cover,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// 单条气泡项（支持分组圆角）
class _GroupBubbleItem extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final isOutgoing = direction == BubbleDirection.outgoing;
    final borderRadius = _getBorderRadius(position, direction);

    // 图片消息
    if (message.isImage) {
      final imageUrls = message.allImageUrls;
      final displayUrl =
          imageUrls.isNotEmpty ? imageUrls.first : message.imageUrl;
      if (displayUrl != null && displayUrl.isNotEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: GestureDetector(
            onTap: () => onImageTap?.call(displayUrl),
            child: AsyncImageView(
              imageUrl: displayUrl,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              borderRadius: borderRadius,
            ),
          ),
        );
      }
    }

    // 文本消息
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: GestureDetector(
        onLongPress: () {
          // 复制消息
          Clipboard.setData(ClipboardData(text: message.content));
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.l10n.chatCopied),
              duration: const Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: isOutgoing
                ? const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF5A67D8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isOutgoing ? null : AppColors.skeletonBase,
            borderRadius: borderRadius,
          ),
          child: Text(
            message.content,
            style: TextStyle(
              color: isOutgoing ? Colors.white : AppColors.textPrimaryLight,
              fontSize: 15,
            ),
          ),
        ),
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
