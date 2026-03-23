import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/banner.dart' as app;
import '../../../data/models/task.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/common_repository.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../../data/repositories/follow_repository.dart';
import '../../../data/repositories/ticker_repository.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/logger.dart';
import 'home_event.dart';
import 'home_state.dart';

/// 首页Bloc
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required TaskRepository taskRepository,
    required ActivityRepository activityRepository,
    CommonRepository? commonRepository,
    DiscoveryRepository? discoveryRepository,
    FollowRepository? followRepository,
    TickerRepository? tickerRepository,
  })  : _taskRepository = taskRepository,
        _activityRepository = activityRepository,
        _commonRepository = commonRepository,
        _discoveryRepository = discoveryRepository,
        _followRepository = followRepository,
        _tickerRepository = tickerRepository,
        super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested);
    on<HomeRefreshRequested>(_onRefreshRequested);
    on<HomeLoadRecommended>(_onLoadRecommended);
    on<HomeLoadNearby>(_onLoadNearby);
    on<HomeTabChanged>(_onTabChanged);
    on<HomeLoadDiscoveryFeed>(_onLoadDiscoveryFeed);
    on<HomeLoadMoreDiscovery>(_onLoadMoreDiscovery);
    on<HomeRecommendedFilterChanged>(_onRecommendedFilterChanged);
    on<HomeLoadFollowFeed>(_onLoadFollowFeed);
    on<HomeLoadTicker>(_onLoadTicker);
    on<HomeLoadActivitiesList>(_onLoadActivitiesList);
    on<HomeLocationCityUpdated>(_onLocationCityUpdated);
  }

  final TaskRepository _taskRepository;
  final ActivityRepository _activityRepository;
  final CommonRepository? _commonRepository;
  final DiscoveryRepository? _discoveryRepository;
  final FollowRepository? _followRepository;
  final TickerRepository? _tickerRepository;

  /// 当前用户（由外部设置，用于权限过滤）
  User? currentUser;

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.status == HomeStatus.loading) return;

    // 对标iOS: 已有数据时不显示全屏loading（避免闪烁）
    final hasExistingData = state.recommendedTasks.isNotEmpty;
    final needsActivityLoading = state.openActivities.isEmpty;
    if (!hasExistingData || needsActivityLoading) {
      emit(state.copyWith(
        status: !hasExistingData ? HomeStatus.loading : null,
        isLoadingOpenActivities: needsActivityLoading ? true : null,
      ));
    }

    try {
      // 已登录用户尝试推荐任务，未登录直接请求公开任务列表（避免无意义的 401）
      TaskListResponse result;
      if (currentUser != null) {
        try {
          result = await _taskRepository.getRecommendedTasks(
            
          );
        } catch (_) {
          AppLogger.info('Recommendations unavailable, falling back to public tasks');
          result = await _taskRepository.getTasks(
            
          );
        }

        // 推荐为空时，降级到公开任务列表（新用户可能没有推荐数据）
        if (result.tasks.isEmpty) {
          AppLogger.info('Recommendations empty, falling back to public tasks');
          try {
            result = await _taskRepository.getTasks(
              
            );
          } catch (_) {
            // 公开任务也失败，保持空列表
          }
        }
      } else {
        // 未登录：直接请求公开任务列表
        result = await _taskRepository.getTasks(
          
        );
      }

      // 并行加载活动 + Banner（避免串行等待）
      final parallelResults = await Future.wait([
        _activityRepository.getActivities(status: 'open')
            .then((r) => r.activities)
            .catchError((_) {
          AppLogger.info('Open activities load failed, home hot section will be hidden');
          return <Activity>[];
        }),
        _commonRepository != null
            ? _commonRepository.getBanners().catchError((_) {
                AppLogger.info('Banner load failed, will show hardcoded banners only');
                return <app.Banner>[];
              })
            : Future.value(<app.Banner>[]),
      ]);
      final openList = parallelResults[0] as List<Activity>;
      final bannerList = parallelResults[1] as List<app.Banner>;

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: result.tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: 1,
        openActivities: openList,
        isLoadingOpenActivities: false,
        banners: bannerList,
      ));
    } catch (e) {
      AppLogger.error('Failed to load home data', e);
      emit(state.copyWith(isLoadingOpenActivities: false));
      // 对标iOS: 已有数据时不切换到error状态，保持显示旧数据
      if (hasExistingData) {
        AppLogger.info('Keeping existing data despite load failure');
      } else {
        emit(state.copyWith(
          status: HomeStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onRefreshRequested(
    HomeRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));

    // 下拉刷新前失效缓存，确保获取最新数据
    await CacheManager.shared.invalidateTasksCache();

    try {
      TaskListResponse result;
      if (currentUser != null) {
        try {
          result = await _taskRepository.getRecommendedTasks(
            
          );
        } catch (_) {
          result = await _taskRepository.getTasks(
            
          );
        }

        // 推荐为空时降级到公开任务
        if (result.tasks.isEmpty) {
          try {
            result = await _taskRepository.getTasks();
          } catch (e) {
            AppLogger.warning('Fallback to public tasks failed', e);
          }
        }
      } else {
        result = await _taskRepository.getTasks();
      }

      // 并行刷新活动 + Banner
      final parallelResults = await Future.wait([
        _activityRepository.getActivities(status: 'open')
            .then((r) => r.activities)
            .catchError((e) {
          AppLogger.warning('Failed to load activities for home', e);
          return <Activity>[];
        }),
        _commonRepository != null
            ? _commonRepository.getBanners().catchError((e) {
                AppLogger.warning('Failed to refresh banners', e);
                return state.banners;
              })
            : Future.value(state.banners),
      ]);
      final openList = parallelResults[0] as List<Activity>;
      final bannerList = parallelResults[1] as List<app.Banner>;

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: result.tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: 1,
        isRefreshing: false,
        openActivities: openList,
        isLoadingOpenActivities: false,
        banners: bannerList,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh home data', e);
      // 刷新失败：通知 UI 层显示 Toast，保持现有数据不变
      emit(state.copyWith(
        isRefreshing: false,
        refreshError: e.toString(),
      ));
      // 立即清除 refreshError，避免重复触发 BlocListener
      emit(state.copyWith(clearRefreshError: true));
    }
  }

  Future<void> _onLoadRecommended(
    HomeLoadRecommended event,
    Emitter<HomeState> emit,
  ) async {
    // 对标iOS: 已有数据时不显示全屏loading
    final hasExistingData = state.recommendedTasks.isNotEmpty;
    if (!event.loadMore && !hasExistingData) {
      emit(state.copyWith(status: HomeStatus.loading));
    }

    try {
      final page = event.loadMore ? state.recommendedPage + 1 : 1;

      TaskListResponse result;
      try {
        result = await _taskRepository.getRecommendedTasks(
          page: page,
        );
      } catch (_) {
        result = await _taskRepository.getTasks(
          page: page,
        );
      }

      final tasks = event.loadMore
          ? [...state.recommendedTasks, ...result.tasks]
          : result.tasks;

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: page,
      ));
    } catch (e) {
      AppLogger.error('Failed to load recommended tasks', e);
      // 已有数据时不切换到error
      if (!event.loadMore && !hasExistingData) {
        emit(state.copyWith(
          status: HomeStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<void> _onLoadNearby(
    HomeLoadNearby event,
    Emitter<HomeState> emit,
  ) async {
    final hasExistingData = state.nearbyTasks.isNotEmpty;
    if (!event.loadMore && !hasExistingData) {
      emit(state.copyWith(status: HomeStatus.loading));
    }

    try {
      final page = event.loadMore ? state.nearbyPage + 1 : 1;
      final nearby = await _taskRepository.getNearbyTasks(
        latitude: event.latitude,
        longitude: event.longitude,
        page: page,
        city: event.city,
      );

      // 为每个任务计算与用户的距离
      final tasksWithDistance = nearby.tasks.map((task) {
        if (task.latitude != null && task.longitude != null) {
          final dist = _haversineDistance(
            event.latitude, event.longitude,
            task.latitude!, task.longitude!,
          );
          return task.copyWith(distance: dist);
        }
        return task;
      }).toList();

      final allTasks = event.loadMore
          ? [...state.nearbyTasks, ...tasksWithDistance]
          : tasksWithDistance;

      // 按模糊距离区间排序（500m 为一个区间）
      // 同一区间内保持原始顺序（后端已按精确距离排序）
      allTasks.sort((a, b) {
        final aBucket = a.blurredDistanceBucket ?? 999999;
        final bBucket = b.blurredDistanceBucket ?? 999999;
        return aBucket.compareTo(bBucket);
      });

      emit(state.copyWith(
        status: HomeStatus.loaded,
        nearbyTasks: allTasks,
        hasMoreNearby: nearby.hasMore,
        nearbyPage: page,
      ));
    } catch (e) {
      AppLogger.error('Failed to load nearby tasks', e);
      if (!event.loadMore && !hasExistingData) {
        emit(state.copyWith(
          status: HomeStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  void _onTabChanged(
    HomeTabChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(currentTab: event.index));
  }

  /// Haversine 公式计算两点间距离（米）
  static double _haversineDistance(
    double lat1, double lon1, double lat2, double lon2,
  ) {
    const earthRadius = 6371000.0; // 地球半径（米）
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) * math.cos(_toRadians(lat2)) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  // ==================== Discovery Feed ====================

  Future<void> _onLoadDiscoveryFeed(
    HomeLoadDiscoveryFeed event,
    Emitter<HomeState> emit,
  ) async {
    if (_discoveryRepository == null) return;
    if (state.isLoadingDiscovery) return;

    emit(state.copyWith(isLoadingDiscovery: true));

    try {
      // 首次加载不传 seed，后端自动生成
      final response = await _discoveryRepository.getFeed();
      emit(state.copyWith(
        discoveryItems: response.items,
        hasMoreDiscovery: response.hasMore,
        discoveryPage: 1,
        discoverySeed: response.seed,
        isLoadingDiscovery: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load discovery feed', e);
      emit(state.copyWith(isLoadingDiscovery: false));
    }
  }

  Future<void> _onLoadMoreDiscovery(
    HomeLoadMoreDiscovery event,
    Emitter<HomeState> emit,
  ) async {
    if (_discoveryRepository == null) return;
    if (state.isLoadingDiscovery || !state.hasMoreDiscovery) return;

    emit(state.copyWith(isLoadingDiscovery: true));

    try {
      final nextPage = state.discoveryPage + 1;
      final response = await _discoveryRepository.getFeed(
        page: nextPage,
        seed: state.discoverySeed,
      );
      // 按 ID 去重，防止后端混排偶尔跨页重复
      final existingIds = state.discoveryItems.map((e) => e.id).toSet();
      final newItems = response.items
          .where((item) => !existingIds.contains(item.id))
          .toList();
      emit(state.copyWith(
        discoveryItems: [...state.discoveryItems, ...newItems],
        hasMoreDiscovery: response.hasMore,
        discoveryPage: nextPage,
        isLoadingDiscovery: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more discovery feed', e);
      emit(state.copyWith(isLoadingDiscovery: false));
    }
  }

  void _onRecommendedFilterChanged(
    HomeRecommendedFilterChanged event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(
      recommendedFilterCategory: event.category,
      clearRecommendedFilterCategory: event.clearCategory,
      recommendedSortBy: event.sortBy,
    ));
    // Reload data from page 1 with updated filters
    add(const HomeLoadRecommended());
  }

  // ==================== Follow Feed ====================

  Future<void> _onLoadFollowFeed(
    HomeLoadFollowFeed event,
    Emitter<HomeState> emit,
  ) async {
    if (_followRepository == null) return;
    if (state.isLoadingFollowFeed) return;
    final page = event.loadMore ? state.followFeedPage + 1 : 1;
    emit(state.copyWith(isLoadingFollowFeed: true));
    try {
      final response = await _followRepository.getFollowFeed(page: page);
      final items = event.loadMore
          ? [...state.followFeedItems, ...response.items]
          : response.items;
      emit(state.copyWith(
        followFeedItems: items,
        followFeedPage: page,
        hasMoreFollowFeed: response.hasMore,
        isLoadingFollowFeed: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingFollowFeed: false, errorMessage: e.toString()));
    }
  }

  // ==================== Ticker ====================

  Future<void> _onLoadTicker(
    HomeLoadTicker event,
    Emitter<HomeState> emit,
  ) async {
    if (_tickerRepository == null) return;
    try {
      var items = await _tickerRepository.getTicker();
      // Fallback: if backend returns empty, show default platform messages
      if (items.isEmpty) {
        items = TickerItem.defaults;
      }
      emit(state.copyWith(tickerItems: items));
    } catch (e) {
      // Ticker is non-critical — use defaults on failure
      emit(state.copyWith(tickerItems: TickerItem.defaults));
    }
  }

  // ==================== Activities List Tab ====================

  Future<void> _onLoadActivitiesList(
    HomeLoadActivitiesList event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isLoadingActivitiesList) return;
    final page = event.loadMore ? state.activitiesListPage + 1 : 1;
    emit(state.copyWith(isLoadingActivitiesList: true));
    try {
      final response = await _activityRepository.getActivities(status: 'open', page: page);
      final items = event.loadMore
          ? [...state.activitiesListItems, ...response.activities]
          : response.activities;
      emit(state.copyWith(
        activitiesListItems: items,
        activitiesListPage: page,
        hasMoreActivitiesList: response.activities.length >= 20,
        isLoadingActivitiesList: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoadingActivitiesList: false, errorMessage: e.toString()));
    }
  }

  // ==================== Location City ====================

  void _onLocationCityUpdated(
    HomeLocationCityUpdated event,
    Emitter<HomeState> emit,
  ) {
    emit(state.copyWith(locationCity: event.city));
  }
}
