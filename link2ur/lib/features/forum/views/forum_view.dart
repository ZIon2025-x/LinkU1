import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/error_localizer.dart';
import '../../../core/utils/haptic_feedback.dart';
import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
import '../../../core/utils/forum_permission_helper.dart';
import '../../../core/design/app_colors.dart';
import '../../../core/design/app_spacing.dart';
import '../../../core/design/app_radius.dart';
import '../../../core/design/app_typography.dart';
import '../../../core/widgets/animated_list_item.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/skeleton_view.dart';
import '../../../core/widgets/error_state_view.dart';
import '../../../core/widgets/empty_state_view.dart';
import '../../../core/widgets/async_image_view.dart';
import '../../../core/widgets/content_constraint.dart';
import '../../../core/widgets/glass_container.dart';
import '../../../core/widgets/decorative_background.dart';
import '../../../data/models/forum.dart';
import '../../../data/models/leaderboard.dart';
import '../bloc/forum_bloc.dart';
import '../../auth/bloc/auth_bloc.dart';
import '../../leaderboard/bloc/leaderboard_bloc.dart';

/// 社区页 (论坛 + 排行榜)
/// [showLeaderboardTab] 为 false 时仅显示论坛（用于独立路由 /forum，不显示排行榜按钮）
class ForumView extends StatefulWidget {
  const ForumView({super.key, this.showLeaderboardTab = true});

  final bool showLeaderboardTab;

  @override
  State<ForumView> createState() => _ForumViewState();
}

class _ForumViewState extends State<ForumView> {
  int _selectedTab = 0; // 0: 论坛, 1: 排行榜
  PageController? _pageController;

  @override
  void initState() {
    super.initState();
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
      });
      _pageController?.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // 仅超宽屏用桌面式内嵌 Header；iPad 与手机一致用 AppBar + 下方 Tab
    if (ResponsiveUtils.isDesktopShell(context)) {
      return _buildDesktopLayout(isDark);
    }
    return _buildMobileLayout(isDark);
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Scaffold(
      body: Stack(
        children: [
          const RepaintBoundary(child: DecorativeBackground()),
          Column(
            children: [
              _buildDesktopHeader(isDark),
              Expanded(
                child: widget.showLeaderboardTab
                    ? IndexedStack(
                        index: _selectedTab,
                        children: const [
                          _ForumTab(),
                          _LeaderboardTab(),
                        ],
                      )
                    : const _ForumTab(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDark) {
    return ContentConstraint(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
        child: Row(
        children: [
          if (widget.showLeaderboardTab) ...[
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
                  _DesktopSegment(
                    label: context.l10n.communityForum,
                    isSelected: _selectedTab == 0,
                    onTap: () => _onTabChanged(0),
                    isDark: isDark,
                  ),
                  _DesktopSegment(
                    label: context.l10n.communityLeaderboard,
                    isSelected: _selectedTab == 1,
                    onTap: () => _onTabChanged(1),
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const Spacer(),
            _DesktopCreateButton(
              label: _selectedTab == 0
                  ? context.l10n.forumRequestNewCategory
                  : context.l10n.leaderboardApplyNew,
              icon: Icons.edit_rounded,
              onTap: () {
                if (_selectedTab == 0) {
                  context.push('/forum/category-request');
                } else {
                  context.push('/leaderboard/apply');
                }
              },
            ),
          ] else ...[
            const Spacer(),
            _DesktopCreateButton(
              label: context.l10n.forumRequestNewCategory,
              icon: Icons.edit_rounded,
              onTap: () => context.push('/forum/category-request'),
            ),
          ],
        ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      body: Stack(
        children: [
          const RepaintBoundary(child: DecorativeBackground()),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _buildMobileAppBar(isDark),
                Expanded(
                  child: widget.showLeaderboardTab
                      ? PageView(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() => _selectedTab = index);
                          },
                          children: const [
                            _ForumTab(),
                            _LeaderboardTab(),
                          ],
                        )
                      : const _ForumTab(),
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
        horizontal: AppSpacing.sm, vertical: AppSpacing.xs,
      ),
      decoration: const BoxDecoration(color: Colors.transparent),
      child: Row(
        children: [
          const SizedBox(width: 44),
          const Spacer(),
          if (widget.showLeaderboardTab)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _CommunityTabButton(
                  title: context.l10n.communityForum,
                  isSelected: _selectedTab == 0,
                  onTap: () => _onTabChanged(0),
                ),
                _CommunityTabButton(
                  title: context.l10n.communityLeaderboard,
                  isSelected: _selectedTab == 1,
                  onTap: () => _onTabChanged(1),
                ),
              ],
            ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                if (widget.showLeaderboardTab && _selectedTab == 1) {
                  context.push('/leaderboard/apply');
                } else {
                  context.push('/forum/category-request');
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.12),
                ),
                child: const Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 桌面端分段按钮
class _DesktopSegment extends StatefulWidget {
  const _DesktopSegment({
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
  State<_DesktopSegment> createState() => _DesktopSegmentState();
}

class _DesktopSegmentState extends State<_DesktopSegment> {
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
                ? (widget.isDark ? AppColors.secondaryBackgroundDark : Colors.white)
                : (_isHovered
                    ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(7),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))]
                : const [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? (widget.isDark ? Colors.white : AppColors.desktopTextLight)
                  : (widget.isDark ? AppColors.textSecondaryDark : AppColors.desktopPlaceholderLight),
            ),
          ),
        ),
      ),
    );
  }
}

/// 桌面端创建按钮（Notion 风格）
class _DesktopCreateButton extends StatefulWidget {
  const _DesktopCreateButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  State<_DesktopCreateButton> createState() => _DesktopCreateButtonState();
}

class _DesktopCreateButtonState extends State<_DesktopCreateButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary : AppColors.primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : const [],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 对标iOS TabButton — 简化动画：去掉 AnimatedScale + BoxShadow 动画
class _CommunityTabButton extends StatelessWidget {
  const _CommunityTabButton({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: AppTypography.body.copyWith(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected
                    ? (isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight)
                    : (isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
              ),
            ),
            const SizedBox(height: 6),
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

/// 板块/排行榜顶部搜索框（仅搜当前板块）
class _SectionSearchBar extends StatelessWidget {
  const _SectionSearchBar({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;

  static const double barHeight = 56;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RepaintBoundary(
      child: Container(
        height: barHeight,
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: Colors.transparent),
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.xs, AppSpacing.md, AppSpacing.xs),
        child: TextField(
        controller: controller,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(Icons.search, size: 20, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
          filled: true,
          fillColor: isDark ? AppColors.cardBackgroundDark : AppColors.secondaryBackgroundLight,
          border: OutlineInputBorder(
            borderRadius: AppRadius.allMedium,
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    ),
    );
  }
}

/// 固定高度的 Sliver 委托，用于置顶搜索框
class _PinnedSearchBarDelegate extends SliverPersistentHeaderDelegate {
  _PinnedSearchBarDelegate({required this.child});

  final Widget child;

  @override
  double get minExtent => _SectionSearchBar.barHeight;

  @override
  double get maxExtent => _SectionSearchBar.barHeight;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _PinnedSearchBarDelegate oldDelegate) => false;
}

/// 论坛Tab - 显示板块(分类)列表，顶部搜索框仅过滤板块
class _ForumTab extends StatefulWidget {
  const _ForumTab();

  @override
  State<_ForumTab> createState() => _ForumTabState();
}

class _ForumTabState extends State<_ForumTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    return BlocBuilder<AuthBloc, AuthState>(
      buildWhen: (prev, curr) =>
          prev.isAuthenticated != curr.isAuthenticated ||
          prev.user?.id != curr.user?.id,
      builder: (context, authState) {
        return BlocListener<ForumBloc, ForumState>(
          listenWhen: (prev, curr) =>
              curr.errorMessage != null &&
              curr.categories.isNotEmpty &&
              prev.errorMessage != curr.errorMessage,
          listener: (context, state) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(context.localizeError(state.errorMessage))),
            );
          },
          child: BlocBuilder<ForumBloc, ForumState>(
          buildWhen: (prev, curr) =>
              prev.categories != curr.categories ||
              prev.status != curr.status,
          builder: (context, state) {
            if (state.status == ForumStatus.loading &&
                state.categories.isEmpty) {
              const body = SkeletonList(imageSize: 64);
              return isDesktop ? const ContentConstraint(child: body) : body;
            }

            if (state.status == ForumStatus.error &&
                state.categories.isEmpty) {
              final body = ErrorStateView.loadFailed(
                message:
                    context.localizeError(state.errorMessage),
                onRetry: () {
                  context
                      .read<ForumBloc>()
                      .add(const ForumLoadCategories());
                },
              );
              return isDesktop ? ContentConstraint(child: body) : body;
            }

            final user = authState.isAuthenticated ? authState.user : null;
            final visible = ForumPermissionHelper.filterVisibleCategories(
              state.categories,
              user,
            );

            if (visible.isEmpty) {
              final body = EmptyStateView.noData(
                context,
                title: context.l10n.forumNoPosts,
                description: context.l10n.forumNoPostsHint,
              );
              return isDesktop ? ContentConstraint(child: body) : body;
            }

            final sorted = List<ForumCategory>.from(visible);
            sorted.sort((a, b) {
              if (a.isFavorited && !b.isFavorited) return -1;
              if (!a.isFavorited && b.isFavorited) return 1;
              return a.sortOrder.compareTo(b.sortOrder);
            });

            final query = _searchController.text.trim().toLowerCase();
            final filtered = query.isEmpty
                ? sorted
                : sorted.where((c) {
                    final locale = Localizations.localeOf(context);
                    final name = (c.displayName(locale)).toLowerCase();
                    final desc = (c.displayDescription(locale) ?? '').toLowerCase();
                    return name.contains(query) || desc.contains(query);
                  }).toList();

            final scrollView = CustomScrollView(
              clipBehavior: Clip.none,
              slivers: [
                SliverPersistentHeader(
                  pinned: true,
                  delegate: _PinnedSearchBarDelegate(
                    child: _SectionSearchBar(
                      controller: _searchController,
                      hint: context.l10n.communitySearchForumHint,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.only(
                    left: AppSpacing.md,
                    right: AppSpacing.md,
                    bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                  ),
                  sliver: filtered.isEmpty
                      ? SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.md),
                            child: EmptyStateView.noData(
                              context,
                              title: context.l10n.commonNoResults,
                              description: context.l10n.forumNoPostsHint,
                            ),
                          ),
                        )
                      : SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  top: index == 0 ? AppSpacing.md : 0,
                                  bottom: AppSpacing.md,
                                ),
                                child: AnimatedListItem(
                                  index: index,
                                  maxAnimatedIndex: 11,
                                  child: _CategoryCard(category: filtered[index]),
                                ),
                              );
                            },
                            childCount: filtered.length,
                          ),
                        ),
                ),
              ],
            );
            final listBody = RefreshIndicator(
              onRefresh: () async {
                context.read<ForumBloc>().add(const ForumRefreshRequested());
              },
              child: scrollView,
            );
            return isDesktop ? ContentConstraint(child: listBody) : listBody;
          },
        ),
        );
      },
    );
  }
}

/// 排行榜 Tab 顶部搜索框（防抖，仅搜排行榜）
class _LeaderboardSearchBar extends StatefulWidget {
  const _LeaderboardSearchBar({
    required this.hint,
    required this.onSearchChanged,
  });

  final String hint;
  final ValueChanged<String> onSearchChanged;

  @override
  State<_LeaderboardSearchBar> createState() => _LeaderboardSearchBarState();
}

class _LeaderboardSearchBarState extends State<_LeaderboardSearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDuration, () {
      if (mounted) widget.onSearchChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SectionSearchBar(
      controller: _controller,
      hint: widget.hint,
      onChanged: _onChanged,
    );
  }
}

/// 排行榜Tab - 顶部搜索框仅搜排行榜（API 关键词），搜索框固定且输入不因列表刷新被清空
class _LeaderboardTab extends StatefulWidget {
  const _LeaderboardTab();

  @override
  State<_LeaderboardTab> createState() => _LeaderboardTabState();
}

class _LeaderboardTabState extends State<_LeaderboardTab> {
  /// 缓存搜索框实例，避免 BlocBuilder 重建时重建 delegate 导致输入被清空
  Widget? _cachedSearchBar;
  late Widget _searchBar;

  Widget _buildSearchBar(BuildContext context) {
    if (_cachedSearchBar != null) return _cachedSearchBar!;
    _cachedSearchBar = _LeaderboardSearchBar(
      hint: context.l10n.communitySearchLeaderboardHint,
      onSearchChanged: (q) {
        if (context.mounted) {
          context.read<LeaderboardBloc>().add(LeaderboardSearchChanged(q));
        }
      },
    );
    return _cachedSearchBar!;
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);
    _searchBar = _buildSearchBar(context);

    return BlocBuilder<LeaderboardBloc, LeaderboardState>(
      buildWhen: (prev, curr) =>
          prev.leaderboards != curr.leaderboards ||
          prev.status != curr.status ||
          prev.hasMore != curr.hasMore ||
          prev.searchKeyword != curr.searchKeyword,
      builder: (context, state) {
        final sliverBody = _buildSliverBody(context, state);
        final scrollView = CustomScrollView(
          clipBehavior: Clip.none,
          slivers: [
            SliverPersistentHeader(
              pinned: true,
              delegate: _PinnedSearchBarDelegate(child: _searchBar),
            ),
            sliverBody,
          ],
        );
        final refresh = RefreshIndicator(
          onRefresh: () async {
            context.read<LeaderboardBloc>().add(
                  const LeaderboardRefreshRequested(),
                );
          },
          child: scrollView,
        );
        return isDesktop ? ContentConstraint(child: refresh) : refresh;
      },
    );
  }

  Widget _buildSliverBody(BuildContext context, LeaderboardState state) {
    if (state.status == LeaderboardStatus.loading &&
        state.leaderboards.isEmpty) {
      return const SliverFillRemaining(
        child: SkeletonList(imageSize: 90),
      );
    }

    if (state.status == LeaderboardStatus.error &&
        state.leaderboards.isEmpty) {
      return SliverFillRemaining(
        child: ErrorStateView.loadFailed(
          message: context.localizeError(state.errorMessage),
          onRetry: () {
            context.read<LeaderboardBloc>().add(
                  const LeaderboardLoadRequested(),
                );
          },
        ),
      );
    }

    if (state.leaderboards.isEmpty) {
      return SliverFillRemaining(
        child: EmptyStateView.noData(
          context,
          title: context.l10n.forumNoLeaderboard,
          description: context.l10n.forumNoLeaderboardMessage,
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            if (index == state.leaderboards.length) {
              context.read<LeaderboardBloc>().add(const LeaderboardLoadMore());
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: LoadingIndicator()),
              );
            }
            return Padding(
              padding: EdgeInsets.only(
                top: index == 0 ? AppSpacing.md : 0,
                bottom: AppSpacing.md,
              ),
              child: AnimatedListItem(
                index: index,
                maxAnimatedIndex: 11,
                child: _LeaderboardCard(
                  leaderboard: state.leaderboards[index],
                ),
              ),
            );
          },
          childCount: state.leaderboards.length + (state.hasMore ? 1 : 0),
        ),
      ),
    );
  }
}

/// 板块卡片 - 对标iOS CategoryCard
/// 图标(64x64) + 名称 + 描述 + 最新帖子预览 + chevron
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final ForumCategory category;

  // 统一使用项目主题蓝色渐变
  List<Color> get _gradient =>
      const [AppColors.primary, Color(0xFF4A7AF5)];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final colors = _gradient;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.push('/forum/category/${category.id}',
            extra: category);
      },
      child: GlassContainer(
        borderRadius: AppRadius.allLarge,
        padding: AppSpacing.allMd,
        blurSigma: 14,
        child: Row(
          children: [
            // 图标容器 - 对标iOS 64x64 渐变背景
            _buildIconArea(colors),
            const SizedBox(width: AppSpacing.md),

            // 信息区域
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题（对标iOS body bold）
                  Text(
                    category.displayName(locale),
                    style: AppTypography.bodyBold.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  // 描述（对标iOS subheadline）
                  if (category.displayDescription(locale)?.isNotEmpty ?? false) ...[
                    const SizedBox(height: 4),
                    Text(
                      category.displayDescription(locale)!,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],

                  // 最新帖子预览（对标iOS latestPost section）
                  if (category.latestPost != null) ...[
                    const SizedBox(height: 8),
                    _buildLatestPostPreview(context, isDark),
                  ] else if (category.postCount == 0) ...[
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.forumNoPosts,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // 收藏按钮（对标 iOS 板块收藏）
            IconButton(
              icon: Icon(
                category.isFavorited ? Icons.favorite : Icons.favorite_border,
                size: 22,
                color: category.isFavorited ? AppColors.error : null,
              ),
              onPressed: () {
                AppHaptics.selection();
                context.read<ForumBloc>().add(
                    ForumToggleCategoryFavorite(category.id));
              },
              tooltip: context.l10n.forumFavorite,
            ),

            // Chevron
            Icon(
              Icons.chevron_right,
              size: 20,
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconArea(List<Color> colors) {
    final hasIcon = category.icon != null && category.icon!.isNotEmpty;
    final isUrl = hasIcon &&
        (category.icon!.startsWith('http://') ||
            category.icon!.startsWith('https://'));

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: isUrl
            ? AsyncImageView(
                imageUrl: category.icon,
                width: 36,
                height: 36,
                fit: BoxFit.contain,
                errorWidget: const Icon(Icons.folder,
                    color: Colors.white, size: 28),
              )
            : hasIcon
                ? Text(
                    category.icon!,
                    style: const TextStyle(fontSize: 32),
                  )
                : const Icon(Icons.folder,
                    color: Colors.white, size: 28),
      ),
    );
  }

  Widget _buildLatestPostPreview(BuildContext context, bool isDark) {
    final post = category.latestPost!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 帖子标题
        Row(
          children: [
            const Icon(
              Icons.message,
              size: 11,
              color: AppColors.primary,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                post.displayTitle(Localizations.localeOf(context)),
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // 元信息：作者 + 回复 + 浏览 + 时间
        Row(
          children: [
            if (post.author != null) ...[
              Icon(Icons.person, size: 10,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight),
              const SizedBox(width: 2),
              Text(
                post.author!.name,
                style: AppTypography.caption2.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(width: 8),
            ],
            Icon(Icons.chat_bubble, size: 10,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight),
            const SizedBox(width: 2),
            Text(
              '${post.replyCount}',
              style: AppTypography.caption2.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.visibility, size: 10,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight),
            const SizedBox(width: 2),
            Text(
              '${post.viewCount}',
              style: AppTypography.caption2.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
            ),
            if (post.lastReplyAt != null) ...[
              const SizedBox(width: 8),
              Icon(Icons.access_time, size: 10,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight),
              const SizedBox(width: 2),
              Text(
                _formatTime(context, post.lastReplyAt),
                style: AppTypography.caption2.copyWith(
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  String _formatTime(BuildContext context, DateTime? time) {
    if (time == null) return '';
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return context.l10n.timeDaysAgo(difference.inDays);
    } else if (difference.inHours > 0) {
      return context.l10n.timeHoursAgo(difference.inHours);
    } else if (difference.inMinutes > 0) {
      return context.l10n.timeMinutesAgo(difference.inMinutes);
    } else {
      return context.l10n.timeJustNow;
    }
  }
}

/// 排行榜卡片 - 对标iOS LeaderboardCard样式
/// 封面图(100x100) + 标题 + 描述 + 位置 + 分隔线 + 统计行(项目/投票/浏览)
class _LeaderboardCard extends StatelessWidget {
  const _LeaderboardCard({required this.leaderboard});

  final Leaderboard leaderboard;

  // 根据排行榜类型提供不同颜色
  List<Color> get _gradient {
    final hash = leaderboard.id.hashCode;
    final gradients = [
      AppColors.gradientCoral,
      AppColors.gradientPurple,
      AppColors.gradientEmerald,
      AppColors.gradientOrange,
      AppColors.gradientIndigo,
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final colors = _gradient;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.push('/leaderboard/${leaderboard.id}');
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassContainer(
        borderRadius: AppRadius.allLarge,
        padding: const EdgeInsets.all(AppSpacing.md),
        blurSigma: 14,
        child: Column(
          children: [
            // 对标iOS: 封面 + 标题/描述/位置
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 封面图片或渐变占位 (对标iOS 100x100)
                leaderboard.coverImage != null &&
                        leaderboard.coverImage!.isNotEmpty
                    ? AsyncImageView(
                        imageUrl: leaderboard.coverImage,
                        width: 90,
                        height: 90,
                        borderRadius: BorderRadius.circular(14),
                        errorWidget: _buildPlaceholderIcon(colors),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: _buildPlaceholderIcon(colors),
                      ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 标题 (对标iOS title3 bold, lineLimit 1)
                      Text(
                        leaderboard.displayName(locale),
                        style: AppTypography.bodyBold.copyWith(
                          fontSize: 17,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // 描述 (对标iOS caption, lineLimit 2)
                      if (leaderboard.displayDescription(locale) != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          leaderboard.displayDescription(locale)!,
                          style: AppTypography.caption.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // 位置 (对标iOS mappin.circle.fill)
                      if (leaderboard.location.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on,
                              size: 13,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                leaderboard.location,
                                style: AppTypography.caption2.copyWith(
                                  fontWeight: FontWeight.w500,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // 对标iOS: 分隔线
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Divider(
                height: 1,
                color: (isDark
                        ? AppColors.separatorDark
                        : AppColors.separatorLight)
                    .withValues(alpha: 0.3),
              ),
            ),

            // 对标iOS: 统计行 (items + votes + views) - CompactStatItem
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _StatItem(
                  icon: Icons.grid_view,
                  count: leaderboard.itemCount,
                  isDark: isDark,
                ),
                _StatItem(
                  icon: Icons.thumb_up_outlined,
                  count: leaderboard.voteCount,
                  isDark: isDark,
                ),
                _StatItem(
                  icon: Icons.visibility_outlined,
                  count: leaderboard.viewCount,
                  isDark: isDark,
                ),
              ],
            ),
          ],
        ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.transparent,
              child: IconButton(
                icon: Icon(
                  leaderboard.isFavorited ? Icons.favorite : Icons.favorite_border,
                  size: 22,
                  color: leaderboard.isFavorited
                      ? AppColors.error
                      : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                ),
                onPressed: () {
                  AppHaptics.selection();
                  context.read<LeaderboardBloc>().add(
                    LeaderboardToggleFavorite(leaderboard.id),
                  );
                },
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                tooltip: context.l10n.forumFavorite,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderIcon(List<Color> colors) {
    return Container(
      width: 90,
      height: 90,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.emoji_events, color: Colors.white, size: 36),
    );
  }
}

/// 统计项组件 (对标iOS CompactStatItem)
class _StatItem extends StatelessWidget {
  const _StatItem({
    required this.icon,
    required this.count,
    required this.isDark,
  });

  final IconData icon;
  final int count;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 14,
          color: isDark
              ? AppColors.textTertiaryDark
              : AppColors.textTertiaryLight,
        ),
        const SizedBox(width: 4),
        Text(
          '$count',
          style: AppTypography.caption.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
