import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../core/utils/logger.dart';
import 'home_event.dart';
import 'home_state.dart';

/// 首页Bloc
class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(const HomeState()) {
    on<HomeLoadRequested>(_onLoadRequested);
    on<HomeRefreshRequested>(_onRefreshRequested);
    on<HomeLoadRecommended>(_onLoadRecommended);
    on<HomeLoadNearby>(_onLoadNearby);
    on<HomeTabChanged>(_onTabChanged);
  }

  final TaskRepository _taskRepository;

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
      // 优先尝试推荐任务（需要认证），失败或为空则降级为公开任务列表
      TaskListResponse result;
      try {
        result = await _taskRepository.getRecommendedTasks(
          page: 1,
          pageSize: 20,
        );
      } catch (_) {
        // 未登录或认证失败时，降级到公开任务列表
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

    try {
      TaskListResponse result;
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

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: result.tasks,
        hasMoreRecommended: result.hasMore,
        recommendedPage: 1,
        isRefreshing: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh home data', e);
      emit(state.copyWith(isRefreshing: false));
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
      );

      final tasks = event.loadMore
          ? [...state.nearbyTasks, ...nearby.tasks]
          : nearby.tasks;

      emit(state.copyWith(
        status: HomeStatus.loaded,
        nearbyTasks: tasks,
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
}
