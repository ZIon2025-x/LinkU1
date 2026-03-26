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

// --- 申请者端：我的申请列表 ---
class PersonalServiceLoadMyApplications extends PersonalServiceEvent {
  const PersonalServiceLoadMyApplications({this.statusFilter});
  final String? statusFilter;
  @override
  List<Object?> get props => [statusFilter];
}

class PersonalServiceRespondCounterOffer extends PersonalServiceEvent {
  const PersonalServiceRespondCounterOffer(this.applicationId, {required this.accept});
  final int applicationId;
  final bool accept;
  @override
  List<Object?> get props => [applicationId, accept];
}

class PersonalServiceCancelApplication extends PersonalServiceEvent {
  const PersonalServiceCancelApplication(this.applicationId);
  final int applicationId;
  @override
  List<Object?> get props => [applicationId];
}

// --- 服务状态开关 ---
class PersonalServiceToggleStatus extends PersonalServiceEvent {
  const PersonalServiceToggleStatus(this.serviceId);
  final String serviceId;
  @override
  List<Object?> get props => [serviceId];
}

// --- 服务浏览 ---
class PersonalServiceBrowse extends PersonalServiceEvent {
  const PersonalServiceBrowse({
    this.type = 'all',
    this.query,
    this.sort = 'recommended',
    this.page = 1,
  });
  final String type;
  final String? query;
  final String sort;
  final int page;
  @override
  List<Object?> get props => [type, query, sort, page];
}

// --- 服务评价 ---
class PersonalServiceLoadReviews extends PersonalServiceEvent {
  const PersonalServiceLoadReviews(this.serviceId, {this.page = 1});
  final int serviceId;
  final int page;
  @override
  List<Object?> get props => [serviceId, page];
}

// ==================== State ====================
enum PersonalServiceStatus { initial, loading, loaded, error }

class PersonalServiceState extends Equatable {
  const PersonalServiceState({
    this.status = PersonalServiceStatus.initial,
    this.services = const [],
    this.receivedApplications = const [],
    this.myApplications = const [],
    this.browseResults = const [],
    this.reviews = const [],
    this.browseTotalPages = 1,
    this.reviewSummary,
    this.errorMessage,
    this.isSubmitting = false,
    this.actionMessage,
  });

  final PersonalServiceStatus status;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> receivedApplications;
  final List<Map<String, dynamic>> myApplications;
  final List<Map<String, dynamic>> browseResults;
  final List<Map<String, dynamic>> reviews;
  final int browseTotalPages;
  final Map<String, dynamic>? reviewSummary;
  final String? errorMessage;
  final bool isSubmitting;
  final String? actionMessage;

  PersonalServiceState copyWith({
    PersonalServiceStatus? status,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? receivedApplications,
    List<Map<String, dynamic>>? myApplications,
    List<Map<String, dynamic>>? browseResults,
    List<Map<String, dynamic>>? reviews,
    int? browseTotalPages,
    Map<String, dynamic>? reviewSummary,
    String? errorMessage,
    bool? isSubmitting,
    String? actionMessage,
  }) {
    return PersonalServiceState(
      status: status ?? this.status,
      services: services ?? this.services,
      receivedApplications: receivedApplications ?? this.receivedApplications,
      myApplications: myApplications ?? this.myApplications,
      browseResults: browseResults ?? this.browseResults,
      reviews: reviews ?? this.reviews,
      browseTotalPages: browseTotalPages ?? this.browseTotalPages,
      reviewSummary: reviewSummary ?? this.reviewSummary,
      errorMessage: errorMessage,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status, services, receivedApplications, myApplications,
        browseResults, reviews, browseTotalPages, reviewSummary,
        errorMessage, isSubmitting, actionMessage,
      ];
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
    on<PersonalServiceLoadMyApplications>(_onLoadMyApplications);
    on<PersonalServiceRespondCounterOffer>(_onRespondCounterOffer);
    on<PersonalServiceCancelApplication>(_onCancelApplication);
    on<PersonalServiceToggleStatus>(_onToggleStatus);
    on<PersonalServiceBrowse>(_onBrowse);
    on<PersonalServiceLoadReviews>(_onLoadReviews);
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

  // ==================== 申请者端 ====================

  Future<void> _onLoadMyApplications(
    PersonalServiceLoadMyApplications event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(status: PersonalServiceStatus.loading));
    try {
      final result = await _repository.getMyServiceApplications(
        status: event.statusFilter,
      );
      final items = (result['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      emit(state.copyWith(
        status: PersonalServiceStatus.loaded,
        myApplications: items,
      ));
    } catch (e) {
      AppLogger.error('Failed to load my applications', e);
      emit(state.copyWith(
        status: PersonalServiceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRespondCounterOffer(
    PersonalServiceRespondCounterOffer event,
    Emitter<PersonalServiceState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.respondCounterOffer(
        event.applicationId,
        accept: event.accept,
      );
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: event.accept
            ? 'counter_offer_accepted'
            : 'counter_offer_rejected',
      ));
      add(const PersonalServiceLoadMyApplications());
    } catch (e) {
      AppLogger.error('Failed to respond counter offer', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'counter_offer_respond_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCancelApplication(
    PersonalServiceCancelApplication event,
    Emitter<PersonalServiceState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      await _repository.cancelApplication(event.applicationId);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'application_cancelled',
      ));
      add(const PersonalServiceLoadMyApplications());
    } catch (e) {
      AppLogger.error('Failed to cancel application', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'cancel_application_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  // ==================== 服务状态开关 ====================

  Future<void> _onToggleStatus(
    PersonalServiceToggleStatus event,
    Emitter<PersonalServiceState> emit,
  ) async {
    if (state.isSubmitting) return;
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _repository.toggleServiceStatus(event.serviceId);
      final newStatus = result['status'] as String?;
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: newStatus == 'active'
            ? 'service_activated'
            : 'service_deactivated',
      ));
      add(const PersonalServiceLoadRequested());
    } catch (e) {
      AppLogger.error('Failed to toggle service status', e);
      emit(state.copyWith(
        isSubmitting: false,
        actionMessage: 'toggle_status_failed',
        errorMessage: e.toString(),
      ));
    }
  }

  // ==================== 服务浏览 ====================

  Future<void> _onBrowse(
    PersonalServiceBrowse event,
    Emitter<PersonalServiceState> emit,
  ) async {
    if (event.page == 1) {
      emit(state.copyWith(status: PersonalServiceStatus.loading));
    }
    try {
      final result = await _repository.browseServices(
        type: event.type,
        query: event.query,
        sort: event.sort,
        page: event.page,
      );
      final items = (result['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];
      final total = (result['total'] as num?)?.toInt() ?? 0;
      final pageSize = (result['page_size'] as num?)?.toInt() ?? 20;
      final totalPages = (total / pageSize).ceil().clamp(1, 9999);

      emit(state.copyWith(
        status: PersonalServiceStatus.loaded,
        browseResults: event.page == 1
            ? items
            : [...state.browseResults, ...items],
        browseTotalPages: totalPages,
      ));
    } catch (e) {
      AppLogger.error('Failed to browse services', e);
      emit(state.copyWith(
        status: PersonalServiceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  // ==================== 服务评价 ====================

  Future<void> _onLoadReviews(
    PersonalServiceLoadReviews event,
    Emitter<PersonalServiceState> emit,
  ) async {
    emit(state.copyWith(status: PersonalServiceStatus.loading));
    try {
      final result = await _repository.getServiceReviews(event.serviceId, page: event.page);
      final items = (result['items'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [];

      final summary = await _repository.getServiceReviewSummary(event.serviceId);
      emit(state.copyWith(
        status: PersonalServiceStatus.loaded,
        reviews: items,
        reviewSummary: summary,
      ));
    } catch (e) {
      AppLogger.error('Failed to load reviews', e);
      emit(state.copyWith(
        status: PersonalServiceStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
