import 'package:flutter_bloc/flutter_bloc.dart';

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

    emit(state.copyWith(status: HomeStatus.loading));

    try {
      final recommended = await _taskRepository.getRecommendedTasks(
        page: 1,
        pageSize: 20,
      );

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: recommended.tasks,
        hasMoreRecommended: recommended.hasMore,
        recommendedPage: 1,
      ));
    } catch (e) {
      AppLogger.error('Failed to load home data', e);
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshRequested(
    HomeRefreshRequested event,
    Emitter<HomeState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));

    try {
      final recommended = await _taskRepository.getRecommendedTasks(
        page: 1,
        pageSize: 20,
      );

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: recommended.tasks,
        hasMoreRecommended: recommended.hasMore,
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
    if (!event.loadMore) {
      emit(state.copyWith(status: HomeStatus.loading));
    }

    try {
      final page = event.loadMore ? state.recommendedPage + 1 : 1;
      final recommended = await _taskRepository.getRecommendedTasks(
        page: page,
        pageSize: 20,
      );

      final tasks = event.loadMore
          ? [...state.recommendedTasks, ...recommended.tasks]
          : recommended.tasks;

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recommendedTasks: tasks,
        hasMoreRecommended: recommended.hasMore,
        recommendedPage: page,
      ));
    } catch (e) {
      AppLogger.error('Failed to load recommended tasks', e);
      if (!event.loadMore) {
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
    if (!event.loadMore) {
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
      if (!event.loadMore) {
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
