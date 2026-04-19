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
    this.consultationTaskId,
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

  /// 占位咨询任务 ID。
  ///
  /// - 非空：该申请是 orig_application（关联了真实任务），占位咨询任务 ID 即此值。
  /// - null：该申请本身就是占位记录，聊天任务 ID 应使用 [taskId]。
  ///
  /// 使用 [TaskApplicationConsultationRoute.consultationMessageTaskId] 作为
  /// 统一入口，无需在调用方判断。
  final int? consultationTaskId;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
  bool get isChatting => status == 'chatting';
  bool get isConsulting => status == 'consulting';
  bool get isNegotiating => status == 'negotiating';
  bool get isPriceAgreed => status == 'price_agreed';
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
      consultationTaskId: json['consultation_task_id'] as int?,
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
    int? consultationTaskId,
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
      consultationTaskId: consultationTaskId ?? this.consultationTaskId,
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
        consultationTaskId,
      ];
}

/// 咨询路由辅助扩展：统一获取发送聊天消息时应使用的任务 ID。
///
/// - 若 [TaskApplication.consultationTaskId] 非空（orig_application），返回它。
/// - 否则回退到 [TaskApplication.taskId]（占位记录本身，咨询中或已取消）。
extension TaskApplicationConsultationRoute on TaskApplication {
  int? get consultationMessageTaskId => consultationTaskId ?? taskId;
}
