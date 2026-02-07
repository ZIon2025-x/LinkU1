import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 消息仓库
/// 参考iOS APIService+Endpoints.swift 消息相关
class MessageRepository {
  MessageRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取聊天联系人列表
  Future<List<ChatContact>> getContacts() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.contacts,
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '获取联系人列表失败');
    }

    return response.data!
        .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取与某用户的消息列表
  Future<List<Message>> getMessagesWith(
    int userId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.messagesWith(userId),
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

  /// 发送消息（HTTP方式）
  Future<Message> sendMessage(SendMessageRequest request) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.messages,
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

  /// 标记消息已读
  Future<void> markMessagesRead(int contactId) async {
    final response = await _apiService.post(
      ApiEndpoints.markMessagesRead(contactId),
    );

    if (!response.isSuccess) {
      throw MessageException(response.message ?? '标记已读失败');
    }

    // 同时通过WebSocket通知已读
    WebSocketService.instance.sendReadReceipt(senderId: contactId);
  }

  /// 获取任务聊天列表
  Future<List<TaskChat>> getTaskChats() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.taskChats,
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '获取任务聊天列表失败');
    }

    return response.data!
        .map((e) => TaskChat.fromJson(e as Map<String, dynamic>))
        .toList();
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

  /// 上传聊天图片
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
  void sendTypingStatus(int receiverId) {
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
