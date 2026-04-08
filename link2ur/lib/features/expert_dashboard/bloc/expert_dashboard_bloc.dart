import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:link2ur/data/repositories/task_expert_repository.dart';

part 'expert_dashboard_event.dart';
part 'expert_dashboard_state.dart';

class ExpertDashboardBloc
    extends Bloc<ExpertDashboardEvent, ExpertDashboardState> {
  ExpertDashboardBloc({
    required TaskExpertRepository repository,
    required this.expertId,
  })  : _repository = repository,
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
  final String expertId;

  Future<void> _onLoadStats(
    ExpertDashboardLoadStats event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.loading));
    try {
      final stats = await _repository.getExpertStats(expertId);
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
      final services = await _repository.getExpertManagedServices(expertId);
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

  /// 帮助函数: 服务列表 + stats 同步刷新,避免 stats_tab 显示陈旧的"上架服务数"
  Future<({List<Map<String, dynamic>> services, Map<String, dynamic>? stats})>
      _reloadServicesAndStats() async {
    final services = await _repository.getExpertManagedServices(expertId);
    Map<String, dynamic>? stats;
    try {
      stats = await _repository.getExpertStats(expertId);
    } catch (_) {
      // stats 失败不阻塞主流程,仍返回 services
      stats = null;
    }
    return (services: services, stats: stats);
  }

  Future<void> _onCreateService(
    ExpertDashboardCreateService event,
    Emitter<ExpertDashboardState> emit,
  ) async {
    emit(state.copyWith(status: ExpertDashboardStatus.submitting));
    try {
      await _repository.createService(expertId, event.data);
      final reloaded = await _reloadServicesAndStats();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: reloaded.services,
        stats: reloaded.stats ?? state.stats,
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
      await _repository.updateService(
          expertId, int.tryParse(event.id) ?? 0, event.data);
      final reloaded = await _reloadServicesAndStats();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: reloaded.services,
        stats: reloaded.stats ?? state.stats,
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
      await _repository.deleteService(expertId, int.tryParse(event.id) ?? 0);
      final reloaded = await _reloadServicesAndStats();
      emit(state.copyWith(
        status: ExpertDashboardStatus.loaded,
        services: reloaded.services,
        stats: reloaded.stats ?? state.stats,
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
      final timeSlots = await _repository.getExpertServiceTimeSlots(
          expertId, int.tryParse(event.serviceId) ?? 0);
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
      final serviceId = int.tryParse(event.serviceId) ?? 0;
      await _repository.createServiceTimeSlot(expertId, serviceId, event.data);
      final timeSlots =
          await _repository.getExpertServiceTimeSlots(expertId, serviceId);
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
      final serviceId = int.tryParse(event.serviceId) ?? 0;
      final slotId = int.tryParse(event.slotId) ?? 0;
      await _repository.deleteServiceTimeSlot(expertId, serviceId, slotId);
      final timeSlots =
          await _repository.getExpertServiceTimeSlots(expertId, serviceId);
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
      final closedDates = await _repository.getClosedDates(expertId);
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
      await _repository.createClosedDate(expertId, event.date,
          reason: event.reason);
      final closedDates = await _repository.getClosedDates(expertId);
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
      await _repository.deleteClosedDate(
          expertId, int.tryParse(event.id) ?? 0);
      final closedDates = await _repository.getClosedDates(expertId);
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
        expertId,
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
