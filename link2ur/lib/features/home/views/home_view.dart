import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/cards.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../../data/repositories/common_repository.dart';
import '../../../data/models/banner.dart' as app_banner;
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

/// 首页
/// 参考iOS HomeView.swift
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => HomeBloc(
        taskRepository: context.read<TaskRepository>(),
      )..add(const HomeLoadRequested()),
      child: const _HomeViewContent(),
    );
  }
}

class _HomeViewContent extends StatefulWidget {
  const _HomeViewContent();

  @override
  State<_HomeViewContent> createState() => _HomeViewContentState();
}

class _HomeViewContentState extends State<_HomeViewContent>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabs = ['推荐', '附近', '达人'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<HomeBloc>().add(HomeTabChanged(_tabController.index));
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _RecommendedTab(),
          _NearbyTab(),
          _ExpertsTab(),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('Link²Ur'),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            context.push('/tasks');
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications_outlined),
          onPressed: () {
            context.push('/notifications');
          },
        ),
      ],
      bottom: TabBar(
        controller: _tabController,
        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
        labelColor: AppColors.primary,
        unselectedLabelColor: AppColors.textSecondaryLight,
        indicatorColor: AppColors.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
    );
  }
}

/// 推荐Tab
class _RecommendedTab extends StatelessWidget {
  const _RecommendedTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<HomeBloc>().add(const HomeRefreshRequested());
            // 等待刷新完成
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
              // 横幅轮播
              const SliverToBoxAdapter(
                child: _BannerCarousel(),
              ),

              // 快捷入口
              SliverToBoxAdapter(
                child: _QuickActions(),
              ),

              // 推荐任务标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: AppSpacing.allMd,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        '推荐任务',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          context.push('/tasks');
                        },
                        child: const Text('查看更多'),
                      ),
                    ],
                  ),
                ),
              ),

              // 内容区域
              if (state.isLoading && state.recommendedTasks.isEmpty)
                const SliverFillRemaining(
                  child: LoadingView(),
                )
              else if (state.hasError && state.recommendedTasks.isEmpty)
                SliverFillRemaining(
                  child: ErrorStateView(
                    message: state.errorMessage ?? '加载失败',
                    onRetry: () {
                      context
                          .read<HomeBloc>()
                          .add(const HomeLoadRequested());
                    },
                  ),
                )
              else if (state.recommendedTasks.isEmpty)
                SliverFillRemaining(
                  child: EmptyStateView.noTasks(
                    actionText: '发布任务',
                    onAction: () {
                      context.push('/tasks/create');
                    },
                  ),
                )
              else ...[
                // 任务列表
                SliverPadding(
                  padding: AppSpacing.horizontalMd,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index >= state.recommendedTasks.length) {
                          return null;
                        }
                        final task = state.recommendedTasks[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _TaskCard(task: task),
                        );
                      },
                      childCount: state.recommendedTasks.length,
                    ),
                  ),
                ),

                // 加载更多
                if (state.hasMoreRecommended)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: TextButton(
                          onPressed: () {
                            context.read<HomeBloc>().add(
                                  const HomeLoadRecommended(loadMore: true),
                                );
                          },
                          child: const Text('加载更多'),
                        ),
                      ),
                    ),
                  ),
              ],

              // 底部间距
              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
            ],
          ),
        );
      },
    );
  }
}

/// 附近Tab
class _NearbyTab extends StatelessWidget {
  const _NearbyTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        if (state.nearbyTasks.isEmpty && !state.isLoading) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 64,
                  color: AppColors.textTertiaryLight,
                ),
                AppSpacing.vMd,
                Text(
                  '暂无附近任务',
                  style: TextStyle(color: AppColors.textSecondaryLight),
                ),
                AppSpacing.vMd,
                TextButton.icon(
                  onPressed: () {
                    // 使用默认坐标加载附近任务
                    context.read<HomeBloc>().add(
                          const HomeLoadNearby(
                            latitude: 51.5074,
                            longitude: -0.1278,
                          ),
                        );
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('加载附近任务'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<HomeBloc>().add(
                  const HomeLoadNearby(
                    latitude: 51.5074,
                    longitude: -0.1278,
                  ),
                );
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.separated(
            padding: AppSpacing.allMd,
            itemCount: state.nearbyTasks.length,
            separatorBuilder: (_, __) => AppSpacing.vMd,
            itemBuilder: (context, index) {
              return _TaskCard(task: state.nearbyTasks[index]);
            },
          ),
        );
      },
    );
  }
}

/// 达人Tab
class _ExpertsTab extends StatelessWidget {
  const _ExpertsTab();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.star_outline,
            size: 64,
            color: AppColors.textTertiaryLight,
          ),
          AppSpacing.vMd,
          Text(
            '任务达人',
            style: TextStyle(color: AppColors.textSecondaryLight),
          ),
          AppSpacing.vMd,
          TextButton(
            onPressed: () {
              context.push('/task-experts');
            },
            child: const Text('浏览达人'),
          ),
        ],
      ),
    );
  }
}

/// 横幅轮播
class _BannerCarousel extends StatelessWidget {
  const _BannerCarousel();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 150,
      margin: AppSpacing.allMd,
      child: PageView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.8),
                  AppColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: AppRadius.allMedium,
            ),
            child: Center(
              child: Text(
                '广告位 ${index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 快捷入口
class _QuickActions extends StatelessWidget {
  final List<_QuickAction> actions = const [
    _QuickAction(
        icon: Icons.local_shipping,
        label: '代取代送',
        color: AppColors.primary,
        category: 'delivery'),
    _QuickAction(
        icon: Icons.shopping_bag,
        label: '代购',
        color: AppColors.accent,
        category: 'shopping'),
    _QuickAction(
        icon: Icons.school,
        label: '辅导',
        color: AppColors.success,
        category: 'tutoring'),
    _QuickAction(
        icon: Icons.translate,
        label: '翻译',
        color: AppColors.teal,
        category: 'translation'),
    _QuickAction(
        icon: Icons.more_horiz,
        label: '更多',
        color: AppColors.purple,
        category: 'all'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.horizontalMd,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: actions.map((action) {
          return GestureDetector(
            onTap: () {
              context.push('/tasks');
            },
            child: Column(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action.icon,
                    color: action.color,
                    size: 24,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  action.label,
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.category,
  });

  final IconData icon;
  final String label;
  final Color color;
  final String category;
}

/// 任务卡片 - 使用真实 Task 数据
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () {
        context.push('/tasks/${task.id}');
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 图片
          ClipRRect(
            borderRadius: AppRadius.allMedium,
            child: Container(
              width: 80,
              height: 80,
              color: AppColors.skeletonBase,
              child: task.firstImage != null
                  ? AsyncImageView(
                      imageUrl: task.firstImage!,
                      width: 80,
                      height: 80,
                    )
                  : const Icon(
                      Icons.image,
                      color: AppColors.textTertiaryLight,
                    ),
            ),
          ),
          AppSpacing.hMd,
          // 内容
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.displayTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (task.displayDescription != null)
                  Text(
                    task.displayDescription!,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${task.currency == 'GBP' ? '£' : '\$'}${task.reward.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.successLight,
                        borderRadius: AppRadius.allTiny,
                      ),
                      child: Text(
                        task.statusText,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
