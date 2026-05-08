import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/message.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/services/storage_service.dart';
import '../../../data/services/websocket_service.dart';
import '../../../core/utils/logger.dart';

// ==================== Events ====================

abstract class MessageEvent extends Equatable {
  const MessageEvent();

  @override
  List<Object?> get props => [];
}

class MessageLoadContacts extends MessageEvent {
  const MessageLoadContacts();
}

/// 加载任务聊天列表。forceRefresh 为 true 时跳过节流（下拉刷新、重试时使用）
class MessageLoadTaskChats extends MessageEvent {
  const MessageLoadTaskChats({this.forceRefresh = false});
  final bool forceRefresh;

  @override
  List<Object?> get props => [forceRefresh];
}

class MessageLoadMoreTaskChats extends MessageEvent {
  const MessageLoadMoreTaskChats();
}

class MessageRefreshRequested extends MessageEvent {
  const MessageRefreshRequested();
}

/// 置顶任务聊天
class MessagePinTaskChat extends MessageEvent {
  const MessagePinTaskChat(this.taskId);
  final int taskId;

  @override
  List<Object?> get props => [taskId];
}

/// 取消置顶任务聊天
class MessageUnpinTaskChat extends MessageEvent {
  const MessageUnpinTaskChat(this.taskId);
  final int taskId;

  @override
  List<Object?> get props => [taskId];
}

/// 隐藏（软删除）任务聊天
class MessageHideTaskChat extends MessageEvent {
  const MessageHideTaskChat(this.taskId);
  final int taskId;

  @override
  List<Object?> get props => [taskId];
}

/// 本地标记任务聊天已读（将 unreadCount 置 0，无需网络请求）
class MessageMarkTaskChatRead extends MessageEvent {
  const MessageMarkTaskChatRead(this.taskId);
  final int taskId;

  @override
  List<Object?> get props => [taskId];
}

/// 开始轮询任务聊天列表（与 NotificationBloc 60 秒轮询对齐，保证消息 Tab 未读红点实时）
class MessageStartPolling extends MessageEvent {
  const MessageStartPolling();
}

/// 停止轮询
class MessageStopPolling extends MessageEvent {
  const MessageStopPolling();
}

/// 拉取任务聊天未读数（对标 iOS loadUnreadMessageCount：WebSocket/前台/定时调 API 实现角标实时）
class MessageFetchUnreadCount extends MessageEvent {
  const MessageFetchUnreadCount();
}

/// 内部事件：WebSocket 收到聊天消息后由 BLoC handler 同步 patch state
/// （listener 内不能直接 emit，必须走 event handler）
class _MessageWsChatReceived extends MessageEvent {
  const _MessageWsChatReceived(this.wsMessage);
  final WebSocketMessage wsMessage;

  // BLoC 不基于 props 对 event 去重，留空即可
  @override
  List<Object?> get props => const [];
}

// ==================== State ====================

enum MessageStatus { initial, loading, loaded, error }

class MessageState extends Equatable {
  const MessageState({
    this.status = MessageStatus.initial,
    this.contacts = const [],
    this.taskChats = const [],
    this.taskChatUnreadFromApi,
    this.errorMessage,
    this.taskChatsPage = 1,
    this.hasMoreTaskChats = true,
    this.isLoadingMore = false,
    this.isRefreshing = false,
    this.pinnedTaskIds = const {},
    this.hiddenTaskChats = const {},
  });

  final MessageStatus status;
  final List<ChatContact> contacts;
  final List<TaskChat> taskChats;
  /// 未读数量 API 结果（WebSocket/前台/定时拉取，角标实时；列表刷新后置 null 用列表汇总）
  final int? taskChatUnreadFromApi;
  final String? errorMessage;
  final int taskChatsPage;
  final bool hasMoreTaskChats;
  final bool isLoadingMore;

  /// 下拉刷新中（用于 RefreshIndicator 正确结束）
  final bool isRefreshing;

  /// 置顶的任务ID集合
  final Set<int> pinnedTaskIds;

  /// 隐藏的任务聊天 (taskId -> 隐藏时间)
  final Map<int, DateTime> hiddenTaskChats;

  bool get isLoading => status == MessageStatus.loading;

  /// 展示用任务聊天列表：过滤隐藏项 + 置顶排序
  List<TaskChat> get displayTaskChats {
    // 1. 过滤：隐藏且没有新消息的聊天不显示
    final visible = taskChats.where((chat) {
      final hiddenAt = hiddenTaskChats[chat.taskId];
      if (hiddenAt == null) return true; // 未隐藏
      // 有新消息（lastMessageTime > hiddenAt）则恢复显示
      if (chat.lastMessageTime != null && chat.lastMessageTime!.isAfter(hiddenAt)) {
        return true;
      }
      return false;
    }).toList();

    // 2. 排序：置顶在前，其余按 lastMessageTime 降序
    visible.sort((a, b) {
      final aPinned = pinnedTaskIds.contains(a.taskId);
      final bPinned = pinnedTaskIds.contains(b.taskId);
      if (aPinned && !bPinned) return -1;
      if (!aPinned && bPinned) return 1;
      // 同组内按时间降序
      final aTime = a.lastMessageTime ?? DateTime(2000);
      final bTime = b.lastMessageTime ?? DateTime(2000);
      return bTime.compareTo(aTime);
    });

    return visible;
  }

  /// 总未读数（联系人 + 任务聊天）
  int get totalUnread =>
      contacts.fold(0, (sum, c) => sum + c.unreadCount) +
      taskChats.fold(0, (sum, c) => sum + c.unreadCount);

  /// 仅任务聊天未读（列表汇总）
  int get _taskChatUnreadFromList =>
      taskChats.fold(0, (sum, c) => sum + c.unreadCount);

  /// 消息 Tab 角标用：优先 API 未读数（实时），否则用列表汇总（对标 iOS）
  int get taskChatUnreadForBadge =>
      taskChatUnreadFromApi ?? _taskChatUnreadFromList;

  MessageState copyWith({
    MessageStatus? status,
    List<ChatContact>? contacts,
    List<TaskChat>? taskChats,
    int? taskChatUnreadFromApi,
    bool clearTaskChatUnreadFromApi = false,
    String? errorMessage,
    int? taskChatsPage,
    bool? hasMoreTaskChats,
    bool? isLoadingMore,
    bool? isRefreshing,
    Set<int>? pinnedTaskIds,
    Map<int, DateTime>? hiddenTaskChats,
  }) {
    return MessageState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      taskChats: taskChats ?? this.taskChats,
      taskChatUnreadFromApi: clearTaskChatUnreadFromApi ? null : (taskChatUnreadFromApi ?? this.taskChatUnreadFromApi),
      errorMessage: errorMessage,
      taskChatsPage: taskChatsPage ?? this.taskChatsPage,
      hasMoreTaskChats: hasMoreTaskChats ?? this.hasMoreTaskChats,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      pinnedTaskIds: pinnedTaskIds ?? this.pinnedTaskIds,
      hiddenTaskChats: hiddenTaskChats ?? this.hiddenTaskChats,
    );
  }

  @override
  List<Object?> get props => [
        status,
        contacts,
        taskChats,
        taskChatUnreadFromApi,
        errorMessage,
        taskChatsPage,
        hasMoreTaskChats,
        isLoadingMore,
        isRefreshing,
        pinnedTaskIds,
        hiddenTaskChats,
      ];
}

// ==================== Bloc ====================

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  MessageBloc({required MessageRepository messageRepository})
      : _messageRepository = messageRepository,
        super(const MessageState()) {
    on<MessageLoadContacts>(_onLoadContacts);
    on<MessageLoadTaskChats>(_onLoadTaskChats);
    on<MessageLoadMoreTaskChats>(_onLoadMoreTaskChats);
    on<MessageRefreshRequested>(_onRefresh);
    on<MessagePinTaskChat>(_onPinTaskChat);
    on<MessageUnpinTaskChat>(_onUnpinTaskChat);
    on<MessageHideTaskChat>(_onHideTaskChat);
    on<MessageMarkTaskChatRead>(_onMarkTaskChatRead);
    on<MessageStartPolling>(_onStartPolling);
    on<MessageStopPolling>(_onStopPolling);
    on<MessageFetchUnreadCount>(_onFetchUnreadCount);

    on<_MessageWsChatReceived>(_onWsChatReceived);

    // 对标 iOS：WebSocket 收到消息/通知时先拉未读 API 再刷新列表，角标实时更新
    // 优化：聊天消息能本地 patch 现有 TaskChat 时跳过整列表刷新，0 网络延迟更新预览/未读数
    // isClosed 守卫：cancel() 是 async，cancel 后 in-flight 事件可能仍触发 listener
    _wsSubscription = WebSocketService.instance.messageStream.listen((wsMessage) {
      if (isClosed) return;
      if (wsMessage.isChatMessage) {
        add(_MessageWsChatReceived(wsMessage));
      } else if (wsMessage.isNotification) {
        // 通知类（点赞、评论、系统等）：仅刷新未读，不重拉列表
        add(const MessageFetchUnreadCount());
      }
    });
  }

  final MessageRepository _messageRepository;
  StreamSubscription<WebSocketMessage>? _wsSubscription;
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 60);

  /// 节流：2.5 秒内不重复请求 loadTaskChats（onAppear/Tab 切换时生效，下拉刷新不节流）
  DateTime? _lastTaskChatsLoadTime;
  static const Duration _loadThrottleInterval = Duration(milliseconds: 2500);

  @override
  Future<void> close() {
    _wsSubscription?.cancel();
    _pollingTimer?.cancel();
    _pollingTimer = null;
    return super.close();
  }

  void _onStartPolling(MessageStartPolling event, Emitter<MessageState> emit) {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      // 对标 iOS 定时器：每 60 秒拉未读数量 API，角标实时
      add(const MessageFetchUnreadCount());
      add(const MessageLoadTaskChats());
    });
  }

  void _onStopPolling(MessageStopPolling event, Emitter<MessageState> emit) {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// 拉取任务聊天未读数（对标 iOS loadUnreadMessageCount：轻量 API，角标实时）
  Future<void> _onFetchUnreadCount(
    MessageFetchUnreadCount event,
    Emitter<MessageState> emit,
  ) async {
    try {
      final count = await _messageRepository.getTaskChatUnreadCount();
      if (emit.isDone) return;
      emit(state.copyWith(taskChatUnreadFromApi: count));
    } catch (e) {
      AppLogger.error('Failed to fetch task chat unread count', e);
    }
  }

  static const _pageSize = 20;
  final StorageService _storage = StorageService.instance;

  /// 从本地存储加载偏好
  void _loadPreferences(Emitter<MessageState> emit) {
    final pinned = _storage.getPinnedTaskChatIds();
    final hidden = _storage.getHiddenTaskChats();
    emit(state.copyWith(
      pinnedTaskIds: pinned,
      hiddenTaskChats: hidden,
    ));
  }

  Future<void> _onLoadContacts(
    MessageLoadContacts event,
    Emitter<MessageState> emit,
  ) async {
    if (state.status == MessageStatus.loading) return;
    final hasExistingData = state.contacts.isNotEmpty;
    if (!hasExistingData) {
      emit(state.copyWith(status: MessageStatus.loading));
    }

    try {
      final contacts = await _messageRepository.getContacts();
      emit(state.copyWith(
        status: MessageStatus.loaded,
        contacts: contacts,
      ));
    } catch (e) {
      AppLogger.error('Failed to load contacts', e);
      emit(state.copyWith(
        status: MessageStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onLoadTaskChats(
    MessageLoadTaskChats event,
    Emitter<MessageState> emit,
  ) async {
    // 节流：非强制刷新时，2.5 秒内跳过
    if (!event.forceRefresh && _lastTaskChatsLoadTime != null) {
      final elapsed = DateTime.now().difference(_lastTaskChatsLoadTime!);
      if (elapsed < _loadThrottleInterval) {
        return;
      }
    }
    _lastTaskChatsLoadTime = DateTime.now();

    if (state.status == MessageStatus.initial) {
      emit(state.copyWith(status: MessageStatus.loading));
    }

    try {
      // 同步加载本地偏好
      _loadPreferences(emit);

      final taskChats = await _messageRepository.getTaskChats();
      emit(state.copyWith(
        status: MessageStatus.loaded,
        taskChats: taskChats,
        taskChatsPage: 1,
        hasMoreTaskChats: taskChats.length >= _pageSize,
        clearTaskChatUnreadFromApi: true,
      ));
    } catch (e) {
      AppLogger.error('Failed to load task chats', e);
      if (state.status != MessageStatus.loaded) {
        emit(state.copyWith(
          status: MessageStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onLoadMoreTaskChats(
    MessageLoadMoreTaskChats event,
    Emitter<MessageState> emit,
  ) async {
    if (state.isLoadingMore || !state.hasMoreTaskChats) return;

    emit(state.copyWith(isLoadingMore: true));

    try {
      final nextPage = state.taskChatsPage + 1;
      final newTaskChats = await _messageRepository.getTaskChats(
        page: nextPage,
      );

      emit(state.copyWith(
        taskChats: [...state.taskChats, ...newTaskChats],
        taskChatsPage: nextPage,
        hasMoreTaskChats: newTaskChats.length >= _pageSize,
        isLoadingMore: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more task chats', e);
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onRefresh(
    MessageRefreshRequested event,
    Emitter<MessageState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));
    try {
      // 刷新时重新加载本地偏好
      _loadPreferences(emit);

      // contacts 仍要拉：desktop_sidebar 用 state.totalUnread（含 contacts.unreadCount）
      // 做未读红点 boolean。即使私聊已下线返回空列表，刷新后能保持角标准确。
      final contacts = await _messageRepository.getContacts();
      final taskChats = await _messageRepository.getTaskChats();
      emit(state.copyWith(
        status: MessageStatus.loaded,
        contacts: contacts,
        taskChats: taskChats,
        taskChatsPage: 1,
        hasMoreTaskChats: taskChats.length >= _pageSize,
        isRefreshing: false,
        clearTaskChatUnreadFromApi: true,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh messages', e);
      emit(state.copyWith(
        status: MessageStatus.error,
        errorMessage: e.toString(),
        isRefreshing: false,
      ));
    }
  }

  /// WebSocket 聊天消息 → 本地 patch 对应 TaskChat（命中即 0 网络延迟更新预览/未读数）
  /// 命中失败（解析异常 / 全新会话）→ 兜底走 forceRefresh 全量刷新
  Future<void> _onWsChatReceived(
    _MessageWsChatReceived event,
    Emitter<MessageState> emit,
  ) async {
    final wsMessage = event.wsMessage;
    void safeAdd(MessageEvent e) {
      if (!isClosed) add(e);
    }

    final data = wsMessage.data;
    if (data == null) {
      safeAdd(const MessageFetchUnreadCount());
      safeAdd(const MessageLoadTaskChats(forceRefresh: true));
      return;
    }

    // 解析消息体（type=task_message 时嵌套在 data['message'] 里，对齐 ChatBloc）
    final Map<String, dynamic> messageMap =
        (wsMessage.type == 'task_message' && data['message'] is Map<String, dynamic>)
            ? (data['message'] as Map<String, dynamic>)
            : data;

    Message message;
    try {
      message = Message.fromJson(messageMap);
    } catch (e) {
      AppLogger.warning('MessageBloc WS parse failed', e);
      safeAdd(const MessageFetchUnreadCount());
      safeAdd(const MessageLoadTaskChats(forceRefresh: true));
      return;
    }

    final taskId = message.taskId;
    if (taskId == null) {
      // 私聊消息（非任务聊天）目前消息列表只展示 task chats，仅刷新未读
      safeAdd(const MessageFetchUnreadCount());
      return;
    }

    // 不增 unread 的两种情况：
    //  1) 自己发的消息（state.taskChats 列表里那条卡片不应该有红点）
    //  2) 系统消息（senderId 为空字符串）— 系统消息走通知路径，不污染聊天未读
    final myUserId = _storage.getUserId();
    final isFromSelf =
        myUserId != null && myUserId.isNotEmpty && message.senderId == myUserId;
    final isSystemMessage = message.senderId.isEmpty;
    final shouldIncrementUnread = !isFromSelf && !isSystemMessage;

    // 在现有列表里找对应的 TaskChat
    final idx = state.taskChats.indexWhere((c) => c.taskId == taskId);
    if (idx < 0) {
      // 新会话 → 走全量刷新（拿出新会话的完整元数据：taskTitle/images/role 等）
      safeAdd(const MessageFetchUnreadCount());
      safeAdd(const MessageLoadTaskChats(forceRefresh: true));
      return;
    }

    final existing = state.taskChats[idx];
    final newLastObj = ChatLastMessage(
      id: message.id,
      content: message.content,
      senderId: message.senderId,
      senderName: message.senderName,
      createdAt: message.createdAt?.toIso8601String(),
    );
    final patched = existing.copyWith(
      lastMessage: message.content,
      lastMessageObj: newLastObj,
      lastMessageTime: message.createdAt ?? DateTime.now().toUtc(),
      unreadCount:
          shouldIncrementUnread ? existing.unreadCount + 1 : existing.unreadCount,
    );

    final updated = List<TaskChat>.from(state.taskChats);
    updated[idx] = patched;
    if (emit.isDone) return;
    emit(state.copyWith(taskChats: updated));

    // 角标 API 单独再拉一次（保险：本地 ++ 可能与服务端实际未读不同步）
    safeAdd(const MessageFetchUnreadCount());
  }

  // ==================== 置顶/隐藏 ====================

  Future<void> _onPinTaskChat(
    MessagePinTaskChat event,
    Emitter<MessageState> emit,
  ) async {
    await _storage.pinTaskChat(event.taskId);
    final updated = Set<int>.from(state.pinnedTaskIds)..add(event.taskId);
    emit(state.copyWith(pinnedTaskIds: updated));
  }

  Future<void> _onUnpinTaskChat(
    MessageUnpinTaskChat event,
    Emitter<MessageState> emit,
  ) async {
    await _storage.unpinTaskChat(event.taskId);
    final updated = Set<int>.from(state.pinnedTaskIds)..remove(event.taskId);
    emit(state.copyWith(pinnedTaskIds: updated));
  }

  Future<void> _onHideTaskChat(
    MessageHideTaskChat event,
    Emitter<MessageState> emit,
  ) async {
    await _storage.hideTaskChat(event.taskId);
    final updated = Map<int, DateTime>.from(state.hiddenTaskChats);
    updated[event.taskId] = DateTime.now();
    emit(state.copyWith(hiddenTaskChats: updated));
  }

  /// 本地乐观更新未读计数，再异步请求后端同步已读状态
  void _onMarkTaskChatRead(
    MessageMarkTaskChatRead event,
    Emitter<MessageState> emit,
  ) {
    final updatedChats = state.taskChats.map((chat) {
      if (chat.taskId == event.taskId && chat.unreadCount > 0) {
        return chat.copyWith(unreadCount: 0);
      }
      return chat;
    }).toList();

    if (updatedChats != state.taskChats) {
      emit(state.copyWith(taskChats: updatedChats));

      // 异步请求后端标记已读，不阻塞 UI；后端需要 uptoMessageId 或 messageIds
      TaskChat? chat;
      for (final c in state.taskChats) {
        if (c.taskId == event.taskId) {
          chat = c;
          break;
        }
      }
      final uptoId = chat?.lastMessageObj?.id;
      if (uptoId != null) {
        _messageRepository
            .markTaskChatRead(event.taskId, uptoMessageId: uptoId)
            .catchError((e) => AppLogger.warning('Failed to mark task chat read', e));
      } else {
        AppLogger.warning(
          'markTaskChatRead skipped: ${chat == null ? "no chat found" : "lastMessageObj.id is null"} for taskId=${event.taskId}',
        );
      }
    }
  }
}
