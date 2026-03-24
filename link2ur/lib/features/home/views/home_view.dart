import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../core/utils/haptic_feedback.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/external_web_view.dart';
import '../../../data/models/banner.dart' as app_banner;
import '../../../data/models/discovery_feed.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/utils/helpers.dart';
import '../../../core/utils/service_category_helper.dart';
import '../../../core/utils/task_type_helper.dart';
import '../../../core/utils/task_status_helper.dart';
import '../../../core/utils/city_display_helper.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/loading_view.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/utils/date_formatter.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/decorative_background.dart';
import '../../../core/widgets/location_picker.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../task_expert/bloc/task_expert_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../../../data/repositories/ticker_repository.dart';
import '../linker_quotes.dart';

part 'home_recommended_section.dart';
part 'home_widgets.dart';
part 'home_activities_section.dart';
part 'home_discovery_cards.dart';
part 'home_task_cards.dart';
part 'home_experts_search.dart';

/// 首页
/// BLoC 在 MainTabView 中创建，此处直接使用
class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return const _HomeViewContent();
  }
}

class _HomeViewContent extends StatefulWidget {
  const _HomeViewContent();

  @override
  State<_HomeViewContent> createState() => _HomeViewContentState();
}

class _HomeViewContentState extends State<_HomeViewContent> {
  int _selectedTab = 1; // 0: 关注, 1: 推荐, 2: 附近
  PageController? _pageController;

  /// 已访问过的 Tab 集合（懒加载：未访问过的 Tab 不构建内容，避免首帧多余 build 开销）
  final Set<int> _visitedTabs = {1}; // 推荐 Tab 默认已访问

  @override
  void initState() {
    super.initState();
    // PageController 仅移动端使用
    _pageController = PageController(initialPage: _selectedTab);
  }

  @override
  void dispose() {
    _pageController?.dispose();
    super.dispose();
  }

  void _onTabChanged(int index) {
    if (_selectedTab != index) {
      AppHaptics.selection();
      setState(() {
        _selectedTab = index;
        _visitedTabs.add(index); // 标记 Tab 已访问，触发内容构建
      });
      // 仅移动端使用 PageView 动画
      _pageController?.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      context.read<HomeBloc>().add(HomeTabChanged(index));
      // 懒加载数据触发
      final homeBloc = context.read<HomeBloc>();
      if (index == 0 && homeBloc.state.followFeedItems.isEmpty) {
        homeBloc.add(const HomeLoadFollowFeed());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 仅超宽屏用桌面式内嵌 Tab；iPad 与手机一致用顶部 AppBar + 下方 Tab
    if (ResponsiveUtils.isDesktopShell(context)) {
      return _buildDesktopHome(context);
    }
    return _buildMobileHome(context);
  }

  // ==================== 桌面端首页 ====================
  Widget _buildDesktopHome(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: AppColors.backgroundFor(Theme.of(context).brightness),
      body: Column(
        children: [
          // Notion 风格内嵌 Tab 切换
          _buildDesktopTabBar(isDark),

          // 懒加载 Tab 内容；桌面端全宽，各 Tab 内部用 ContentConstraint 约束 1200（对齐 frontend）
          Expanded(
            child: IndexedStack(
              index: _selectedTab,
              children: [
                _visitedTabs.contains(0) ? const _FollowTab() : const SizedBox.shrink(),
                const _RecommendedTab(), // 默认 Tab，始终构建
                _visitedTabs.contains(2) ? const _NearbyTab() : const SizedBox.shrink(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTabBar(bool isDark) {
    return ContentConstraint(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.desktopHoverLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : AppColors.desktopBorderLight,
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DesktopSegmentButton(
                    label: context.l10n.homeFollow,
                    isSelected: _selectedTab == 0,
                    onTap: () => _onTabChanged(0),
                    isDark: isDark,
                  ),
                  _DesktopSegmentButton(
                    label: context.l10n.homeRecommended,
                    isSelected: _selectedTab == 1,
                    onTap: () => _onTabChanged(1),
                    isDark: isDark,
                  ),
                  _DesktopSegmentButton(
                    label: context.l10n.homeNearby,
                    isSelected: _selectedTab == 2,
                    onTap: () => _onTabChanged(2),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==================== 移动端首页（保持原样） ====================
  Widget _buildMobileHome(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;

    return Scaffold(
      drawer: _buildDrawer(context),
      body: Stack(
        children: [
          const RepaintBoundary(child: DecorativeBackground()),
          SafeArea(
            child: Column(
              children: [
                _buildMobileAppBar(isDark),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _selectedTab = index;
                        _visitedTabs.add(index);
                      });
                      final homeBloc = context.read<HomeBloc>();
                      homeBloc.add(HomeTabChanged(index));
                      if (index == 0 && homeBloc.state.followFeedItems.isEmpty) {
                        homeBloc.add(const HomeLoadFollowFeed());
                      }
                    },
                    children: [
                      _visitedTabs.contains(0) ? const _FollowTab() : const SizedBox.shrink(),
                      const _RecommendedTab(),
                      _visitedTabs.contains(2) ? const _NearbyTab() : const SizedBox.shrink(),
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

  Widget _buildMobileAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md, vertical: AppSpacing.sm,
      ),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // 左上角：菜单按钮（与右侧搜索按钮对称）
          Builder(
            builder: (scaffoldContext) => SizedBox(
              width: 72,
              height: 44,
              child: GestureDetector(
                onTap: () {
                  AppHaptics.selection();
                  Scaffold.of(scaffoldContext).openDrawer();
                },
                behavior: HitTestBehavior.opaque,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Icon(
                    Icons.menu,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    size: 24,
                  ),
                ),
              ),
            ),
          ),
          // 中间：3 个 Tab 居中
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TabButton(
                  title: context.l10n.homeFollow,
                  isSelected: _selectedTab == 0,
                  onTap: () => _onTabChanged(0),
                ),
                const SizedBox(width: 24),
                _TabButton(
                  title: context.l10n.homeRecommended,
                  isSelected: _selectedTab == 1,
                  onTap: () => _onTabChanged(1),
                ),
                const SizedBox(width: 24),
                _TabButton(
                  title: context.l10n.homeNearby,
                  isSelected: _selectedTab == 2,
                  onTap: () => _onTabChanged(2),
                ),
              ],
            ),
          ),
          // 右侧：搜索按钮（与左侧等宽保证 tab 居中）
          Semantics(
            button: true,
            label: 'Search',
            child: GestureDetector(
              onTap: () {
                AppHaptics.selection();
                context.push('/search');
              },
              child: SizedBox(
                width: 72, height: 44,
                child: Center(
                  child: Icon(Icons.search,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      size: 24),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Drawer(
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: user avatar + name
            BlocBuilder<AuthBloc, AuthState>(
              buildWhen: (p, c) => p.status != c.status || p.user != c.user,
              builder: (context, state) {
                final isLoggedIn = state.status == AuthStatus.authenticated;
                final user = state.user;
                return InkWell(
                  onTap: isLoggedIn
                      ? () {
                          Navigator.of(context).pop();
                          context.go('/profile-tab');
                        }
                      : () {
                          Navigator.of(context).pop();
                          context.push('/login');
                        },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: (isLoggedIn && user?.avatar != null)
                              ? NetworkImage(user!.avatar!)
                              : null,
                          backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE8E8E8),
                          child: (isLoggedIn && user?.avatar != null)
                              ? null
                              : Icon(Icons.person,
                                  size: 28,
                                  color: isDark ? Colors.grey[400] : Colors.grey[600]),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            isLoggedIn
                                ? (user?.name.isNotEmpty == true ? user!.name : 'User')
                                : context.l10n.drawerLogin,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                        ),
                        Icon(Icons.chevron_right,
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            size: 20),
                      ],
                    ),
                  ),
                );
              },
            ),

            Divider(
              height: 1,
              color: isDark ? Colors.white12 : Colors.black12,
            ),
            const SizedBox(height: 8),

            // Menu items
            _DrawerMenuItem(
              icon: Icons.assignment_outlined,
              label: context.l10n.drawerMyTasks,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/profile/my-tasks');
              },
            ),
            _DrawerMenuItem(
              icon: Icons.account_balance_wallet_outlined,
              label: context.l10n.drawerMyWallet,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/wallet');
              },
            ),
            _DrawerMenuItem(
              icon: Icons.settings_outlined,
              label: context.l10n.drawerSettings,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/settings');
              },
            ),
            _DrawerMenuItem(
              icon: Icons.help_outline,
              label: context.l10n.drawerHelpFeedback,
              onTap: () {
                Navigator.of(context).pop();
                context.push('/support-chat');
              },
            ),

            const Spacer(),

            // Footer: app version
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                'LinkU',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 桌面端分段按钮（Notion 风格）
class _DesktopSegmentButton extends StatefulWidget {
  const _DesktopSegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  @override
  State<_DesktopSegmentButton> createState() => _DesktopSegmentButtonState();
}

class _DesktopSegmentButtonState extends State<_DesktopSegmentButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: widget.label,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
            decoration: BoxDecoration(
              color: widget.isSelected
                ? (widget.isDark ? AppColors.secondaryBackgroundDark : AppColors.cardBackgroundLight)
                : (_isHovered
                    ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent),
            borderRadius: AppRadius.allSmall,
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? (widget.isDark ? AppColors.textPrimaryDark : AppColors.desktopTextLight)
                  : (widget.isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.desktopPlaceholderLight),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// 移动端 TabButton — 简化动画：去掉 AnimatedScale + BoxShadow 动画
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

    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
              style: AppTypography.body.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                    : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
              ),
            ),
            const SizedBox(height: 6),
            // 保留指示器宽度动画，去掉 BoxShadow 动画
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              height: 3,
              width: isSelected ? 28 : 0,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.allPill,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}

// ==================== 关注 Tab ====================
class _FollowTab extends StatelessWidget {
  const _FollowTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (p, c) =>
          p.followFeedItems != c.followFeedItems ||
          p.isLoadingFollowFeed != c.isLoadingFollowFeed ||
          (c.followFeedItems.isEmpty && p.discoveryItems != c.discoveryItems),
      builder: (context, state) {
        if (state.isLoadingFollowFeed && state.followFeedItems.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }

        // 有关注内容时显示关注 feed，否则显示空状态引导 + 热门动态
        final hasFollowContent = state.followFeedItems.isNotEmpty;
        final displayItems = hasFollowContent
            ? state.followFeedItems
            : state.discoveryItems;
        final hasMore = hasFollowContent ? state.hasMoreFollowFeed : false;

        if (displayItems.isEmpty) {
          // 空状态：支持下拉刷新重试
          return RefreshIndicator(
            onRefresh: () async {
              final bloc = context.read<HomeBloc>();
              bloc.add(const HomeLoadFollowFeed());
              await bloc.stream.firstWhere(
                (s) => !s.isLoadingFollowFeed,
                orElse: () => state,
              );
            },
            child: CustomScrollView(
              slivers: [
                SliverFillRemaining(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            context.l10n.homeFollowEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            final bloc = context.read<HomeBloc>();
            bloc.add(const HomeLoadFollowFeed());
            await bloc.stream.firstWhere(
              (s) => !s.isLoadingFollowFeed,
              orElse: () => state,
            );
          },
          child: CustomScrollView(
            slivers: [
              // 未关注时的提示标题 + 热门 fallback
              if (!hasFollowContent) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      context.l10n.homeFollowEmpty,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department,
                            size: 18, color: Colors.orange[600]),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.homeTrending,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              // Feed 列表
              SliverPadding(
                padding: const EdgeInsets.all(8),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index == displayItems.length) {
                        if (hasFollowContent) {
                          context.read<HomeBloc>().add(
                              const HomeLoadFollowFeed(loadMore: true));
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      }
                      final item = displayItems[index];
                      final locale = Localizations.localeOf(context);
                      return _FollowFeedCard(key: ValueKey(item.id), item: item, locale: locale);
                    },
                    childCount: displayItems.length + (hasMore ? 1 : 0),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// _ActivitiesTab removed — activities accessible via Story row entry or dedicated page

/// 关注 Feed 卡片 — 社交动态风格（参考小红书关注 Tab）
class _FollowFeedCard extends StatelessWidget {
  const _FollowFeedCard({super.key, required this.item, required this.locale});
  final DiscoveryFeedItem item;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final title = item.displayTitle(locale);
    final description = item.displayDescription(locale);
    final timeAgo = item.createdAt != null
        ? DateFormatter.formatRelative(item.createdAt!, l10n: l10n)
        : '';
    final feedLabel = _feedTypeLabel(item.feedType, l10n);

    return Semantics(
      button: true,
      label: 'View $feedLabel',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: GestureDetector(
          onTap: () => _onCardTap(context),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: isDark
                  ? null
                  : [BoxShadow(color: Colors.black.withAlpha(10), blurRadius: 3, offset: const Offset(0, 1))],
            ),
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 头部：头像 + 名字 + 时间 + 类型标签 ──
                Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundImage: item.userAvatar != null && item.userAvatar!.isNotEmpty
                          ? NetworkImage(item.userAvatar!)
                          : null,
                      backgroundColor: isDark ? Colors.grey[800] : const Color(0xFFE8E8E8),
                      onBackgroundImageError: item.userAvatar != null && item.userAvatar!.isNotEmpty
                          ? (_, __) {}
                          : null,
                      child: item.userAvatar == null || item.userAvatar!.isEmpty
                          ? Icon(Icons.person, size: 18, color: isDark ? Colors.grey[400] : Colors.grey[600])
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  item.userName ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                feedLabel,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF999999),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            timeAgo,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textTertiaryDark : const Color(0xFFBBBBBB),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _FeedTypeBadge(feedType: item.feedType),
                  ],
                ),

                const SizedBox(height: 10),

                // ── 内容区 ──
                if (title.isNotEmpty)
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : const Color(0xFF222222),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (description != null && description.isNotEmpty && description != title) ...[
                  SizedBox(height: title.isNotEmpty ? 4 : 0),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF666666),
                      height: 1.5,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],

                // ── 任务信息条：类型 + 赏金 + 申请人数 ──
                if (item.feedType == 'task') ...[
                  const SizedBox(height: 8),
                  _buildTaskInfoRow(l10n, isDark),
                ],

                // ── 服务信息条：分类 + 价格 ──
                if (item.feedType == 'service') ...[
                  const SizedBox(height: 8),
                  _buildServiceInfoRow(l10n, isDark),
                ],

                // ── 活动信息条：参与人数 + 价格 ──
                if (item.feedType == 'activity' && item.activityInfo != null) ...[
                  const SizedBox(height: 8),
                  _buildActivityInfoRow(l10n, isDark),
                ],

                // ── 商品价格 ──
                if (item.feedType == 'product' && item.price != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '£${item.price!.toStringAsFixed(item.price! == item.price!.roundToDouble() ? 0 : 2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFFEE5A24)),
                  ),
                ],

                // ── 评价目标（竞品评价/服务评价）──
                if (item.targetItem != null &&
                    (item.feedType == 'competitor_review' || item.feedType == 'service_review')) ...[
                  const SizedBox(height: 8),
                  _buildTargetItemRow(isDark),
                ],

                // ── 服务评价：评分星级 ──
                if (item.feedType == 'service_review' && item.rating != null) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: List.generate(5, (i) => Icon(
                      i < item.rating!.round() ? Icons.star_rounded : Icons.star_border_rounded,
                      size: 16,
                      color: const Color(0xFFFFB300),
                    )),
                  ),
                ],

                // ── 排行榜 TOP 3 ──
                if (item.feedType == 'ranking' && item.top3 != null && item.top3!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _buildTop3List(l10n, isDark),
                ],

                // ── 图片 ──
                if (item.hasImages) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildImages(item.images!, isDark),
                  ),
                ],

                // ── 底部互动数据 ──
                if (_hasBottomMetrics) ...[
                  const SizedBox(height: 10),
                  _buildBottomMetrics(isDark),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 任务信息行 ──
  Widget _buildTaskInfoRow(AppLocalizations l10n, bool isDark) {
    final taskType = item.taskType;
    final appCount = item.applicationCount ?? 0;
    final reward = item.price;
    final quoted = item.rewardToBeQuoted == true;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (taskType != null && taskType.isNotEmpty)
          _InfoChip(
            icon: Icons.category_outlined,
            label: TaskTypeHelper.getLocalizedLabel(taskType, l10n),
            isDark: isDark,
          ),
        if (reward != null && reward > 0)
          _InfoChip(
            icon: Icons.paid_outlined,
            label: '£${reward.toStringAsFixed(0)}',
            isDark: isDark,
            highlight: true,
          )
        else if (quoted)
          _InfoChip(icon: Icons.paid_outlined, label: l10n.taskRewardToBeQuoted, isDark: isDark),
        if (appCount > 0)
          _InfoChip(
            icon: Icons.people_outline,
            label: l10n.nearbyApplicants(appCount),
            isDark: isDark,
          ),
      ],
    );
  }

  // ── 服务信息行 ──
  Widget _buildServiceInfoRow(AppLocalizations l10n, bool isDark) {
    final category = item.extraData?['category'] as String?;
    final price = item.price;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (category != null && category.isNotEmpty)
          _InfoChip(
            icon: ServiceCategoryHelper.getIcon(category),
            label: ServiceCategoryHelper.getLocalizedLabel(category, l10n),
            isDark: isDark,
          ),
        if (price != null && price > 0)
          _InfoChip(
            icon: Icons.paid_outlined,
            label: '£${price.toStringAsFixed(0)}',
            isDark: isDark,
            highlight: true,
          ),
      ],
    );
  }

  // ── 活动信息行 ──
  Widget _buildActivityInfoRow(AppLocalizations l10n, bool isDark) {
    final info = item.activityInfo!;
    final price = item.price;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (info.currentParticipants != null)
          _InfoChip(
            icon: Icons.people_outline,
            label: '${info.currentParticipants}/${info.maxParticipants ?? '∞'}',
            isDark: isDark,
          ),
        if (price != null && price > 0)
          _InfoChip(
            icon: Icons.paid_outlined,
            label: '£${price.toStringAsFixed(0)}',
            isDark: isDark,
            highlight: true,
          )
        else
          _InfoChip(
            icon: Icons.volunteer_activism_outlined,
            label: l10n.homeActivityFree,
            isDark: isDark,
            color: const Color(0xFF4CAF50),
          ),
      ],
    );
  }

  // ── 评价目标 ──
  Widget _buildTargetItemRow(bool isDark) {
    final target = item.targetItem!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : const Color(0xFFF7F7F8),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (target.thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.network(
                target.thumbnail!,
                width: 36, height: 36, fit: BoxFit.cover, cacheWidth: 72,
                errorBuilder: (_, __, ___) => const SizedBox(width: 36, height: 36),
              ),
            ),
          if (target.thumbnail != null) const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.name ?? '',
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
                if (target.subtitle != null)
                  Text(
                    target.subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textTertiaryDark : const Color(0xFF999999),
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (item.feedType == 'competitor_review' && item.voteType != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: item.voteType == 'upvote'
                    ? const Color(0xFF4CAF50).withAlpha(25)
                    : const Color(0xFFE53935).withAlpha(25),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.voteType == 'upvote' ? Icons.thumb_up_alt_rounded : Icons.thumb_down_alt_rounded,
                    size: 12,
                    color: item.voteType == 'upvote' ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    item.voteType == 'upvote' ? 'UP' : 'DOWN',
                    style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: item.voteType == 'upvote' ? const Color(0xFF4CAF50) : const Color(0xFFE53935),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── 排行榜 TOP 3 ──
  Widget _buildTop3List(AppLocalizations l10n, bool isDark) {
    final top3 = item.top3!.take(3).toList();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(8) : const Color(0xFFFAF9FF),
        borderRadius: BorderRadius.circular(8),
        border: isDark ? null : Border.all(color: const Color(0xFFEEECF9), width: 0.5),
      ),
      child: Column(
        children: top3.asMap().entries.map((entry) {
          final rank = entry.key + 1;
          final data = entry.value;
          final name = data['name']?.toString() ?? '';
          final votes = (data['rating'] as num?)?.toInt() ?? 0;
          final image = data['image'] as String?;
          return Padding(
            padding: EdgeInsets.only(top: entry.key > 0 ? 6 : 0),
            child: Row(
              children: [
                Text(
                  rank == 1 ? '🥇' : rank == 2 ? '🥈' : '🥉',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(width: 6),
                if (image != null && image.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      image, width: 24, height: 24, fit: BoxFit.cover, cacheWidth: 48,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 24, height: 24),
                    ),
                  ),
                if (image != null && image.isNotEmpty) const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  l10n.leaderboardNetVotesCount(votes),
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? AppColors.textTertiaryDark : const Color(0xFF999999),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── 底部指标 ──
  bool get _hasBottomMetrics {
    if (item.feedType == 'competitor_review') {
      return (item.upvoteCount ?? 0) > 0 || (item.downvoteCount ?? 0) > 0 || (item.likeCount ?? 0) > 0;
    }
    return (item.likeCount ?? 0) > 0 || (item.commentCount ?? 0) > 0;
  }

  Widget _buildBottomMetrics(bool isDark) {
    final metricStyle = TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : const Color(0xFF999999));
    if (item.feedType == 'competitor_review') {
      return Row(
        children: [
          if ((item.upvoteCount ?? 0) > 0)
            Text('👍 ${item.upvoteCount}', style: metricStyle),
          if ((item.upvoteCount ?? 0) > 0 && (item.downvoteCount ?? 0) > 0)
            const SizedBox(width: 12),
          if ((item.downvoteCount ?? 0) > 0)
            Text('👎 ${item.downvoteCount}', style: metricStyle),
          if ((item.likeCount ?? 0) > 0) ...[
            const SizedBox(width: 12),
            Text('❤️ ${item.likeCount}', style: metricStyle),
          ],
        ],
      );
    }
    return Row(
      children: [
        if ((item.likeCount ?? 0) > 0) ...[
          Text('❤️ ${item.likeCount}', style: metricStyle),
          const SizedBox(width: 16),
        ],
        if ((item.commentCount ?? 0) > 0)
          Text('💬 ${item.commentCount}', style: metricStyle),
      ],
    );
  }

  Widget _buildImages(List<String> images, bool isDark) {
    final validImages = images.where((url) => url.isNotEmpty).toList();
    if (validImages.isEmpty) return const SizedBox.shrink();

    if (validImages.length == 1) {
      return AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          validImages.first,
          fit: BoxFit.cover,
          width: double.infinity,
          cacheWidth: 600,
          errorBuilder: (_, __, ___) => Container(
            color: isDark ? Colors.grey[800] : const Color(0xFFF0F0F0),
            child: const Center(child: Icon(Icons.image, color: Colors.grey)),
          ),
        ),
      );
    }

    return Row(
      children: validImages.take(3).map((url) {
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 3),
            child: AspectRatio(
              aspectRatio: 1,
              child: Image.network(
                url,
                fit: BoxFit.cover,
                cacheWidth: 300,
                errorBuilder: (_, __, ___) => Container(
                  color: isDark ? Colors.grey[800] : const Color(0xFFF0F0F0),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onCardTap(BuildContext context) {
    switch (item.feedType) {
      case 'task':
        final taskId = item.id.replaceFirst('task_', '');
        if (taskId.isNotEmpty) context.push('/tasks/$taskId');
      case 'forum_post':
        final postId = item.id.replaceFirst('post_', '');
        if (postId.isNotEmpty) context.push('/forum/posts/$postId');
      case 'product':
        final productId = item.id.replaceFirst('product_', '');
        if (productId.isNotEmpty) context.push('/flea-market/$productId');
      case 'service':
        final serviceId = item.id.replaceFirst('service_', '');
        if (serviceId.isNotEmpty) context.push('/service/$serviceId');
      case 'activity':
        final activityId = item.id.replaceFirst('activity_', '');
        if (activityId.isNotEmpty) context.push('/activities/$activityId');
      case 'completion':
        final taskId = item.extraData?['task_id']?.toString();
        if (taskId != null && taskId.isNotEmpty) context.push('/tasks/$taskId');
      case 'competitor_review':
        if (item.targetItem != null) {
          context.push('/leaderboard/item/${item.targetItem!.itemId}');
        }
      case 'service_review':
        if (item.targetItem != null) {
          context.push('/service/${item.targetItem!.itemId}');
        }
      case 'ranking':
        final id = item.id.replaceFirst('ranking_', '');
        if (id.isNotEmpty) context.push('/leaderboard/$id');
      default:
        break;
    }
  }

  String _feedTypeLabel(String feedType, AppLocalizations l10n) {
    switch (feedType) {
      case 'task': return l10n.feedLabelPublishedTask;
      case 'forum_post': return l10n.feedLabelPosted;
      case 'product': return l10n.feedLabelListedItem;
      case 'service': return l10n.feedLabelNewService;
      case 'activity': return l10n.feedLabelCreatedActivity;
      case 'completion': return l10n.feedLabelCompletedTask;
      case 'competitor_review': return l10n.feedLabelReviewedCompetitor;
      case 'service_review': return l10n.feedLabelReviewedService;
      case 'ranking': return l10n.feedLabelCreatedRanking;
      default: return l10n.feedLabelUpdated;
    }
  }
}

/// 信息标签（任务类型、价格、分类等）
class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.isDark,
    this.highlight = false,
    this.color,
  });
  final IconData icon;
  final String label;
  final bool isDark;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? (highlight
        ? const Color(0xFFEE5A24)
        : isDark ? AppColors.textSecondaryDark : const Color(0xFF666666));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withAlpha(10) : fg.withAlpha(12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: fg),
          const SizedBox(width: 3),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
        ],
      ),
    );
  }
}

class _DrawerMenuItem extends StatelessWidget {
  const _DrawerMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListTile(
      leading: Icon(icon, size: 22,
          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
      title: Text(label,
        style: TextStyle(fontSize: 15,
          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}

