part of 'expert_dashboard_bloc.dart';

enum ExpertDashboardStatus { initial, loading, loaded, submitting, error }

class ExpertDashboardState extends Equatable {
  const ExpertDashboardState({
    this.status = ExpertDashboardStatus.initial,
    this.stats = const {},
    this.services = const [],
    this.timeSlots = const [],
    this.closedDates = const [],
    this.selectedServiceId,
    this.errorMessage,
    this.actionMessage,
  });

  final ExpertDashboardStatus status;
  final Map<String, dynamic> stats;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> timeSlots;
  final List<Map<String, dynamic>> closedDates;
  final String? selectedServiceId;
  final String? errorMessage;
  final String? actionMessage;

  ExpertDashboardState copyWith({
    ExpertDashboardStatus? status,
    Map<String, dynamic>? stats,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? timeSlots,
    List<Map<String, dynamic>>? closedDates,
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
        selectedServiceId,
        errorMessage,
        actionMessage,
      ];
}
