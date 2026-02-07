import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../core/utils/logger.dart';

/// 我的任务页面
/// 显示我接取的任务和我发布的任务
class MyTasksView extends StatefulWidget {
  const MyTasksView({super.key});

  @override
  State<MyTasksView> createState() => _MyTasksViewState();
}

class _MyTasksViewState extends State<MyTasksView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();

  List<Task> _myTasks = [];
  List<Task> _myPostedTasks = [];
  bool _isLoadingMyTasks = false;
  bool _isLoadingMyPostedTasks = false;
  String? _errorMessageMyTasks;
  String? _errorMessageMyPostedTasks;
  int _myTasksPage = 1;
  int _myPostedTasksPage = 1;
  bool _hasMoreMyTasks = true;
  bool _hasMoreMyPostedTasks = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _scrollController.addListener(_onScroll);
    _loadMyTasks();
    _loadMyPostedTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (_tabController.index == 0 && _hasMoreMyTasks) {
        _loadMoreMyTasks();
      } else if (_tabController.index == 1 && _hasMoreMyPostedTasks) {
        _loadMoreMyPostedTasks();
      }
    }
  }

  Future<void> _loadMyTasks() async {
    if (_isLoadingMyTasks) return;

    setState(() {
      _isLoadingMyTasks = true;
      _errorMessageMyTasks = null;
    });

    try {
      final taskRepo = context.read<TaskRepository>();
      final response = await taskRepo.getMyTasks(page: 1, pageSize: 20);

      setState(() {
        _myTasks = response.tasks;
        _myTasksPage = 1;
        _hasMoreMyTasks = response.hasMore;
        _isLoadingMyTasks = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load my tasks', e);
      setState(() {
        _isLoadingMyTasks = false;
        _errorMessageMyTasks = e.toString();
      });
    }
  }

  Future<void> _loadMoreMyTasks() async {
    if (_isLoadingMyTasks || !_hasMoreMyTasks) return;

    try {
      final taskRepo = context.read<TaskRepository>();
      final nextPage = _myTasksPage + 1;
      final response = await taskRepo.getMyTasks(page: nextPage, pageSize: 20);

      setState(() {
        _myTasks.addAll(response.tasks);
        _myTasksPage = nextPage;
        _hasMoreMyTasks = response.hasMore;
      });
    } catch (e) {
      AppLogger.error('Failed to load more my tasks', e);
    }
  }

  Future<void> _loadMyPostedTasks() async {
    if (_isLoadingMyPostedTasks) return;

    setState(() {
      _isLoadingMyPostedTasks = true;
      _errorMessageMyPostedTasks = null;
    });

    try {
      final taskRepo = context.read<TaskRepository>();
      final response =
          await taskRepo.getMyPostedTasks(page: 1, pageSize: 20);

      setState(() {
        _myPostedTasks = response.tasks;
        _myPostedTasksPage = 1;
        _hasMoreMyPostedTasks = response.hasMore;
        _isLoadingMyPostedTasks = false;
      });
    } catch (e) {
      AppLogger.error('Failed to load my posted tasks', e);
      setState(() {
        _isLoadingMyPostedTasks = false;
        _errorMessageMyPostedTasks = e.toString();
      });
    }
  }

  Future<void> _loadMoreMyPostedTasks() async {
    if (_isLoadingMyPostedTasks || !_hasMoreMyPostedTasks) return;

    try {
      final taskRepo = context.read<TaskRepository>();
      final nextPage = _myPostedTasksPage + 1;
      final response =
          await taskRepo.getMyPostedTasks(page: nextPage, pageSize: 20);

      setState(() {
        _myPostedTasks.addAll(response.tasks);
        _myPostedTasksPage = nextPage;
        _hasMoreMyPostedTasks = response.hasMore;
      });
    } catch (e) {
      AppLogger.error('Failed to load more my posted tasks', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我的任务'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '我接的'),
            Tab(text: '我发的'),
          ],
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMyTasksTab(),
          _buildMyPostedTasksTab(),
        ],
      ),
    );
  }

  Widget _buildMyTasksTab() {
    if (_isLoadingMyTasks && _myTasks.isEmpty) {
      return const LoadingView();
    }

    if (_errorMessageMyTasks != null && _myTasks.isEmpty) {
      return ErrorStateView(
        message: _errorMessageMyTasks!,
        onRetry: _loadMyTasks,
      );
    }

    if (_myTasks.isEmpty) {
      return EmptyStateView.noTasks(
        actionText: '去接任务',
        onAction: () {
          context.push('/tasks');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyTasks,
      child: ListView.separated(
        controller: _scrollController,
        padding: AppSpacing.allMd,
        itemCount: _myTasks.length + (_hasMoreMyTasks ? 1 : 0),
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) {
          if (index >= _myTasks.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _TaskCard(task: _myTasks[index]);
        },
      ),
    );
  }

  Widget _buildMyPostedTasksTab() {
    if (_isLoadingMyPostedTasks && _myPostedTasks.isEmpty) {
      return const LoadingView();
    }

    if (_errorMessageMyPostedTasks != null && _myPostedTasks.isEmpty) {
      return ErrorStateView(
        message: _errorMessageMyPostedTasks!,
        onRetry: _loadMyPostedTasks,
      );
    }

    if (_myPostedTasks.isEmpty) {
      return EmptyStateView.noTasks(
        actionText: '发布任务',
        onAction: () {
          context.push('/tasks/create');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _loadMyPostedTasks,
      child: ListView.separated(
        controller: _scrollController,
        padding: AppSpacing.allMd,
        itemCount: _myPostedTasks.length + (_hasMoreMyPostedTasks ? 1 : 0),
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) {
          if (index >= _myPostedTasks.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _TaskCard(task: _myPostedTasks[index]);
        },
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

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
                        child: AsyncImageView(
                          imageUrl: task.poster!.avatar!,
                          width: 36,
                          height: 36,
                        ),
                      )
                    : const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 20,
                      ),
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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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

          // 图片（如果有）
          if (task.firstImage != null) ...[
            ClipRRect(
              borderRadius: AppRadius.allMedium,
              child: AsyncImageView(
                imageUrl: task.firstImage!,
                width: double.infinity,
                height: 200,
              ),
            ),
            AppSpacing.vMd,
          ],

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
