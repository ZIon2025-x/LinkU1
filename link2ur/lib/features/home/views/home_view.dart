import 'dart:ui';

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
import '../../../core/utils/responsive.dart';
import '../../../core/utils/task_type_helper.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../data/models/task.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../bloc/home_bloc.dart';
import '../bloc/home_event.dart';
import '../bloc/home_state.dart';

part 'home_recommended_section.dart';
part 'home_widgets.dart';

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
      HapticFeedback.selectionClick();
      setState(() {
        _selectedTab = index;
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
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (isDesktop) {
      return _buildDesktopHome(context);
    }
    return _buildMobileHome(context);
  }

  // ==================== 桌面端首页 ====================
  Widget _buildDesktopHome(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: Column(
        children: [
          // Notion 风格内嵌 Tab 切换
          _buildDesktopTabBar(isDark),

          // 直接渲染当前 Tab 内容（不用 PageView）
          Expanded(
            child: ContentConstraint(
              child: IndexedStack(
                index: _selectedTab,
                children: const [
                  _ExpertsTab(),
                  _RecommendedTab(),
                  _NearbyTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopTabBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 20, 40, 12),
      child: Row(
        children: [
          // 分段控件
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : const Color(0xFFF2F2F7),
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
    );
  }

  // ==================== 移动端首页（保持原样） ====================
  Widget _buildMobileHome(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          Container(
            color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
          ),
          // 装饰性背景
          Positioned(
            right: -60, top: -100,
            child: Container(
              width: 300, height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Positioned(
            left: -75, top: 200,
            child: Container(
              width: 250, height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentPink.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned.fill(
            child: Container(
              color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
                  .withValues(alpha: 0.85),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildMobileAppBar(isDark),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _selectedTab = index);
                      context.read<HomeBloc>().add(HomeTabChanged(index));
                    },
                    children: const [
                      _ExpertsTab(),
                      _RecommendedTab(),
                      _NearbyTab(),
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
      color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
          .withValues(alpha: 0.95),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
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
              HapticFeedback.selectionClick();
              _showSearchSheet(context);
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
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.85, minChildSize: 0.5, maxChildSize: 0.95,
        builder: (context, scrollController) => const _MenuView(),
      ),
    );
  }

  void _showSearchSheet(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9, minChildSize: 0.5, maxChildSize: 0.95,
        builder: (context, scrollController) => const _SearchView(),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
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

/// 移动端 TabButton（保持原样）
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
            AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected
                      ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOut,
              height: 3,
              width: isSelected ? 28 : 0,
              decoration: BoxDecoration(
                color: isSelected ? AppColors.primary : Colors.transparent,
                borderRadius: AppRadius.allPill,
                boxShadow: isSelected
                    ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 4, offset: const Offset(0, 2))]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
