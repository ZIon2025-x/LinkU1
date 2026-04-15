import 'package:equatable/equatable.dart';

/// Status of a [ServiceApplication].
///
/// Values mirror the backend string enum used by
/// `user_service_application_routes.py` and `schemas.ServiceApplicationOut`.
enum ServiceApplicationStatus {
  pending,
  negotiating,
  priceAgreed,
  approved,
  rejected,
  cancelled;

  static ServiceApplicationStatus fromApi(String? raw) {
    switch (raw) {
      case 'pending':
        return ServiceApplicationStatus.pending;
      case 'negotiating':
        return ServiceApplicationStatus.negotiating;
      case 'price_agreed':
        return ServiceApplicationStatus.priceAgreed;
      case 'approved':
        return ServiceApplicationStatus.approved;
      case 'rejected':
        return ServiceApplicationStatus.rejected;
      case 'cancelled':
        return ServiceApplicationStatus.cancelled;
      default:
        return ServiceApplicationStatus.pending;
    }
  }

  String get apiValue => switch (this) {
        ServiceApplicationStatus.priceAgreed => 'price_agreed',
        _ => name,
      };

  bool get isTerminal =>
      this == ServiceApplicationStatus.approved ||
      this == ServiceApplicationStatus.rejected ||
      this == ServiceApplicationStatus.cancelled;
}

/// Typed model of a personal-service / expert-service application.
///
/// Mirrors `schemas.ServiceApplicationOut` plus the JOIN fields that the
/// `user_service_application_routes` list endpoints add to the serialized
/// dict (`service_name`, `owner_name`, `applicant_name`, `applicant_avatar`).
///
/// ID fields that the backend declares as `Optional[str]`
/// (`applicant_id`, `expert_id`, `service_owner_id`) are kept as `String`
/// here; integer IDs (`id`, `service_id`, `task_id`) are `int`.
class ServiceApplication extends Equatable {
  final int id;
  final ServiceApplicationStatus status;
  final int serviceId;
  final String? serviceName;
  final String? ownerId;
  final String? ownerName;
  final String? expertId;
  final String? expertName;
  final String? applicantId;
  final String? applicantName;
  final String? applicantAvatar;
  final String? applicationMessage;
  final double? negotiatedPrice;
  final double? expertCounterPrice;
  final double? finalPrice;
  final String currency;
  final int? taskId;
  final DateTime createdAt;
  final DateTime? approvedAt;
  final DateTime? priceAgreedAt;

  const ServiceApplication({
    required this.id,
    required this.status,
    required this.serviceId,
    required this.currency,
    required this.createdAt,
    this.serviceName,
    this.ownerId,
    this.ownerName,
    this.expertId,
    this.expertName,
    this.applicantId,
    this.applicantName,
    this.applicantAvatar,
    this.applicationMessage,
    this.negotiatedPrice,
    this.expertCounterPrice,
    this.finalPrice,
    this.taskId,
    this.approvedAt,
    this.priceAgreedAt,
  });

  factory ServiceApplication.fromJson(Map<String, dynamic> json) {
    return ServiceApplication(
      id: (json['id'] as num).toInt(),
      status: ServiceApplicationStatus.fromApi(json['status'] as String?),
      serviceId: (json['service_id'] as num).toInt(),
      serviceName: json['service_name'] as String?,
      ownerId: _parseStringOrNull(json['service_owner_id']),
      ownerName: json['owner_name'] as String? ??
          json['service_owner_name'] as String?,
      expertId: _parseStringOrNull(json['expert_id']),
      expertName: json['expert_name'] as String?,
      applicantId: _parseStringOrNull(json['applicant_id']),
      applicantName: json['applicant_name'] as String?,
      applicantAvatar: json['applicant_avatar'] as String?,
      applicationMessage: json['application_message'] as String?,
      negotiatedPrice: _parseDoubleOrNull(json['negotiated_price']),
      expertCounterPrice: _parseDoubleOrNull(json['expert_counter_price']),
      finalPrice: _parseDoubleOrNull(json['final_price']),
      currency: (json['currency'] as String?) ?? 'GBP',
      taskId: _parseIntOrNull(json['task_id']),
      createdAt: DateTime.parse(json['created_at'] as String),
      approvedAt: _parseDateOrNull(json['approved_at']),
      priceAgreedAt: _parseDateOrNull(json['price_agreed_at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status.apiValue,
        'service_id': serviceId,
        'service_name': serviceName,
        'service_owner_id': ownerId,
        'owner_name': ownerName,
        'expert_id': expertId,
        'expert_name': expertName,
        'applicant_id': applicantId,
        'applicant_name': applicantName,
        'applicant_avatar': applicantAvatar,
        'application_message': applicationMessage,
        'negotiated_price': negotiatedPrice,
        'expert_counter_price': expertCounterPrice,
        'final_price': finalPrice,
        'currency': currency,
        'task_id': taskId,
        'created_at': createdAt.toIso8601String(),
        'approved_at': approvedAt?.toIso8601String(),
        'price_agreed_at': priceAgreedAt?.toIso8601String(),
      };

  ServiceApplication copyWith({
    int? id,
    ServiceApplicationStatus? status,
    int? serviceId,
    String? serviceName,
    String? ownerId,
    String? ownerName,
    String? expertId,
    String? expertName,
    String? applicantId,
    String? applicantName,
    String? applicantAvatar,
    String? applicationMessage,
    double? negotiatedPrice,
    double? expertCounterPrice,
    double? finalPrice,
    String? currency,
    int? taskId,
    DateTime? createdAt,
    DateTime? approvedAt,
    DateTime? priceAgreedAt,
  }) {
    return ServiceApplication(
      id: id ?? this.id,
      status: status ?? this.status,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      ownerId: ownerId ?? this.ownerId,
      ownerName: ownerName ?? this.ownerName,
      expertId: expertId ?? this.expertId,
      expertName: expertName ?? this.expertName,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      applicantAvatar: applicantAvatar ?? this.applicantAvatar,
      applicationMessage: applicationMessage ?? this.applicationMessage,
      negotiatedPrice: negotiatedPrice ?? this.negotiatedPrice,
      expertCounterPrice: expertCounterPrice ?? this.expertCounterPrice,
      finalPrice: finalPrice ?? this.finalPrice,
      currency: currency ?? this.currency,
      taskId: taskId ?? this.taskId,
      createdAt: createdAt ?? this.createdAt,
      approvedAt: approvedAt ?? this.approvedAt,
      priceAgreedAt: priceAgreedAt ?? this.priceAgreedAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        status,
        serviceId,
        serviceName,
        ownerId,
        ownerName,
        expertId,
        expertName,
        applicantId,
        applicantName,
        applicantAvatar,
        applicationMessage,
        negotiatedPrice,
        expertCounterPrice,
        finalPrice,
        currency,
        taskId,
        createdAt,
        approvedAt,
        priceAgreedAt,
      ];
}

int? _parseIntOrNull(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

double? _parseDoubleOrNull(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

String? _parseStringOrNull(dynamic v) {
  if (v == null) return null;
  if (v is String) return v;
  return v.toString();
}

DateTime? _parseDateOrNull(dynamic v) {
  if (v == null) return null;
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// Business rules mapping status (+ other fields) to allowed user actions.
///
/// These getters are the SINGLE source of truth for "what can happen in
/// state X" and must stay aligned with the backend in
/// `backend/app/user_service_application_routes.py`.
///
/// Kept in sync with the committed views as of 2026-04-15
/// (commits c842ade83, 2871722ae).
extension ServiceApplicationRules on ServiceApplication {
  // ---- Applicant-side rules (what the person who applied can do) ----

  /// Applicant can cancel the application.
  /// Backend allows cancel in: pending, negotiating, price_agreed.
  bool get canCancel =>
      status == ServiceApplicationStatus.pending ||
      status == ServiceApplicationStatus.negotiating ||
      status == ServiceApplicationStatus.priceAgreed;

  /// Applicant can accept/reject an owner's counter-offer.
  /// Only meaningful while negotiating AND a counter-offer exists.
  bool get canRespondCounterOffer =>
      status == ServiceApplicationStatus.negotiating &&
      expertCounterPrice != null;

  /// Applicant can navigate to the created task.
  bool get canViewTask =>
      status == ServiceApplicationStatus.approved && taskId != null;

  // ---- Owner-side rules (what the service owner can do) ----

  /// Owner can approve (creates task + payment flow).
  /// Backend allows approve in: pending, price_agreed.
  bool get canApprove =>
      status == ServiceApplicationStatus.pending ||
      status == ServiceApplicationStatus.priceAgreed;

  /// Owner can reject the application.
  /// Backend allows reject in: pending, negotiating, price_agreed.
  bool get canReject =>
      status == ServiceApplicationStatus.pending ||
      status == ServiceApplicationStatus.negotiating ||
      status == ServiceApplicationStatus.priceAgreed;

  /// Owner can send a counter-offer.
  /// Backend allows counter-offer in: pending, negotiating.
  bool get canCounterOffer =>
      status == ServiceApplicationStatus.pending ||
      status == ServiceApplicationStatus.negotiating;
}
