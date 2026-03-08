import 'package:equatable/equatable.dart';

/// Skill leaderboard entry
class SkillLeaderboardEntry extends Equatable {
  final String userId;
  final String userName;
  final String? userAvatar;
  final String skillCategory;
  final int completedTasks;
  final double totalAmount;
  final double avgRating;
  final double score;
  final int rank;

  const SkillLeaderboardEntry({
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.skillCategory,
    this.completedTasks = 0,
    this.totalAmount = 0,
    this.avgRating = 0,
    this.score = 0,
    this.rank = 0,
  });

  factory SkillLeaderboardEntry.fromJson(Map<String, dynamic> json) {
    return SkillLeaderboardEntry(
      userId: json['user_id']?.toString() ?? '',
      userName: json['user_name'] as String? ?? '',
      userAvatar: json['user_avatar'] as String?,
      skillCategory: json['skill_category'] as String? ?? '',
      completedTasks: json['completed_tasks'] as int? ?? 0,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      avgRating: (json['avg_rating'] as num?)?.toDouble() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0,
      rank: json['rank'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
        'user_name': userName,
        'user_avatar': userAvatar,
        'skill_category': skillCategory,
        'completed_tasks': completedTasks,
        'total_amount': totalAmount,
        'avg_rating': avgRating,
        'score': score,
        'rank': rank,
      };

  SkillLeaderboardEntry copyWith({
    String? userId,
    String? userName,
    String? userAvatar,
    String? skillCategory,
    int? completedTasks,
    double? totalAmount,
    double? avgRating,
    double? score,
    int? rank,
  }) {
    return SkillLeaderboardEntry(
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      userAvatar: userAvatar ?? this.userAvatar,
      skillCategory: skillCategory ?? this.skillCategory,
      completedTasks: completedTasks ?? this.completedTasks,
      totalAmount: totalAmount ?? this.totalAmount,
      avgRating: avgRating ?? this.avgRating,
      score: score ?? this.score,
      rank: rank ?? this.rank,
    );
  }

  /// Rating display string
  String get ratingDisplay =>
      avgRating > 0 ? avgRating.toStringAsFixed(1) : '-';

  @override
  List<Object?> get props => [
        userId,
        userName,
        userAvatar,
        skillCategory,
        completedTasks,
        totalAmount,
        avgRating,
        score,
        rank,
      ];
}
