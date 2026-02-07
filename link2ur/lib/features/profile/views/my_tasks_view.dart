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
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/forum_repository.dart';
import '../bloc/profile_bloc.dart';

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
  ProfileState? _currentState;
  bool _scrollListenerAttached = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_currentState == null) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final context = this.context;
      final bloc = context.read<ProfileBloc>();
      if (_tabController.index == 0 && _currentState!.myTasksHasMore) {
        bloc.add(ProfileLoadMyTasks(
          isPosted: false,
          page: _currentState!.myTasksPage + 1,
        ));
      } else if (_tabController.index == 1 && _currentState!.postedTasksHasMore) {
        bloc.add(ProfileLoadMyTasks(
          isPosted: true,
          page: _currentState!.postedTasksPage + 1,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProfileBloc(
        userRepository: context.read<UserRepository>(),
        taskRepository: context.read<TaskRepository>(),
        forumRepository: context.read<ForumRepository>(),
      )
        ..add(const ProfileLoadMyTasks(isPosted: false, page: 1))
        ..add(const ProfileLoadMyTasks(isPosted: true, page: 1)),
      child: Scaffold(
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
        body: BlocBuilder<ProfileBloc, ProfileState>(
          builder: (context, state) {
            // Update current state for scroll listener
            _currentState = state;
            // Ensure scroll listener is attached once
            if (!_scrollListenerAttached) {
              _scrollListenerAttached = true;
              _scrollController.addListener(_onScroll);
            }

            return TabBarView(
              controller: _tabController,
              children: [
                _buildMyTasksTab(context, state),
                _buildMyPostedTasksTab(context, state),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMyTasksTab(BuildContext context, ProfileState state) {
    final isLoading = state.myTasks.isEmpty && state.status == ProfileStatus.loading;
    
    if (isLoading) {
      return const LoadingView();
    }

    if (state.errorMessage != null && state.myTasks.isEmpty) {
      return ErrorStateView(
        message: state.errorMessage!,
        onRetry: () {
          context.read<ProfileBloc>().add(
                const ProfileLoadMyTasks(isPosted: false, page: 1),
              );
        },
      );
    }

    if (state.myTasks.isEmpty) {
      return EmptyStateView.noTasks(
        actionText: '去接任务',
        onAction: () {
          context.push('/tasks');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProfileBloc>().add(
              const ProfileLoadMyTasks(isPosted: false, page: 1),
            );
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: AppSpacing.allMd,
        itemCount: state.myTasks.length + (state.myTasksHasMore ? 1 : 0),
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) {
          if (index >= state.myTasks.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _TaskCard(task: state.myTasks[index]);
        },
      ),
    );
  }

  Widget _buildMyPostedTasksTab(BuildContext context, ProfileState state) {
    final isLoading = state.postedTasks.isEmpty && state.status == ProfileStatus.loading;
    
    if (isLoading) {
      return const LoadingView();
    }

    if (state.errorMessage != null && state.postedTasks.isEmpty) {
      return ErrorStateView(
        message: state.errorMessage!,
        onRetry: () {
          context.read<ProfileBloc>().add(
                const ProfileLoadMyTasks(isPosted: true, page: 1),
              );
        },
      );
    }

    if (state.postedTasks.isEmpty) {
      return EmptyStateView.noTasks(
        actionText: '发布任务',
        onAction: () {
          context.push('/tasks/create');
        },
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<ProfileBloc>().add(
              const ProfileLoadMyTasks(isPosted: true, page: 1),
            );
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: AppSpacing.allMd,
        itemCount: state.postedTasks.length + (state.postedTasksHasMore ? 1 : 0),
        separatorBuilder: (context, index) => AppSpacing.vMd,
        itemBuilder: (context, index) {
          if (index >= state.postedTasks.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(),
              ),
            );
          }
          return _TaskCard(task: state.postedTasks[index]);
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
                      style: const TextStyle(
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
              style: const TextStyle(
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
                    const Icon(
                      Icons.location_on_outlined,
                      size: 16,
                      color: AppColors.textTertiaryLight,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.location!,
                      style: const TextStyle(
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
