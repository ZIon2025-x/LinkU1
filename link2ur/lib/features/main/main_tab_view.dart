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
/// - 平板端：左侧收起侧边栏（NavigationRail 风格）
/// - 桌面端：左侧展开侧边栏 + 内容区宽度约束
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

  // 桌面/平板侧边栏的路由列表（不含 create 按钮，与侧边栏索引一一对应）
  final List<String> _sidebarRoutes = const [
    '/',
    '/community',
    '/messages-tab',
    '/profile-tab',
  ];

  /// 将移动端 tab 索引转换为侧边栏索引
  int get _sidebarIndex {
    // 移动端索引：0=首页, 1=社区, 2=创建, 3=消息, 4=个人
    // 侧边栏索引：0=首页, 1=社区, 2=消息, 3=个人
    if (_currentIndex <= 1) return _currentIndex;
    if (_currentIndex >= 3) return _currentIndex - 1;
    return 0; // create 按钮情况，默认回到首页
  }

  /// 将侧边栏索引转换为移动端 tab 索引
  int _sidebarToMobileIndex(int sidebarIndex) {
    // 侧边栏索引 0,1 对应移动端 0,1
    // 侧边栏索引 2,3 对应移动端 3,4（跳过中间 create 按钮）
    if (sidebarIndex <= 1) return sidebarIndex;
    return sidebarIndex + 1;
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
      context.go(_mobileTabs[index].route);
    }
  }

  void _onSidebarTabSelected(int sidebarIndex) {
    final mobileIndex = _sidebarToMobileIndex(sidebarIndex);
    if (mobileIndex != _currentIndex) {
      setState(() {
        _currentIndex = mobileIndex;
      });
      context.go(_sidebarRoutes[sidebarIndex]);
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
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(
          create: (context) => HomeBloc(
            taskRepository: context.read<TaskRepository>(),
          )..add(const HomeLoadRequested()),
        ),
        BlocProvider<ForumBloc>(
          create: (context) => ForumBloc(
            forumRepository: context.read<ForumRepository>(),
          )..add(const ForumLoadPosts()),
        ),
        BlocProvider<LeaderboardBloc>(
          create: (context) => LeaderboardBloc(
            leaderboardRepository: context.read<LeaderboardRepository>(),
          )..add(const LeaderboardLoadRequested()),
        ),
        BlocProvider<MessageBloc>(
          create: (context) => MessageBloc(
            messageRepository: context.read<MessageRepository>(),
          )
            ..add(const MessageLoadContacts())
            ..add(const MessageLoadTaskChats()),
        ),
      ],
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth >= Breakpoints.tablet) {
            return _buildDesktopLayout(context);
          } else if (constraints.maxWidth >= Breakpoints.mobile) {
            return _buildTabletLayout(context);
          }
          return _buildMobileLayout(context);
        },
      ),
    );
  }

  // ==================== 桌面布局 ====================
  Widget _buildDesktopLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 展开的侧边栏
          DesktopSidebar(
            currentIndex: _sidebarIndex,
            onTabSelected: _onSidebarTabSelected,
            onCreateTapped: _showCreateOptions,
            isCollapsed: false,
          ),
          // 内容区
          Expanded(
            child: ContentConstraint(
              child: widget.child,
            ),
          ),
        ],
      ),
    );
  }

  // ==================== 平板布局 ====================
  Widget _buildTabletLayout(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // 收起的侧边栏（仅图标）
          DesktopSidebar(
            currentIndex: _sidebarIndex,
            onTabSelected: _onSidebarTabSelected,
            onCreateTapped: _showCreateOptions,
            isCollapsed: true,
          ),
          // 内容区
          Expanded(
            child: widget.child,
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
                label: '发布闲置',
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
