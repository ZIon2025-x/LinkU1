import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../core/design/app_colors.dart';
import '../../core/widgets/badge_view.dart';
import '../../core/utils/l10n_extension.dart';
import '../auth/bloc/auth_bloc.dart';
import '../notification/bloc/notification_bloc.dart';

/// 主页面（底部导航栏）
/// 参考iOS MainTabView.swift
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

  // 对齐iOS MainTabView SF Symbols
  final List<_TabItem> _tabs = const [
    _TabItem(
      icon: Icons.home_outlined,              // house.fill
      activeIcon: Icons.home,
      label: 'home',
      route: '/',
    ),
    _TabItem(
      icon: Icons.groups_outlined,            // person.3.fill
      activeIcon: Icons.groups,
      label: 'community',
      route: '/community',
    ),
    _TabItem(
      icon: Icons.add_circle_outline,         // plus.circle.fill
      activeIcon: Icons.add_circle,
      label: '',
      route: '/tasks/create',
      isCenter: true,
    ),
    _TabItem(
      icon: Icons.message_outlined,           // message.fill
      activeIcon: Icons.message,
      label: 'messages',
      route: '/messages-tab',
    ),
    _TabItem(
      icon: Icons.person_outline,             // person.fill
      activeIcon: Icons.person,
      label: 'profile',
      route: '/profile-tab',
    ),
  ];

  void _onTabTapped(int index) {
    // 中间按钮特殊处理
    if (_tabs[index].isCenter) {
      HapticFeedback.mediumImpact();
      _showCreateOptions();
      return;
    }

    if (index != _currentIndex) {
      HapticFeedback.selectionClick();
      setState(() {
        _currentIndex = index;
      });
      context.go(_tabs[index].route);
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
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
              children: List.generate(_tabs.length, (index) {
                final tab = _tabs[index];
                final isSelected = index == _currentIndex;

                if (tab.isCenter) {
                  return _buildCenterButton();
                }

                return _buildTabItem(
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

  Widget _buildTabItem({
    required _TabItem tab,
    required bool isSelected,
    required int index,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
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
    return GestureDetector(
      onTap: () => _onTabTapped(2),
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
              blurRadius: 10,
              offset: const Offset(0, 4),
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
