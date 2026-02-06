import 'package:equatable/equatable.dart';

/// 任务列表事件
abstract class TaskListEvent extends Equatable {
  const TaskListEvent();

  @override
  List<Object?> get props => [];
}

/// 加载任务列表
class TaskListLoadRequested extends TaskListEvent {
  const TaskListLoadRequested();
}

/// 刷新任务列表
class TaskListRefreshRequested extends TaskListEvent {
  const TaskListRefreshRequested();
}

/// 加载更多任务
class TaskListLoadMore extends TaskListEvent {
  const TaskListLoadMore();
}

/// 搜索任务
class TaskListSearchChanged extends TaskListEvent {
  const TaskListSearchChanged(this.query);

  final String query;

  @override
  List<Object?> get props => [query];
}

/// 切换分类
class TaskListCategoryChanged extends TaskListEvent {
  const TaskListCategoryChanged(this.category);

  final String category;

  @override
  List<Object?> get props => [category];
}

/// 排序方式改变
class TaskListSortChanged extends TaskListEvent {
  const TaskListSortChanged(this.sortBy);

  final String sortBy;

  @override
  List<Object?> get props => [sortBy];
}
