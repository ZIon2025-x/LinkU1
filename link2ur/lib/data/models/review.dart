import 'package:equatable/equatable.dart';
import 'user.dart';

/// 评价模型
class Review extends Equatable {
  const Review({
    required this.id,
    required this.taskId,
    required this.reviewerId,
    this.reviewer,
    required this.rating,
    this.comment,
    this.createdAt,
    this.isAnonymous = false,
  });

  final int id;
  final int taskId;
  final String reviewerId;
  final UserBrief? reviewer;
  final double rating;
  final String? comment;
  final DateTime? createdAt;
  final bool isAnonymous;

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      reviewerId: (json['user_id'] ?? json['reviewer_id'] ?? '').toString(),
      reviewer: json['reviewer'] != null
          ? UserBrief.fromJson(json['reviewer'] as Map<String, dynamic>)
          : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      comment: json['comment'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      isAnonymous: json['is_anonymous'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, taskId, rating, isAnonymous];
}

/// 创建评价请求
class CreateReviewRequest {
  const CreateReviewRequest({
    required this.rating,
    this.comment,
    this.isAnonymous = false,
  });

  /// 评分 0.5–5.0，支持 0.5 间隔，与后端 ReviewCreate 一致
  final double rating;
  final String? comment;
  final bool isAnonymous;

  Map<String, dynamic> toJson() {
    return {
      'rating': rating,
      if (comment != null) 'comment': comment,
      'is_anonymous': isAnonymous,
    };
  }
}
