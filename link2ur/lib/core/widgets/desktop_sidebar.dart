import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../design/app_colors.dart';
import '../design/app_radius.dart';
import '../utils/l10n_extension.dart';
import '../utils/logger.dart';
import '../utils/responsive.dart';
import '../../features/auth/bloc/auth_bloc.dart';
import '../../features/notification/bloc/notification_bloc.dart';
import '../../features/message/bloc/message_bloc.dart';

/// 桌面端右侧浮层抽屉
/// 对齐 frontend HamburgerMenu：居中布局、emoji 图标、简洁宽敞风格
class DesktopDrawer extends StatelessWidget {
  const DesktopDrawer({
    super.key,
    required this.currentRoute,
    required this.onNavigate,
    required this.onClose,
  });

  /// 当前路由路径，用于高亮当前项
  final String currentRoute;

  /// 导航回调（路由路径）
  final ValueChanged<String> onNavigate;

  /// 关闭菜单回调（对齐 frontend：遮罩/面板独立于 Navigator，由调用方控制关闭）
  final VoidCallback onClose;

  /// 菜单项文字色（对齐 frontend #A67C52 金棕色）
  static const Color _menuItemColor = Color(0xFFA67C52);
  static const Color _menuItemColorDark = Color(0xFFD4A574);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final authState = context.watch<AuthBloc>().state;

    return Container(
      width: Breakpoints.drawerWidth,
      decoration: BoxDecoration(
        color: isDark ? AppColors.cardBackgroundDark : AppColors.cardBackgroundLight,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            offset: const Offset(-2, 0),
            blurRadius: 16,
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 顶部 Header：Logo + 关闭按钮（对齐 frontend .menu-header）
            _buildHeader(context, isDark),

            // 可滚动内容区（RepaintBoundary 隔离菜单项 hover 重绘，减轻背后阴影晃动）
            Expanded(
              child: RepaintBoundary(
                child: ListView(
                  padding: EdgeInsets.zero,
                children: [
                  const SizedBox(height: 20),

                  // 主导航（RepaintBoundary 隔离每项 hover 重绘，避免整列闪烁）
                  RepaintBoundary(child: _MenuItem(
                    emoji: '🏠',
                    label: l10n.tabsHome,
                    onTap: () => _navigate(context, '/'),
                    isDark: isDark,
                  )),
                  RepaintBoundary(child: _MenuItem(
                    emoji: '✨',
                    label: l10n.menuTaskHall,
                    onTap: () => _navigate(context, '/tasks'),
                    isDark: isDark,
                  )),
                  RepaintBoundary(child: _MenuItem(
                    emoji: '🚀',
                    label: l10n.publishTitle,
                    onTap: () {
                      onClose();
                      _showCreateOptions(context);
                    },
                    isDark: isDark,
                  )),
                  RepaintBoundary(child: _MenuItem(
                    emoji: '👑',
                    label: l10n.menuTaskExperts,
                    onTap: () => _navigate(context, '/task-experts'),
                    isDark: isDark,
                  )),
                  RepaintBoundary(child: _MenuItem(
                    emoji: '💬',
                    label: l10n.tabsCommunity,
                    onTap: () => _navigate(context, '/community'),
                    isDark: isDark,
                  )),
                  RepaintBoundary(child: _MenuItem(
                    emoji: '💭',
                    label: l10n.menuForum,
                    onTap: () => _navigate(context, '/forum'),
                    isDark: isDark,
                  )),
                  RepaintBoundary(child: _MenuItem(
                    emoji: '🏪',
                    label: l10n.menuFleaMarket,
                    onTap: () => _navigate(context, '/flea-market'),
                    isDark: isDark,
                  )),
                  RepaintBoundary(child: _MenuItem(
                    emoji: '🏆',
                    label: l10n.menuLeaderboard,
                    onTap: () => _navigate(context, '/leaderboard'),
                    isDark: isDark,
                  )),

                  // 分割线
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    child: Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.06)
                          : AppColors.desktopBorderLight,
                    ),
                  ),

                  // 用户相关（已登录才显示）
                  if (authState.isAuthenticated) ...[
                    _buildUserInfo(context, authState, isDark),

                    RepaintBoundary(child: _MenuItem(
                      emoji: '📋',
                      label: l10n.tabsMessages,
                      onTap: () => _navigate(context, '/messages-tab'),
                      isDark: isDark,
                      trailing: _buildUnreadBadge(context),
                    )),
                    RepaintBoundary(child: _MenuItem(
                      emoji: '👤',
                      label: l10n.tabsProfile,
                      onTap: () => _navigate(context, '/profile-tab'),
                      isDark: isDark,
                    )),
                    RepaintBoundary(child: _MenuItem(
                      emoji: '⚙️',
                      label: l10n.menuSettings,
                      onTap: () => _navigate(context, '/settings'),
                      isDark: isDark,
                    )),
                    RepaintBoundary(child: _MenuItem(
                      emoji: '🎓',
                      label: l10n.menuStudentVerification,
                      onTap: () => _navigate(context, '/student-verification'),
                      isDark: isDark,
                    )),
                    RepaintBoundary(child: _MenuItem(
                      emoji: '💰',
                      label: l10n.sidebarWallet,
                      onTap: () => _navigate(context, '/wallet'),
                      isDark: isDark,
                    )),

                    RepaintBoundary(child: _MenuItem(
                      emoji: '🚪',
                      label: l10n.authLogout,
                      onTap: () {
                        onClose();
                        context.read<AuthBloc>().add(AuthLogoutRequested());
                      },
                      isDark: isDark,
                      isDestructive: true,
                    )),
                  ],
                ],
              ),
              ),
            ),

            // 底部：未登录显示登录按钮
            if (!authState.isAuthenticated)
              _buildLoginButton(context, isDark),
          ],
        ),
      ),
    );
  }

  /// 顶部 Header：品牌渐变 Logo + 关闭按钮
  Widget _buildHeader(BuildContext context, bool isDark) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : AppColors.desktopBorderLight,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: AppColors.gradientPrimary,
            ).createShader(bounds),
            blendMode: BlendMode.srcIn,
            child: const Text(
              'Link²Ur',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
          ),
          _HoverIconButton(
            icon: Icons.close_rounded,
            size: 24,
            isDark: isDark,
            onTap: onClose,
          ),
        ],
      ),
    );
  }

  /// 用户信息区（对齐 frontend .user-info 居中样式）
  Widget _buildUserInfo(
      BuildContext context, AuthState authState, bool isDark) {
    final userName = authState.user?.name ?? context.l10n.commonUser;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
              ),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
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
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Column(
              children: [
                Text(
                  userName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textPrimaryDark : const Color(0xFF2D3748),
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
                if (authState.user?.email != null)
                  Text(
                    authState.user!.email ?? '',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF718096),
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 未读消息徽章
  Widget _buildUnreadBadge(BuildContext context) {
    return BlocBuilder<NotificationBloc, NotificationState>(
      builder: (context, notifState) {
        final notifCount = notifState.unreadCount.totalCount;
        int chatCount = 0;
        try {
          chatCount = context.read<MessageBloc>().state.totalUnread;
        } catch (e) {
          AppLogger.debug('MessageBloc not available in desktop sidebar: $e');
        }
        final total = notifCount + chatCount;
        if (total <= 0) return const SizedBox.shrink();
        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        );
      },
    );
  }

  /// 登录按钮：品牌主色渐变
  Widget _buildLoginButton(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            onClose();
            context.push('/login');
          },
          borderRadius: AppRadius.allMedium,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
              ),
              borderRadius: AppRadius.allMedium,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('🔑', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Text(
                    '${context.l10n.authLogin} / ${context.l10n.authRegister}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
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
    onClose();
    onNavigate(route);
  }

  void _showCreateOptions(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (!authState.isAuthenticated) {
      context.push('/login');
      return;
    }
    context.push('/publish');
  }
}

/// 菜单项（对齐 frontend .menu-item 居中大号风格）
/// 使用 InkWell 替代 MouseRegion+setState，减少 Web 端 hover 时闪烁
class _MenuItem extends StatelessWidget {
  const _MenuItem({
    required this.emoji,
    required this.label,
    required this.onTap,
    required this.isDark,
    this.trailing,
    this.isDestructive = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool isDark;
  final Widget? trailing;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final textColor = isDestructive
        ? const Color(0xFFE53E3E)
        : (isDark
            ? DesktopDrawer._menuItemColorDark
            : DesktopDrawer._menuItemColor);

    final hoverColor = isDestructive
        ? const Color(0xFFFED7D7)
        : (isDark
            ? Colors.white.withValues(alpha: 0.04)
            : const Color(0xFFF8F9FA));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          hoverColor: hoverColor,
          borderRadius: AppRadius.allMedium,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 14),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hover 图标按钮（InkWell 稳定 hover，减少 Web 闪烁）
class _HoverIconButton extends StatelessWidget {
  const _HoverIconButton({
    required this.icon,
    required this.size,
    required this.isDark,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hoverColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : AppColors.desktopHoverLight;
    final iconColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.desktopTextLight;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: hoverColor,
        borderRadius: AppRadius.allSmall,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, size: size, color: iconColor),
        ),
      ),
    );
  }
}
