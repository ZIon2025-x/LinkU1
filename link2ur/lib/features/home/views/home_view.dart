import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../data/models/task.dart';
import '../../../data/repositories/task_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

/// 首页
/// 对标iOS HomeView.swift
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

class _HomeViewContentState extends State<_HomeViewContent> {
  // 对标iOS: @State private var selectedTab = 1 // 0: 达人, 1: 推荐, 2: 附近
  int _selectedTab = 1;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedTab);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (_selectedTab != index) {
      HapticFeedback.selectionClick();
      setState(() {
        _selectedTab = index;
      });
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      // 通知 Bloc tab 变化
      context.read<HomeBloc>().add(HomeTabChanged(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // 背景色
          Container(
            color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          ),

          // 对标iOS: 装饰性背景：增加品牌氛围
          Positioned(
            right: -60,
            top: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            left: -75,
            top: 200,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPink.withValues(alpha: 0.08),
              ),
            ),
          ),
          // 使用 BackdropFilter 模拟 blur 效果
          Positioned.fill(
            child: Container(
              color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
                  .withValues(alpha: 0.85),
            ),
          ),

          // 主内容
          SafeArea(
            child: Column(
              children: [
                // 对标iOS: 自定义顶部导航栏
                _buildCustomAppBar(isDark),

                // 内容区域 - 对标iOS TabView(.page)
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedTab = index;
                      });
                      context.read<HomeBloc>().add(HomeTabChanged(index));
                    },
                    children: const [
                      _ExpertsTab(),       // Tab 0: 达人
                      _RecommendedTab(),   // Tab 1: 推荐
                      _NearbyTab(),        // Tab 2: 附近
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 对标iOS: HStack自定义顶部导航栏
  Widget _buildCustomAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
          .withValues(alpha: 0.95),
      child: Row(
        children: [
          // 对标iOS: 左侧汉堡菜单
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showMenuSheet(context);
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.menu,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  size: 24,
                ),
              ),
            ),
          ),

          const Spacer(),

          // 对标iOS: 中间三个标签
          SizedBox(
            width: 240,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _TabButton(
                  title: context.l10n.homeExperts,
                  isSelected: _selectedTab == 0,
                  onTap: () => _onTabChanged(0),
                ),
                _TabButton(
                  title: context.l10n.homeRecommended,
                  isSelected: _selectedTab == 1,
                  onTap: () => _onTabChanged(1),
                ),
                _TabButton(
                  title: context.l10n.homeNearby,
                  isSelected: _selectedTab == 2,
                  onTap: () => _onTabChanged(2),
                ),
              ],
            ),
          ),

          const Spacer(),

          // 对标iOS: 右侧搜索图标
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              _showSearchSheet(context);
            },
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: Icon(
                  Icons.search,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 对标iOS: sheet(isPresented: $showMenu) { MenuView() }
  void _showMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return const _MenuView();
        },
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return const _SearchView();
        },
      ),
    );
  }
}

/// 对标iOS: TabButton组件 (符合 Apple HIG + 丝滑动画)
class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.title,
    required this.isSelected,
    required this.onTap,
  });

  final String title;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 对标iOS: scaleEffect(isSelected ? 1.05 : 1.0)
            AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight)
                      : (isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // 对标iOS: Capsule下划线指示器
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              height: 3,
              width: isSelected ? 28 : 0,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.allPill,
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: RecommendedContentView (推荐Tab)
class _RecommendedTab extends StatelessWidget {
  const _RecommendedTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () async {
            context.read<HomeBloc>().add(const HomeRefreshRequested());
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            slivers: [
              // 对标iOS: 顶部欢迎区域
              SliverToBoxAdapter(
                child: _GreetingSection(),
              ),

              // 对标iOS: BannerCarouselSection
              const SliverToBoxAdapter(
                child: _BannerCarousel(),
              ),

              // 对标iOS: RecommendedTasksSection - 推荐任务标题
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.homeRecommendedTasks,
                        style: AppTypography.title3.copyWith(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.push('/tasks'),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              context.l10n.commonViewAll,
                              style: AppTypography.body.copyWith(
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(
                              Icons.chevron_right,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 对标iOS: 横向滚动推荐任务
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
                // 对标iOS: 横向滚动任务卡片 (最多10个)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 200,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.only(
                        left: AppSpacing.md,
                        right: AppSpacing.lg,
                      ),
                      itemCount: state.recommendedTasks.length > 10
                          ? 10
                          : state.recommendedTasks.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 12),
                      itemBuilder: (context, index) {
                        final task = state.recommendedTasks[index];
                        return _HorizontalTaskCard(task: task);
                      },
                    ),
                  ),
                ),

                // 对标iOS: PopularActivitiesSection - 热门活动标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.l10n.homeHotEvents,
                          style: AppTypography.title3.copyWith(
                            color:
                                Theme.of(context).brightness == Brightness.dark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => context.push('/activities'),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                context.l10n.commonViewAll,
                                style: AppTypography.body.copyWith(
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.chevron_right,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // 对标iOS: 横向滚动活动卡片
                SliverToBoxAdapter(
                  child: _PopularActivitiesSection(),
                ),

                // 对标iOS: RecentActivitiesSection - 最新动态标题
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
                    child: Text(
                      context.l10n.homeLatestActivity,
                      style: AppTypography.title3.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ),

                // 对标iOS: 最新动态列表 (垂直)
                SliverToBoxAdapter(
                  child: _RecentActivitiesSection(),
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

/// 对标iOS: GreetingSection - 个性化问候语
class _GreetingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authState = context.watch<AuthBloc>().state;
    final userName = authState.isAuthenticated
        ? (authState.user?.name ?? '用户')
        : '同学';

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.lg, AppSpacing.md, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.homeGreeting(userName),
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.homeWhatToDo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // 对标iOS: Image(systemName: "sparkles") + .ultraThinMaterial + Circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// 对标iOS: BannerCarouselSection - 横幅轮播
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 150,
          margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              // 对标iOS: 跳蚤市场Banner — 使用真实图片
              _BannerItem(
                title: '二手市场',
                subtitle: '闲置物品，低价出售',
                gradient: const [Color(0xFF34C759), Color(0xFF30D158)],
                icon: Icons.storefront,
                imagePath: AppAssets.fleaMarketBanner,
                onTap: () => context.push('/flea-market'),
              ),
              // 对标iOS: 学生认证Banner — 使用真实图片
              _BannerItem(
                title: '学生认证',
                subtitle: '完成认证，享受更多权益',
                gradient: const [Color(0xFF5856D6), Color(0xFF007AFF)],
                icon: Icons.school,
                imagePath: AppAssets.studentVerificationBanner,
                onTap: () => context.push('/student-verification'),
              ),
              // 任务达人Banner
              _BannerItem(
                title: '成为任务达人',
                subtitle: '展示技能，获取更多机会',
                gradient: const [Color(0xFFFF9500), Color(0xFFFF6B00)],
                icon: Icons.star,
                onTap: () => context.push('/task-experts/intro'),
              ),
            ],
          ),
        ),
        // 页面指示器
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(3, (index) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              height: 6,
              width: _currentPage == index ? 18 : 6,
              decoration: BoxDecoration(
                color: _currentPage == index
                    ? AppColors.primary
                    : AppColors.primary.withValues(alpha: 0.2),
                borderRadius: AppRadius.allPill,
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.imagePath,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: imagePath == null
              ? LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 真实图片背景
            if (imagePath != null)
              Image.asset(
                imagePath!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // 图片加载失败时回退到渐变背景
                  return Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  );
                },
              ),
            // 图片上的渐变遮罩，保证文字可读
            if (imagePath != null)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.55),
                      Colors.black.withValues(alpha: 0.15),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
              ),
            // 装饰图标（无图片时显示）
            if (imagePath == null)
              Positioned(
                right: 20,
                bottom: 10,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            // 文字内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: PopularActivitiesSection - 热门活动区域
class _PopularActivitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.lg,
        ),
        children: [
          _ActivityCard(
            title: '新人奖励',
            subtitle: '完成首单即可获得',
            gradient: const [Color(0xFFFF6B6B), Color(0xFFFF4757)],
            icon: Icons.card_giftcard,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: '邀请好友',
            subtitle: '邀请好友得积分',
            gradient: const [Color(0xFF7C5CFC), Color(0xFF5F27CD)],
            icon: Icons.people,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: '每日签到',
            subtitle: '连续签到得奖励',
            gradient: const [Color(0xFF2ED573), Color(0xFF00B894)],
            icon: Icons.calendar_today,
            onTap: () => context.push('/activities'),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.allMedium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const Spacer(),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: RecentActivitiesSection - 最新动态区域
class _RecentActivitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // 模拟最新动态数据 (实际应从API获取)
    final activities = [
      const _RecentActivityData(
        icon: Icons.forum,
        iconGradient: [Color(0xFF34C759), Color(0xFF30D158)],
        userName: '用户',
        actionText: '发布了新帖子',
        title: '校园生活分享',
        description: '分享我的校园日常',
      ),
      const _RecentActivityData(
        icon: Icons.shopping_bag,
        iconGradient: [Color(0xFFFF9500), Color(0xFFFF6B00)],
        userName: '用户',
        actionText: '发布了新商品',
        title: '闲置书籍出售',
      ),
      const _RecentActivityData(
        icon: Icons.emoji_events,
        iconGradient: [Color(0xFF5856D6), Color(0xFF007AFF)],
        userName: '系统',
        actionText: '创建了新排行榜',
        title: '本周任务达人榜',
      ),
    ];

    if (activities.isEmpty) {
      return Padding(
        padding: AppSpacing.allMd,
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.notifications_none,
                size: 48,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              AppSpacing.vSm,
              Text(
                context.l10n.homeNoActivity,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              AppSpacing.vXs,
              Text(
                context.l10n.homeNoActivityMessage,
                style: AppTypography.caption.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: AppSpacing.horizontalMd,
      child: Column(
        children: activities.map((activity) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityRow(activity: activity),
          );
        }).toList(),
      ),
    );
  }
}

class _RecentActivityData {
  const _RecentActivityData({
    required this.icon,
    required this.iconGradient,
    required this.userName,
    required this.actionText,
    required this.title,
    this.description,
  });

  final IconData icon;
  final List<Color> iconGradient;
  final String userName;
  final String actionText;
  final String title;

  final String? description;
}

/// 对标iOS: ActivityRow - 动态行组件
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final _RecentActivityData activity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 对标iOS: 渐变图标
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activity.iconGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: activity.iconGradient.first.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              activity.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 对标iOS: 合并用户名和动作文本
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: activity.userName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      TextSpan(
                        text: ' ${activity.actionText}',
                        style: AppTypography.body.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  activity.title,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.description!,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ],
      ),
    );
  }
}

/// 对标iOS: 横向任务卡片
class _HorizontalTaskCard extends StatelessWidget {
  const _HorizontalTaskCard({required this.task});

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
        width: 180,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片区域
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(12)),
              child: Container(
                height: 100,
                width: double.infinity,
                color: AppColors.primary.withValues(alpha: 0.05),
                child: task.firstImage != null
                    ? AsyncImageView(
                        imageUrl: task.firstImage!,
                        width: 180,
                        height: 100,
                      )
                    : Center(
                        child: Icon(
                          Icons.image,
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                          size: 32,
                        ),
                      ),
              ),
            ),
            // 内容区域
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.displayTitle,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${task.currency == 'GBP' ? '£' : '\$'}${task.reward.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                        if (task.location != null)
                          Flexible(
                            child: Text(
                              task.location!,
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
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
}

/// 对标iOS: NearbyTasksView (附近Tab)
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
                const Icon(
                  Icons.location_off_outlined,
                  size: 64,
                  color: AppColors.textTertiaryLight,
                ),
                AppSpacing.vMd,
                Text(
                  context.l10n.homeNoNearbyTasks,
                  style: const TextStyle(color: AppColors.textSecondaryLight),
                ),
                AppSpacing.vMd,
                TextButton.icon(
                  onPressed: () {
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

/// 对标iOS: TaskExpertListContentView (达人Tab)
class _ExpertsTab extends StatelessWidget {
  const _ExpertsTab();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 对标iOS: 搜索框
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: GestureDetector(
            onTap: () => context.push('/task-experts'),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm + 2,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardBackgroundDark
                    : AppColors.cardBackgroundLight,
                borderRadius: AppRadius.allMedium,
                border: Border.all(
                  color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                      .withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    context.l10n.homeSearchExperts,
                    style: AppTypography.subheadline.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // 对标iOS: 达人列表
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.star_outline,
                  size: 64,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
                AppSpacing.vMd,
                Text(
                  context.l10n.homeExperts,
                  style: TextStyle(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
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
          ),
        ),
      ],
    );
  }
}

/// 任务卡片 - 垂直列表
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

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
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片
            ClipRRect(
              borderRadius: AppRadius.allMedium,
              child: Container(
                width: 80,
                height: 80,
                color: AppColors.primary.withValues(alpha: 0.05),
                child: task.firstImage != null
                    ? AsyncImageView(
                        imageUrl: task.firstImage!,
                        width: 80,
                        height: 80,
                      )
                    : Icon(
                        Icons.image,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
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
                    style: AppTypography.bodyBold.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (task.displayDescription != null)
                    Text(
                      task.displayDescription!,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
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
                        style: AppTypography.priceSmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.taskStatusColor(task.status)
                              .withValues(alpha: 0.1),
                          borderRadius: AppRadius.allTiny,
                        ),
                        child: Text(
                          task.statusText,
                          style: AppTypography.caption2.copyWith(
                            color: AppColors.taskStatusColor(task.status),
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
      ),
    );
  }
}

/// 对标iOS: MenuView - 菜单视图
class _MenuView extends StatelessWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.menuMenu,
                  style: AppTypography.title3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.menuClose),
                ),
              ],
            ),
          ),
          // 对标iOS: 菜单项列表
          Expanded(
            child: ListView(
              padding: AppSpacing.horizontalMd,
              children: [
                _MenuListItem(
                  icon: Icons.person,
                  title: context.l10n.menuMy,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                _MenuListItem(
                  icon: Icons.list_alt,
                  title: context.l10n.menuTaskHall,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/tasks');
                  },
                ),
                _MenuListItem(
                  icon: Icons.star,
                  title: context.l10n.menuTaskExperts,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/task-experts');
                  },
                ),
                _MenuListItem(
                  icon: Icons.forum,
                  title: context.l10n.menuForum,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/forum');
                  },
                ),
                _MenuListItem(
                  icon: Icons.emoji_events,
                  title: context.l10n.menuLeaderboard,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/leaderboard');
                  },
                ),
                _MenuListItem(
                  icon: Icons.shopping_cart,
                  title: context.l10n.menuFleaMarket,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/flea-market');
                  },
                ),
                _MenuListItem(
                  icon: Icons.calendar_month,
                  title: context.l10n.menuActivity,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/activities');
                  },
                ),
                _MenuListItem(
                  icon: Icons.stars,
                  title: context.l10n.menuPointsCoupons,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/coupon-points');
                  },
                ),
                _MenuListItem(
                  icon: Icons.verified_user,
                  title: context.l10n.menuStudentVerification,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/student-verification');
                  },
                ),
                const Divider(height: 32),
                _MenuListItem(
                  icon: Icons.settings,
                  title: context.l10n.menuSettings,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  const _MenuListItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
        size: 18,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// 对标iOS: SearchView - 搜索视图
class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  // 热门搜索关键词
  final List<String> _hotKeywords = [
    '代取快递',
    '论文辅导',
    '搬家',
    '代购',
    '遛狗',
    '翻译',
    '拍照',
    '家教',
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AppSpacing.vSm,

          // 搜索栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        Navigator.pop(context);
                        context.push('/tasks');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: context.l10n.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.secondaryBackgroundDark
                          : AppColors.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allSmall,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                AppSpacing.hSm,
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.commonCancel),
                ),
              ],
            ),
          ),

          // 搜索内容
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildSearchHome(isDark)
                : _buildSearchResults(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHome(bool isDark) {
    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.homeHotSearches,
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _hotKeywords.map((keyword) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = keyword;
                  setState(() => _searchQuery = keyword);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.secondaryBackgroundDark
                        : AppColors.backgroundLight,
                    borderRadius: AppRadius.allPill,
                  ),
                  child: Text(
                    keyword,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          AppSpacing.vXl,

          // 搜索分类
          Text(
            '搜索分类',
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          _SearchCategoryItem(
            icon: Icons.task_alt,
            title: '搜索任务',
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              context.push('/tasks');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.star,
            title: context.l10n.homeSearchExperts,
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              context.push('/task-experts');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.storefront,
            title: '搜索闲置',
            color: AppColors.success,
            onTap: () {
              Navigator.pop(context);
              context.push('/flea-market');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.forum,
            title: '搜索帖子',
            color: AppColors.teal,
            onTap: () {
              Navigator.pop(context);
              context.push('/forum');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          AppSpacing.vMd,
          Text(
            '搜索 "$_searchQuery"',
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          Text(
            '按回车键搜索',
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCategoryItem extends StatelessWidget {
  const _SearchCategoryItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.allSmall,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }
}
