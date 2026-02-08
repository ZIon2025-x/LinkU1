import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../design/app_colors.dart';
import '../design/app_typography.dart';
import '../utils/l10n_extension.dart';
import '../utils/responsive.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/notification/bloc/notification_bloc.dart';

/// 桌面端右侧浮层抽屉
/// Notion/Linear 风格：浅色背景、分组导航、用户信息
class DesktopDrawer extends StatelessWidget {
  const DesktopDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
  });

  /// 当前路由路径，用于高亮当前项
  final String currentRoute;

  /// 导航回调（路由路径）
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    return Container(
      width: Breakpoints.drawerWidth,
      color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFFBFBFA),
      child: SafeArea(
        child: Column(
          children: [
            // 用户信息区
            _buildUserSection(context, isDark),

            const SizedBox(height: 8),

            // 导航列表
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  // 主导航
                  _DrawerSectionLabel(
                    label: l10n.tabsHome,
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: l10n.tabsHome,
                    route: '/',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.groups_outlined,
                    activeIcon: Icons.groups_rounded,
                    label: l10n.tabsCommunity,
                    route: '/community',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/community'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.message_outlined,
                    activeIcon: Icons.message_rounded,
                    label: l10n.tabsMessages,
                    route: '/messages-tab',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/messages-tab'),
                    isDark: isDark,
                    trailing: BlocBuilder<NotificationBloc, NotificationState>(
                      builder: (context, state) {
                        final count = state.unreadCount.totalCount;
                        if (count <= 0) return const SizedBox.shrink();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEB5757),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            count > 99 ? '99+' : count.toString(),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _DrawerNavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: l10n.tabsProfile,
                    route: '/profile-tab',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/profile-tab'),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 8),
                  _DrawerDivider(isDark: isDark),
                  const SizedBox(height: 8),

                  // 发现
                  _DrawerSectionLabel(
                    label: l10n.sidebarDiscover,
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.list_alt_outlined,
                    activeIcon: Icons.list_alt_rounded,
                    label: l10n.menuTaskHall,
                    route: '/tasks',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/tasks'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.star_outline_rounded,
                    activeIcon: Icons.star_rounded,
                    label: l10n.menuTaskExperts,
                    route: '/task-experts',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/task-experts'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.storefront_outlined,
                    activeIcon: Icons.storefront_rounded,
                    label: l10n.menuFleaMarket,
                    route: '/flea-market',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/flea-market'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.emoji_events_outlined,
                    activeIcon: Icons.emoji_events_rounded,
                    label: l10n.menuLeaderboard,
                    route: '/leaderboard',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/leaderboard'),
                    isDark: isDark,
                  ),

                  const SizedBox(height: 8),
                  _DrawerDivider(isDark: isDark),
                  const SizedBox(height: 8),

                  // 账户
                  _DrawerSectionLabel(
                    label: l10n.sidebarAccount,
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.stars_outlined,
                    activeIcon: Icons.stars_rounded,
                    label: l10n.menuPointsCoupons,
                    route: '/coupon-points',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/coupon-points'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.account_balance_wallet_outlined,
                    activeIcon: Icons.account_balance_wallet_rounded,
                    label: l10n.sidebarWallet,
                    route: '/wallet',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/wallet'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.verified_user_outlined,
                    activeIcon: Icons.verified_user_rounded,
                    label: l10n.menuStudentVerification,
                    route: '/student-verification',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/student-verification'),
                    isDark: isDark,
                  ),
                  _DrawerNavItem(
                    icon: Icons.settings_outlined,
                    activeIcon: Icons.settings_rounded,
                    label: l10n.menuSettings,
                    route: '/settings',
                    currentRoute: currentRoute,
                    onTap: () => _navigate(context, '/settings'),
                    isDark: isDark,
                  ),
                ],
              ),
            ),

            // 底部发布按钮
            _buildCreateButton(context, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, bool isDark) {
    final authState = context.watch<AuthBloc>().state;
    final userName = authState.isAuthenticated
        ? (authState.user?.name ?? '用户')
        : '未登录';
    final isVerified = authState.user?.isStudentVerified ?? false;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          // 头像
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFFFF6B6B), Color(0xFFFF4757)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : const Color(0xFF37352F),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                if (isVerified)
                  Text(
                    '学生认证 ✓',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF9B9A97),
                    ),
                  ),
              ],
            ),
          ),
          // 关闭按钮
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(
              Icons.close_rounded,
              size: 20,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : const Color(0xFF9B9A97),
            ),
            splashRadius: 18,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.of(context).pop(); // 关闭抽屉
            _showCreateOptions(context);
          },
          borderRadius: BorderRadius.circular(10),
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '发布',
                    style: AppTypography.buttonSmall.copyWith(
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.of(context).pop(); // 关闭抽屉
    onNavigate(route);
  }

  void _showCreateOptions(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      context.push('/login');
      return;
    }
    // 直接跳转到创建任务页
    context.push('/tasks/create');
  }
}

/// 抽屉分组标签
class _DrawerSectionLabel extends StatelessWidget {
  const _DrawerSectionLabel({
    required this.label,
    required this.isDark,
  });

  final String label;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark
              ? AppColors.textTertiaryDark
              : const Color(0xFF9B9A97),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// 抽屉导航项
class _DrawerNavItem extends StatefulWidget {
  const _DrawerNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
    required this.currentRoute,
    required this.onTap,
    required this.isDark,
    this.trailing,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  final String currentRoute;
  final VoidCallback onTap;
  final bool isDark;
  final Widget? trailing;

  @override
  State<_DrawerNavItem> createState() => _DrawerNavItemState();
}

class _DrawerNavItemState extends State<_DrawerNavItem> {
  bool _isHovered = false;

  bool get _isActive => widget.currentRoute == widget.route;

  @override
  Widget build(BuildContext context) {
    final activeBg = widget.isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE8E8E5);
    final hoverBg = widget.isDark
        ? Colors.white.withValues(alpha: 0.04)
        : const Color(0xFFF0F0EE);

    final iconColor = _isActive
        ? (widget.isDark ? Colors.white : const Color(0xFF37352F))
        : (widget.isDark
            ? AppColors.textSecondaryDark
            : const Color(0xFF37352F).withValues(alpha: 0.65));

    final textColor = _isActive
        ? (widget.isDark ? Colors.white : const Color(0xFF37352F))
        : (widget.isDark
            ? AppColors.textPrimaryDark
            : const Color(0xFF37352F));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _isActive
                  ? activeBg
                  : (_isHovered ? hoverBg : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  _isActive ? widget.activeIcon : widget.icon,
                  size: 20,
                  color: iconColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _isActive ? FontWeight.w600 : FontWeight.w400,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.trailing != null) widget.trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 抽屉分隔线
class _DrawerDivider extends StatelessWidget {
  const _DrawerDivider({required this.isDark});

  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Divider(
        height: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFFE8E8E5),
      ),
    );
  }
}
