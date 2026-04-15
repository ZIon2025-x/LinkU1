part of 'expert_dashboard_bloc.dart';

abstract class ExpertDashboardEvent extends Equatable {
  const ExpertDashboardEvent();
  @override
  List<Object?> get props => [];
}

class ExpertDashboardLoadStats extends ExpertDashboardEvent {
  const ExpertDashboardLoadStats();
}

class ExpertDashboardLoadMyServices extends ExpertDashboardEvent {
  const ExpertDashboardLoadMyServices();
}

class ExpertDashboardCreateService extends ExpertDashboardEvent {
  const ExpertDashboardCreateService(this.data);
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [data];
}

class ExpertDashboardUpdateService extends ExpertDashboardEvent {
  const ExpertDashboardUpdateService(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
  @override
  List<Object?> get props => [id, data];
}

class ExpertDashboardDeleteService extends ExpertDashboardEvent {
  const ExpertDashboardDeleteService(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class ExpertDashboardLoadTimeSlots extends ExpertDashboardEvent {
  const ExpertDashboardLoadTimeSlots(this.serviceId);
  final String serviceId;
  @override
  List<Object?> get props => [serviceId];
}

class ExpertDashboardCreateTimeSlot extends ExpertDashboardEvent {
  const ExpertDashboardCreateTimeSlot(
    this.serviceId,
    this.data, {
    this.force = false,
  });
  final String serviceId;
  final Map<String, dynamic> data;
  /// 用户在"不在营业时间"确认框中点击"仍然创建"后重试时为 true
  final bool force;
  @override
  List<Object?> get props => [serviceId, data, force];
}

class ExpertDashboardDeleteTimeSlot extends ExpertDashboardEvent {
  const ExpertDashboardDeleteTimeSlot(this.serviceId, this.slotId);
  final String serviceId;
  final String slotId;
  @override
  List<Object?> get props => [serviceId, slotId];
}

class ExpertDashboardLoadClosedDates extends ExpertDashboardEvent {
  const ExpertDashboardLoadClosedDates();
}

class ExpertDashboardCreateClosedDate extends ExpertDashboardEvent {
  const ExpertDashboardCreateClosedDate(this.date, {this.reason});
  final String date;
  final String? reason;
  @override
  List<Object?> get props => [date, reason];
}

class ExpertDashboardDeleteClosedDate extends ExpertDashboardEvent {
  const ExpertDashboardDeleteClosedDate(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class ExpertDashboardLoadBusinessHours extends ExpertDashboardEvent {
  const ExpertDashboardLoadBusinessHours();
}

class ExpertDashboardUpdateBusinessHours extends ExpertDashboardEvent {
  const ExpertDashboardUpdateBusinessHours(this.hours);
  final Map<String, dynamic> hours;
  @override
  List<Object?> get props => [hours];
}

