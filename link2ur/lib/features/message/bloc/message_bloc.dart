import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/message.dart';
import '../../../data/repositories/message_repository.dart';
import '../../../data/services/storage_service.dart';
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

class MessageLoadTaskChats extends MessageEvent {
  const MessageLoadTaskChats();
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

// ==================== State ====================

enum MessageStatus { initial, loading, loaded, error }

class MessageState extends Equatable {
  const MessageState({
    this.status = MessageStatus.initial,
    this.contacts = const [],
    this.taskChats = const [],
    this.errorMessage,
    this.taskChatsPage = 1,
    this.hasMoreTaskChats = true,
    this.isLoadingMore = false,
    this.pinnedTaskIds = const {},
    this.hiddenTaskChats = const {},
  });

  final MessageStatus status;
  final List<ChatContact> contacts;
  final List<TaskChat> taskChats;
  final String? errorMessage;
  final int taskChatsPage;
  final bool hasMoreTaskChats;
  final bool isLoadingMore;

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

  /// 总未读数
  int get totalUnread =>
      contacts.fold(0, (sum, c) => sum + c.unreadCount) +
      taskChats.fold(0, (sum, c) => sum + c.unreadCount);

  MessageState copyWith({
    MessageStatus? status,
    List<ChatContact>? contacts,
    List<TaskChat>? taskChats,
    String? errorMessage,
    int? taskChatsPage,
    bool? hasMoreTaskChats,
    bool? isLoadingMore,
    Set<int>? pinnedTaskIds,
    Map<int, DateTime>? hiddenTaskChats,
  }) {
    return MessageState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      taskChats: taskChats ?? this.taskChats,
      errorMessage: errorMessage,
      taskChatsPage: taskChatsPage ?? this.taskChatsPage,
      hasMoreTaskChats: hasMoreTaskChats ?? this.hasMoreTaskChats,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      pinnedTaskIds: pinnedTaskIds ?? this.pinnedTaskIds,
      hiddenTaskChats: hiddenTaskChats ?? this.hiddenTaskChats,
    );
  }

  @override
  List<Object?> get props => [
        status,
        contacts,
        taskChats,
        errorMessage,
        taskChatsPage,
        hasMoreTaskChats,
        isLoadingMore,
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
  }

  final MessageRepository _messageRepository;
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
    try {
      // 同步加载本地偏好
      _loadPreferences(emit);

      final taskChats = await _messageRepository.getTaskChats(
        page: 1,
        pageSize: _pageSize,
      );
      emit(state.copyWith(
        status: MessageStatus.loaded,
        taskChats: taskChats,
        taskChatsPage: 1,
        hasMoreTaskChats: taskChats.length >= _pageSize,
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
        pageSize: _pageSize,
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
    try {
      // 刷新时重新加载本地偏好
      _loadPreferences(emit);

      final contacts = await _messageRepository.getContacts();
      final taskChats = await _messageRepository.getTaskChats(
        page: 1,
        pageSize: _pageSize,
      );
      emit(state.copyWith(
        status: MessageStatus.loaded,
        contacts: contacts,
        taskChats: taskChats,
        taskChatsPage: 1,
        hasMoreTaskChats: taskChats.length >= _pageSize,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh messages', e);
      emit(state.copyWith(
        status: MessageStatus.error,
        errorMessage: e.toString(),
      ));
    }
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

  /// 本地将指定任务聊天的未读计数清零
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

    // 只在确实有变化时 emit
    if (updatedChats != state.taskChats) {
      emit(state.copyWith(taskChats: updatedChats));
    }
  }
}
