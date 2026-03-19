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
    this.unreadCount = 0,
    this.posterReply,
    this.posterReplyAt,
    this.taskStatus,
    this.taskTitle,
  });

  final int id;
  final int taskId;
  final String? applicantId;
  final String? applicantName;
  final String? applicantAvatar;
  final String? applicantUserLevel;
  final String status; // pending, approved, rejected, chatting
  final String? message;
  final double? proposedPrice;
  final String? currency;
  final String? createdAt;
  final int unreadCount;
  final String? posterReply;
  final String? posterReplyAt;
  final String? taskStatus; // 任务状态：open, in_progress, completed, cancelled
  final String? taskTitle;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isChatting => status == 'chatting';
  /// 任务仍在接受申请（open 状态）
  bool get isTaskOpen => taskStatus == 'open';

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
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
      posterReply: json['poster_reply'] as String?,
      posterReplyAt: json['poster_reply_at'] as String?,
      taskStatus: json['task_status'] as String?,
      taskTitle: json['task_title'] as String?,
    );
  }

  TaskApplication copyWith({
    int? id,
    int? taskId,
    String? applicantId,
    String? applicantName,
    String? applicantAvatar,
    String? applicantUserLevel,
    String? status,
    String? message,
    double? proposedPrice,
    String? currency,
    String? createdAt,
    int? unreadCount,
    String? posterReply,
    String? posterReplyAt,
    String? taskStatus,
    String? taskTitle,
  }) {
    return TaskApplication(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      applicantId: applicantId ?? this.applicantId,
      applicantName: applicantName ?? this.applicantName,
      applicantAvatar: applicantAvatar ?? this.applicantAvatar,
      applicantUserLevel: applicantUserLevel ?? this.applicantUserLevel,
      status: status ?? this.status,
      message: message ?? this.message,
      proposedPrice: proposedPrice ?? this.proposedPrice,
      currency: currency ?? this.currency,
      createdAt: createdAt ?? this.createdAt,
      unreadCount: unreadCount ?? this.unreadCount,
      posterReply: posterReply ?? this.posterReply,
      posterReplyAt: posterReplyAt ?? this.posterReplyAt,
      taskStatus: taskStatus ?? this.taskStatus,
      taskTitle: taskTitle ?? this.taskTitle,
    );
  }

  @override
  List<Object?> get props => [
        id,
        taskId,
        applicantId,
        applicantName,
        applicantAvatar,
        applicantUserLevel,
        status,
        message,
        proposedPrice,
        currency,
        createdAt,
        unreadCount,
        posterReply,
        posterReplyAt,
        taskStatus,
        taskTitle,
      ];
}
