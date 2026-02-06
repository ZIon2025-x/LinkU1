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

  final int id;
  final UserBrief user;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      id: json['id'] as int,
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
  final int senderId;
  final int receiverId;
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
      senderId: json['sender_id'] as int,
      receiverId: json['receiver_id'] as int,
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

/// 任务聊天
class TaskChat extends Equatable {
  const TaskChat({
    required this.taskId,
    required this.taskTitle,
    this.taskStatus,
    required this.participants,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  final int taskId;
  final String taskTitle;
  final String? taskStatus;
  final List<UserBrief> participants;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  factory TaskChat.fromJson(Map<String, dynamic> json) {
    return TaskChat(
      taskId: json['task_id'] as int,
      taskTitle: json['task_title'] as String? ?? '',
      taskStatus: json['task_status'] as String?,
      participants: (json['participants'] as List<dynamic>?)
              ?.map((e) => UserBrief.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      lastMessage: json['last_message'] as String?,
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : null,
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

  final int receiverId;
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
