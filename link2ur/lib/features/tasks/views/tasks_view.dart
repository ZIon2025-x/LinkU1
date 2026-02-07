import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../bloc/task_list_bloc.dart';
import '../bloc/task_list_event.dart';
import '../bloc/task_list_state.dart';

/// 任务列表页
/// 参考iOS TasksView.swift - Grid布局 + 图片卡片
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

  // 11个分类 (对齐iOS TasksView - SF Symbols)
  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'label': '全部', 'icon': Icons.grid_view},
    {'key': 'housekeeping', 'label': '家务生活', 'icon': Icons.home_outlined},          // house.fill
    {'key': 'campus', 'label': '校园生活', 'icon': Icons.school_outlined},              // graduationcap.fill
    {'key': 'secondhand', 'label': '二手租赁', 'icon': Icons.shopping_bag_outlined},    // bag.fill
    {'key': 'delivery', 'label': '跑腿代办', 'icon': Icons.directions_run_outlined},    // figure.run
    {'key': 'skill', 'label': '技能服务', 'icon': Icons.build_outlined},                // wrench.and.screwdriver.fill
    {'key': 'social', 'label': '社交帮助', 'icon': Icons.people_outlined},              // person.2.fill
    {'key': 'transport', 'label': '交通出行', 'icon': Icons.directions_car_outlined},   // car.fill
    {'key': 'pet', 'label': '宠物照顾', 'icon': Icons.pets_outlined},                   // pawprint.fill
    {'key': 'life', 'label': '生活便利', 'icon': Icons.shopping_cart_outlined},          // cart.fill
    {'key': 'other', 'label': '其他', 'icon': Icons.apps},                              // square.grid.2x2.fill
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
        title: Text(context.l10n.tasksTasks),
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
          const SizedBox(height: 8),
          Expanded(child: _buildTaskGrid()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.allMd,
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.secondaryBackgroundDark
              : AppColors.backgroundLight,
          borderRadius: AppRadius.allPill,
          border: Border.all(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(
              Icons.search,
              size: 20,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: context.l10n.commonSearch,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onChanged: (value) {
                  context
                      .read<TaskListBloc>()
                      .add(TaskListSearchChanged(value));
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                onPressed: () {
                  _searchController.clear();
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSearchChanged(''));
                },
              )
            else
              // 搜索/筛选按钮
              IconButton(
                icon: const Icon(Icons.tune, size: 20),
                onPressed: () => _showSortOptions(context),
              ),
          ],
        ),
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
            separatorBuilder: (context, index) =>
                const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected =
                  state.selectedCategory == category['key'];

              return GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  context.read<TaskListBloc>().add(
                        TaskListCategoryChanged(
                            category['key'] as String),
                      );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: AppRadius.allPill,
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _categoryLabel(context, category['key'] as String),
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : (Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
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

  String _categoryLabel(BuildContext context, String key) {
    final l10n = context.l10n;
    switch (key) {
      case 'all':
        return l10n.taskCategoryAll;
      case 'housekeeping':
        return l10n.taskCategoryHousekeeping;
      case 'campus':
        return l10n.taskCategoryCampusLife;
      case 'secondhand':
        return l10n.taskCategorySecondhandRental;
      case 'delivery':
        return l10n.taskCategoryErrandRunning;
      case 'skill':
        return l10n.taskCategorySkillService;
      case 'social':
        return l10n.taskCategorySocialHelp;
      case 'transport':
        return l10n.taskCategoryTransportation;
      case 'pet':
        return l10n.taskCategoryPetCare;
      case 'life':
        return l10n.taskCategoryLifeConvenience;
      case 'other':
        return l10n.taskCategoryOther;
      default:
        return key;
    }
  }

  /// Grid任务列表 (对齐iOS LazyVGrid)
  Widget _buildTaskGrid() {
    return BlocBuilder<TaskListBloc, TaskListState>(
      builder: (context, state) {
        if (state.isLoading && state.tasks.isEmpty) {
          return const LoadingView();
        }

        if (state.hasError && state.tasks.isEmpty) {
          return ErrorStateView(
            message: state.errorMessage ?? context.l10n.tasksLoadFailed,
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
          child: GridView.builder(
            controller: _scrollController,
            padding: AppSpacing.allMd,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.68,
            ),
            itemCount: state.tasks.length + (state.hasMore ? 1 : 0),
            itemBuilder: (context, index) {
              if (index >= state.tasks.length) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              return _TaskGridCard(task: state.tasks[index]);
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
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  '排序方式',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: const Text('最新发布'),
                onTap: () {
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSortChanged('latest'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: const Text('报酬最高'),
                onTap: () {
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSortChanged('reward'));
                  Navigator.pop(ctx);
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer),
                title: const Text('即将截止'),
                onTap: () {
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSortChanged('deadline'));
                  Navigator.pop(ctx);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

/// 任务Grid卡片 - 对齐iOS TaskCard (图片式卡片)
class _TaskGridCard extends StatelessWidget {
  const _TaskGridCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/tasks/${task.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域 (对齐iOS 180pt height)
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  // 任务图片
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(12)),
                    child: Container(
                      width: double.infinity,
                      color: AppColors.primary.withValues(alpha: 0.05),
                      child: task.firstImage != null
                          ? AsyncImageView(
                              imageUrl: task.firstImage!,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Icon(
                                _taskTypeIcon(task.taskType),
                                size: 40,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                    ),
                  ),

                  // 位置标签 (左上角, 对齐iOS)
                  if (task.location != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: AppRadius.allSmall,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              task.location!.length > 8
                                  ? '${task.location!.substring(0, 8)}...'
                                  : task.location!,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 任务类型标签 (右下角, 对齐iOS)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.9),
                        borderRadius: AppRadius.allSmall,
                      ),
                      child: Text(
                        task.taskTypeText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // 价格标签 (右下角, 对齐iOS)
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.gradientPrimary,
                        ),
                        borderRadius: AppRadius.allSmall,
                      ),
                      child: Text(
                        '${task.currency == 'GBP' ? '£' : '\$'}${task.reward.toStringAsFixed(0)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 内容区域
            Expanded(
              flex: 3,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 标题
                    Text(
                      task.displayTitle,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // 截止时间
                    if (task.deadline != null)
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: _deadlineColor(task.deadline!),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              _formatDeadline(task.deadline!),
                              style: TextStyle(
                                fontSize: 11,
                                color: _deadlineColor(task.deadline!),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 任务类型图标 (对齐iOS taskTypeIcons SF Symbols)
  IconData _taskTypeIcon(String type) {
    switch (type) {
      case 'delivery':
        return Icons.directions_run;       // figure.run
      case 'shopping':
        return Icons.shopping_bag;         // bag.fill
      case 'tutoring':
        return Icons.school;               // graduationcap.fill
      case 'translation':
        return Icons.translate;
      case 'housekeeping':
        return Icons.home;                 // house.fill
      case 'campus':
        return Icons.school;               // graduationcap.fill
      case 'secondhand':
        return Icons.shopping_bag;         // bag.fill
      case 'skill':
        return Icons.build;                // wrench.and.screwdriver.fill
      case 'social':
        return Icons.people;               // person.2.fill
      case 'transport':
        return Icons.directions_car;       // car.fill
      case 'pet':
        return Icons.pets;                 // pawprint.fill
      case 'life':
        return Icons.shopping_cart;        // cart.fill
      default:
        return Icons.apps;                 // square.grid.2x2.fill
    }
  }

  Color _deadlineColor(DateTime deadline) {
    final now = DateTime.now();
    if (deadline.isBefore(now)) {
      return AppColors.error; // 已过期
    }
    final diff = deadline.difference(now);
    if (diff.inHours < 24) {
      return AppColors.warning; // 即将到期
    }
    return AppColors.textTertiaryLight; // 正常
  }

  String _formatDeadline(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);

    if (diff.isNegative) {
      return '已过期';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}分钟后截止';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}小时后截止';
    }
    if (diff.inDays < 7) {
      return '${diff.inDays}天后截止';
    }
    return '${deadline.month}/${deadline.day} 截止';
  }
}
