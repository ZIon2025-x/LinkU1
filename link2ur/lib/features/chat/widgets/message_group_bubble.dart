import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/utils/date_formatter.dart';
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
  });

  final List<Message> messages;
  final BubbleDirection direction;
  final int? senderId;
  final String? senderName;
  final String? senderAvatar;
}

/// 将消息按发送者和时间间隔分组
/// 参考iOS groupMessages()
List<MessageGroup> groupMessages(List<Message> messages, int? currentUserId) {
  if (messages.isEmpty) return [];

  final groups = <MessageGroup>[];
  var currentGroup = <Message>[];
  int? currentSenderId;
  BubbleDirection? currentDirection;
  DateTime? lastMessageTime;
  const timeThreshold = Duration(minutes: 3);

  for (final message in messages) {
    // 跳过系统消息
    if (message.isSystem) {
      if (currentGroup.isNotEmpty) {
        final dir = currentDirection;
        if (dir != null) {
          groups.add(MessageGroup(
            messages: List.from(currentGroup),
            direction: dir,
            senderId: currentSenderId,
          ));
        }
        currentGroup = [];
      }
      continue;
    }

    final isMe = currentUserId != null && message.senderId == currentUserId;
    final direction = isMe ? BubbleDirection.outgoing : BubbleDirection.incoming;

    bool shouldStartNewGroup;
    if (currentGroup.isEmpty) {
      shouldStartNewGroup = true;
    } else if (message.senderId != currentSenderId) {
      shouldStartNewGroup = true;
    } else if (message.createdAt != null && lastMessageTime != null) {
      shouldStartNewGroup =
          message.createdAt!.difference(lastMessageTime).abs() > timeThreshold;
    } else {
      shouldStartNewGroup = false;
    }

    if (shouldStartNewGroup) {
      if (currentGroup.isNotEmpty && currentDirection != null) {
        groups.add(MessageGroup(
          messages: List.from(currentGroup),
          direction: currentDirection,
          senderId: currentSenderId,
        ));
      }
      currentGroup = [message];
      currentSenderId = message.senderId;
      currentDirection = direction;
      lastMessageTime = message.createdAt;
    } else {
      currentGroup.add(message);
      lastMessageTime = message.createdAt;
    }
  }

  if (currentGroup.isNotEmpty && currentDirection != null) {
    groups.add(MessageGroup(
      messages: List.from(currentGroup),
      direction: currentDirection,
      senderId: currentSenderId,
    ));
  }

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
                crossAxisAlignment:
                    isOutgoing ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 发送者名称
                  if (!isOutgoing &&
                      group.senderName != null &&
                      group.senderName!.isNotEmpty)
                    Padding(
                      padding:
                          const EdgeInsets.only(left: 4, bottom: 2),
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
                    final position = _piecePosition(index, group.messages.length);
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
                      padding: const EdgeInsets.only(top: 2, left: 4, right: 4),
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
    if (message.isImage && message.imageUrl != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 1),
        child: GestureDetector(
          onTap: () => onImageTap?.call(message.imageUrl!),
          child: ClipRRect(
            borderRadius: borderRadius,
            child: Image.network(
              message.imageUrl!,
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 200,
                height: 200,
                color: AppColors.skeletonBase,
                child: const Icon(Icons.broken_image),
              ),
            ),
          ),
        ),
      );
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
            const SnackBar(
              content: Text('已复制'),
              duration: Duration(seconds: 1),
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
