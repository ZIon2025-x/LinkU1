import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/utils/haptic_feedback.dart';
import '../../core/utils/l10n_extension.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/badge_view.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/desktop_sidebar.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/common_repository.dart';
import '../../data/repositories/discovery_repository.dart';
import '../../data/repositories/forum_repository.dart';
import '../../data/repositories/leaderboard_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/task_repository.dart';
import '../auth/bloc/auth_bloc.dart';
import '../forum/bloc/forum_bloc.dart';
import '../home/bloc/home_bloc.dart';
import '../home/bloc/home_event.dart';
import '../leaderboard/bloc/leaderboard_bloc.dart';
import '../message/bloc/message_bloc.dart';
import '../notification/bloc/notification_bloc.dart';

/// 主页面（响应式导航布局）
/// - 移动端：底部导航栏
/// - 桌面/平板端：TopBar + 右侧 Overlay Drawer + 全宽内容
///
/// 使用 StatefulShellRoute.indexedStack 原生保持各分支 State
class MainTabView extends StatefulWidget {
  const MainTabView({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView>
    with WidgetsBindingObserver {
  final _desktopScaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _loadedTabs = {0}; // 首页默认加载
  /// 桌面端汉堡菜单是否展开（对齐 frontend：遮罩+面板 overlay，不用 Drawer 避免 elevation 阴影随 hover 晃动）
  bool _showDesktopMenu = false;

  // StatefulShellRoute branch index ↔ 移动端 Tab index 映射
  // Branch: [0=home, 1=community, 2=messages, 3=profile]
  // Mobile: [0=home, 1=community, 2=create, 3=messages, 4=profile]
  static const _branchToMobileTab = [0, 1, 3, 4];
  static const _mobileTabToBranch = {0: 0, 1: 1, 3: 2, 4: 3};

  /// 当前移动端 Tab 索引（从 branch index 映射）
  int get _currentIndex {
    final branchIndex = widget.navigationShell.currentIndex;
    return branchIndex < _branchToMobileTab.length
        ? _branchToMobileTab[branchIndex]
        : 0;
  }

  // Tab 级别的 BLoC 实例（全部在 didChangeDependencies 中创建）
  // 通过 BlocProvider.value 提供，确保 State context 也能直接访问
  late final HomeBloc _homeBloc;
  late final ForumBloc _forumBloc;
  late final LeaderboardBloc _leaderboardBloc;
  late final MessageBloc _messageBloc;
  bool _blocsInitialized = false;

  // 移动端底部导航栏的 tab 配置（包含中间 create 按钮）
  final List<_TabItem> _mobileTabs = const [
    _TabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'home',
      route: '/',
    ),
    _TabItem(
      icon: Icons.groups_outlined,
      activeIcon: Icons.groups,
      label: 'community',
      route: '/community',
    ),
    _TabItem(
      icon: Icons.add_circle_outline,
      activeIcon: Icons.add_circle,
      label: '',
      route: '/tasks/create',
      isCenter: true,
    ),
    _TabItem(
      icon: Icons.message_outlined,
      activeIcon: Icons.message,
      label: 'messages',
      route: '/messages-tab',
    ),
    _TabItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person,
      label: 'profile',
      route: '/profile-tab',
    ),
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_blocsInitialized) {
      final authState = context.read<AuthBloc>().state;
      // 仅 HomeBloc 立即创建并加载数据（首页默认展示）
      _homeBloc = HomeBloc(
        taskRepository: context.read<TaskRepository>(),
        activityRepository: context.read<ActivityRepository>(),
        commonRepository: context.read<CommonRepository>(),
        discoveryRepository: context.read<DiscoveryRepository>(),
      )
        ..currentUser = authState.isAuthenticated ? authState.user : null
        ..add(const HomeLoadRequested())
        ..add(const HomeLoadDiscoveryFeed());
      // 其他 Tab BLoC 也在此创建，通过字段引用访问，避免 context.read 找不到 Provider
      _forumBloc = ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      );
      _leaderboardBloc = LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      );
      _messageBloc = MessageBloc(
        messageRepository: context.read<MessageRepository>(),
      );
      // 已登录时拉未读数 + 聊天列表并启动 60s 轮询（对标 iOS startPeriodicRefresh + 列表）
      if (authState.isAuthenticated) {
        _messageBloc.add(const MessageFetchUnreadCount());
        _messageBloc.add(const MessageLoadTaskChats());
        _messageBloc.add(const MessageStartPolling());
      }
      _blocsInitialized = true;
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _blocsInitialized && mounted) {
      final authState = context.read<AuthBloc>().state;
      if (authState.isAuthenticated) {
        // 对标 iOS：进入前台先拉未读 API 再拉列表，角标实时更新
        _messageBloc.add(const MessageFetchUnreadCount());
        _messageBloc.add(const MessageLoadTaskChats());
      }
    }
  }

  @override
  void dispose() {
    if (_blocsInitialized) {
      WidgetsBinding.instance.removeObserver(this);
    }
    if (_blocsInitialized) {
      _homeBloc.close();
      _forumBloc.close();
      _leaderboardBloc.close();
      _messageBloc.close();
    }
    super.dispose();
  }

  String get _currentRoute {
    if (_currentIndex == 2) return '/'; // center button
    if (_currentIndex < 2) return _mobileTabs[_currentIndex].route;
    return _mobileTabs[_currentIndex].route;
  }

  void _onMobileTabTapped(int index) {
    if (_mobileTabs[index].isCenter) {
      AppHaptics.medium();
      _showCreateOptions();
      return;
    }

    if (index == _currentIndex) {
      // 重复点击当前 Tab → Scroll-to-Top（对标 iOS tab bar re-tap 行为）
      AppHaptics.selection();
      _scrollCurrentTabToTop();
      return;
    }

    AppHaptics.tabSwitch();
    final branchIndex = _mobileTabToBranch[index];
    if (branchIndex != null) {
      widget.navigationShell.goBranch(
        branchIndex,
        initialLocation: branchIndex == widget.navigationShell.currentIndex,
      );
    }
    _ensureTabLoaded(index);
  }

  /// 滚动当前 Tab 到顶部
  void _scrollCurrentTabToTop() {
    // 通过发送一个专用事件或直接找到 PrimaryScrollController 来滚动
    final scrollController = PrimaryScrollController.maybeOf(context);
    if (scrollController != null && scrollController.hasClients) {
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  /// 确保 Tab 对应的 BLoC 数据已加载（懒加载数据）
  /// BLoC 实例由 BlocProvider(lazy: true) 在首次 context.read 时创建
  /// 此方法仅负责触发数据加载事件
  void _ensureTabLoaded(int index) {
    final wasAlreadyLoaded = _loadedTabs.contains(index);
    _loadedTabs.add(index);

    // 根据 tab index 触发对应 BLoC 数据加载
    switch (index) {
      case 0: // Home
        if (!wasAlreadyLoaded) {
          _homeBloc.add(const HomeLoadRequested());
          _homeBloc.add(const HomeLoadDiscoveryFeed());
        }
        break;
      case 1: // Community (Forum) — 首次切到社区 Tab 时触发加载
        if (!wasAlreadyLoaded) {
          _forumBloc.add(const ForumLoadCategories());
          _leaderboardBloc.add(const LeaderboardLoadRequested());
        }
        break;
      case 3: // Messages — 每次切到消息 Tab 都刷新未读，便于实时更新红点
        _messageBloc
          ..add(const MessageLoadContacts())
          ..add(const MessageLoadTaskChats());
        context.read<NotificationBloc>()
            .add(const NotificationLoadUnreadNotificationCount());
        break;
      case 4: // Profile — no BLoC here at this level
        break;
    }
  }

  void _onDesktopNavigate(String route) {
    // 查找匹配的移动端 tab 索引
    final mobileIndex = _mobileTabs.indexWhere((t) => t.route == route);
    if (mobileIndex >= 0 && mobileIndex != _currentIndex) {
      final branchIndex = _mobileTabToBranch[mobileIndex];
      if (branchIndex != null) {
        widget.navigationShell.goBranch(branchIndex);
        _ensureTabLoaded(mobileIndex);
      }
    } else if (mobileIndex < 0) {
      // 非主 tab 路由，直接 push
      context.push(route);
    }
  }

  void _showCreateOptions() {
    final authState = context.read<AuthBloc>().state;

    if (!authState.isAuthenticated) {
      context.push('/login');
      return;
    }

    // 直接进入统一发布页（从底部滑入）
    context.push('/publish');
  }

  @override
  Widget build(BuildContext context) {
    // Tab 级别的 BLoC 提升到此处，切换 Tab 时不再重建
    // HomeBloc 始终存在（首页默认展示）
    // 其他 BLoC lazy: true（默认），首次 context.read 时才创建实例
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>.value(value: _homeBloc),
        BlocProvider<ForumBloc>.value(value: _forumBloc),
        BlocProvider<LeaderboardBloc>.value(value: _leaderboardBloc),
        BlocProvider<MessageBloc>.value(value: _messageBloc),
      ],
      child: BlocListener<AuthBloc, AuthState>(
        listenWhen: (prev, curr) =>
            prev.isAuthenticated != curr.isAuthenticated,
        listener: (context, state) {
          if (state.isAuthenticated) {
            _messageBloc.add(const MessageLoadTaskChats());
            _messageBloc.add(const MessageStartPolling());
          } else {
            _messageBloc.add(const MessageStopPolling());
          }
        },
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= Breakpoints.mobile) {
              return _buildDesktopLayout(context);
            }
            return _buildMobileLayout(context);
          },
        ),
      ),
    );
  }

  // ==================== 桌面/平板布局 ====================
  /// 对齐 frontend：遮罩 + 固定右侧面板，面板用 CSS box-shadow 静态阴影（-4px 0 32px rgba(0,0,0,0.15)），
  /// 指针在菜单项间移动时不会触发阴影重绘，避免晃动。
  Widget _buildDesktopLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _desktopScaffoldKey,
      body: Stack(
        children: [
          Column(
            children: [
              _DesktopTopBar(
                isDark: isDark,
                onMenuTap: () => setState(() => _showDesktopMenu = true),
              ),
              Expanded(child: widget.navigationShell),
            ],
          ),
          if (_showDesktopMenu) _desktopMenuOverlay(
            currentRoute: _currentRoute,
            onNavigate: _onDesktopNavigate,
            onClose: () => setState(() => _showDesktopMenu = false),
          ),
        ],
      ),
    );
  }

  // ==================== 桌面菜单浮层（对齐 frontend 遮罩 + 静态 box-shadow 面板） ====================
  static Widget _desktopMenuOverlay({
    required String currentRoute,
    required ValueChanged<String> onNavigate,
    required VoidCallback onClose,
  }) {
    return Positioned.fill(
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.black54,
            ),
          ),
          Material(
            color: Colors.transparent,
            child: Container(
              width: Breakpoints.drawerWidth,
              decoration: BoxDecoration(
                color: Colors.transparent,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    offset: const Offset(-4, 0),
                    blurRadius: 32,
                  ),
                ],
              ),
              child: DesktopDrawer(
                currentRoute: currentRoute,
                onNavigate: onNavigate,
                onClose: onClose,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 移动端布局 ====================
  Widget _buildMobileLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      extendBody: true,
      body: widget.navigationShell,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
              color: isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.cardBackgroundLight,
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                  width: 0.5,
                ),
              ),
            ),
            child: SafeArea(
              child: SizedBox(
                height: 60,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(_mobileTabs.length, (index) {
                    final tab = _mobileTabs[index];
                    final isSelected = index == _currentIndex;

                    if (tab.isCenter) {
                      return _buildCenterButton();
                    }

                    return _buildMobileTabItem(
                      tab: tab,
                      isSelected: isSelected,
                      index: index,
                    );
                  }),
                ),
              ),
            ),
    ),
    );
  }

  Widget _buildMobileTabItem({
    required _TabItem tab,
    required bool isSelected,
    required int index,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final unselectedColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondaryLight;

    Widget iconWidget;
    if (index == 3) {
      iconWidget = RepaintBoundary(
        child: _NotificationTabIcon(
          tab: tab,
          isSelected: isSelected,
          selectedColor: AppColors.primary,
          unselectedColor: unselectedColor,
        ),
      );
    } else {
      final icon = Icon(
        isSelected ? tab.activeIcon : tab.icon,
        size: 24,
        color: isSelected ? Colors.white : unselectedColor,
      );
      iconWidget = isSelected
          ? ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              blendMode: BlendMode.srcIn,
              child: icon,
            )
          : icon;
    }

    return Expanded(
      child: Semantics(
        label: _getTabLabel(context, tab.label),
        button: true,
        child: GestureDetector(
          onTap: () => _onMobileTabTapped(index),
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: isSelected ? 1.1 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: iconWidget,
                ),
                const SizedBox(height: 4),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  width: isSelected ? 4 : 0,
                  height: isSelected ? 4 : 0,
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(colors: AppColors.gradientPrimary)
                        : null,
                    shape: BoxShape.circle,
                  ),
                ),
                AnimatedOpacity(
                  opacity: isSelected ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 150),
                  child: AnimatedSlide(
                    offset: isSelected ? const Offset(0, -0.3) : Offset.zero,
                    duration: const Duration(milliseconds: 150),
                    child: Text(
                      _getTabLabel(context, tab.label),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                        color: unselectedColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    // RepaintBoundary 隔离脉冲动画的重绘区域，避免动画帧导致整个底部导航栏重绘
    return RepaintBoundary(
      child: Semantics(
        label: context.l10n.publishTitle,
        button: true,
        child: _PulsingCenterButton(
          onTap: () => _onMobileTabTapped(2),
        ),
      ),
    );
  }

  String _getTabLabel(BuildContext context, String key) {
    if (key.isEmpty) return '';
    final l10n = context.l10n;
    switch (key) {
      case 'home':
        return l10n.tabsHome;
      case 'community':
        return l10n.tabsCommunity;
      case 'messages':
        return l10n.tabsMessages;
      case 'profile':
        return l10n.tabsProfile;
      default:
        return key;
    }
  }
}

// ==================== TopBar ====================

/// 桌面端顶部导航栏
/// Notion/Linear 风格：Logo + 搜索框 + 通知 + 汉堡菜单
class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.isDark,
    required this.onMenuTap,
  });

  final bool isDark;
  final VoidCallback onMenuTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
        border: isDark
            ? Border(
                bottom: BorderSide(
                  color: Colors.white.withValues(alpha: 0.06),
                ),
              )
            : null,
      ),
      // 内容居中约束在 maxContentWidth 内，对齐 frontend Header
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: Breakpoints.maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
        children: [
          // Logo
          GestureDetector(
            onTap: () => context.go('/'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 28,
                  height: 28,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(7),
                      gradient: const LinearGradient(
                        colors: AppColors.gradientPrimary,
                      ),
                    ),
                    child: const Center(
                      child: Text('L',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Link²Ur',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.desktopTextLight,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 32),

          // 搜索框
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: GestureDetector(
                  onTap: () => context.push('/search'),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.06)
                            : AppColors.desktopHoverLight,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : AppColors.desktopBorderLight,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            size: 18,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.desktopPlaceholderLight,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            context.l10n.searchPlaceholder,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.desktopPlaceholderLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // 通知铃铛
          BlocBuilder<NotificationBloc, NotificationState>(
            // 仅在未读总数变化时重建铃铛按钮
            buildWhen: (prev, curr) =>
                prev.unreadCount.totalCount != curr.unreadCount.totalCount,
            builder: (context, state) {
              final count = state.unreadCount.totalCount;
              return _TopBarIconButton(
                icon: Icons.notifications_outlined,
                isDark: isDark,
                badge: count > 0 ? count : null,
                onTap: () => context.push('/notifications'),
              );
            },
          ),

          const SizedBox(width: 4),

          // 汉堡菜单（对齐 frontend 渐变三线风格）
          _GradientHamburgerButton(
            isDark: isDark,
            onTap: onMenuTap,
          ),
        ],
      ),
          ),
        ),
      ),
    );
  }
}

/// TopBar 图标按钮（带 hover 效果）
class _TopBarIconButton extends StatefulWidget {
  const _TopBarIconButton({
    required this.icon,
    required this.isDark,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final int? badge;

  @override
  State<_TopBarIconButton> createState() => _TopBarIconButtonState();
}

class _TopBarIconButtonState extends State<_TopBarIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.desktopHoverLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                widget.icon,
                size: 22,
                color: widget.isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.desktopTextLight,
              ),
              if (widget.badge != null)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.badgeRed,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    this.isCenter = false,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final bool isCenter;
}

/// 消息 Tab 图标 - 汇总所有未读数（通知 + 聊天）
/// 提取为独立组件，隔离 BlocBuilder 重建范围
class _NotificationTabIcon extends StatelessWidget {
  const _NotificationTabIcon({
    required this.tab,
    required this.isSelected,
    required this.selectedColor,
    required this.unselectedColor,
  });

  final _TabItem tab;
  final bool isSelected;
  final Color selectedColor;
  final Color unselectedColor;

  @override
  Widget build(BuildContext context) {
    // 监听通知未读数
    final notifUnread = context.select<NotificationBloc, int>(
      (bloc) => bloc.state.unreadCount.totalCount,
    );
    // 监听任务聊天未读（对标 iOS：角标用 API 未读数或列表汇总，实现实时红点）
    final chatUnread = context.select<MessageBloc, int>(
      (bloc) => bloc.state.taskChatUnreadForBadge,
    );
    final totalUnread = notifUnread + chatUnread;

    return IconWithBadge(
      icon: isSelected ? tab.activeIcon : tab.icon,
      count: totalUnread,
      iconColor: isSelected ? selectedColor : unselectedColor,
    );
  }
}

/// 渐变汉堡菜单按钮（对齐 frontend .hamburger-btn 风格）
/// 三条渐变色线 + gradient-shift 动画
class _GradientHamburgerButton extends StatefulWidget {
  const _GradientHamburgerButton({
    required this.isDark,
    required this.onTap,
  });

  final bool isDark;
  final VoidCallback onTap;

  @override
  State<_GradientHamburgerButton> createState() =>
      _GradientHamburgerButtonState();
}

class _GradientHamburgerButtonState extends State<_GradientHamburgerButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animController;
  bool _isHovered = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: _isHovered
                ? (widget.isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : AppColors.desktopHoverLight)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: SizedBox(
              width: 22,
              height: 16,
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildLine(0),
                      _buildLine(1),
                      _buildLine(2),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLine(int index) {
    // 对齐 frontend: gradient-shift 动画 — 渐变流动
    // 三条线略有偏移以产生交错效果
    final offset = _animController.value + (index * 0.15);
    final normalizedOffset = offset - offset.floor();

    return Container(
      width: double.infinity,
      height: 2,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(1),
        gradient: LinearGradient(
          colors: const [
            Color(0xFFFF6B6B),
            Color(0xFF4ECDC4),
            Color(0xFF45B7D1),
            Color(0xFFFF6B6B),
          ],
          stops: const [0.0, 0.33, 0.66, 1.0],
          begin: Alignment(-1 + 2 * normalizedOffset, 0),
          end: Alignment(1 + 2 * normalizedOffset, 0),
        ),
      ),
    );
  }
}

/// 中间创建按钮 — 静态渐变样式，按压时有缩放反馈
/// 移除持续脉冲动画（AnimationController.repeat + BoxShadow 动画每帧重绘，性能开销大）
class _PulsingCenterButton extends StatelessWidget {
  const _PulsingCenterButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ScaleTapWrapper(
      scaleDown: 0.9,
      onTap: onTap,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientPrimary,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Icon(
          Icons.add,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
