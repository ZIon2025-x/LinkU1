import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/task.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/activity_repository.dart';
import '../../../data/repositories/discovery_repository.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/logger.dart';
import 'home_event.dart';
import 'home_state.dart';

/// 首页Bloc
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required TaskRepository taskRepository,
    required ActivityRepository activityRepository,
    DiscoveryRepository? discoveryRepository,
  })  : _taskRepository = taskRepository,
        _activityRepository = activityRepository,
        _discoveryRepository = discoveryRepository,
        super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested);
    on<HomeRefreshRequested>(_onRefreshRequested);
    on<HomeLoadRecommended>(_onLoadRecommended);
    on<HomeLoadNearby>(_onLoadNearby);
    on<HomeTabChanged>(_onTabChanged);
    on<HomeLoadDiscoveryFeed>(_onLoadDiscoveryFeed);
    on<HomeLoadMoreDiscovery>(_onLoadMoreDiscovery);
  }

  final TaskRepository _taskRepository;
  final ActivityRepository _activityRepository;
  final DiscoveryRepository? _discoveryRepository;

  /// 当前用户（由外部设置，用于权限过滤）
  User? currentUser;

  Future<void> _onLoadRequested(
    HomeLoadRequested event,
    Emitter<HomeState> emit,
  ) async {
    if (state.status == HomeStatus.loading) return;

    // 对标iOS: 已有数据时不显示全屏loading（避免闪烁）
    final hasExistingData = state.recommendedTasks.isNotEmpty;
    if (!hasExistingData) {
      emit(state.copyWith(status: HomeStatus.loading));
    }
    if (state.openActivities.isEmpty) {
      emit(state.copyWith(isLoadingOpenActivities: true));
    }

    try {
      // 已登录用户尝试推荐任务，未登录直接请求公开任务列表（避免无意义的 401）
      TaskListResponse result;
      if (currentUser != null) {
        try {
          result = await _taskRepository.getRecommendedTasks(
            page: 1,
            pageSize: 20,
          );
        } catch (_) {
          AppLogger.info('Recommendations unavailable, falling back to public tasks');
          result = await _taskRepository.getTasks(
            page: 1,
            pageSize: 20,
          );
        }

        // 推荐为空时，降级到公开任务列表（新用户可能没有推荐数据）
        if (result.tasks.isEmpty) {
          AppLogger.info('Recommendations empty, falling back to public tasks');
          try {
            result = await _taskRepository.getTasks(
              page: 1,
              pageSize: 20,
            );
          } catch (_) {
            // 公开任务也失败，保持空列表
          }
        }
      } else {
        // 未登录：直接请求公开任务列表
        result = await _taskRepository.getTasks(
          page: 1,
          pageSize: 20,
        );
      }

      // 并行加载开放中的活动（首页「热门活动」；无则隐藏区域）
      List<Activity> openList = [];
      try {
        final actRes = await _activityRepository.getActivities(
          page: 1,
          pageSize: 20,
          status: 'open',
        );
        openList = actRes.activities;
      } catch (_) {
        AppLogger.info('Open activities load failed, home hot section will be hidden');
      }

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: result.tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: 1,
        openActivities: openList,
        isLoadingOpenActivities: false,
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
            page: 1,
            pageSize: 20,
          );
        } catch (_) {
          result = await _taskRepository.getTasks(
            page: 1,
            pageSize: 20,
          );
        }

        // 推荐为空时降级到公开任务
        if (result.tasks.isEmpty) {
          try {
            result = await _taskRepository.getTasks(page: 1, pageSize: 20);
          } catch (_) {}
        }
      } else {
        result = await _taskRepository.getTasks(page: 1, pageSize: 20);
      }

      // 刷新开放中的活动（首页「热门活动」）
      List<Activity> openList = [];
      try {
        final actRes = await _activityRepository.getActivities(
          page: 1,
          pageSize: 20,
          status: 'open',
        );
        openList = actRes.activities;
      } catch (_) {}

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: result.tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: 1,
        isRefreshing: false,
        openActivities: openList,
        isLoadingOpenActivities: false,
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
          pageSize: 20,
        );
      } catch (_) {
        result = await _taskRepository.getTasks(
          page: page,
          pageSize: 20,
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
        pageSize: 20,
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
      final response = await _discoveryRepository.getFeed(page: 1, limit: 20);
      emit(state.copyWith(
        discoveryItems: response.items,
        hasMoreDiscovery: response.hasMore,
        discoveryPage: 1,
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
        limit: 20,
      );
      emit(state.copyWith(
        discoveryItems: [...state.discoveryItems, ...response.items],
        hasMoreDiscovery: response.hasMore,
        discoveryPage: nextPage,
        isLoadingDiscovery: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more discovery feed', e);
      emit(state.copyWith(isLoadingDiscovery: false));
    }
  }
}
