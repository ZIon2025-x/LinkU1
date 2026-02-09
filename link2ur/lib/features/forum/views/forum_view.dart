import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/utils/l10n_extension.dart';
import '../../../core/utils/responsive.dart';
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
import '../../../data/models/forum.dart';
import '../../../data/models/leaderboard.dart';
import '../bloc/forum_bloc.dart';
import '../../leaderboard/bloc/leaderboard_bloc.dart';

/// 社区页 (论坛 + 排行榜)
class ForumView extends StatefulWidget {
  const ForumView({super.key});

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
      HapticFeedback.selectionClick();
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
    final isDesktop = ResponsiveUtils.isDesktop(context);

    if (isDesktop) {
      return _buildDesktopLayout(isDark);
    }
    return _buildMobileLayout(isDark);
  }

  Widget _buildDesktopLayout(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : Colors.white,
      body: Column(
        children: [
          // Notion 风格 tab + 发帖按钮
          _buildDesktopHeader(isDark),

          // 直接渲染 tab 内容
          Expanded(
            child: ContentConstraint(
              child: IndexedStack(
                index: _selectedTab,
                children: const [
                  _ForumTab(),
                  _LeaderboardTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(bool isDark) {
    return Padding(
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
          // 申请按钮（根据选中tab切换功能）
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
        ],
      ),
    );
  }

  Widget _buildMobileLayout(bool isDark) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildMobileAppBar(isDark),
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() => _selectedTab = index);
                },
                children: const [
                  _ForumTab(),
                  _LeaderboardTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedTab == 0) {
            // 论坛tab → 申请新版块
            context.push('/forum/category-request');
          } else {
            // 排行榜tab → 申请新排行榜
            context.push('/leaderboard/apply');
          }
        },
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  Widget _buildMobileAppBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm, vertical: AppSpacing.xs,
      ),
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Row(
        children: [
          const SizedBox(width: 44),
          const Spacer(),
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
          const SizedBox(width: 44),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? (widget.isDark ? const Color(0xFF2C2C2E) : Colors.white)
                : (_isHovered
                    ? (widget.isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(7),
            boxShadow: widget.isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 3, offset: const Offset(0, 1))]
                : [],
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: widget.isSelected ? FontWeight.w600 : FontWeight.w500,
              color: widget.isSelected
                  ? (widget.isDark ? Colors.white : const Color(0xFF37352F))
                  : (widget.isDark ? AppColors.textSecondaryDark : const Color(0xFF9B9A97)),
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? AppColors.primary : AppColors.primary.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(8),
            boxShadow: _isHovered
                ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
                : [],
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

/// 对标iOS TabButton - 与首页风格一致
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
            AnimatedScale(
              scale: isSelected ? 1.05 : 1.0,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              child: Text(
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
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : [],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 论坛Tab - BLoC 在 MainTabView 中创建
class _ForumTab extends StatelessWidget {
  const _ForumTab();

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return BlocBuilder<ForumBloc, ForumState>(
      builder: (context, state) {
        if (state.status == ForumStatus.loading && state.posts.isEmpty) {
          return const SkeletonList();
        }

        if (state.status == ForumStatus.error && state.posts.isEmpty) {
          return ErrorStateView.loadFailed(
            message: state.errorMessage ?? context.l10n.tasksLoadFailed,
            onRetry: () {
              context.read<ForumBloc>().add(const ForumLoadPosts());
            },
          );
        }

        if (state.posts.isEmpty) {
          return EmptyStateView.noData(
            title: context.l10n.forumNoPosts,
            description: context.l10n.forumNoPostsHint,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<ForumBloc>().add(const ForumRefreshRequested());
          },
          child: isDesktop
              ? _buildDesktopGrid(context, state)
              : _buildMobileList(context, state),
        );
      },
    );
  }

  Widget _buildDesktopGrid(BuildContext context, ForumState state) {
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
          sliver: SliverGrid(
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: ResponsiveUtils.gridColumnCount(context, type: GridItemType.forum),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.6,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index == state.posts.length) {
                  context.read<ForumBloc>().add(const ForumLoadMorePosts());
                  return const Center(child: Padding(
                    padding: EdgeInsets.all(16), child: LoadingIndicator()));
                }
                return _PostCard(post: state.posts[index]);
              },
              childCount: state.posts.length + (state.hasMore ? 1 : 0),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileList(BuildContext context, ForumState state) {
    return ListView.separated(
      clipBehavior: Clip.none,
      padding: AppSpacing.allMd,
      itemCount: state.posts.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (context, index) => AppSpacing.vMd,
      itemBuilder: (context, index) {
        if (index == state.posts.length) {
          context.read<ForumBloc>().add(const ForumLoadMorePosts());
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: LoadingIndicator(),
            ),
          );
        }
        return AnimatedListItem(
          index: index,
          child: _PostCard(post: state.posts[index]),
        );
      },
    );
  }
}

/// 排行榜Tab
class _LeaderboardTab extends StatelessWidget {
  const _LeaderboardTab();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<LeaderboardBloc, LeaderboardState>(
      builder: (context, state) {
        if (state.status == LeaderboardStatus.loading &&
            state.leaderboards.isEmpty) {
          return const SkeletonList();
        }

        if (state.status == LeaderboardStatus.error &&
            state.leaderboards.isEmpty) {
          return ErrorStateView.loadFailed(
            message: state.errorMessage ?? context.l10n.tasksLoadFailed,
            onRetry: () {
              context.read<LeaderboardBloc>().add(
                    const LeaderboardLoadRequested(),
                  );
            },
          );
        }

        if (state.leaderboards.isEmpty) {
          return EmptyStateView.noData(
            title: context.l10n.forumNoLeaderboard,
            description: context.l10n.forumNoLeaderboardMessage,
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            context.read<LeaderboardBloc>().add(
                  const LeaderboardRefreshRequested(),
                );
          },
          child: ListView.separated(
            clipBehavior: Clip.none,
            padding: AppSpacing.allMd,
            itemCount: state.leaderboards.length +
                (state.hasMore ? 1 : 0),
            separatorBuilder: (context, index) => AppSpacing.vMd,
            itemBuilder: (context, index) {
              if (index == state.leaderboards.length) {
                context.read<LeaderboardBloc>().add(
                      const LeaderboardLoadMore(),
                    );
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: LoadingIndicator(),
                    ),
                  );
                }
                return AnimatedListItem(
                  index: index,
                  child: _LeaderboardCard(
                    leaderboard: state.leaderboards[index],
                  ),
                );
              },
            ),
          );
        },
      );
  }
}

/// 帖子卡片 - 对齐iOS ForumPostCard样式
class _PostCard extends StatelessWidget {
  const _PostCard({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/forum/posts/${post.id}');
      },
      child: Container(
        padding: AppSpacing.allMd,
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户信息 - 对齐iOS: avatar + name + time + category tag
            Row(
              children: [
                // 头像 (带白色边框 + 阴影)
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                    backgroundImage: post.author?.avatar != null
                        ? NetworkImage(post.author!.avatar!)
                        : null,
                    child: post.author?.avatar == null
                        ? Icon(Icons.person,
                            color: AppColors.primary.withValues(alpha: 0.5),
                            size: 22)
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.author?.name ?? context.l10n.forumUserFallback(post.authorId.toString()),
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatTime(context, post.createdAt),
                        style: AppTypography.caption.copyWith(
                          color: isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                // 分类标签 (胶囊)
                if (post.category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: AppRadius.allPill,
                    ),
                    child: Text(
                      post.category!.displayName,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // 标题
            Text(
              post.title,
              style: AppTypography.bodyBold.copyWith(
                fontSize: 16,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            // 内容预览
            if (post.content != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                post.content!,
                style: AppTypography.subheadline.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                  height: 1.4,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // 分隔线
            Divider(
              height: 1,
              color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                  .withValues(alpha: 0.3),
            ),

            const SizedBox(height: AppSpacing.sm),

            // 互动栏 - 对齐iOS: 点赞 + 评论 + 浏览
            Row(
              children: [
                _InteractionItem(
                  icon: post.isLiked
                      ? Icons.thumb_up
                      : Icons.thumb_up_outlined,
                  count: post.likeCount,
                  color: post.isLiked ? AppColors.primary : null,
                  isDark: isDark,
                ),
                const SizedBox(width: 20),
                _InteractionItem(
                  icon: Icons.chat_bubble_outline,
                  count: post.replyCount,
                  isDark: isDark,
                ),
                const Spacer(),
                Icon(
                  Icons.more_horiz,
                  size: 16,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
              ],
            ),
          ],
        ),
      ),
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

/// 互动项组件 (点赞/评论)
class _InteractionItem extends StatelessWidget {
  const _InteractionItem({
    required this.icon,
    required this.count,
    required this.isDark,
    this.color,
  });

  final IconData icon;
  final int count;
  final bool isDark;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final defaultColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiaryLight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? defaultColor),
        const SizedBox(width: 4),
        Text(
          count > 0 ? '$count' : '',
          style: AppTypography.caption.copyWith(
            color: color ?? defaultColor,
            fontWeight: color != null ? FontWeight.w600 : null,
          ),
        ),
      ],
    );
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
      [const Color(0xFFFF6B6B), const Color(0xFFFF4757)],
      [const Color(0xFF7C5CFC), const Color(0xFF5F27CD)],
      [const Color(0xFF2ED573), const Color(0xFF00B894)],
      [const Color(0xFFFF9500), const Color(0xFFFF6B00)],
      [const Color(0xFF5856D6), const Color(0xFF007AFF)],
    ];
    return gradients[hash.abs() % gradients.length];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _gradient;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        context.push('/leaderboard/${leaderboard.id}');
      },
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.cardBackgroundDark
              : AppColors.cardBackgroundLight,
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
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
                        fit: BoxFit.cover,
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
                        leaderboard.displayName,
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
                      if (leaderboard.displayDescription != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          leaderboard.displayDescription!,
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
