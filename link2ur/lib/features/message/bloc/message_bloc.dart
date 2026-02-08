import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/message.dart';
import '../../../data/repositories/message_repository.dart';
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
  });

  final MessageStatus status;
  final List<ChatContact> contacts;
  final List<TaskChat> taskChats;
  final String? errorMessage;
  final int taskChatsPage;
  final bool hasMoreTaskChats;
  final bool isLoadingMore;

  bool get isLoading => status == MessageStatus.loading;

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
  }) {
    return MessageState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      taskChats: taskChats ?? this.taskChats,
      errorMessage: errorMessage,
      taskChatsPage: taskChatsPage ?? this.taskChatsPage,
      hasMoreTaskChats: hasMoreTaskChats ?? this.hasMoreTaskChats,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
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
  }

  final MessageRepository _messageRepository;
  static const _pageSize = 20;

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
}
