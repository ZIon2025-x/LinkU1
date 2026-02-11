import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/repositories/task_repository.dart';
import '../../../core/utils/logger.dart';
import 'task_list_event.dart';
import 'task_list_state.dart';

/// 任务列表Bloc
class TaskListBloc extends Bloc<TaskListEvent, TaskListState> {
  TaskListBloc({required TaskRepository taskRepository})
      : _taskRepository = taskRepository,
        super(const TaskListState()) {
    on<TaskListLoadRequested>(_onLoadRequested);
    on<TaskListRefreshRequested>(_onRefreshRequested);
    on<TaskListLoadMore>(_onLoadMore);
    on<TaskListSearchChanged>(_onSearchChanged);
    on<TaskListCategoryChanged>(_onCategoryChanged);
    on<TaskListSortChanged>(_onSortChanged);
    on<TaskListCityChanged>(_onCityChanged);
  }

  final TaskRepository _taskRepository;

  /// 获取当前城市筛选参数，'all' 时返回 null
  String? _cityParam(String city) => city == 'all' ? null : city;

  Future<void> _onLoadRequested(
    TaskListLoadRequested event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(status: TaskListStatus.loading));

    try {
      final response = await _taskRepository.getTasks(
        page: 1,
        taskType: state.selectedCategory == 'all' ? null : state.selectedCategory,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
        sortBy: state.sortBy,
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        status: TaskListStatus.loaded,
        tasks: response.tasks,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load tasks', e);
      emit(state.copyWith(
        status: TaskListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onRefreshRequested(
    TaskListRefreshRequested event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));

    try {
      final response = await _taskRepository.getTasks(
        page: 1,
        taskType: state.selectedCategory == 'all' ? null : state.selectedCategory,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
        sortBy: state.sortBy,
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        status: TaskListStatus.loaded,
        tasks: response.tasks,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
        isRefreshing: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to refresh tasks', e);
      emit(state.copyWith(isRefreshing: false));
    }
  }

  Future<void> _onLoadMore(
    TaskListLoadMore event,
    Emitter<TaskListState> emit,
  ) async {
    if (!state.hasMore || state.isLoading) return;

    try {
      final nextPage = state.page + 1;
      final response = await _taskRepository.getTasks(
        page: nextPage,
        taskType: state.selectedCategory == 'all' ? null : state.selectedCategory,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
        sortBy: state.sortBy,
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        tasks: [...state.tasks, ...response.tasks],
        total: response.total,
        page: nextPage,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to load more tasks', e);
    }
  }

  Future<void> _onSearchChanged(
    TaskListSearchChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      searchQuery: event.query,
      status: TaskListStatus.loading,
    ));

    try {
      final response = await _taskRepository.getTasks(
        page: 1,
        taskType: state.selectedCategory == 'all' ? null : state.selectedCategory,
        keyword: event.query.isEmpty ? null : event.query,
        sortBy: state.sortBy,
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        status: TaskListStatus.loaded,
        tasks: response.tasks,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to search tasks', e);
      emit(state.copyWith(
        status: TaskListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCategoryChanged(
    TaskListCategoryChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      selectedCategory: event.category,
      status: TaskListStatus.loading,
    ));

    try {
      final response = await _taskRepository.getTasks(
        page: 1,
        taskType: event.category == 'all' ? null : event.category,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
        sortBy: state.sortBy,
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        status: TaskListStatus.loaded,
        tasks: response.tasks,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to filter tasks', e);
      emit(state.copyWith(
        status: TaskListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onSortChanged(
    TaskListSortChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      sortBy: event.sortBy,
      status: TaskListStatus.loading,
    ));

    try {
      final response = await _taskRepository.getTasks(
        page: 1,
        taskType: state.selectedCategory == 'all' ? null : state.selectedCategory,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
        sortBy: event.sortBy,
        location: _cityParam(state.selectedCity),
      );

      emit(state.copyWith(
        status: TaskListStatus.loaded,
        tasks: response.tasks,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to sort tasks', e);
      emit(state.copyWith(
        status: TaskListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> _onCityChanged(
    TaskListCityChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      selectedCity: event.city,
      status: TaskListStatus.loading,
    ));

    try {
      final response = await _taskRepository.getTasks(
        page: 1,
        taskType: state.selectedCategory == 'all' ? null : state.selectedCategory,
        keyword: state.searchQuery.isEmpty ? null : state.searchQuery,
        sortBy: state.sortBy,
        location: _cityParam(event.city),
      );

      emit(state.copyWith(
        status: TaskListStatus.loaded,
        tasks: response.tasks,
        total: response.total,
        page: 1,
        hasMore: response.hasMore,
      ));
    } catch (e) {
      AppLogger.error('Failed to filter tasks by city', e);
      emit(state.copyWith(
        status: TaskListStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }
}
