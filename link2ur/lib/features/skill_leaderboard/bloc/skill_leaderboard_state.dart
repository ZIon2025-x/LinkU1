part of 'skill_leaderboard_bloc.dart';

// ==================== State ====================

enum LeaderboardStatus { initial, loading, loaded, error }

class SkillLeaderboardState extends Equatable {
  const SkillLeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.categories = const [],
    this.entries = const [],
    this.selectedCategory,
    this.myRank,
    this.errorMessage,
  });

  final LeaderboardStatus status;
  final List<SkillCategory> categories;
  final List<SkillLeaderboardEntry> entries;
  final String? selectedCategory;
  final SkillLeaderboardEntry? myRank;
  final String? errorMessage;

  bool get isLoading => status == LeaderboardStatus.loading;

  SkillLeaderboardState copyWith({
    LeaderboardStatus? status,
    List<SkillCategory>? categories,
    List<SkillLeaderboardEntry>? entries,
    String? selectedCategory,
    SkillLeaderboardEntry? myRank,
    String? errorMessage,
    bool clearError = false,
    bool clearMyRank = false,
  }) {
    return SkillLeaderboardState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      entries: entries ?? this.entries,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      myRank: clearMyRank ? null : (myRank ?? this.myRank),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        categories,
        entries,
        selectedCategory,
        myRank,
        errorMessage,
      ];
}
