import 'package:equatable/equatable.dart';
import 'user.dart';

/// 评价模型
class Review extends Equatable {
  const Review({
    required this.id,
    required this.taskId,
    required this.reviewerId,
    this.reviewer,
    required this.revieweeId,
    this.reviewee,
    required this.rating,
    this.comment,
    this.tags = const [],
    this.createdAt,
  });

  final int id;
  final int taskId;
  final int reviewerId;
  final UserBrief? reviewer;
  final int revieweeId;
  final UserBrief? reviewee;
  final double rating; // 1-5
  final String? comment;
  final List<String> tags; // e.g., "准时", "高效", "友善"
  final DateTime? createdAt;

  /// 评分星级描述
  String get ratingText {
    if (rating >= 4.5) return '非常好';
    if (rating >= 3.5) return '好';
    if (rating >= 2.5) return '一般';
    if (rating >= 1.5) return '差';
    return '很差';
  }

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id'] as int,
      taskId: json['task_id'] as int? ?? 0,
      reviewerId: json['reviewer_id'] as int? ?? 0,
      reviewer: json['reviewer'] != null
          ? UserBrief.fromJson(json['reviewer'] as Map<String, dynamic>)
          : null,
      revieweeId: json['reviewee_id'] as int? ?? 0,
      reviewee: json['reviewee'] != null
          ? UserBrief.fromJson(json['reviewee'] as Map<String, dynamic>)
          : null,
      rating: (json['rating'] as num?)?.toDouble() ?? 0,
      comment: json['comment'] as String?,
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'rating': rating,
      if (comment != null) 'comment': comment,
      'tags': tags,
    };
  }

  @override
  List<Object?> get props => [id, taskId, reviewerId, rating];
}

/// 创建评价请求
class CreateReviewRequest {
  const CreateReviewRequest({
    required this.taskId,
    required this.rating,
    this.comment,
    this.tags = const [],
  });

  final int taskId;
  final double rating;
  final String? comment;
  final List<String> tags;

  Map<String, dynamic> toJson() {
    return {
      'task_id': taskId,
      'rating': rating,
      if (comment != null) 'comment': comment,
      'tags': tags,
    };
  }
}
