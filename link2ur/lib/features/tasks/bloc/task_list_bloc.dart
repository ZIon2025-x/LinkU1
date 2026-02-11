import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/cache_manager.dart';
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

  /// 共享的任务列表请求方法，消除重复代码
  Future<void> _fetchTasks({
    required Emitter<TaskListState> emit,
    String? category,
    String? keyword,
    String? sortBy,
    String? city,
    int page = 1,
  }) async {
    try {
      final response = await _taskRepository.getTasks(
        page: page,
        taskType: category == 'all' ? null : category,
        keyword: (keyword?.isEmpty ?? true) ? null : keyword,
        sortBy: sortBy,
        location: _cityParam(city ?? state.selectedCity),
      );

      emit(state.copyWith(
        status: TaskListStatus.loaded,
        tasks: page == 1
            ? response.tasks
            : [...state.tasks, ...response.tasks],
        total: response.total,
        page: page,
        hasMore: response.hasMore,
        isRefreshing: false,
        isLoadingMore: false,
      ));
    } catch (e) {
      AppLogger.error('Failed to fetch tasks (page=$page)', e);
      // LoadMore 失败不改变整体状态，仅重置 isLoadingMore
      if (page > 1) {
        emit(state.copyWith(isLoadingMore: false));
      } else {
        emit(state.copyWith(
          status: TaskListStatus.error,
          errorMessage: e.toString(),
          isRefreshing: false,
        ));
      }
    }
  }

  Future<void> _onLoadRequested(
    TaskListLoadRequested event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(status: TaskListStatus.loading));

    await _fetchTasks(
      emit: emit,
      category: state.selectedCategory,
      keyword: state.searchQuery,
      sortBy: state.sortBy,
    );
  }

  Future<void> _onRefreshRequested(
    TaskListRefreshRequested event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(isRefreshing: true));

    // 下拉刷新前失效缓存，确保获取最新数据
    await CacheManager.shared.invalidateTasksCache();

    await _fetchTasks(
      emit: emit,
      category: state.selectedCategory,
      keyword: state.searchQuery,
      sortBy: state.sortBy,
    );
  }

  Future<void> _onLoadMore(
    TaskListLoadMore event,
    Emitter<TaskListState> emit,
  ) async {
    if (!state.hasMore || state.isLoadingMore) return;

    emit(state.copyWith(isLoadingMore: true));

    await _fetchTasks(
      emit: emit,
      category: state.selectedCategory,
      keyword: state.searchQuery,
      sortBy: state.sortBy,
      page: state.page + 1,
    );
  }

  Future<void> _onSearchChanged(
    TaskListSearchChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      searchQuery: event.query,
      status: TaskListStatus.loading,
    ));

    await _fetchTasks(
      emit: emit,
      category: state.selectedCategory,
      keyword: event.query,
      sortBy: state.sortBy,
    );
  }

  Future<void> _onCategoryChanged(
    TaskListCategoryChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      selectedCategory: event.category,
      status: TaskListStatus.loading,
    ));

    await _fetchTasks(
      emit: emit,
      category: event.category,
      keyword: state.searchQuery,
      sortBy: state.sortBy,
    );
  }

  Future<void> _onSortChanged(
    TaskListSortChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      sortBy: event.sortBy,
      status: TaskListStatus.loading,
    ));

    await _fetchTasks(
      emit: emit,
      category: state.selectedCategory,
      keyword: state.searchQuery,
      sortBy: event.sortBy,
    );
  }

  Future<void> _onCityChanged(
    TaskListCityChanged event,
    Emitter<TaskListState> emit,
  ) async {
    emit(state.copyWith(
      selectedCity: event.city,
      status: TaskListStatus.loading,
    ));

    await _fetchTasks(
      emit: emit,
      category: state.selectedCategory,
      keyword: state.searchQuery,
      sortBy: state.sortBy,
      city: event.city,
    );
  }
}
