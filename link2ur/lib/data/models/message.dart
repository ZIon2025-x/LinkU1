import 'package:equatable/equatable.dart';
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
          ? DateTime.parse(json['last_message_time'])
          : null,
      unreadCount: json['unread_count'] as int? ?? 0,
      isOnline: json['is_online'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, user, lastMessage, unreadCount];
}

/// 消息模型
class Message extends Equatable {
  const Message({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.messageType = 'text',
    this.imageUrl,
    this.taskId,
    this.isRead = false,
    this.createdAt,
  });

  final int id;
  final String senderId;
  final String receiverId;
  final String content;
  final String messageType; // text, image, system
  final String? imageUrl;
  final int? taskId;
  final bool isRead;
  final DateTime? createdAt;

  /// 是否是图片消息
  bool get isImage => messageType == 'image';

  /// 是否是系统消息
  bool get isSystem => messageType == 'system';

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] as int,
      senderId: json['sender_id']?.toString() ?? '',
      receiverId: json['receiver_id']?.toString() ?? '',
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String? ?? 'text',
      imageUrl: json['image_url'] as String?,
      taskId: json['task_id'] as int?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
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
      if (taskId != null) 'task_id': taskId,
      'is_read': isRead,
      'created_at': createdAt?.toIso8601String(),
    };
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

  /// 多语言显示标题（对齐iOS displayTitle）
  String get displayTitle => titleZh ?? titleEn ?? taskTitle;

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
