import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/task_type_helper.dart';
import '../../../core/utils/task_status_helper.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_application.dart';
import '../../../data/repositories/task_repository.dart';
import '../../auth/bloc/auth_bloc.dart';

/// 任务Tab定义 - 对齐iOS MyTasksView.swift（7个Tab含Pending）
enum _TaskTab {
  all,
  posted,
  taken,
  inProgress,
  pending,
  completed,
  cancelled,
}

/// 我的任务页面
/// 对齐iOS MyTasksView - 7个Tab：全部/已发布/已接取/进行中/待处理/已完成/已取消
class MyTasksView extends StatefulWidget {
  const MyTasksView({super.key});

  @override
  State<MyTasksView> createState() => _MyTasksViewState();
}

class _MyTasksViewState extends State<MyTasksView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  /// 只拉一次「全部我的任务」，各 Tab 在本地按状态/角色筛选展示
  List<Task> _allMyTasks = [];
  bool _allMyTasksLoading = true;
  String? _allMyTasksError;

  final Map<_TaskTab, ScrollController> _scrollControllers = {};

  // Pending tab 使用独立的申请数据
  List<TaskApplication> _pendingApplications = [];
  bool _pendingLoading = true;
  String? _pendingError;

  Timer? _delayedLoadTimer;

  static const _tabs = _TaskTab.values;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(_onTabChanged);

    for (final tab in _tabs) {
      _scrollControllers[tab] = ScrollController();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadAllMyTasks();
      _delayedLoadTimer = Timer(const Duration(milliseconds: 200), () {
        if (mounted) _loadPendingApplications();
      });
    });
  }

  @override
  void dispose() {
    _delayedLoadTimer?.cancel();
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    for (final sc in _scrollControllers.values) {
      sc.dispose();
    }
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      AppHaptics.tabSwitch();
    }
  }

  /// 根据当前 Tab 从「全部我的任务」中筛选：我发布的 / 我接取的 / 进行中 / 已完成 / 已取消 / 全部
  List<Task> _getFilteredTasks(_TaskTab tab) {
    final userId = context.read<AuthBloc>().state.user?.id;
    switch (tab) {
      case _TaskTab.all:
        return _allMyTasks;
      case _TaskTab.posted:
        if (userId == null) return [];
        return _allMyTasks.where((t) => t.posterId == userId).toList();
      case _TaskTab.taken:
        if (userId == null) return [];
        return _allMyTasks.where((t) => t.posterId != userId).toList();
      case _TaskTab.inProgress:
        return _allMyTasks
            .where((t) => t.status == AppConstants.taskStatusInProgress)
            .toList();
      case _TaskTab.pending:
        return []; // 使用 _pendingApplications，不会走到这里
      case _TaskTab.completed:
        return _allMyTasks
            .where((t) => t.status == AppConstants.taskStatusCompleted)
            .toList();
      case _TaskTab.cancelled:
        return _allMyTasks
            .where((t) => t.status == AppConstants.taskStatusCancelled)
            .toList();
    }
  }

  /// 只请求一次「全部我的任务」，各 Tab 本地筛选
  Future<void> _loadAllMyTasks() async {
    setState(() {
      _allMyTasksLoading = true;
      _allMyTasksError = null;
    });
    try {
      final repo = context.read<TaskRepository>();
      final response = await repo.getMyTasks(
        pageSize: 100,
      );
      if (mounted) {
        setState(() {
          _allMyTasks = response.tasks;
          _allMyTasksLoading = false;
          _allMyTasksError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allMyTasksLoading = false;
          _allMyTasksError = e.toString();
        });
      }
    }
  }

  Future<void> _loadPendingApplications() async {
    setState(() => _pendingLoading = true);
    try {
      final repo = context.read<TaskRepository>();
      final applications = await repo.getMyApplications();
      if (mounted) {
        setState(() {
          _pendingApplications = applications;
          _pendingLoading = false;
          _pendingError = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _pendingLoading = false;
          _pendingError = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.myTasksTitle),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.primary,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondaryLight,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          tabs: [
            Tab(text: l10n.myTasksTabAll),
            Tab(text: l10n.myTasksTabPosted),
            Tab(text: l10n.myTasksTabTaken),
            Tab(text: l10n.myTasksTabInProgress),
            Tab(text: l10n.myTasksTabPending),
            Tab(text: l10n.myTasksTabCompleted),
            Tab(text: l10n.myTasksTabCancelled),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _tabs.map((tab) => _buildTabContent(tab)).toList(),
      ),
    );
  }

  Widget _buildTabContent(_TaskTab tab) {
    if (tab == _TaskTab.pending) {
      return _buildPendingContent();
    }

    final tasks = _getFilteredTasks(tab);
    final loading = _allMyTasksLoading;
    final error = _allMyTasksError;
    final l10n = context.l10n;

    if (loading && _allMyTasks.isEmpty) {
      return const SkeletonList(hasImage: false);
    }

    if (error != null && _allMyTasks.isEmpty) {
      return ErrorStateView(
        message: error,
        onRetry: _loadAllMyTasks,
      );
    }

    if (tasks.isEmpty) {
      return EmptyStateView(
        icon: Icons.assignment_outlined,
        title: _getEmptyTitle(tab, l10n),
        message: _getEmptyMessage(tab, l10n),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAllMyTasks,
      child: ListView.separated(
        controller: _scrollControllers[tab],
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: tasks.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return AnimatedListItem(
            key: ValueKey(tasks[index].id),
            index: index,
            child: _TaskCard(task: tasks[index]),
          );
        },
      ),
    );
  }

  Widget _buildPendingContent() {
    final l10n = context.l10n;

    if (_pendingLoading && _pendingApplications.isEmpty) {
      return const SkeletonList(hasImage: false);
    }

    if (_pendingError != null && _pendingApplications.isEmpty) {
      return ErrorStateView(
        message: _pendingError!,
        onRetry: () => _loadPendingApplications(),
      );
    }

    if (_pendingApplications.isEmpty) {
      return EmptyStateView(
        icon: Icons.pending_actions,
        title: l10n.myTasksEmptyPending,
        message: l10n.myTasksNoPendingApplicationsMessage,
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadPendingApplications(),
      child: ListView.separated(
        controller: _scrollControllers[_TaskTab.pending],
        clipBehavior: Clip.none,
        padding: const EdgeInsets.all(AppSpacing.md),
        itemCount: _pendingApplications.length,
        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
        itemBuilder: (context, index) {
          return AnimatedListItem(
            key: ValueKey(_pendingApplications[index].id),
            index: index,
            child: _ApplicationCard(application: _pendingApplications[index]),
          );
        },
      ),
    );
  }

  String _getEmptyTitle(_TaskTab tab, dynamic l10n) {
    switch (tab) {
      case _TaskTab.all:
        return l10n.myTasksEmptyAll;
      case _TaskTab.posted:
        return l10n.myTasksEmptyPosted;
      case _TaskTab.taken:
        return l10n.myTasksEmptyTaken;
      case _TaskTab.inProgress:
        return l10n.myTasksEmptyInProgress;
      case _TaskTab.pending:
        return l10n.myTasksEmptyPending;
      case _TaskTab.completed:
        return l10n.myTasksEmptyCompleted;
      case _TaskTab.cancelled:
        return l10n.myTasksEmptyCancelled;
    }
  }

  String _getEmptyMessage(_TaskTab tab, dynamic l10n) {
    switch (tab) {
      case _TaskTab.all:
        return l10n.myTasksEmptyAll;
      case _TaskTab.posted:
        return l10n.myTasksEmptyPosted;
      case _TaskTab.taken:
        return l10n.myTasksEmptyTaken;
      case _TaskTab.inProgress:
        return l10n.myTasksEmptyInProgress;
      case _TaskTab.pending:
        return l10n.myTasksEmptyPending;
      case _TaskTab.completed:
        return l10n.myTasksEmptyCompleted;
      case _TaskTab.cancelled:
        return l10n.myTasksEmptyCancelled;
    }
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        context.safePush('/tasks/${task.id}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：用户信息和状态
          Row(
            children: [
              AvatarView(
                imageUrl: task.poster?.avatar,
                name: task.poster?.name,
                size: 36,
              ),
              AppSpacing.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.poster?.name ?? context.l10n.profileAnonymousUser,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      TaskTypeHelper.getLocalizedLabel(task.taskType, context.l10n),
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
                  TaskStatusHelper.getLocalizedLabel(task.status, context.l10n),
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
            task.displayTitle(Localizations.localeOf(context)),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (task.displayDescription(Localizations.localeOf(context)) != null) ...[
            AppSpacing.vSm,
            Text(
              task.displayDescription(Localizations.localeOf(context))!,
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
                '£${task.reward.toStringAsFixed(0)}',
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
      case AppConstants.taskStatusOpen:
        return AppColors.success;
      case AppConstants.taskStatusInProgress:
        return AppColors.primary;
      case AppConstants.taskStatusCompleted:
        return AppColors.textSecondaryLight;
      case AppConstants.taskStatusCancelled:
        return AppColors.error;
      case AppConstants.taskStatusPendingConfirmation:
      case AppConstants.taskStatusPendingPayment:
        return Colors.orange;
      default:
        return AppColors.textSecondaryLight;
    }
  }
}

/// 待处理申请卡片 - 对齐iOS MyTasksApplicationCard
class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application});

  final TaskApplication application;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return AppCard(
      onTap: () {
        context.safePush('/tasks/${application.taskId}');
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 头部：申请人信息和状态
          Row(
            children: [
              AvatarView(
                imageUrl: application.applicantAvatar,
                name: application.applicantName,
                size: 36,
              ),
              AppSpacing.hSm,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.applicantName ?? l10n.profileAnonymousUser,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      l10n.myTasksPending,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: AppRadius.allTiny,
                ),
                child: Text(
                  l10n.myTasksPending,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          // 申请消息
          if (application.message != null && application.message!.isNotEmpty) ...[
            AppSpacing.vMd,
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.secondaryBackgroundDark
                    : const Color(0xFFF7F7F7),
                borderRadius: AppRadius.allMedium,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.myTasksApplicationMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    application.message!,
                    style: const TextStyle(fontSize: 14),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],

          // 报价
          if (application.proposedPrice != null) ...[
            AppSpacing.vMd,
            Row(
              children: [
                Text(
                  '\$${application.proposedPrice!.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ],

          AppSpacing.vSm,
          // 查看详情按钮
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              l10n.myTasksViewDetails,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
