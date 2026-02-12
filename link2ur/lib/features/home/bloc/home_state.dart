import 'package:equatable/equatable.dart';

import '../../../data/models/task.dart';
import '../../../data/models/discovery_feed.dart';

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
      errorMessage: errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      refreshError: clearRefreshError ? null : (refreshError ?? this.refreshError),
      discoveryItems: discoveryItems ?? this.discoveryItems,
      isLoadingDiscovery: isLoadingDiscovery ?? this.isLoadingDiscovery,
      hasMoreDiscovery: hasMoreDiscovery ?? this.hasMoreDiscovery,
      discoveryPage: discoveryPage ?? this.discoveryPage,
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
      ];
}
