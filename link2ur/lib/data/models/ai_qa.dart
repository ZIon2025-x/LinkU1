import 'package:equatable/equatable.dart';

class AiQuestion extends Equatable {
  final int id;
  final String title;
  final String content;
  final String status;
  final DateTime? deadline;
  final DateTime? editLockAt;
  final DateTime? canceledAt;
  final DateTime? settledAt;
  final int rewardPoolPence;
  final int participationPoints;
  final int targetForumCategoryId;

  const AiQuestion({
    required this.id,
    required this.title,
    required this.content,
    required this.status,
    this.deadline,
    this.editLockAt,
    this.canceledAt,
    this.settledAt,
    required this.rewardPoolPence,
    required this.participationPoints,
    required this.targetForumCategoryId,
  });

  factory AiQuestion.fromJson(Map<String, dynamic> json) => AiQuestion(
        id: json['id'] as int,
        title: json['title'] as String,
        content: json['content'] as String,
        status: json['status'] as String,
        deadline: json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String)
            : null,
        editLockAt: json['edit_lock_at'] != null
            ? DateTime.parse(json['edit_lock_at'] as String)
            : null,
        canceledAt: json['canceled_at'] != null
            ? DateTime.parse(json['canceled_at'] as String)
            : null,
        settledAt: json['settled_at'] != null
            ? DateTime.parse(json['settled_at'] as String)
            : null,
        rewardPoolPence: json['reward_pool_pence'] as int,
        participationPoints: json['participation_points'] as int,
        targetForumCategoryId: json['target_forum_category_id'] as int,
      );

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        status,
        deadline,
        editLockAt,
        canceledAt,
        settledAt,
        rewardPoolPence,
        participationPoints,
        targetForumCategoryId,
      ];
}

class AiAnswer extends Equatable {
  final int id;
  final int forumPostId;
  final String userId;
  final String? userName;
  final String? userAvatar;
  final String? title;
  final String? content;
  final List<String>? images;
  final DateTime? createdAt;
  final bool isDeleted;
  final int? aiScore;
  final String? aiGenerated;
  final int? finalScore;
  final int? rankFinal;
  final int rewardPence;
  final bool hideInQa;

  const AiAnswer({
    required this.id,
    required this.forumPostId,
    required this.userId,
    this.userName,
    this.userAvatar,
    this.title,
    this.content,
    this.images,
    this.createdAt,
    this.isDeleted = false,
    this.aiScore,
    this.aiGenerated,
    this.finalScore,
    this.rankFinal,
    this.rewardPence = 0,
    this.hideInQa = false,
  });

  factory AiAnswer.fromJson(Map<String, dynamic> json) => AiAnswer(
        id: json['id'] as int,
        forumPostId: json['forum_post_id'] as int,
        userId: json['user_id'] as String,
        userName: json['user_name'] as String?,
        userAvatar: json['user_avatar'] as String?,
        title: json['title'] as String?,
        content: json['content'] as String?,
        images: json['images'] != null
            ? List<String>.from(json['images'] as List)
            : null,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        isDeleted: (json['is_deleted'] as bool?) ?? false,
        aiScore: json['ai_score'] as int?,
        aiGenerated: json['ai_generated'] as String?,
        finalScore: json['final_score'] as int?,
        rankFinal: json['rank_final'] as int?,
        rewardPence: (json['reward_pence'] as int?) ?? 0,
        hideInQa: (json['hide_in_qa'] as bool?) ?? false,
      );

  @override
  List<Object?> get props => [
        id,
        forumPostId,
        userId,
        content,
        isDeleted,
        aiScore,
        aiGenerated,
        finalScore,
        rankFinal,
        rewardPence,
        hideInQa,
      ];
}
