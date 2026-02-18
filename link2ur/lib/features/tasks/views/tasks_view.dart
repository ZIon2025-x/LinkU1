import 'package:flutter/material.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/uk_cities.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/task_type_helper.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/router/app_router.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/loading_view.dart';
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
  final Debouncer _debouncer = Debouncer();

  // 11个分类 (对齐iOS TasksView - SF Symbols)
  final List<Map<String, dynamic>> _categories = [
    {'key': 'all', 'icon': Icons.grid_view},
    {'key': 'housekeeping', 'icon': Icons.home_outlined},
    {'key': 'campus', 'icon': Icons.school_outlined},
    {
      'key': 'secondhand',
      'icon': Icons.shopping_bag_outlined
    },
    {
      'key': 'delivery',
      'icon': Icons.directions_run_outlined
    },
    {'key': 'skill', 'icon': Icons.build_outlined},
    {'key': 'social', 'icon': Icons.people_outlined},
    {
      'key': 'transport',
      'icon': Icons.directions_car_outlined
    },
    {'key': 'pet', 'icon': Icons.pets_outlined},
    {
      'key': 'life',
      'icon': Icons.shopping_cart_outlined
    },
    {'key': 'other', 'icon': Icons.apps},
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
    _debouncer.dispose();
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
    final isDesktop = ResponsiveUtils.isDesktop(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: isDesktop ? ContentConstraint(child: _buildSearchBar()) : _buildSearchBar(),
      ),
      body: Column(
        children: [
          isDesktop ? ContentConstraint(child: _buildCategoryTabs()) : _buildCategoryTabs(),
          const SizedBox(height: 8),
          Expanded(
            child: isDesktop
                ? ContentConstraint(child: _buildTaskGrid())
                : _buildTaskGrid(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await context.push('/tasks/create');
          if (context.mounted) {
            context.read<TaskListBloc>().add(const TaskListRefreshRequested());
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildSearchBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 8),
      child: Container(
        height: 40,
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
            const SizedBox(width: 12),
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
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                ),
                onChanged: (value) {
                  _debouncer.call(() {
                    if (!mounted) return;
                    context
                        .read<TaskListBloc>()
                        .add(TaskListSearchChanged(value));
                  });
                },
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear, size: 18),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                padding: EdgeInsets.zero,
                onPressed: () {
                  _searchController.clear();
                  _debouncer.cancel();
                  context
                      .read<TaskListBloc>()
                      .add(const TaskListSearchChanged(''));
                },
              )
            else
              // 筛选按钮（有激活筛选时显示小圆点）
              BlocBuilder<TaskListBloc, TaskListState>(
                buildWhen: (prev, curr) =>
                    prev.hasActiveFilters != curr.hasActiveFilters,
                builder: (context, state) {
                  return Stack(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.tune, size: 20),
                        constraints:
                            const BoxConstraints(minWidth: 36, minHeight: 36),
                        padding: EdgeInsets.zero,
                        onPressed: () => _showFilterPanel(context),
                      ),
                      if (state.hasActiveFilters)
                        Positioned(
                          right: 6,
                          top: 6,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  );
                },
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
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: AppSpacing.horizontalMd,
            itemCount: _categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final category = _categories[index];
              final isSelected =
                  state.selectedCategory == category['key'];
              final label = _categoryLabel(context, category['key'] as String);

              return GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  context.read<TaskListBloc>().add(
                        TaskListCategoryChanged(
                            category['key'] as String),
                      );
                },
                child: AnimatedContainer(
                  duration: AppConstants.animationDuration,
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: AppColors.gradientPrimary,
                          )
                        : null,
                    color: isSelected
                        ? null
                        : (isDark
                            ? AppColors.surface2(Brightness.dark)
                            : AppColors.surface1(Brightness.light)),
                    borderRadius: BorderRadius.circular(20),
                    border: isSelected
                        ? null
                        : Border.all(
                            color: (isDark
                                    ? AppColors.separatorDark
                                    : AppColors.separatorLight)
                                .withValues(alpha: 0.3),
                          ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight),
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 14,
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
        return l10n.taskCategoryHousekeepingLife;
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
      buildWhen: (prev, curr) =>
          prev.tasks != curr.tasks ||
          prev.isLoading != curr.isLoading ||
          prev.hasMore != curr.hasMore ||
          prev.hasError != curr.hasError ||
          prev.isEmpty != curr.isEmpty,
      builder: (context, state) {
        // AnimatedSwitcher 实现 skeleton → 内容的平滑淡出淡入过渡
        return AnimatedSwitcher(
          duration: AppConstants.animationDuration,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _buildTaskGridContent(context, state),
        );
      },
    );
  }

  Widget _buildTaskGridContent(BuildContext context, TaskListState state) {
        if (state.isLoading && state.tasks.isEmpty) {
          return const SkeletonGrid(
            key: ValueKey('skeleton'),
            aspectRatio: 0.68,
          );
        }

        if (state.hasError && state.tasks.isEmpty) {
          return ErrorStateView(
            key: const ValueKey('error'),
            message: state.errorMessage ?? context.l10n.tasksLoadFailed,
            onRetry: () {
              context
                  .read<TaskListBloc>()
                  .add(const TaskListLoadRequested());
            },
          );
        }

        if (state.isEmpty) {
          return KeyedSubtree(
            key: const ValueKey('empty'),
            child: EmptyStateView.noTasks(
              context,
              actionText: context.l10n.homePublishTask,
              onAction: () async {
                await context.push('/tasks/create');
                if (context.mounted) {
                  context.read<TaskListBloc>().add(const TaskListRefreshRequested());
                }
              },
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context
                .read<TaskListBloc>()
                .add(const TaskListRefreshRequested());
            // 等待 BLoC 状态变化而非人为延迟
            await context.read<TaskListBloc>().stream.firstWhere(
                  (s) => !s.isLoading,
                  orElse: () => state,
                );
          },
          key: const ValueKey('content'),
          child: GridView.builder(
            controller: _scrollController,
            cacheExtent: 500,
            clipBehavior: Clip.none,
            padding: AppSpacing.allMd,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.gridColumnCount(context, type: GridItemType.task),
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
                    child: LoadingIndicator(),
                  ),
                );
              }
              final task = state.tasks[index];
              return AnimatedListItem(
                key: ValueKey(task.id),
                index: index,
                child: _TaskGridCard(task: task),
              );
            },
          ),
        );
  }

  void _showFilterPanel(BuildContext context) {
    final bloc = context.read<TaskListBloc>();
    final currentState = bloc.state;
    // 临时变量，用于面板内选择（确认后才应用）
    String tempSortBy = currentState.sortBy;
    String tempCity = currentState.selectedCity;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final isDark = Theme.of(ctx).brightness == Brightness.dark;
            final l10n = ctx.l10n;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 顶部拖拽条
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark
                              ? AppColors.dividerDark
                              : AppColors.dividerLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 标题行：筛选 + 重置按钮
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n.commonFilter,
                          style: AppTypography.title2.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            setModalState(() {
                              tempSortBy = 'latest';
                              tempCity = 'all';
                            });
                          },
                          child: Text(
                            l10n.commonReset,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── 排序方式 ──
                    Text(
                      l10n.taskSortBy,
                      style: AppTypography.bodyBold,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _buildFilterChip(
                          label: l10n.taskSortLatest,
                          isSelected: tempSortBy == 'latest',
                          isDark: isDark,
                          onTap: () => setModalState(() => tempSortBy = 'latest'),
                        ),
                        _buildFilterChip(
                          label: l10n.taskSortHighestPay,
                          isSelected: tempSortBy == 'reward',
                          isDark: isDark,
                          onTap: () => setModalState(() => tempSortBy = 'reward'),
                        ),
                        _buildFilterChip(
                          label: l10n.taskSortNearDeadline,
                          isSelected: tempSortBy == 'deadline',
                          isDark: isDark,
                          onTap: () => setModalState(() => tempSortBy = 'deadline'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // ── 城市筛选 ──
                    Text(
                      l10n.taskFilterCity,
                      style: AppTypography.bodyBold,
                    ),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 220),
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _buildFilterChip(
                              label: l10n.commonAll,
                              isSelected: tempCity == 'all',
                              isDark: isDark,
                              onTap: () => setModalState(() => tempCity = 'all'),
                            ),
                            ...UKCities.all.map((city) {
                              final zhName = UKCities.zhName[city];
                              // 根据当前语言显示城市名
                              final locale = Localizations.localeOf(ctx);
                              final displayName = locale.languageCode == 'zh'
                                  ? (zhName ?? city)
                                  : city;
                              return _buildFilterChip(
                                label: displayName,
                                isSelected: tempCity == city,
                                isDark: isDark,
                                onTap: () => setModalState(() => tempCity = city),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── 确认按钮 ──
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          // 应用筛选
                          if (tempSortBy != currentState.sortBy) {
                            bloc.add(TaskListSortChanged(tempSortBy));
                          }
                          if (tempCity != currentState.selectedCity) {
                            bloc.add(TaskListCityChanged(tempCity));
                          }
                          Navigator.pop(ctx);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          l10n.commonConfirm,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// 构建筛选 Chip
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(colors: AppColors.gradientPrimary)
              : null,
          color: isSelected
              ? null
              : (isDark
                  ? AppColors.surface2(Brightness.dark)
                  : AppColors.surface1(Brightness.light)),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(
                  color: (isDark
                          ? AppColors.separatorDark
                          : AppColors.separatorLight)
                      .withValues(alpha: 0.3),
                ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

/// 任务Grid卡片 - 对齐iOS TaskCard (图片式卡片)
/// 参考 iOS TasksView.swift - struct TaskCard
class _TaskGridCard extends StatelessWidget {
  const _TaskGridCard({required this.task});

  final Task task;

  // 任务类型 icon 映射 (对齐iOS taskTypeIcons SF Symbols)
  // 任务类型图标 — 使用统一映射（TaskTypeHelper）

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.safePush('/tasks/${task.id}');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          // 对标iOS: 0.5pt separator边框
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
          // 对标iOS: 双层阴影
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域 (对齐iOS 180pt height + gradient overlay)
            Expanded(
              flex: 5,
              child: _buildImageArea(isDark),
            ),

            // 内容区域 (对齐iOS: title + deadline + price)
            Expanded(
              flex: 3,
              child: _buildContentArea(context, isDark),
            ),
          ],
        ),
      ),
    );
  }

  /// 图片区域 - 对齐iOS TaskCard ZStack；等比例裁剪不拉伸变形
  Widget _buildImageArea(bool isDark) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final dpr = MediaQuery.devicePixelRatioOf(context);
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 任务图片或占位背景（显式宽高 + cover 保证等比例裁剪、不变形）
              if (task.firstImage != null)
                Hero(
                  tag: 'task_image_${task.id}',
                  child: AsyncImageView(
                    imageUrl: task.firstImage!,
                    width: w,
                    height: h,
                    memCacheWidth: (w * dpr).round(),
                    memCacheHeight: (h * dpr).round(),
                  ),
                )
              else
                _buildPlaceholderBackground(),

        // 渐变遮罩层 (对齐iOS LinearGradient overlay)
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withValues(alpha: 0.2),
                Colors.black.withValues(alpha: 0.0),
                Colors.black.withValues(alpha: 0.4),
              ],
              stops: const [0.0, 0.4, 1.0],
            ),
          ),
        ),

        // 左上角：位置标签 (半透明胶囊，替代 BackdropFilter 以提升滚动性能)
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: AppRadius.allPill,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 0.5,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  task.isOnline
                      ? Icons.language
                      : Icons.location_on,
                  size: 12,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 80),
                  child: Text(
                    task.blurredLocation ?? 'Online',
                    style: AppTypography.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),

        // 右下角：任务类型标签（与 frontend .taskTypeBadge 一致：蓝紫渐变）
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.taskTypeBadgeGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.allPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  TaskTypeHelper.getIcon(task.taskType),
                  size: 11,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  TaskTypeHelper.getLocalizedLabel(task.taskType, context.l10n),
                  style: AppTypography.caption.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
            ],
          ),
        );
      },
    );
  }

  /// 占位背景 (对齐iOS placeholderBackground - 渐变 + 图标)
  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          TaskTypeHelper.getIcon(task.taskType),
          size: 40,
          color: AppColors.primary.withValues(alpha: 0.3),
        ),
      ),
    );
  }

  /// 内容区域 (对齐iOS: title + HStack(deadline, Spacer, priceBadge))
  Widget _buildContentArea(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题 (单行 + 省略号)
          Text(
            task.displayTitle(Localizations.localeOf(context)),
            style: AppTypography.body.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),

          // 底部信息栏 (对齐iOS HStack: deadline + Spacer + priceBadge)
          Row(
            children: [
              // 截止时间
              if (task.deadline != null)
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 12,
                        color: _deadlineColor(task.deadline!),
                      ),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          _formatDeadline(context, task.deadline!),
                          style: AppTypography.caption.copyWith(
                            color: _deadlineColor(task.deadline!),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              if (task.deadline == null) const Spacer(),

              // 价格标签 (对齐iOS priceBadge - 绿色胶囊)
              _buildPriceBadge(),
            ],
          ),
        ],
      ),
    );
  }

  /// 价格标签 (对齐iOS priceBadge - success渐变胶囊)
  Widget _buildPriceBadge() {
    if (task.reward <= 0) return const SizedBox.shrink();

    final currencySymbol = task.currency == 'GBP' ? '£' : '\$';
    final priceText = task.reward.truncateToDouble() == task.reward
        ? task.reward.toStringAsFixed(0)
        : task.reward.toStringAsFixed(2);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.success,
            AppColors.success.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: AppRadius.allPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            currencySymbol,
            style: AppTypography.caption2.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            priceText,
            style: AppTypography.caption.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
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

  String _formatDeadline(BuildContext context, DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    final l10n = context.l10n;

    if (diff.isNegative) {
      return l10n.taskDeadlineExpired;
    }
    if (diff.inMinutes < 60) {
      return l10n.taskDeadlineMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) {
      return l10n.taskDeadlineHours(diff.inHours);
    }
    if (diff.inDays < 7) {
      return l10n.taskDeadlineDays(diff.inDays);
    }
    return l10n.taskDeadlineDate(deadline.month, deadline.day);
  }
}
