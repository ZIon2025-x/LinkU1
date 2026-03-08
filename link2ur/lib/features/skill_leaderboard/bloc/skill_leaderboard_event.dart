part of 'skill_leaderboard_bloc.dart';

// ==================== Events ====================

abstract class SkillLeaderboardEvent extends Equatable {
  const SkillLeaderboardEvent();

  @override
  List<Object?> get props => [];
}

/// Load leaderboard categories
class LeaderboardLoadRequested extends SkillLeaderboardEvent {
  const LeaderboardLoadRequested();
}

/// Select a category and load its Top 10
class LeaderboardCategorySelected extends SkillLeaderboardEvent {
  final String category;
  const LeaderboardCategorySelected(this.category);

  @override
  List<Object?> get props => [category];
}

/// Load my rank for a specific category
class LeaderboardMyRankRequested extends SkillLeaderboardEvent {
  final String category;
  const LeaderboardMyRankRequested(this.category);

  @override
  List<Object?> get props => [category];
}
