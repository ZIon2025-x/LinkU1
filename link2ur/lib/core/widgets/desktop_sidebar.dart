import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../design/app_colors.dart';
import '../design/app_spacing.dart';
import '../design/app_typography.dart';
import '../utils/l10n_extension.dart';
import '../utils/responsive.dart';
import '../../features/notification/bloc/notification_bloc.dart';
import 'badge_view.dart';

/// 桌面端侧边栏导航项数据
class SidebarNavItem {
  const SidebarNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.route,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
}

/// 桌面端侧边栏组件
/// 支持展开（桌面）和收起（平板）两种模式
class DesktopSidebar extends StatelessWidget {
  const DesktopSidebar({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
    required this.onCreateTapped,
    this.isCollapsed = false,
  });

  /// 当前选中的导航项索引
  final int currentIndex;

  /// 导航项点击回调
  final ValueChanged<int> onTabSelected;

  /// 创建按钮点击回调
  final VoidCallback onCreateTapped;

  /// 是否为收起模式（平板端）
  final bool isCollapsed;

  double get _width =>
      isCollapsed ? Breakpoints.sidebarCollapsed : Breakpoints.sidebarExpanded;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;

    final navItems = [
      SidebarNavItem(
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
        label: l10n.tabsHome,
        route: '/',
      ),
      SidebarNavItem(
        icon: Icons.groups_outlined,
        activeIcon: Icons.groups,
        label: l10n.tabsCommunity,
        route: '/community',
      ),
      SidebarNavItem(
        icon: Icons.message_outlined,
        activeIcon: Icons.message,
        label: l10n.tabsMessages,
        route: '/messages-tab',
      ),
      SidebarNavItem(
        icon: Icons.person_outline,
        activeIcon: Icons.person,
        label: l10n.tabsProfile,
        route: '/profile-tab',
      ),
    ];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: _width,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        border: Border(
          right: BorderSide(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo 区域
          _buildLogo(context),

          const SizedBox(height: AppSpacing.sm),

          // 发布按钮
          _buildCreateButton(context),

          const SizedBox(height: AppSpacing.md),

          // 导航项
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
              ),
              itemCount: navItems.length,
              itemBuilder: (context, index) {
                final item = navItems[index];
                final isSelected = index == currentIndex;
                // 消息tab（index=2）需要显示未读数
                final isMessageTab = index == 2;

                return _SidebarNavTile(
                  item: item,
                  isSelected: isSelected,
                  isCollapsed: isCollapsed,
                  isMessageTab: isMessageTab,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onTabSelected(index);
                  },
                );
              },
            ),
          ),

          // 底部区域
          const SizedBox(height: AppSpacing.md),
        ],
      ),
    );
  }

  Widget _buildLogo(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + AppSpacing.md,
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: AppSpacing.sm,
      ),
      child: isCollapsed
          ? Image.asset(
              'assets/images/logo.png',
              width: 36,
              height: 36,
            )
          : Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  width: 36,
                  height: 36,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    'Link2Ur',
                    style: AppTypography.title3.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCreateButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      child: isCollapsed
          ? _CollapsedCreateButton(onTap: onCreateTapped)
          : _ExpandedCreateButton(onTap: onCreateTapped),
    );
  }
}

/// 展开模式的发布按钮
class _ExpandedCreateButton extends StatelessWidget {
  const _ExpandedCreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.gradientPrimary,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
              horizontal: AppSpacing.md,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.add, color: Colors.white, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  l10n.createTaskPublishTask,
                  style: AppTypography.buttonSmall.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 收起模式的发布按钮
class _CollapsedCreateButton extends StatelessWidget {
  const _CollapsedCreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: AppColors.gradientPrimary,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}

/// 侧边栏导航项
class _SidebarNavTile extends StatelessWidget {
  const _SidebarNavTile({
    required this.item,
    required this.isSelected,
    required this.isCollapsed,
    required this.isMessageTab,
    required this.onTap,
  });

  final SidebarNavItem item;
  final bool isSelected;
  final bool isCollapsed;
  final bool isMessageTab;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final selectedBg = isDark
        ? AppColors.primary.withValues(alpha: 0.15)
        : AppColors.primary.withValues(alpha: 0.08);

    final iconColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    final textColor = isSelected
        ? AppColors.primary
        : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

    final icon = isSelected ? item.activeIcon : item.icon;

    Widget iconWidget;
    if (isMessageTab) {
      iconWidget = BlocBuilder<NotificationBloc, NotificationState>(
        builder: (context, notifState) {
          final unreadCount = notifState.unreadCount.totalCount;
          return IconWithBadge(
            icon: icon,
            count: unreadCount,
            iconSize: 22,
            iconColor: iconColor,
          );
        },
      );
    } else {
      iconWidget = Icon(icon, size: 22, color: iconColor);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.symmetric(
              vertical: 10,
              horizontal: isCollapsed ? 0 : 12,
            ),
            decoration: BoxDecoration(
              color: isSelected ? selectedBg : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: isCollapsed
                ? Center(
                    child: Tooltip(
                      message: item.label,
                      child: iconWidget,
                    ),
                  )
                : Row(
                    children: [
                      iconWidget,
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item.label,
                          style: AppTypography.subheadline.copyWith(
                            color: textColor,
                            fontWeight: isSelected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isMessageTab)
                        BlocBuilder<NotificationBloc, NotificationState>(
                          builder: (context, notifState) {
                            final unreadCount =
                                notifState.unreadCount.totalCount;
                            if (unreadCount <= 0) {
                              return const SizedBox.shrink();
                            }
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                unreadCount > 99
                                    ? '99+'
                                    : unreadCount.toString(),
                                style: AppTypography.caption2.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
