import '../models/message.dart';
import '../services/api_service.dart';
import '../services/websocket_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/logger.dart';
import '../../core/utils/app_exception.dart';

/// 消息仓库
/// 与iOS MessageViewModel + 后端路由对齐
class MessageRepository {
  MessageRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

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
  Future<List<ChatContact>> getContacts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final cacheKey = CacheManager.buildKey(
      CacheManager.prefixContacts,
      {'p': page, 'ps': pageSize},
    );

    // 1. 检查缓存
    final cached = _cache.getWithOfflineFallback<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached
          .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 2. 网络请求
    try {
      final response = await _apiService.get<dynamic>(
        ApiEndpoints.messageContacts,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      if (!response.isSuccess || response.data == null) {
        throw MessageException(response.message ?? '获取联系人列表失败');
      }

      final items = _extractList(response.data, ['contacts', 'items', 'data']);
      await _cache.set(cacheKey, items, ttl: CacheManager.shortTTL);
      return items
          .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 3. 离线回退
      final stale = _cache.getStale<List<dynamic>>(cacheKey);
      if (stale != null) {
        return stale
            .map((e) => ChatContact.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  /// 获取与某用户的消息历史
  Future<List<Message>> getMessageHistory(
    String userId, {
    int page = 1,
    int pageSize = 50,
  }) async {
    final cacheKey = CacheManager.buildKey(
      CacheManager.prefixMessages,
      {'uid': userId, 'p': page},
    );

    // 1. 检查缓存
    final cached = _cache.getWithOfflineFallback<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 2. 网络请求
    try {
      final response = await _apiService.get(
        ApiEndpoints.messageHistory(userId),
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      if (!response.isSuccess || response.data == null) {
        throw MessageException(response.message ?? '获取消息失败');
      }

      final items = _extractList(
          response.data, ['items', 'messages', 'data']);
      await _cache.set(cacheKey, items, ttl: CacheManager.defaultTTL);
      return items
          .map((e) => Message.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 3. 离线回退
      final stale = _cache.getStale<List<dynamic>>(cacheKey);
      if (stale != null) {
        return stale
            .map((e) => Message.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
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

    // 发送后失效对应聊天缓存
    await _cache.invalidateChatCache(request.receiverId);

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
    final response = await _apiService.get(
      ApiEndpoints.unreadMessagesCount,
    );

    if (!response.isSuccess || response.data == null) {
      return 0;
    }

    if (response.data is Map<String, dynamic>) {
      return (response.data as Map<String, dynamic>)['count'] as int? ?? 0;
    }
    return 0;
  }

  // ==================== 任务聊天 ====================

  /// 获取任务聊天列表
  Future<List<TaskChat>> getTaskChats({
    int page = 1,
    int pageSize = 20,
  }) async {
    final cacheKey = CacheManager.buildKey(
      CacheManager.prefixTaskChats,
      {'p': page, 'ps': pageSize},
    );

    // 1. 检查缓存
    final cached = _cache.getWithOfflineFallback<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached
          .map((e) => TaskChat.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // 2. 网络请求
    try {
      final response = await _apiService.get<dynamic>(
        ApiEndpoints.taskChatList,
        queryParameters: {
          'page': page,
          'page_size': pageSize,
        },
      );

      if (!response.isSuccess || response.data == null) {
        throw MessageException(response.message ?? '获取任务聊天列表失败');
      }

      final items = _extractList(
          response.data, ['task_chats', 'tasks', 'items', 'data']);
      await _cache.set(cacheKey, items, ttl: CacheManager.shortTTL);
      return items
          .map((e) => TaskChat.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      // 3. 离线回退
      final stale = _cache.getStale<List<dynamic>>(cacheKey);
      if (stale != null) {
        return stale
            .map((e) => TaskChat.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  /// 获取任务聊天未读数量（后端返回 unread_count，对标 iOS loadUnreadMessageCount）
  Future<int> getTaskChatUnreadCount() async {
    final response = await _apiService.get(
      ApiEndpoints.taskChatUnreadCount,
    );

    if (!response.isSuccess || response.data == null) {
      return 0;
    }

    if (response.data is Map<String, dynamic>) {
      final map = response.data as Map<String, dynamic>;
      return map['unread_count'] as int? ?? map['count'] as int? ?? 0;
    }
    return 0;
  }

  /// 任务聊天消息列表结果（后端游标分页：limit + cursor）
  static List<Message> parseTaskChatMessagesResponse(Map<String, dynamic> data) {
    final items = (data['messages'] as List<dynamic>?) ?? const [];
    return items
        .map((e) => Message.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取任务聊天消息（后端使用 limit + cursor 分页，非 page）
  Future<({List<Message> messages, String? nextCursor, bool hasMore})>
      getTaskChatMessages(
    int taskId, {
    int limit = 50,
    String? cursor,
  }) async {
    final cacheKey = CacheManager.buildKey(
      CacheManager.prefixTaskMessages,
      {'tid': taskId, 'cursor': cursor ?? 'first'},
    );

    // 首屏（进入聊天）不读缓存，始终拉网络，保证看到最新消息；列表预览来自 getTaskChats 会更新
    // 仅加载更多（有 cursor）或网络失败时用缓存/离线数据
    try {
      final params = <String, dynamic>{'limit': limit.clamp(1, 100)};
      if (cursor != null && cursor.isNotEmpty) {
        params['cursor'] = cursor;
      }
      final response = await _apiService.get(
        ApiEndpoints.taskChatMessages(taskId),
        queryParameters: params,
      );

      if (!response.isSuccess || response.data == null) {
        throw MessageException(response.message ?? '获取任务聊天消息失败');
      }

      final data = response.data as Map<String, dynamic>;
      final messages = parseTaskChatMessagesResponse(data);
      final nextCursor = data['next_cursor'] as String?;
      final hasMore = data['has_more'] as bool? ?? false;

      if (cursor == null || cursor.isEmpty) {
        final rawMessages = data['messages'] as List<dynamic>? ?? [];
        await _cache.set(
          cacheKey,
          {
            'messages': rawMessages,
            'next_cursor': nextCursor,
            'has_more': hasMore,
          },
          ttl: CacheManager.defaultTTL,
        );
      }

      return (messages: messages, nextCursor: nextCursor, hasMore: hasMore);
    } catch (e) {
      if (cursor == null || cursor.isEmpty) {
        final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
        if (stale != null) {
          final list = stale['messages'] as List<dynamic>? ?? const [];
          return (
            messages: list
                .map((e) => Message.fromJson(e as Map<String, dynamic>))
                .toList(),
            nextCursor: stale['next_cursor'] as String?,
            hasMore: stale['has_more'] as bool? ?? false,
          );
        }
      }
      rethrow;
    }
  }

  /// 发送任务聊天消息
  /// [attachments] 附件数组，与 iOS sendMessageWithAttachment 对齐：每项含 attachment_type、url、可选 meta
  Future<Message> sendTaskChatMessage(
    int taskId, {
    required String content,
    String messageType = 'text',
    List<Map<String, dynamic>>? attachments,
  }) async {
    final data = <String, dynamic>{
      'content': content,
      'message_type': messageType,
    };
    if (attachments != null && attachments.isNotEmpty) {
      data['attachments'] = attachments;
    }
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskChatSend(taskId),
      data: data,
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '发送任务聊天消息失败');
    }

    // 发送后失效对应任务聊天缓存
    await _cache.invalidateTaskChatCache(taskId);

    return Message.fromJson(response.data!);
  }

  /// 标记任务聊天已读
  ///
  /// [uptoMessageId] — 标记该消息及之前的所有消息为已读；
  /// [messageIds] — 标记指定消息 ID 列表为已读。
  /// 二者至少传一个，否则后端返回 422。
  Future<void> markTaskChatRead(
    int taskId, {
    int? uptoMessageId,
    List<int>? messageIds,
  }) async {
    final body = <String, dynamic>{};
    if (uptoMessageId != null) {
      body['upto_message_id'] = uptoMessageId;
    }
    if (messageIds != null && messageIds.isNotEmpty) {
      body['message_ids'] = messageIds;
    }

    final response = await _apiService.post(
      ApiEndpoints.taskChatRead(taskId),
      data: body.isEmpty ? null : body,
    );

    if (!response.isSuccess) {
      throw MessageException(response.message ?? '标记任务聊天已读失败');
    }

    // 失效任务聊天列表缓存，刷新时能拿到最新未读数
    await _cache.invalidateTaskChatCache(taskId);
  }

  /// 上传任务聊天图片（私密图片，走 /api/upload/image，后端要求字段名为 image）
  Future<String> uploadImage(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      ApiEndpoints.uploadImage,
      filePath: filePath,
      fieldName: 'image',
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

  /// 生成消息图片上传URL
  Future<String> generateImageUrl() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.messageGenerateImageUrl,
    );

    if (!response.isSuccess || response.data == null) {
      throw MessageException(response.message ?? '生成图片URL失败');
    }

    return response.data!['url'] as String? ?? '';
  }
}

/// 消息异常
class MessageException extends AppException {
  const MessageException(super.message);
}
