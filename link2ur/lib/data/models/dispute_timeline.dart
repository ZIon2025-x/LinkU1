import 'package:equatable/equatable.dart';

/// 争议时间线响应
class DisputeTimelineResponse extends Equatable {
  const DisputeTimelineResponse({
    required this.taskId,
    required this.taskTitle,
    this.timeline = const [],
  });

  final int taskId;
  final String taskTitle;
  final List<TimelineItem> timeline;

  factory DisputeTimelineResponse.fromJson(Map<String, dynamic> json) {
    return DisputeTimelineResponse(
      taskId: json['task_id'] as int,
      taskTitle: json['task_title'] as String? ?? '',
      timeline: (json['timeline'] as List<dynamic>?)
              ?.map((e) => TimelineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  @override
  List<Object?> get props => [taskId, taskTitle, timeline];
}

/// 时间线项
class TimelineItem extends Equatable {
  const TimelineItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.timestamp,
    required this.actor,
    this.evidence,
    this.reasonType,
    this.refundType,
    this.refundAmount,
    this.status,
    this.reviewerName,
    this.resolverName,
    this.refundRequestId,
    this.disputeId,
  });

  final String id;
  final String type; // task_completed, task_confirmed, refund_request, rebuttal, admin_review, dispute, dispute_resolution
  final String title;
  final String description;
  final String? timestamp;
  final String actor; // poster, taker, admin
  final List<EvidenceItem>? evidence;
  final String? reasonType;
  final String? refundType;
  final double? refundAmount;
  final String? status;
  final String? reviewerName;
  final String? resolverName;
  final int? refundRequestId;
  final int? disputeId;

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String? ?? '';
    final timestamp = json['timestamp'] as String?;
    final refundRequestId = json['refund_request_id'] as int?;
    final disputeId = json['dispute_id'] as int?;
    final id = '${type}_${timestamp ?? ''}_${refundRequestId ?? 0}_${disputeId ?? 0}';

    return TimelineItem(
      id: id,
      type: type,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: timestamp,
      actor: json['actor'] as String? ?? '',
      evidence: (json['evidence'] as List<dynamic>?)
          ?.map((e) => EvidenceItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      reasonType: json['reason_type'] as String?,
      refundType: json['refund_type'] as String?,
      refundAmount: (json['refund_amount'] as num?)?.toDouble(),
      status: json['status'] as String?,
      reviewerName: json['reviewer_name'] as String?,
      resolverName: json['resolver_name'] as String?,
      refundRequestId: refundRequestId,
      disputeId: disputeId,
    );
  }

  @override
  List<Object?> get props => [id, type, title, timestamp];
}

/// 证据项（支持图片/文件 URL 与文字说明）
class EvidenceItem extends Equatable {
  const EvidenceItem({
    required this.id,
    required this.type,
    this.url,
    this.fileId,
    this.content,
  });

  final String id;
  final String type; // "image", "file", "text"
  final String? url;
  final String? fileId;
  final String? content;

  /// 可用于展示的 URL（图片/文件类型）
  String? get displayURL {
    if (type == 'text') return null;
    return (url != null && url!.isNotEmpty) ? url : null;
  }

  factory EvidenceItem.fromJson(Map<String, dynamic> json) {
    final fileId = json['file_id'] as String?;
    final url = json['url'] as String?;
    final content = json['content'] as String?;
    final id = fileId ?? url ?? content ?? DateTime.now().millisecondsSinceEpoch.toString();

    return EvidenceItem(
      id: id,
      type: json['type'] as String? ?? 'text',
      url: url,
      fileId: fileId,
      content: content,
    );
  }

  @override
  List<Object?> get props => [id, type, url];
}
