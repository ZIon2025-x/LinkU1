part of 'skill_leaderboard_bloc.dart';

// ==================== State ====================

enum LeaderboardStatus { initial, loading, loaded, error }

/// 该 category 下达人列表 / 服务列表的加载状态
enum SkillSectionStatus { idle, loading, loaded, error }

class SkillLeaderboardState extends Equatable {
  const SkillLeaderboardState({
    this.status = LeaderboardStatus.initial,
    this.categories = const [],
    this.entries = const [],
    this.selectedCategory,
    this.myRank,
    this.errorMessage,
    this.experts = const [],
    this.services = const [],
    this.expertsStatus = SkillSectionStatus.idle,
    this.servicesStatus = SkillSectionStatus.idle,
  });

  final LeaderboardStatus status;
  final List<SkillCategory> categories;
  final List<SkillLeaderboardEntry> entries;
  final String? selectedCategory;
  final SkillLeaderboardEntry? myRank;
  final String? errorMessage;
  final List<TaskExpert> experts;
  final List<TaskExpertService> services;
  final SkillSectionStatus expertsStatus;
  final SkillSectionStatus servicesStatus;

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
    List<TaskExpert>? experts,
    List<TaskExpertService>? services,
    SkillSectionStatus? expertsStatus,
    SkillSectionStatus? servicesStatus,
  }) {
    return SkillLeaderboardState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      entries: entries ?? this.entries,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      myRank: clearMyRank ? null : (myRank ?? this.myRank),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      experts: experts ?? this.experts,
      services: services ?? this.services,
      expertsStatus: expertsStatus ?? this.expertsStatus,
      servicesStatus: servicesStatus ?? this.servicesStatus,
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
        experts,
        services,
        expertsStatus,
        servicesStatus,
      ];
}
