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
  });

  final MessageStatus status;
  final List<ChatContact> contacts;
  final List<TaskChat> taskChats;
  final String? errorMessage;

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
  }) {
    return MessageState(
      status: status ?? this.status,
      contacts: contacts ?? this.contacts,
      taskChats: taskChats ?? this.taskChats,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, contacts, taskChats, errorMessage];
}

// ==================== Bloc ====================

class MessageBloc extends Bloc<MessageEvent, MessageState> {
  MessageBloc({required MessageRepository messageRepository})
      : _messageRepository = messageRepository,
        super(const MessageState()) {
    on<MessageLoadContacts>(_onLoadContacts);
    on<MessageLoadTaskChats>(_onLoadTaskChats);
    on<MessageRefreshRequested>(_onRefresh);
  }

  final MessageRepository _messageRepository;

  Future<void> _onLoadContacts(
    MessageLoadContacts event,
    Emitter<MessageState> emit,
  ) async {
    emit(state.copyWith(status: MessageStatus.loading));

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
      final taskChats = await _messageRepository.getTaskChats();
      emit(state.copyWith(
        status: MessageStatus.loaded,
        taskChats: taskChats,
      ));
    } catch (e) {
      AppLogger.error('Failed to load task chats', e);
    }
  }

  Future<void> _onRefresh(
    MessageRefreshRequested event,
    Emitter<MessageState> emit,
  ) async {
    try {
      final contacts = await _messageRepository.getContacts();
      final taskChats = await _messageRepository.getTaskChats();
      emit(state.copyWith(
        status: MessageStatus.loaded,
        contacts: contacts,
        taskChats: taskChats,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh messages', e);
    }
  }
}
