import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../bloc/task_list_bloc.dart';
import '../bloc/task_list_event.dart';
import '../bloc/task_list_state.dart';

/// 任务列表页
/// 参考iOS TasksView.swift
class TasksView extends StatelessWidget {
  const TasksView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskListBloc(
        taskRepository: context.read<TaskRepository>(),
      )..add(const TaskListLoadRequested()),
      child: const _TasksViewContent(),
    );
  }
}

class _TasksViewContent extends StatefulWidget {
  const _TasksViewContent();

  @override
  State<_TasksViewContent> createState() => _TasksViewContentState();
}

class _TasksViewContentState extends State<_TasksViewContent> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': '全部'},
    {'key': 'delivery', 'label': '代取代送'},
    {'key': 'shopping', 'label': '代购'},
    {'key': 'tutoring', 'label': '辅导'},
    {'key': 'translation', 'label': '翻译'},
    {'key': 'other', 'label': '其他'},
  ];

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<TaskListBloc>().add(const TaskListLoadMore());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('任务列表'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showSortOptions(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryTabs(),
          Expanded(child: _buildTaskList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          context.push('/tasks/create');
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: AppSpacing.allMd,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: '搜索任务...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    context
                        .read<TaskListBloc>()
                        .add(const TaskListSearchChanged(''));
                  },
                )
              : null,
        ),
        onChanged: (value) {
          context.read<TaskListBloc>().add(TaskListSearchChanged(value));
        },
      ),
    );
  }

  Widget _buildCategoryTabs() {
    return BlocBuilder<TaskListBloc, TaskListState>(
      buildWhen: (prev, curr) =>
          prev.selectedCategory != curr.selectedCategory,
      builder: (context, state) {
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.horizontalMd,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => AppSpacing.hSm,
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected =
                  state.selectedCategory == category['key'];

              return GestureDetector(
                onTap: () {
                  context.read<TaskListBloc>().add(
                        TaskListCategoryChanged(
                            category['key'] as String),
                      );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: AppRadius.allPill,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.dividerLight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    category['label'] as String,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : AppColors.textSecondaryLight,
                      fontWeight:
                          isSelected ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTaskList() {
    return BlocBuilder<TaskListBloc, TaskListState>(
      builder: (context, state) {
        if (state.isLoading && state.tasks.isEmpty) {
          return const LoadingView();
        }

        if (state.hasError && state.tasks.isEmpty) {
          return ErrorStateView(
            message: state.errorMessage ?? '加载失败',
            onRetry: () {
              context
                  .read<TaskListBloc>()
                  .add(const TaskListLoadRequested());
            },
          );
        }

        if (state.isEmpty) {
          return EmptyStateView.noTasks(
            actionText: '发布任务',
            onAction: () {
              context.push('/tasks/create');
            },
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<TaskListBloc>()
                .add(const TaskListRefreshRequested());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.separated(
            controller: _scrollController,
            padding: AppSpacing.allMd,
            itemCount: state.tasks.length + (state.hasMore ? 1 : 0),
            separatorBuilder: (context, index) => AppSpacing.vMd,
            itemBuilder: (context, index) {
              if (index >= state.tasks.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return _TaskListItem(task: state.tasks[index]);
            },
          ),
        );
      },
    );
  }

  void _showSortOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: const Text('最新发布'),
                onTap: () {
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSortChanged('latest'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('报酬最高'),
                onTap: () {
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSortChanged('reward'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                title: const Text('即将截止'),
                onTap: () {
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSortChanged('deadline'));
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TaskListItem extends StatelessWidget {
  const _TaskListItem({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        context.push('/tasks/${task.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：用户信息和状态
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary,
                child: task.poster?.avatar != null
                    ? ClipOval(
                        child: Image.network(
                          task.poster!.avatar!,
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 20),
                        ),
                      )
                    : const Icon(Icons.person,
                        color: Colors.white, size: 20),
              ),
              AppSpacing.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.poster?.name ?? '匿名用户',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      task.taskTypeText,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor(task.status).withValues(alpha: 0.1),
                  borderRadius: AppRadius.allTiny,
                ),
                child: Text(
                  task.statusText,
                  style: TextStyle(
                    color: _statusColor(task.status),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          AppSpacing.vMd,

          // 标题
          Text(
            task.displayTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.displayDescription != null) ...[
            AppSpacing.vSm,
            Text(
              task.displayDescription!,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          AppSpacing.vMd,

          // 底部：价格和位置
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${task.currency == 'GBP' ? '£' : '\$'}${task.reward.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              if (task.location != null)
                Row(
                  children: [
                    Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textTertiaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.location!,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.success;
      case 'in_progress':
        return AppColors.primary;
      case 'completed':
        return AppColors.textSecondaryLight;
      case 'cancelled':
        return AppColors.error;
      default:
        return AppColors.textSecondaryLight;
    }
  }
}
