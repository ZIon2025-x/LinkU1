import 'dart:math' as math;

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/task.dart';
import '../../../data/models/user.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../../../data/repositories/flea_market_repository.dart';
import '../../../data/repositories/leaderboard_repository.dart';
import '../../../core/utils/cache_manager.dart';
import '../../../core/utils/logger.dart';
import '../../../core/utils/forum_permission_helper.dart';
import 'home_event.dart';
import 'home_state.dart';

/// 首页Bloc
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    required TaskRepository taskRepository,
    ForumRepository? forumRepository,
    FleaMarketRepository? fleaMarketRepository,
    LeaderboardRepository? leaderboardRepository,
  })  : _taskRepository = taskRepository,
        _forumRepository = forumRepository,
        _fleaMarketRepository = fleaMarketRepository,
        _leaderboardRepository = leaderboardRepository,
        super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested);
    on<HomeRefreshRequested>(_onRefreshRequested);
    on<HomeLoadRecommended>(_onLoadRecommended);
    on<HomeLoadNearby>(_onLoadNearby);
    on<HomeTabChanged>(_onTabChanged);
    on<HomeLoadRecentActivities>(_onLoadRecentActivities);
  }

  final TaskRepository _taskRepository;
  final ForumRepository? _forumRepository;
  final FleaMarketRepository? _fleaMarketRepository;
  final LeaderboardRepository? _leaderboardRepository;

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

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: result.tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: 1,
      ));
    } catch (e) {
      AppLogger.error('Failed to load home data', e);
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

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: result.tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: 1,
        isRefreshing: false,
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

  /// 加载最新动态（对标 iOS RecentActivityViewModel）
  ///
  /// 并行获取三个数据源：
  /// 1. 论坛帖子（按可见板块过滤）
  /// 2. 跳蚤市场商品（仅 active 状态）
  /// 3. 排行榜（仅 active 状态）
  /// 然后合并、去重、按时间排序
  Future<void> _onLoadRecentActivities(
    HomeLoadRecentActivities event,
    Emitter<HomeState> emit,
  ) async {
    if (state.isLoadingActivities) return;

    emit(state.copyWith(isLoadingActivities: true));

    try {
      // 并行获取三个数据源（对标 iOS Publishers.Zip3）
      // 使用独立 try-catch 包裹每个源，避免一个失败导致全部失败
      final results = await Future.wait([
        _fetchForumActivities().catchError((_) => <RecentActivityItem>[]),
        _fetchFleaMarketActivities().catchError((_) => <RecentActivityItem>[]),
        _fetchLeaderboardActivities().catchError((_) => <RecentActivityItem>[]),
      ]);

      // 合并所有动态（部分数据源失败时仍显示可用数据）
      final allActivities = <RecentActivityItem>[];
      for (final list in results) {
        allActivities.addAll(list);
      }

      // 去重（按 id）
      final seenIds = <String>{};
      final uniqueActivities = <RecentActivityItem>[];
      for (final activity in allActivities) {
        if (seenIds.add(activity.id)) {
          uniqueActivities.add(activity);
        }
      }

      // 按时间排序（最新在前，对标 iOS sorted { $0.createdAt > $1.createdAt }）
      uniqueActivities.sort((a, b) {
        final aTime = a.createdAt ?? DateTime(2000);
        final bTime = b.createdAt ?? DateTime(2000);
        return bTime.compareTo(aTime);
      });

      // 最多显示 15 条（对标 iOS maxDisplayCount = 15）
      final activities = uniqueActivities.take(15).toList();

      emit(state.copyWith(
        recentActivities: activities,
        isLoadingActivities: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to load recent activities', e);
      emit(state.copyWith(isLoadingActivities: false));
    }
  }

  /// 获取论坛帖子动态（按权限过滤可见板块）
  Future<List<RecentActivityItem>> _fetchForumActivities() async {
    if (_forumRepository == null) return [];

    try {
      // 1. 获取可见板块（后端已按用户权限过滤）
      final visibleCategories =
          await _forumRepository.getVisibleCategories();

      // 2. 客户端兜底过滤，获取可见板块 ID 集合
      final visibleIds = ForumPermissionHelper.getVisibleCategoryIds(
        visibleCategories,
        currentUser,
      );

      // 3. 获取最新帖子
      final postResponse = await _forumRepository.getPosts(
        page: 1,
        pageSize: 20,
        sortBy: 'latest',
      );

      // 4. 过滤：只保留可见板块内的帖子
      final filteredPosts = visibleIds.isNotEmpty
          ? ForumPermissionHelper.filterPostsByVisibleCategories(
              postResponse.posts,
              visibleIds,
            )
          : postResponse.posts;

      return filteredPosts
          .map((post) => RecentActivityItem.fromForumPost(post))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to fetch forum activities', e);
      return [];
    }
  }

  /// 获取跳蚤市场动态（仅 active 状态，对标 iOS item.status == "active"）
  Future<List<RecentActivityItem>> _fetchFleaMarketActivities() async {
    if (_fleaMarketRepository == null) return [];

    try {
      final response = await _fleaMarketRepository.getItems(
        page: 1,
        pageSize: 20,
      );

      return response.items
          .where((item) => item.isActive) // 只包含在售商品
          .map((item) => RecentActivityItem.fromFleaMarketItem(item))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to fetch flea market activities', e);
      return [];
    }
  }

  /// 获取排行榜动态（仅 active 状态，对标 iOS leaderboard.status == "active"）
  Future<List<RecentActivityItem>> _fetchLeaderboardActivities() async {
    if (_leaderboardRepository == null) return [];

    try {
      final response = await _leaderboardRepository.getLeaderboards(
        page: 1,
        pageSize: 20,
      );

      return response.leaderboards
          .where((lb) => lb.isActive) // 只包含活跃排行榜
          .map((lb) => RecentActivityItem.fromLeaderboard(lb))
          .toList();
    } catch (e) {
      AppLogger.error('Failed to fetch leaderboard activities', e);
      return [];
    }
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
}
