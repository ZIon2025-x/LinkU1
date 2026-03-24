import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
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

// --- 收到的申请管理 ---
class PersonalServiceLoadReceivedApplications extends PersonalServiceEvent {
  const PersonalServiceLoadReceivedApplications();
}

class PersonalServiceApproveApplication extends PersonalServiceEvent {
  const PersonalServiceApproveApplication(this.applicationId);
  final int applicationId;
  @override
  List<Object?> get props => [applicationId];
}

class PersonalServiceRejectApplication extends PersonalServiceEvent {
  const PersonalServiceRejectApplication(this.applicationId, {this.reason});
  final int applicationId;
  final String? reason;
  @override
  List<Object?> get props => [applicationId, reason];
}

class PersonalServiceCounterOffer extends PersonalServiceEvent {
  const PersonalServiceCounterOffer(
    this.applicationId, {
    required this.counterPrice,
    this.message,
  });
  final int applicationId;
  final double counterPrice;
  final String? message;
  @override
  List<Object?> get props => [applicationId, counterPrice, message];
}

// ==================== State ====================
enum PersonalServiceStatus { initial, loading, loaded, error }

class PersonalServiceState extends Equatable {
  const PersonalServiceState({
    this.status = PersonalServiceStatus.initial,
    this.services = const [],
    this.receivedApplications = const [],
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final PersonalServiceStatus status;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> receivedApplications;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  PersonalServiceState copyWith({
    PersonalServiceStatus? status,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? receivedApplications,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return PersonalServiceState(
      status: status ?? this.status,
      services: services ?? this.services,
      receivedApplications: receivedApplications ?? this.receivedApplications,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [status, services, receivedApplications, errorMessage, isSubmitting, actionMessage];
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
    on<PersonalServiceLoadReceivedApplications>(_onLoadReceivedApplications);
    on<PersonalServiceApproveApplication>(_onApproveApplication);
    on<PersonalServiceRejectApplication>(_onRejectApplication);
    on<PersonalServiceCounterOffer>(_onCounterOffer);
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

  // ==================== 收到的申请管理 ====================

  Future<void> _onLoadReceivedApplications(
    PersonalServiceLoadReceivedApplications event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(status: PersonalServiceStatus.loading));
    try {
      final result = await _repository.getReceivedApplications(limit: 100);
      final items = (result['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      emit(state.copyWith(
        status: PersonalServiceStatus.loaded,
        receivedApplications: items,
      ));
    } catch (e) {
      AppLogger.error('Failed to load received applications', e);
      emit(state.copyWith(
        status: PersonalServiceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onApproveApplication(
    PersonalServiceApproveApplication event,
    Emitter<PersonalServiceState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.approveApplication(event.applicationId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_approved',
      ));
      add(const PersonalServiceLoadReceivedApplications());
    } catch (e) {
      AppLogger.error('Failed to approve application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRejectApplication(
    PersonalServiceRejectApplication event,
    Emitter<PersonalServiceState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.rejectApplication(event.applicationId, reason: event.reason);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_rejected',
      ));
      add(const PersonalServiceLoadReceivedApplications());
    } catch (e) {
      AppLogger.error('Failed to reject application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCounterOffer(
    PersonalServiceCounterOffer event,
    Emitter<PersonalServiceState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.counterOffer(
        event.applicationId,
        counterPrice: event.counterPrice,
        message: event.message,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'counter_offer_sent',
      ));
      add(const PersonalServiceLoadReceivedApplications());
    } catch (e) {
      AppLogger.error('Failed to send counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_action_failed',
        errorMessage: e.toString(),
      ));
    }
  }
}
