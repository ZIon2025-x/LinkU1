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
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/sheet_adaptation.dart';
import '../../../core/utils/helpers.dart';
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

import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/decorative_background.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/activity.dart';
import '../../../data/models/task.dart';
import '../../../data/models/task_expert.dart';
import '../../../data/repositories/task_expert_repository.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../task_expert/bloc/task_expert_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';
import '../linker_quotes.dart';

part 'home_recommended_section.dart';
part 'home_widgets.dart';
part 'home_activities_section.dart';
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
  int _selectedTab = 1; // 0: 达人, 1: 推荐, 2: 附近
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
                _visitedTabs.contains(0) ? const _ExpertsTab() : const SizedBox.shrink(),
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
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Row(
          children: [
            // 分段控件
            Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DesktopSegmentButton(
                  label: context.l10n.homeExperts,
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
                      context.read<HomeBloc>().add(HomeTabChanged(index));
                    },
                    children: [
                      _visitedTabs.contains(0) ? const _ExpertsTab() : const SizedBox.shrink(),
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
          GestureDetector(
            onTap: () {
              AppHaptics.selection();
              _showMenuSheet(context);
            },
            child: SizedBox(
              width: 44, height: 44,
              child: Center(
                child: Icon(Icons.menu,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    size: 24),
              ),
            ),
          ),
          const Spacer(),
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
          GestureDetector(
            onTap: () {
              AppHaptics.selection();
              context.push('/search');
            },
            child: SizedBox(
              width: 44, height: 44,
              child: Center(
                child: Icon(Icons.search,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    size: 24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showMenuSheet(BuildContext context) {
    SheetAdaptation.showAdaptiveModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => const _MenuView(),
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
            borderRadius: BorderRadius.circular(7),
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

    return GestureDetector(
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
    );
  }
}

