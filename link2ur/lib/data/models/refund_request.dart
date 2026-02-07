import 'package:equatable/equatable.dart';

/// 退款申请模型
/// 参考iOS RefundRequest.swift
class RefundRequest extends Equatable {
  const RefundRequest({
    required this.id,
    required this.taskId,
    required this.posterId,
    this.reasonType,
    this.refundType,
    required this.reason,
    this.evidenceFiles,
    this.refundAmount,
    this.refundPercentage,
    required this.status,
    this.adminComment,
    this.reviewedBy,
    this.reviewedAt,
    this.refundIntentId,
    this.refundTransferId,
    this.processedAt,
    this.completedAt,
    this.rebuttalText,
    this.rebuttalEvidenceFiles,
    this.rebuttalSubmittedAt,
    this.rebuttalSubmittedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  final int id;
  final int taskId;
  final String posterId;
  final String? reasonType;
  final String? refundType; // "full" / "partial"
  final String reason;
  final List<String>? evidenceFiles;
  final double? refundAmount;
  final double? refundPercentage;
  final String status; // pending, approved, rejected, processing, completed, cancelled
  final String? adminComment;
  final String? reviewedBy;
  final String? reviewedAt;
  final String? refundIntentId;
  final String? refundTransferId;
  final String? processedAt;
  final String? completedAt;
  final String? rebuttalText;
  final List<String>? rebuttalEvidenceFiles;
  final String? rebuttalSubmittedAt;
  final String? rebuttalSubmittedBy;
  final String createdAt;
  final String updatedAt;

  /// 是否已完成
  bool get isCompleted => status == 'completed';

  /// 是否待处理
  bool get isPending => status == 'pending';

  /// 是否已有反驳
  bool get hasRebuttal =>
      rebuttalText != null && rebuttalText!.isNotEmpty;

  factory RefundRequest.fromJson(Map<String, dynamic> json) {
    return RefundRequest(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      posterId: json['poster_id'] as String? ?? '',
      reasonType: json['reason_type'] as String?,
      refundType: json['refund_type'] as String?,
      reason: json['reason'] as String? ?? '',
      evidenceFiles: (json['evidence_files'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      refundPercentage: (json['refund_percentage'] as num?)?.toDouble(),
      status: json['status'] as String? ?? 'pending',
      adminComment: json['admin_comment'] as String?,
      reviewedBy: json['reviewed_by'] as String?,
      reviewedAt: json['reviewed_at'] as String?,
      refundIntentId: json['refund_intent_id'] as String?,
      refundTransferId: json['refund_transfer_id'] as String?,
      processedAt: json['processed_at'] as String?,
      completedAt: json['completed_at'] as String?,
      rebuttalText: json['rebuttal_text'] as String?,
      rebuttalEvidenceFiles:
          (json['rebuttal_evidence_files'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList(),
      rebuttalSubmittedAt: json['rebuttal_submitted_at'] as String?,
      rebuttalSubmittedBy: json['rebuttal_submitted_by'] as String?,
      createdAt: json['created_at'] as String? ?? '',
      updatedAt: json['updated_at'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'task_id': taskId,
      'poster_id': posterId,
      'reason_type': reasonType,
      'refund_type': refundType,
      'reason': reason,
      'evidence_files': evidenceFiles,
      'refund_amount': refundAmount,
      'refund_percentage': refundPercentage,
      'status': status,
      'admin_comment': adminComment,
      'reviewed_by': reviewedBy,
      'reviewed_at': reviewedAt,
      'rebuttal_text': rebuttalText,
      'rebuttal_evidence_files': rebuttalEvidenceFiles,
      'rebuttal_submitted_at': rebuttalSubmittedAt,
      'rebuttal_submitted_by': rebuttalSubmittedBy,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  @override
  List<Object?> get props => [id, taskId, status, createdAt];
}

/// 提交反驳请求
class RefundRequestRebuttal extends Equatable {
  const RefundRequestRebuttal({
    required this.rebuttalText,
    this.evidenceFiles,
  });

  final String rebuttalText;
  final List<String>? evidenceFiles;

  Map<String, dynamic> toJson() {
    return {
      'rebuttal_text': rebuttalText,
      'evidence_files': evidenceFiles,
    };
  }

  @override
  List<Object?> get props => [rebuttalText];
}

/// 创建退款申请请求
class RefundRequestCreate extends Equatable {
  const RefundRequestCreate({
    required this.reasonType,
    required this.reason,
    required this.refundType,
    this.evidenceFiles,
    this.refundAmount,
    this.refundPercentage,
  });

  final String reasonType;
  final String reason;
  final String refundType;
  final List<String>? evidenceFiles;
  final double? refundAmount;
  final double? refundPercentage;

  Map<String, dynamic> toJson() {
    return {
      'reason_type': reasonType,
      'reason': reason,
      'refund_type': refundType,
      'evidence_files': evidenceFiles,
      'refund_amount': refundAmount,
      'refund_percentage': refundPercentage,
    };
  }

  @override
  List<Object?> get props => [reasonType, reason, refundType];
}

/// 退款原因类型
enum RefundReasonType {
  completionTimeUnsatisfactory('completion_time_unsatisfactory'),
  notCompleted('not_completed'),
  qualityIssue('quality_issue'),
  other('other');

  const RefundReasonType(this.value);
  final String value;

  static RefundReasonType fromValue(String value) {
    return RefundReasonType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => RefundReasonType.other,
    );
  }
}
