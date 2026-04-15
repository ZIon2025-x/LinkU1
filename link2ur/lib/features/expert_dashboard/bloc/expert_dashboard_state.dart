part of 'expert_dashboard_bloc.dart';

enum ExpertDashboardStatus { initial, loading, loaded, submitting, error }

class ExpertDashboardState extends Equatable {
  const ExpertDashboardState({
    this.status = ExpertDashboardStatus.initial,
    this.stats = const {},
    this.services = const [],
    this.timeSlots = const [],
    this.closedDates = const <ExpertClosedDate>[],
    this.businessHours = const {},
    this.selectedServiceId,
    this.errorMessage,
    this.actionMessage,
  });

  final ExpertDashboardStatus status;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> timeSlots;
  final List<ExpertClosedDate> closedDates;
  final Map<String, dynamic> businessHours;
  final String? selectedServiceId;
  final String? errorMessage;
  final String? actionMessage;

  ExpertDashboardState copyWith({
    ExpertDashboardStatus? status,
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? timeSlots,
    List<ExpertClosedDate>? closedDates,
    Map<String, dynamic>? businessHours,
    String? selectedServiceId,
    String? errorMessage,
    String? actionMessage,
  }) {
    return ExpertDashboardState(
      status: status ?? this.status,
      stats: stats ?? this.stats,
      services: services ?? this.services,
      timeSlots: timeSlots ?? this.timeSlots,
      closedDates: closedDates ?? this.closedDates,
      businessHours: businessHours ?? this.businessHours,
      selectedServiceId: selectedServiceId ?? this.selectedServiceId,
      errorMessage: errorMessage,
      actionMessage: actionMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        stats,
        services,
        timeSlots,
        closedDates,
        businessHours,
        selectedServiceId,
        errorMessage,
        actionMessage,
      ];
}
