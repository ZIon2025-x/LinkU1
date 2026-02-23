import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/localized_string.dart';
import 'user.dart';

/// 聊天联系人
class ChatContact extends Equatable {
  const ChatContact({
    required this.id,
    required this.user,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  final String id;
  final UserBrief user;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: json['id']?.toString() ?? '',
      user: UserBrief.fromJson(json['user'] as Map<String, dynamic>),
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.tryParse(json['last_message_time'])
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, user, lastMessage, unreadCount];
}

/// 消息附件模型（对齐iOS MessageAttachment + 后端response）
class MessageAttachment extends Equatable {
  const MessageAttachment({
    this.id,
    this.attachmentType,
    this.url,
    this.blobId,
    this.meta,
  });

  final int? id;
  final String? attachmentType; // image, file
  final String? url;
  final String? blobId;
  final Map<String, dynamic>? meta;

  bool get isImage => attachmentType == 'image';

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    return MessageAttachment(
      id: json['id'] as int?,
      attachmentType: json['attachment_type'] as String?,
      url: json['url'] as String?,
      blobId: json['blob_id'] as String?,
      meta: json['meta'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, url, blobId];
}

/// 消息模型
class Message extends Equatable {
  const Message({
    required this.id,
    required this.senderId,
    this.receiverId = '',
    required this.content,
    this.messageType = 'text',
    this.imageUrl,
    this.senderName,
    this.senderAvatar,
    this.taskId,
    this.isRead = false,
    this.createdAt,
    this.attachments = const [],
  });

  final int id;
  final String senderId;
  final String receiverId;
  final String content;
  final String messageType; // text, normal, image, system, file
  final String? imageUrl;
  final String? senderName;
  final String? senderAvatar;
  final int? taskId;
  final bool isRead;
  final DateTime? createdAt;
  final List<MessageAttachment> attachments;

  /// 是否是图片消息
  bool get isImage => messageType == 'image';

  /// 是否是系统消息 - 对齐iOS: msgType == .system || senderId == nil
  bool get isSystem => messageType == 'system' || senderId.isEmpty;

  /// 是否有图片附件
  bool get hasImageAttachments =>
      attachments.any((a) => a.isImage && a.url != null);

  /// 获取所有图片URL（包括imageUrl和附件中的图片）
  List<String> get allImageUrls {
    final urls = <String>[];
    if (imageUrl != null && imageUrl!.isNotEmpty) urls.add(imageUrl!);
    for (final a in attachments) {
      if (a.isImage && a.url != null && a.url!.isNotEmpty) {
        if (!urls.contains(a.url!)) urls.add(a.url!);
      }
    }
    return urls;
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ??
          json['msg_type'] as String? ??
          'text',
      imageUrl: json['image_url'] as String?,
      senderName: json['sender_name'] as String?,
      senderAvatar: json['sender_avatar'] as String?,
      taskId: json['task_id'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      attachments: (json['attachments'] as List<dynamic>?)
              ?.map((e) =>
                  MessageAttachment.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sender_id': senderId,
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      if (imageUrl != null) 'image_url': imageUrl,
      if (senderName != null) 'sender_name': senderName,
      if (senderAvatar != null) 'sender_avatar': senderAvatar,
      if (taskId != null) 'task_id': taskId,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
  }

  Message copyWith({
    int? id,
    String? senderId,
    String? receiverId,
    String? content,
    String? messageType,
    String? imageUrl,
    String? senderName,
    String? senderAvatar,
    int? taskId,
    bool? isRead,
    DateTime? createdAt,
    List<MessageAttachment>? attachments,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      messageType: messageType ?? this.messageType,
      imageUrl: imageUrl ?? this.imageUrl,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      taskId: taskId ?? this.taskId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
    );
  }

  @override
  List<Object?> get props => [id, senderId, receiverId, content, createdAt];
}

/// 最后一条消息（含发送者信息，对齐iOS LastMessage）
class ChatLastMessage {
  const ChatLastMessage({
    this.id,
    this.content,
    this.senderId,
    this.senderName,
    this.createdAt,
  });

  final int? id;
  final String? content;
  final String? senderId;
  final String? senderName;
  final String? createdAt;

  factory ChatLastMessage.fromJson(Map<String, dynamic> json) {
    return ChatLastMessage(
      id: json['id'] as int?,
      content: json['content'] as String?,
      senderId: json['sender_id']?.toString(),
      senderName: json['sender_name'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }
}

/// 任务聊天（对齐iOS TaskChatItem）
class TaskChat extends Equatable {
  const TaskChat({
    required this.taskId,
    required this.taskTitle,
    this.titleEn,
    this.titleZh,
    this.taskStatus,
    this.taskType,
    this.taskSource,
    this.posterId,
    this.takerId,
    this.expertCreatorId,
    this.images = const [],
    this.isMultiParticipant = false,
    required this.participants,
    this.lastMessage,
    this.lastMessageObj,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  final int taskId;
  final String taskTitle;
  final String? titleEn;
  final String? titleZh;
  final String? taskStatus;
  final String? taskType;
  final String? taskSource;
  final String? posterId;
  final String? takerId;
  final String? expertCreatorId;
  final List<String> images;
  final bool isMultiParticipant;
  final List<UserBrief> participants;
  final String? lastMessage;
  final ChatLastMessage? lastMessageObj;
  final DateTime? lastMessageTime;
  final int unreadCount;

  /// 多语言显示标题（根据 locale 选择 zh/en）
  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, taskTitle, locale);

  factory TaskChat.fromJson(Map<String, dynamic> json) {
    // 解析 last_message：兼容 String 或 Object 两种格式
    String? lastMessageText;
    ChatLastMessage? lastMessageObj;
    final rawLastMessage = json['last_message'];
    if (rawLastMessage is Map<String, dynamic>) {
      lastMessageObj = ChatLastMessage.fromJson(rawLastMessage);
      lastMessageText = lastMessageObj.content;
    } else if (rawLastMessage is String) {
      lastMessageText = rawLastMessage;
    }

    // 解析 last_message_time，如果没有则从 lastMessage.createdAt 提取
    DateTime? lastMessageTime;
    final rawTime = json['last_message_time'];
    if (rawTime != null) {
      lastMessageTime = DateTime.tryParse(rawTime.toString());
    } else if (lastMessageObj?.createdAt != null) {
      lastMessageTime = DateTime.tryParse(lastMessageObj!.createdAt!);
    }

    // 解析 images：可能是数组或其他格式
    List<String> images = [];
    final rawImages = json['images'];
    if (rawImages is List) {
      images = rawImages.whereType<String>().toList();
    }

    return TaskChat(
      taskId: (json['task_id'] ?? json['id']) as int? ?? 0,
      taskTitle: json['task_title'] as String?
          ?? json['title'] as String?
          ?? '',
      titleEn: json['title_en'] as String?,
      titleZh: json['title_zh'] as String?,
      taskStatus: json['task_status'] as String?
          ?? json['status'] as String?,
      taskType: json['task_type'] as String?,
      taskSource: json['task_source'] as String?,
      posterId: json['poster_id']?.toString(),
      takerId: json['taker_id']?.toString(),
      expertCreatorId: json['expert_creator_id']?.toString(),
      images: images,
      isMultiParticipant: json['is_multi_participant'] as bool? ?? false,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => UserBrief.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: lastMessageText,
      lastMessageObj: lastMessageObj,
      lastMessageTime: lastMessageTime,
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  /// 创建副本，仅覆盖指定字段
  TaskChat copyWith({
    int? unreadCount,
  }) {
    return TaskChat(
      taskId: taskId,
      taskTitle: taskTitle,
      titleEn: titleEn,
      titleZh: titleZh,
      taskStatus: taskStatus,
      taskType: taskType,
      taskSource: taskSource,
      posterId: posterId,
      takerId: takerId,
      expertCreatorId: expertCreatorId,
      images: images,
      isMultiParticipant: isMultiParticipant,
      participants: participants,
      lastMessage: lastMessage,
      lastMessageObj: lastMessageObj,
      lastMessageTime: lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }

  @override
  List<Object?> get props => [taskId, lastMessage, unreadCount];
}

/// 发送消息请求
class SendMessageRequest {
  const SendMessageRequest({
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
    this.taskId,
    this.imageUrl,
  });

  final String receiverId;
  final String content;
  final String messageType;
  final int? taskId;
  final String? imageUrl;

  Map<String, dynamic> toJson() {
    return {
      'receiver_id': receiverId,
      'content': content,
      'message_type': messageType,
      if (taskId != null) 'task_id': taskId,
      if (imageUrl != null) 'image_url': imageUrl,
    };
  }
}
