import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/utils/l10n_extension.dart';
import '../../core/utils/responsive.dart';
import '../../core/widgets/badge_view.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/content_constraint.dart';
import '../../core/widgets/desktop_sidebar.dart';
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
class MainTabView extends StatefulWidget {
  const MainTabView({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<MainTabView> createState() => _MainTabViewState();
}

class _MainTabViewState extends State<MainTabView> {
  int _currentIndex = 0;
  final _desktopScaffoldKey = GlobalKey<ScaffoldState>();
  final Set<int> _loadedTabs = {0}; // 首页默认加载

  // Tab 级别的 BLoC 实例（在 didChangeDependencies 中初始化）
  // 提前创建并持有引用，避免通过 State.context 查找 MultiBlocProvider 内部的 Provider
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
      _homeBloc = HomeBloc(
        taskRepository: context.read<TaskRepository>(),
      )..add(const HomeLoadRequested()); // 首页默认加载
      _forumBloc = ForumBloc(
        forumRepository: context.read<ForumRepository>(),
      );
      _leaderboardBloc = LeaderboardBloc(
        leaderboardRepository: context.read<LeaderboardRepository>(),
      );
      _messageBloc = MessageBloc(
        messageRepository: context.read<MessageRepository>(),
      );
      _blocsInitialized = true;
    }
  }

  @override
  void dispose() {
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
      HapticFeedback.mediumImpact();
      _showCreateOptions();
      return;
    }

    if (index != _currentIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex = index;
      });
      _ensureTabLoaded(index);
      context.go(_mobileTabs[index].route);
    }
  }

  /// 确保 Tab 对应的 BLoC 数据已加载（懒加载）
  /// 直接使用 BLoC 引用，避免通过 State.context 查找 MultiBlocProvider 内部的 Provider
  void _ensureTabLoaded(int index) {
    if (_loadedTabs.contains(index)) return;
    _loadedTabs.add(index);

    // 根据 tab index 触发对应 BLoC 数据加载
    switch (index) {
      case 0: // Home
        _homeBloc.add(const HomeLoadRequested());
        break;
      case 1: // Community (Forum)
        _forumBloc.add(const ForumLoadPosts());
        break;
      case 3: // Messages
        _messageBloc
          ..add(const MessageLoadContacts())
          ..add(const MessageLoadTaskChats());
        break;
      case 4: // Profile — no BLoC here at this level
        break;
    }
  }

  void _onDesktopNavigate(String route) {
    // 查找匹配的移动端 tab 索引
    final mobileIndex = _mobileTabs.indexWhere((t) => t.route == route);
    if (mobileIndex >= 0 && mobileIndex != _currentIndex) {
      setState(() {
        _currentIndex = mobileIndex;
      });
      context.go(route);
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

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreateOptionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 将 Tab 级别的 BLoC 提升到此处，切换 Tab 时不再重建
    // BLoC 在 didChangeDependencies 中创建，此处用 .value 提供给子树
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>.value(value: _homeBloc),
        BlocProvider<ForumBloc>.value(value: _forumBloc),
        BlocProvider<LeaderboardBloc>.value(value: _leaderboardBloc),
        BlocProvider<MessageBloc>.value(value: _messageBloc),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= Breakpoints.mobile) {
            return _buildDesktopLayout(context);
          }
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  // ==================== 桌面/平板布局 ====================
  Widget _buildDesktopLayout(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      key: _desktopScaffoldKey,
      endDrawer: DesktopDrawer(
        currentRoute: _currentRoute,
        onNavigate: _onDesktopNavigate,
      ),
      body: Column(
        children: [
          // TopBar
          _DesktopTopBar(
            isDark: isDark,
            onMenuTap: () {
              _desktopScaffoldKey.currentState?.openEndDrawer();
            },
          ),
          // 全宽内容区
          Expanded(
            child: ContentConstraint(
              child: widget.child,
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
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
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

    return Expanded(
      child: GestureDetector(
        onTap: () => _onMobileTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 消息Tab显示未读数
            if (index == 3)
              BlocBuilder<NotificationBloc, NotificationState>(
                builder: (context, notifState) {
                  final unreadCount = notifState.unreadCount.totalCount;
                  return IconWithBadge(
                    icon: isSelected ? tab.activeIcon : tab.icon,
                    count: unreadCount,
                    iconSize: 24,
                    iconColor: isSelected
                        ? AppColors.primary
                        : (isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight),
                  );
                },
              )
            else
              Icon(
                isSelected ? tab.activeIcon : tab.icon,
                size: 24,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            const SizedBox(height: 4),
            Text(
              _getTabLabel(context, tab.label),
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w500 : FontWeight.normal,
                color: isSelected
                    ? AppColors.primary
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterButton() {
    // 使用ScaleTapWrapper实现iOS FloatingButtonStyle的按压缩放效果(0.9)
    return ScaleTapWrapper(
      scaleDown: 0.9,
      onTap: () => _onMobileTabTapped(2),
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
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 15,
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
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.desktopBorderLight,
            width: 1,
          ),
        ),
      ),
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
                          width: 1,
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

          // 汉堡菜单
          _TopBarIconButton(
            icon: Icons.menu_rounded,
            isDark: isDark,
            onTap: onMenuTap,
          ),
        ],
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

/// 创建选项底部弹窗
class _CreateOptionsSheet extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 拖动指示器
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // 选项
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _CreateOption(
                icon: Icons.task_alt,
                label: context.l10n.createTaskPublishTask,
                color: AppColors.primary,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/tasks/create');
                },
              ),
              _CreateOption(
                icon: Icons.storefront,
                label: context.l10n.fleaMarketPublishItem,
                color: AppColors.accent,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/flea-market/create');
                },
              ),
              _CreateOption(
                icon: Icons.article,
                label: context.l10n.forumCreatePostTitle,
                color: AppColors.success,
                onTap: () {
                  Navigator.pop(context);
                  context.push('/forum/posts/create');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _CreateOption extends StatelessWidget {
  const _CreateOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }
}
