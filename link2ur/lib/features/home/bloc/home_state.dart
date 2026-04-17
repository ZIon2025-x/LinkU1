import 'package:equatable/equatable.dart';

import '../../../data/models/banner.dart' as app;
import '../../../data/models/task.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/discovery_feed.dart';
import '../../../data/models/trending_search.dart';
import '../../../data/repositories/ticker_repository.dart';

/// 首页状态
enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  const HomeState({
    this.status = HomeStatus.initial,
    this.recommendedTasks = const [],
    this.nearbyTasks = const [],
    this.currentTab = 0,
    this.hasMoreRecommended = true,
    this.hasMoreNearby = true,
    this.recommendedPage = 1,
    this.nearbyPage = 1,
    this.errorMessage,
    this.isRefreshing = false,
    this.refreshError,
    this.discoveryItems = const [],
    this.isLoadingDiscovery = false,
    this.hasMoreDiscovery = true,
    this.discoveryPage = 1,
    this.discoverySeed,
    this.openActivities = const [],
    this.isLoadingOpenActivities = false,
    this.banners = const [],
    this.recommendedFilterCategory,
    this.recommendedSortBy = 'latest',
    this.followFeedItems = const [],
    this.isLoadingFollowFeed = false,
    this.hasMoreFollowFeed = true,
    this.followFeedPage = 0,
    this.tickerItems = const [],
    this.activitiesListItems = const [],
    this.isLoadingActivitiesList = false,
    this.hasMoreActivitiesList = true,
    this.activitiesListPage = 0,
    this.locationCity,
    this.nearbyServices = const [],
    this.nearbyRadius = 5,
    this.isLoadingNearby = false,
    this.nearbyServicesPage = 1,
    this.hasMoreNearbyServices = true,
    this.trendingSearches = const [],
  });

  final HomeStatus status;
  final List<Task> recommendedTasks;
  final List<Task> nearbyTasks;
  final int currentTab;
  final bool hasMoreRecommended;
  final bool hasMoreNearby;
  final int recommendedPage;
  final int nearbyPage;
  final String? errorMessage;
  final bool isRefreshing;
  /// 刷新失败错误信息，用于 UI 层通过 BlocListener 显示 Toast
  final String? refreshError;

  // Discovery Feed
  final List<DiscoveryFeedItem> discoveryItems;
  final bool isLoadingDiscovery;
  final bool hasMoreDiscovery;
  final int discoveryPage;
  /// 后端返回的随机种子，翻页时回传保证排序一致
  final int? discoverySeed;

  /// 开放中的活动（首页「热门活动」用；空则隐藏区域）
  final List<Activity> openActivities;
  final bool isLoadingOpenActivities;

  /// 轮播 Banner（后端 + 硬编码合并）
  final List<app.Banner> banners;

  /// 推荐任务客户端筛选：类别（null = 全部）
  final String? recommendedFilterCategory;
  /// 推荐任务客户端排序：latest / highest_pay / near_deadline
  final String recommendedSortBy;

  // Follow feed
  final List<DiscoveryFeedItem> followFeedItems;
  final bool isLoadingFollowFeed;
  final bool hasMoreFollowFeed;
  final int followFeedPage;

  // Ticker
  final List<TickerItem> tickerItems;

  // Activities list tab
  final List<Activity> activitiesListItems;
  final bool isLoadingActivitiesList;
  final bool hasMoreActivitiesList;
  final int activitiesListPage;

  /// GPS 反向地理编码得到的城市名（左上角显示）
  final String? locationCity;

  /// 附近的个人服务列表
  final List<Map<String, dynamic>> nearbyServices;
  /// 附近服务搜索半径（km）
  final int nearbyRadius;
  /// 附近数据加载中（切换半径时不清空已有数据）
  final bool isLoadingNearby;
  final int nearbyServicesPage;
  final bool hasMoreNearbyServices;

  /// 热搜榜数据
  final List<TrendingSearchItem> trendingSearches;

  bool get isLoading => status == HomeStatus.loading;
  bool get isLoaded => status == HomeStatus.loaded;
  bool get hasError => status == HomeStatus.error;

  HomeState copyWith({
    HomeStatus? status,
    List<Task>? recommendedTasks,
    List<Task>? nearbyTasks,
    int? currentTab,
    bool? hasMoreRecommended,
    bool? hasMoreNearby,
    int? recommendedPage,
    int? nearbyPage,
    String? errorMessage,
    bool? isRefreshing,
    String? refreshError,
    bool clearRefreshError = false,
    List<DiscoveryFeedItem>? discoveryItems,
    bool? isLoadingDiscovery,
    bool? hasMoreDiscovery,
    int? discoveryPage,
    int? discoverySeed,
    List<Activity>? openActivities,
    bool? isLoadingOpenActivities,
    List<app.Banner>? banners,
    String? recommendedFilterCategory,
    bool clearRecommendedFilterCategory = false,
    String? recommendedSortBy,
    List<DiscoveryFeedItem>? followFeedItems,
    bool? isLoadingFollowFeed,
    bool? hasMoreFollowFeed,
    int? followFeedPage,
    List<TickerItem>? tickerItems,
    List<Activity>? activitiesListItems,
    bool? isLoadingActivitiesList,
    bool? hasMoreActivitiesList,
    int? activitiesListPage,
    String? locationCity,
    List<Map<String, dynamic>>? nearbyServices,
    int? nearbyRadius,
    bool? isLoadingNearby,
    int? nearbyServicesPage,
    bool? hasMoreNearbyServices,
    List<TrendingSearchItem>? trendingSearches,
  }) {
    return HomeState(
      status: status ?? this.status,
      recommendedTasks: recommendedTasks ?? this.recommendedTasks,
      nearbyTasks: nearbyTasks ?? this.nearbyTasks,
      currentTab: currentTab ?? this.currentTab,
      hasMoreRecommended: hasMoreRecommended ?? this.hasMoreRecommended,
      hasMoreNearby: hasMoreNearby ?? this.hasMoreNearby,
      recommendedPage: recommendedPage ?? this.recommendedPage,
      nearbyPage: nearbyPage ?? this.nearbyPage,
      errorMessage: errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshError: clearRefreshError ? null : (refreshError ?? this.refreshError),
      discoveryItems: discoveryItems ?? this.discoveryItems,
      isLoadingDiscovery: isLoadingDiscovery ?? this.isLoadingDiscovery,
      hasMoreDiscovery: hasMoreDiscovery ?? this.hasMoreDiscovery,
      discoveryPage: discoveryPage ?? this.discoveryPage,
      discoverySeed: discoverySeed ?? this.discoverySeed,
      openActivities: openActivities ?? this.openActivities,
      isLoadingOpenActivities: isLoadingOpenActivities ?? this.isLoadingOpenActivities,
      banners: banners ?? this.banners,
      recommendedFilterCategory: clearRecommendedFilterCategory
          ? null
          : (recommendedFilterCategory ?? this.recommendedFilterCategory),
      recommendedSortBy: recommendedSortBy ?? this.recommendedSortBy,
      followFeedItems: followFeedItems ?? this.followFeedItems,
      isLoadingFollowFeed: isLoadingFollowFeed ?? this.isLoadingFollowFeed,
      hasMoreFollowFeed: hasMoreFollowFeed ?? this.hasMoreFollowFeed,
      followFeedPage: followFeedPage ?? this.followFeedPage,
      tickerItems: tickerItems ?? this.tickerItems,
      activitiesListItems: activitiesListItems ?? this.activitiesListItems,
      isLoadingActivitiesList: isLoadingActivitiesList ?? this.isLoadingActivitiesList,
      hasMoreActivitiesList: hasMoreActivitiesList ?? this.hasMoreActivitiesList,
      activitiesListPage: activitiesListPage ?? this.activitiesListPage,
      locationCity: locationCity ?? this.locationCity,
      nearbyServices: nearbyServices ?? this.nearbyServices,
      nearbyRadius: nearbyRadius ?? this.nearbyRadius,
      isLoadingNearby: isLoadingNearby ?? this.isLoadingNearby,
      nearbyServicesPage: nearbyServicesPage ?? this.nearbyServicesPage,
      hasMoreNearbyServices: hasMoreNearbyServices ?? this.hasMoreNearbyServices,
      trendingSearches: trendingSearches ?? this.trendingSearches,
    );
  }

  @override
  List<Object?> get props => [
        status,
        recommendedTasks,
        nearbyTasks,
        currentTab,
        hasMoreRecommended,
        hasMoreNearby,
        recommendedPage,
        nearbyPage,
        errorMessage,
        isRefreshing,
        refreshError,
        discoveryItems,
        isLoadingDiscovery,
        hasMoreDiscovery,
        discoveryPage,
        discoverySeed,
        openActivities,
        isLoadingOpenActivities,
        banners,
        recommendedFilterCategory,
        recommendedSortBy,
        followFeedItems,
        isLoadingFollowFeed,
        hasMoreFollowFeed,
        followFeedPage,
        tickerItems,
        activitiesListItems,
        isLoadingActivitiesList,
        hasMoreActivitiesList,
        activitiesListPage,
        locationCity,
        nearbyServices,
        nearbyRadius,
        isLoadingNearby,
        nearbyServicesPage,
        hasMoreNearbyServices,
        trendingSearches,
      ];
}
