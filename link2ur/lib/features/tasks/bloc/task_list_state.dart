import 'package:equatable/equatable.dart';

import '../../../data/models/task.dart';

/// 任务列表状态
enum TaskListStatus { initial, loading, loaded, error }

class TaskListState extends Equatable {
  const TaskListState({
    this.status = TaskListStatus.initial,
    this.tasks = const [],
    this.total = 0,
    this.page = 1,
    this.hasMore = true,
    this.selectedCategory = 'all',
    this.selectedCity = 'all',
    this.searchQuery = '',
    this.sortBy = 'latest',
    this.errorMessage,
    this.isRefreshing = false,
    this.isLoadingMore = false,
  });

  final TaskListStatus status;
  final List<Task> tasks;
  final int total;
  final int page;
  final bool hasMore;
  final String selectedCategory;

  /// 选中的城市筛选，'all' 表示全部城市
  final String selectedCity;
  final String searchQuery;
  final String sortBy;
  final String? errorMessage;
  final bool isRefreshing;

  /// 是否正在加载更多（防止快速滚动触发多次 LoadMore）
  final bool isLoadingMore;

  bool get isLoading => status == TaskListStatus.loading;
  bool get isLoaded => status == TaskListStatus.loaded;
  bool get hasError => status == TaskListStatus.error;
  bool get isEmpty => tasks.isEmpty && isLoaded;

  /// 当前是否有激活的筛选条件（排序非默认 或 城市非全部）
  bool get hasActiveFilters => sortBy != 'latest' || selectedCity != 'all';

  TaskListState copyWith({
    TaskListStatus? status,
    List<Task>? tasks,
    int? total,
    int? page,
    bool? hasMore,
    String? selectedCategory,
    String? selectedCity,
    String? searchQuery,
    String? sortBy,
    String? errorMessage,
    bool? isRefreshing,
    bool? isLoadingMore,
  }) {
    return TaskListState(
      status: status ?? this.status,
      tasks: tasks ?? this.tasks,
      total: total ?? this.total,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      selectedCity: selectedCity ?? this.selectedCity,
      searchQuery: searchQuery ?? this.searchQuery,
      sortBy: sortBy ?? this.sortBy,
      errorMessage: errorMessage ?? this.errorMessage,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tasks,
        total,
        page,
        hasMore,
        selectedCategory,
        selectedCity,
        searchQuery,
        sortBy,
        errorMessage,
        isRefreshing,
        isLoadingMore,
      ];
}
