import 'package:equatable/equatable.dart';

/// 任务申请模型
class TaskApplication extends Equatable {
  const TaskApplication({
    required this.id,
    required this.taskId,
    this.applicantId,
    this.applicantName,
    this.applicantAvatar,
    this.applicantUserLevel,
    required this.status,
    this.message,
    this.proposedPrice,
    this.currency,
    this.createdAt,
  });

  final int id;
  final int taskId;
  final String? applicantId;
  final String? applicantName;
  final String? applicantAvatar;
  final String? applicantUserLevel;
  final String status; // pending, approved, rejected
  final String? message;
  final double? proposedPrice;
  final String? currency;
  final String? createdAt;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory TaskApplication.fromJson(Map<String, dynamic> json) {
    return TaskApplication(
      id: json['id'] as int,
      taskId: json['task_id'] as int? ?? 0,
      applicantId: json['applicant_id']?.toString(),
      applicantName: json['applicant_name'] as String?,
      applicantAvatar: json['applicant_avatar'] as String?,
      applicantUserLevel: json['applicant_user_level'] as String?,
      status: json['status'] as String? ?? 'pending',
      message: json['message'] as String?,
      proposedPrice: (json['negotiated_price'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      createdAt: json['created_at'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, taskId, status, proposedPrice, message];
}
