import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';

/// 消息仓库
/// 与iOS MessageViewModel + 后端路由对齐
class MessageRepository {
  MessageRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 从 API 响应中提取列表数据
  /// 后端可能返回 List 或 Map（带包装键如 contacts, task_chats, items 等）
  List<dynamic> _extractList(dynamic data, List<String> possibleKeys) {
    if (data is List) return data;
    if (data is Map<String, dynamic>) {
      for (final key in possibleKeys) {
        final value = data[key];
        if (value is List) return value;
      }
      // 尝试所有值中的第一个 List
      for (final value in data.values) {
        if (value is List) return value;
      }
    }
    AppLogger.warning('_extractList: unexpected data type ${data.runtimeType}');
    return [];
  }

  // ==================== 私信 ====================

  /// 获取聊天联系人列表
  Future<List<ChatContact>> getContacts() async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.messageContacts,
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '获取联系人列表失败');
    }

    final items = _extractList(response.data, ['contacts', 'items', 'data']);
    return items
        .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取与某用户的消息历史
  Future<List<Message>> getMessageHistory(
    String userId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.messageHistory(userId),
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '获取消息失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取与某用户的消息列表（兼容旧调用）
  Future<List<Message>> getMessagesWith(
    String userId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    return getMessageHistory(
      userId,
      page: page,
      pageSize: pageSize,
    );
  }

  /// 发送私信（HTTP方式）
  Future<Message> sendMessage(SendMessageRequest request) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.sendMessage,
      data: request.toJson(),
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '发送消息失败');
    }

    return Message.fromJson(response.data!);
  }

  /// 通过WebSocket发送消息
  void sendMessageViaWebSocket(SendMessageRequest request) {
    WebSocketService.instance.sendChatMessage(
      receiverId: request.receiverId,
      content: request.content,
      msgType: request.messageType,
      taskId: request.taskId,
    );
  }

  /// 标记聊天已读
  Future<void> markChatRead(String contactId) async {
    final response = await _apiService.post(
      ApiEndpoints.markChatRead(contactId),
    );

    if (!response.isSuccess) {
      throw MessageException(response.message ?? '标记已读失败');
    }
  }

  /// 标记消息已读
  Future<void> markMessagesRead(String contactId) async {
    await markChatRead(contactId);
    // 同时通过WebSocket通知已读
    WebSocketService.instance.sendReadReceipt(senderId: contactId);
  }

  /// 获取未读消息
  Future<List<Message>> getUnreadMessages() async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.unreadMessages,
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '获取未读消息失败');
    }

    final items = _extractList(
        response.data, ['messages', 'items', 'data']);
    return items
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取未读消息数量
  Future<int> getUnreadMessagesCount() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.unreadMessagesCount,
    );

    if (!response.isSuccess || response.data == null) {
      return 0;
    }

    return response.data!['count'] as int? ?? 0;
  }

  // ==================== 任务聊天 ====================

  /// 获取任务聊天列表
  Future<List<TaskChat>> getTaskChats() async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.taskChatList,
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '获取任务聊天列表失败');
    }

    final items = _extractList(
        response.data, ['task_chats', 'tasks', 'items', 'data']);
    return items
        .map((e) => TaskChat.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取任务聊天未读数量
  Future<int> getTaskChatUnreadCount() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskChatUnreadCount,
    );

    if (!response.isSuccess || response.data == null) {
      return 0;
    }

    return response.data!['count'] as int? ?? 0;
  }

  /// 获取任务聊天消息
  Future<List<Message>> getTaskChatMessages(
    int taskId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskChatMessages(taskId),
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '获取任务聊天消息失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 发送任务聊天消息
  Future<Message> sendTaskChatMessage(
    int taskId, {
    required String content,
    String messageType = 'text',
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskChatSend(taskId),
      data: {
        'content': content,
        'message_type': messageType,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '发送任务聊天消息失败');
    }

    return Message.fromJson(response.data!);
  }

  /// 标记任务聊天已读
  Future<void> markTaskChatRead(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.taskChatRead(taskId),
    );

    if (!response.isSuccess) {
      throw MessageException(response.message ?? '标记任务聊天已读失败');
    }
  }

  /// 上传聊天图片（私密图片）
  Future<String> uploadImage(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.uploadImage,
      filePath: filePath,
      fieldName: 'file',
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '上传图片失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  /// 发送正在输入状态
  void sendTypingStatus(String receiverId) {
    WebSocketService.instance.sendTyping(receiverId: receiverId);
  }

  /// 获取消息流（WebSocket）
  Stream<WebSocketMessage> get messageStream =>
      WebSocketService.instance.messageStream;

  /// 获取连接状态流
  Stream<bool> get connectionStream =>
      WebSocketService.instance.connectionStream;
}

/// 消息异常
class MessageException implements Exception {
  MessageException(this.message);

  final String message;

  @override
  String toString() => 'MessageException: $message';
}
