import 'package:equatable/equatable.dart';

/// 客服分配响应
class CustomerServiceAssignResponse extends Equatable {
  const CustomerServiceAssignResponse({
    this.service,
    this.chat,
    this.error,
    this.message,
    this.queueStatus,
    this.systemMessage,
  });

  final CustomerServiceInfo? service;
  final CustomerServiceChat? chat;
  final String? error;
  final String? message;
  final CustomerServiceQueueStatus? queueStatus;
  final SystemMessage? systemMessage;

  factory CustomerServiceAssignResponse.fromJson(Map<String, dynamic> json) {
    return CustomerServiceAssignResponse(
      service: json['service'] != null
          ? CustomerServiceInfo.fromJson(json['service'] as Map<String, dynamic>)
          : null,
      chat: json['chat'] != null
          ? CustomerServiceChat.fromJson(json['chat'] as Map<String, dynamic>)
          : null,
      error: json['error'] as String?,
      message: json['message'] as String?,
      queueStatus: json['queue_status'] != null
          ? CustomerServiceQueueStatus.fromJson(
              json['queue_status'] as Map<String, dynamic>)
          : null,
      systemMessage: json['system_message'] != null
          ? SystemMessage.fromJson(
              json['system_message'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [service, chat, error, message];
}

/// 客服信息
class CustomerServiceInfo extends Equatable {
  const CustomerServiceInfo({
    required this.id,
    required this.name,
    this.avatar,
    this.avgRating,
    this.totalRatings,
  });

  final String id;
  final String name;
  final String? avatar;
  final double? avgRating;
  final int? totalRatings;

  factory CustomerServiceInfo.fromJson(Map<String, dynamic> json) {
    return CustomerServiceInfo(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      avatar: json['avatar'] as String?,
      avgRating: (json['avg_rating'] as num?)?.toDouble(),
      totalRatings: json['total_ratings'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'avg_rating': avgRating,
      'total_ratings': totalRatings,
    };
  }

  @override
  List<Object?> get props => [id, name];
}

/// 客服会话
class CustomerServiceChat extends Equatable {
  const CustomerServiceChat({
    required this.chatId,
    required this.userId,
    required this.serviceId,
    this.isEnded = 0,
    this.createdAt,
    this.totalMessages,
  });

  final String chatId;
  final String userId;
  final String serviceId;
  final int isEnded;
  final String? createdAt;
  final int? totalMessages;

  factory CustomerServiceChat.fromJson(Map<String, dynamic> json) {
    return CustomerServiceChat(
      chatId: json['chat_id'] as String,
      userId: json['user_id'] as String,
      serviceId: json['service_id'] as String,
      isEnded: json['is_ended'] as int? ?? 0,
      createdAt: json['created_at'] as String?,
      totalMessages: json['total_messages'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'chat_id': chatId,
      'user_id': userId,
      'service_id': serviceId,
      'is_ended': isEnded,
      'created_at': createdAt,
      'total_messages': totalMessages,
    };
  }

  @override
  List<Object?> get props => [chatId, userId, serviceId];
}

/// 客服消息
class CustomerServiceMessage extends Equatable {
  const CustomerServiceMessage({
    this.messageId,
    this.chatId,
    this.senderId,
    this.senderType,
    required this.content,
    this.messageType,
    this.taskId,
    this.imageId,
    this.createdAt,
    this.isRead,
  });

  final int? messageId;
  final String? chatId;
  final String? senderId;
  final String? senderType; // "user" 或 "customer_service"
  final String content;
  final String? messageType; // "text", "task_card", "image", "file"
  final int? taskId;
  final String? imageId;
  final String? createdAt;
  final bool? isRead;

  /// 唯一标识
  String get id {
    if (messageId != null) return '$messageId';
    final timestamp = createdAt ?? DateTime.now().toIso8601String();
    return '${senderId ?? ''}_${chatId ?? ''}_$timestamp';
  }

  factory CustomerServiceMessage.fromJson(Map<String, dynamic> json) {
    // messageId 可能是 int 或 String
    int? parsedMessageId;
    final rawId = json['id'];
    if (rawId is int) {
      parsedMessageId = rawId;
    } else if (rawId is String) {
      parsedMessageId = int.tryParse(rawId);
    }

    // is_read 可能是 int(0/1) 或 bool
    bool? parsedIsRead;
    final rawIsRead = json['is_read'];
    if (rawIsRead is int) {
      parsedIsRead = rawIsRead != 0;
    } else if (rawIsRead is bool) {
      parsedIsRead = rawIsRead;
    }

    return CustomerServiceMessage(
      messageId: parsedMessageId,
      chatId: json['chat_id'] as String?,
      senderId: json['sender_id'] as String?,
      senderType: json['sender_type'] as String?,
      content: json['content'] as String? ?? '',
      messageType: json['message_type'] as String?,
      taskId: json['task_id'] as int?,
      imageId: json['image_id'] as String?,
      createdAt: json['created_at'] as String?,
      isRead: parsedIsRead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': messageId,
      'chat_id': chatId,
      'sender_id': senderId,
      'sender_type': senderType,
      'content': content,
      'message_type': messageType,
      'task_id': taskId,
      'image_id': imageId,
      'created_at': createdAt,
      'is_read': isRead,
    };
  }

  @override
  List<Object?> get props => [messageId, chatId, content, createdAt];
}

/// 客服排队状态
class CustomerServiceQueueStatus extends Equatable {
  const CustomerServiceQueueStatus({
    this.position,
    this.estimatedWaitTime,
    this.status,
  });

  final int? position;
  final int? estimatedWaitTime; // 预计等待时间（秒）
  final String? status; // "waiting", "assigned", "none"

  factory CustomerServiceQueueStatus.fromJson(Map<String, dynamic> json) {
    return CustomerServiceQueueStatus(
      position: json['position'] as int?,
      estimatedWaitTime: json['estimated_wait_time'] as int?,
      status: json['status'] as String?,
    );
  }

  @override
  List<Object?> get props => [position, estimatedWaitTime, status];
}

/// 系统消息
class SystemMessage extends Equatable {
  const SystemMessage({required this.content});

  final String content;

  factory SystemMessage.fromJson(Map<String, dynamic> json) {
    return SystemMessage(content: json['content'] as String? ?? '');
  }

  @override
  List<Object?> get props => [content];
}
