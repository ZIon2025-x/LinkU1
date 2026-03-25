import 'package:equatable/equatable.dart';

class TaskQuestion extends Equatable {
  const TaskQuestion({
    required this.id,
    required this.targetType,
    required this.targetId,
    required this.content,
    this.reply,
    this.replyAt,
    this.createdAt,
    this.isOwn = false,
  });

  final int id;
  final String targetType;
  final int targetId;
  final String content;
  final String? reply;
  final String? replyAt;
  final String? createdAt;
  final bool isOwn;

  bool get hasReply => reply != null && reply!.isNotEmpty;

  factory TaskQuestion.fromJson(Map<String, dynamic> json) {
    return TaskQuestion(
      id: json['id'] as int,
      targetType: json['target_type'] as String? ?? '',
      targetId: json['target_id'] as int? ?? 0,
      content: json['content'] as String? ?? '',
      reply: json['reply'] as String?,
      replyAt: json['reply_at'] as String?,
      createdAt: json['created_at'] as String?,
      isOwn: json['is_own'] as bool? ?? false,
    );
  }

  TaskQuestion copyWith({
    int? id,
    String? targetType,
    int? targetId,
    String? content,
    String? reply,
    String? replyAt,
    String? createdAt,
    bool? isOwn,
  }) {
    return TaskQuestion(
      id: id ?? this.id,
      targetType: targetType ?? this.targetType,
      targetId: targetId ?? this.targetId,
      content: content ?? this.content,
      reply: reply ?? this.reply,
      replyAt: replyAt ?? this.replyAt,
      createdAt: createdAt ?? this.createdAt,
      isOwn: isOwn ?? this.isOwn,
    );
  }

  @override
  List<Object?> get props => [id, targetType, targetId, content, reply, replyAt, createdAt, isOwn];
}
