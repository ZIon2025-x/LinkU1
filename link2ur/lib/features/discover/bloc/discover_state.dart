part of 'discover_bloc.dart';

enum DiscoverStatus { initial, loading, loaded, error }

enum DiscoverFeedStatus { initial, loading, loaded, error }

class DiscoverState extends Equatable {
  const DiscoverState({
    this.status = DiscoverStatus.initial,
    this.trendingSearches = const [],
    this.boards = const [],
    this.leaderboards = const [],
    this.skillCategories = const [],
    this.experts = const [],
    this.activities = const [],
    this.followedExpertIds = const {},
    this.errorMessage,
    this.userCity,
    this.communityFeedStatus = DiscoverFeedStatus.initial,
    this.communityFeedItems = const [],
    this.communityFeedPage = 1,
    this.communityFeedSeed,
    this.communityFeedHasMore = true,
  });

  final DiscoverStatus status;
  final List<TrendingSearchItem> trendingSearches;
  final List<ForumCategory> boards;
  final List<Leaderboard> leaderboards;
  final List<ForumCategory> skillCategories;
  final List<TaskExpert> experts;
  final List<Activity> activities;
  final Set<String> followedExpertIds;
  final String? errorMessage;
  final String? userCity;

  // 社区 tab 独立的 discovery feed (scope=community)
  final DiscoverFeedStatus communityFeedStatus;
  final List<DiscoveryFeedItem> communityFeedItems;
  final int communityFeedPage;
  final int? communityFeedSeed;
  final bool communityFeedHasMore;

  DiscoverState copyWith({
    DiscoverStatus? status,
    List<TrendingSearchItem>? trendingSearches,
    List<ForumCategory>? boards,
    List<Leaderboard>? leaderboards,
    List<ForumCategory>? skillCategories,
    List<TaskExpert>? experts,
    List<Activity>? activities,
    Set<String>? followedExpertIds,
    String? errorMessage,
    String? userCity,
    DiscoverFeedStatus? communityFeedStatus,
    List<DiscoveryFeedItem>? communityFeedItems,
    int? communityFeedPage,
    int? communityFeedSeed,
    bool? communityFeedHasMore,
  }) {
    return DiscoverState(
      status: status ?? this.status,
      trendingSearches: trendingSearches ?? this.trendingSearches,
      boards: boards ?? this.boards,
      leaderboards: leaderboards ?? this.leaderboards,
      skillCategories: skillCategories ?? this.skillCategories,
      experts: experts ?? this.experts,
      activities: activities ?? this.activities,
      followedExpertIds: followedExpertIds ?? this.followedExpertIds,
      errorMessage: errorMessage,
      userCity: userCity ?? this.userCity,
      communityFeedStatus: communityFeedStatus ?? this.communityFeedStatus,
      communityFeedItems: communityFeedItems ?? this.communityFeedItems,
      communityFeedPage: communityFeedPage ?? this.communityFeedPage,
      communityFeedSeed: communityFeedSeed ?? this.communityFeedSeed,
      communityFeedHasMore: communityFeedHasMore ?? this.communityFeedHasMore,
    );
  }

  @override
  List<Object?> get props => [
    status, trendingSearches, boards, leaderboards,
    skillCategories, experts, activities, followedExpertIds,
    errorMessage, userCity,
    communityFeedStatus, communityFeedItems, communityFeedPage,
    communityFeedSeed, communityFeedHasMore,
  ];
}
