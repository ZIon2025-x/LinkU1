part of 'discover_bloc.dart';

enum DiscoverStatus { initial, loading, loaded, error }

class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.trendingSearches = const [],
    this.boards = const [],
    this.leaderboards = const [],
    this.skillCategories = const [],
    this.experts = const [],
    this.activities = const [],
    this.errorMessage,
    this.userCity,
  });

  final DiscoverStatus status;
  final List<TrendingSearchItem> trendingSearches;
  final List<ForumCategory> boards;
  final List<Leaderboard> leaderboards;
  final List<ForumCategory> skillCategories;
  final List<TaskExpert> experts;
  final List<Activity> activities;
  final String? errorMessage;
  final String? userCity;

  DiscoverState copyWith({
    DiscoverStatus? status,
    List<TrendingSearchItem>? trendingSearches,
    List<ForumCategory>? boards,
    List<Leaderboard>? leaderboards,
    List<ForumCategory>? skillCategories,
    List<TaskExpert>? experts,
    List<Activity>? activities,
    String? errorMessage,
    String? userCity,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      trendingSearches: trendingSearches ?? this.trendingSearches,
      boards: boards ?? this.boards,
      leaderboards: leaderboards ?? this.leaderboards,
      skillCategories: skillCategories ?? this.skillCategories,
      experts: experts ?? this.experts,
      activities: activities ?? this.activities,
      errorMessage: errorMessage,
      userCity: userCity ?? this.userCity,
    );
  }

  @override
  List<Object?> get props => [
    status, trendingSearches, boards, leaderboards,
    skillCategories, experts, activities, errorMessage, userCity,
  ];
}
