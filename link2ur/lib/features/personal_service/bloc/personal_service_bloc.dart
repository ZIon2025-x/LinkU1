import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/personal_service_repository.dart';

// ==================== Events ====================
abstract class PersonalServiceEvent extends Equatable {
  const PersonalServiceEvent();
  @override
  List<Object?> get props => [];
}

class PersonalServiceLoadRequested extends PersonalServiceEvent {
  const PersonalServiceLoadRequested();
}

class PersonalServiceCreateRequested extends PersonalServiceEvent {
  const PersonalServiceCreateRequested(this.data);
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [data];
}

class PersonalServiceUpdateRequested extends PersonalServiceEvent {
  const PersonalServiceUpdateRequested(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [id, data];
}

class PersonalServiceDeleteRequested extends PersonalServiceEvent {
  const PersonalServiceDeleteRequested(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

// ==================== State ====================
enum PersonalServiceStatus { initial, loading, loaded, error }

class PersonalServiceState extends Equatable {
  const PersonalServiceState({
    this.status = PersonalServiceStatus.initial,
    this.services = const [],
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final PersonalServiceStatus status;
  final List<Map<String, dynamic>> services;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  PersonalServiceState copyWith({
    PersonalServiceStatus? status,
    List<Map<String, dynamic>>? services,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return PersonalServiceState(
      status: status ?? this.status,
      services: services ?? this.services,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, services, errorMessage, isSubmitting, actionMessage];
}

// ==================== BLoC ====================
class PersonalServiceBloc extends Bloc<PersonalServiceEvent, PersonalServiceState> {
  PersonalServiceBloc({required PersonalServiceRepository repository})
      : _repository = repository,
        super(const PersonalServiceState()) {
    on<PersonalServiceLoadRequested>(_onLoad);
    on<PersonalServiceCreateRequested>(_onCreate);
    on<PersonalServiceUpdateRequested>(_onUpdate);
    on<PersonalServiceDeleteRequested>(_onDelete);
  }

  final PersonalServiceRepository _repository;

  Future<void> _onLoad(
    PersonalServiceLoadRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(status: PersonalServiceStatus.loading));
    try {
      final services = await _repository.getMyServices();
      emit(state.copyWith(status: PersonalServiceStatus.loaded, services: services));
    } catch (e) {
      emit(state.copyWith(
        status: PersonalServiceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCreate(
    PersonalServiceCreateRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.createService(event.data);
      emit(state.copyWith(isSubmitting: false, actionMessage: 'service_created'));
      add(const PersonalServiceLoadRequested());
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onUpdate(
    PersonalServiceUpdateRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.updateService(event.id, event.data);
      emit(state.copyWith(isSubmitting: false, actionMessage: 'service_updated'));
      add(const PersonalServiceLoadRequested());
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }

  Future<void> _onDelete(
    PersonalServiceDeleteRequested event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.deleteService(event.id);
      emit(state.copyWith(isSubmitting: false, actionMessage: 'service_deleted'));
      add(const PersonalServiceLoadRequested());
    } catch (e) {
      emit(state.copyWith(isSubmitting: false, errorMessage: e.toString()));
    }
  }
}
