import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';

part 'expert_dashboard_event.dart';
part 'expert_dashboard_state.dart';

class ExpertDashboardBloc
    extends Bloc<ExpertDashboardEvent, ExpertDashboardState> {
  ExpertDashboardBloc({required TaskExpertRepository repository})
      : _repository = repository,
        super(const ExpertDashboardState()) {
    on<ExpertDashboardLoadStats>(_onLoadStats);
    on<ExpertDashboardLoadMyServices>(_onLoadMyServices);
    on<ExpertDashboardCreateService>(_onCreateService);
    on<ExpertDashboardUpdateService>(_onUpdateService);
    on<ExpertDashboardDeleteService>(_onDeleteService);
    on<ExpertDashboardLoadTimeSlots>(_onLoadTimeSlots);
    on<ExpertDashboardCreateTimeSlot>(_onCreateTimeSlot);
    on<ExpertDashboardDeleteTimeSlot>(_onDeleteTimeSlot);
    on<ExpertDashboardLoadClosedDates>(_onLoadClosedDates);
    on<ExpertDashboardCreateClosedDate>(_onCreateClosedDate);
    on<ExpertDashboardDeleteClosedDate>(_onDeleteClosedDate);
    on<ExpertDashboardSubmitProfileUpdate>(_onSubmitProfileUpdate);
  }

  final TaskExpertRepository _repository;

  Future<void> _onLoadStats(
    ExpertDashboardLoadStats event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final stats = await _repository.getMyExpertStats();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        stats: stats,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_stats_failed',
      ));
    }
  }

  Future<void> _onLoadMyServices(
    ExpertDashboardLoadMyServices event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final services = await _repository.getMyServices();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_services_failed',
      ));
    }
  }

  Future<void> _onCreateService(
    ExpertDashboardCreateService event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.createService(event.data);
      final services = await _repository.getMyServices();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
        actionMessage: 'expertServiceSubmitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_create_service_failed',
      ));
    }
  }

  Future<void> _onUpdateService(
    ExpertDashboardUpdateService event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.updateService(event.id, event.data);
      final services = await _repository.getMyServices();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
        actionMessage: 'expertServiceUpdated',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_update_service_failed',
      ));
    }
  }

  Future<void> _onDeleteService(
    ExpertDashboardDeleteService event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.deleteService(event.id);
      final services = await _repository.getMyServices();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: services,
        actionMessage: 'expertServiceDeleted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_delete_service_failed',
      ));
    }
  }

  Future<void> _onLoadTimeSlots(
    ExpertDashboardLoadTimeSlots event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(
      status: ExpertDashboardStatus.loading,
      selectedServiceId: event.serviceId,
    ));
    try {
      final timeSlots =
          await _repository.getMyExpertServiceTimeSlots(event.serviceId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        timeSlots: timeSlots,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_time_slots_failed',
      ));
    }
  }

  Future<void> _onCreateTimeSlot(
    ExpertDashboardCreateTimeSlot event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.createServiceTimeSlot(event.serviceId, event.data);
      final timeSlots =
          await _repository.getMyExpertServiceTimeSlots(event.serviceId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        timeSlots: timeSlots,
        selectedServiceId: event.serviceId,
        actionMessage: 'expertTimeSlotCreated',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_create_time_slot_failed',
      ));
    }
  }

  Future<void> _onDeleteTimeSlot(
    ExpertDashboardDeleteTimeSlot event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.deleteServiceTimeSlot(event.serviceId, event.slotId);
      final timeSlots =
          await _repository.getMyExpertServiceTimeSlots(event.serviceId);
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        timeSlots: timeSlots,
        selectedServiceId: event.serviceId,
        actionMessage: 'expertTimeSlotDeleted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_delete_time_slot_failed',
      ));
    }
  }

  Future<void> _onLoadClosedDates(
    ExpertDashboardLoadClosedDates event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final closedDates = await _repository.getMyClosedDates();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        closedDates: closedDates,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_load_closed_dates_failed',
      ));
    }
  }

  Future<void> _onCreateClosedDate(
    ExpertDashboardCreateClosedDate event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.createClosedDate(event.date, reason: event.reason);
      final closedDates = await _repository.getMyClosedDates();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        closedDates: closedDates,
        actionMessage: 'expertScheduleMarkedRest',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_create_closed_date_failed',
      ));
    }
  }

  Future<void> _onDeleteClosedDate(
    ExpertDashboardDeleteClosedDate event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.deleteClosedDate(event.id);
      final closedDates = await _repository.getMyClosedDates();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        closedDates: closedDates,
        actionMessage: 'expertScheduleUnmarked',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_delete_closed_date_failed',
      ));
    }
  }

  Future<void> _onSubmitProfileUpdate(
    ExpertDashboardSubmitProfileUpdate event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.submitProfileUpdateRequest(
        name: event.name,
        bio: event.bio,
        avatarUrl: event.avatarUrl,
      );
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        actionMessage: 'expertProfileUpdateSubmitted',
      ));
    } catch (e) {
      emit(state.copyWith(
        status: ExpertDashboardStatus.error,
        errorMessage: 'expert_dashboard_submit_profile_update_failed',
      ));
    }
  }
}
