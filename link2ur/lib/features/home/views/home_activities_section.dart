part of 'home_view.dart';

/// 对标iOS: PopularActivitiesSection - 热门活动区域
class _PopularActivitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 164,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.lg,
          top: 4,
          bottom: 10,
        ),
        children: [
          _ActivityCard(
            title: context.l10n.homeNewUserReward,
            subtitle: context.l10n.homeNewUserRewardSubtitle,
            gradient: AppColors.gradientCoral,
            icon: Icons.card_giftcard,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: context.l10n.homeInviteFriends,
            subtitle: context.l10n.homeInviteFriendsSubtitle,
            gradient: AppColors.gradientPurple,
            icon: Icons.people,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: context.l10n.homeDailyCheckIn,
            subtitle: context.l10n.homeDailyCheckInSubtitle,
            gradient: AppColors.gradientEmerald,
            icon: Icons.calendar_today,
            onTap: () => context.push('/activities'),
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 180,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.allLarge,
          // 对标iOS: 彩色阴影，更有深度感
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.35),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: gradient.last.withValues(alpha: 0.15),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Stack(
          children: [
            // 装饰性大圆 (右下角，增加层次感)
            Positioned(
              right: -20,
              bottom: -20,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.1),
                ),
              ),
            ),
            // 装饰性小圆 (右上角)
            Positioned(
              right: 20,
              top: -10,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            // 主内容
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 毛玻璃效果图标容器（对标iOS Material风格）
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const Spacer(),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: RecentActivitiesSection - 最新动态区域
/// 从 HomeBloc 获取真实数据，无穷滚动加载（每次5条，最多15条）
/// 对标 iOS batchSize=5, maxDisplayCount=15
class _RecentActivitiesSection extends StatefulWidget {
  @override
  State<_RecentActivitiesSection> createState() =>
      _RecentActivitiesSectionState();
}

class _RecentActivitiesSectionState extends State<_RecentActivitiesSection> {
  /// 当前显示条数（每次递增5，对标 iOS batchSize = 5）
  int _displayedCount = 5;

  /// 每批加载数量
  static const int _batchSize = 5;

  /// 最大显示数量（对标 iOS maxDisplayCount = 15）
  static const int _maxDisplayCount = 15;

  void _loadMore(int totalAvailable) {
    setState(() {
      _displayedCount = (_displayedCount + _batchSize)
          .clamp(0, totalAvailable.clamp(0, _maxDisplayCount));
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.recentActivities != curr.recentActivities ||
          prev.isLoadingActivities != curr.isLoadingActivities,
      builder: (context, state) {
        // 加载中状态
        if (state.isLoadingActivities && state.recentActivities.isEmpty) {
          return const Padding(
            padding: AppSpacing.allMd,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final allItems = state.recentActivities;

        if (allItems.isEmpty) {
          return Padding(
            padding: AppSpacing.allMd,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 48,
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  AppSpacing.vSm,
                  Text(
                    context.l10n.homeNoActivity,
                    style: AppTypography.body.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  AppSpacing.vXs,
                  Text(
                    context.l10n.homeNoActivityMessage,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        // 取当前批次要显示的条目（最多 _maxDisplayCount）
        final maxAvailable = allItems.length.clamp(0, _maxDisplayCount);
        final showCount = _displayedCount.clamp(0, maxAvailable);
        final displayedItems = allItems.take(showCount).toList();
        final hasMore = showCount < maxAvailable;

        // 转换为 UI 数据
        final activities = displayedItems.map((item) {
          return _RecentActivityData(
            icon: _getIconForType(item.type),
            iconGradient: _getGradientForType(item.type),
            userName: item.userName.isNotEmpty
                ? item.userName
                : context.l10n.homeDefaultUser,
            actionText: _getActionText(context, item.type),
            title: item.title,
            description: item.description,
            itemId: item.itemId,
            type: item.type,
          );
        }).toList();

        return Padding(
          padding: AppSpacing.horizontalMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 动态列表（带错落入场动画）
              ...activities.asMap().entries.map((entry) {
                final index = entry.key;
                final activity = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AnimatedListItem(
                    index: index,
                    child: _ActivityRow(activity: activity),
                  ),
                );
              }),

              // "加载更多" 或 "没有更多了"
              if (hasMore)
                _LoadMoreButton(
                  onTap: () => _loadMore(allItems.length),
                  isDark: isDark,
                )
              else if (displayedItems.length >= _batchSize)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      context.l10n.homeNoMoreActivity,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiaryLight,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  // ==================== 类型 → 图标 / 颜色 / 文本 ====================

  /// 根据动态类型获取图标
  static IconData _getIconForType(String type) {
    switch (type) {
      case RecentActivityItem.typeForumPost:
        return Icons.forum_rounded;
      case RecentActivityItem.typeFleaMarketItem:
        return Icons.shopping_bag_rounded;
      case RecentActivityItem.typeLeaderboardCreated:
        return Icons.emoji_events_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  /// 根据动态类型获取渐变色 — 三种类型颜色差异明显
  static List<Color> _getGradientForType(String type) {
    switch (type) {
      // 论坛帖子 → 蓝紫色（primary 风格）
      case RecentActivityItem.typeForumPost:
        return AppColors.gradientBlueTeal;
      // 跳蚤市场 → 橙色（warning 风格）
      case RecentActivityItem.typeFleaMarketItem:
        return const [Color(0xFFFF9500), Color(0xFFFF6B00)];
      // 排行榜 → 绿色（success 风格）
      case RecentActivityItem.typeLeaderboardCreated:
        return const [Color(0xFF34C759), Color(0xFF30D158)];
      default:
        return const [AppColors.offline, AppColors.textPlaceholderDark];
    }
  }

  /// 根据动态类型获取动作文本
  static String _getActionText(BuildContext context, String type) {
    switch (type) {
      case RecentActivityItem.typeForumPost:
        return context.l10n.homePostedNewPost;
      case RecentActivityItem.typeFleaMarketItem:
        return context.l10n.homePostedNewProduct;
      case RecentActivityItem.typeLeaderboardCreated:
        return context.l10n.homeCreatedLeaderboard;
      default:
        return context.l10n.homePostedNewPost;
    }
  }
}

/// "加载更多" 按钮
class _LoadMoreButton extends StatelessWidget {
  const _LoadMoreButton({required this.onTap, required this.isDark});

  final VoidCallback onTap;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.04)
              : Colors.black.withValues(alpha: 0.02),
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: (isDark
                    ? AppColors.separatorDark
                    : AppColors.separatorLight)
                .withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
            const SizedBox(width: 4),
            Text(
              context.l10n.homeLoadMore,
              style: AppTypography.caption.copyWith(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentActivityData {
  _RecentActivityData({
    required this.icon,
    required this.iconGradient,
    required this.userName,
    required this.actionText,
    required this.title,
    this.description,
    this.itemId,
    this.type = RecentActivityItem.typeForumPost,
  });

  final IconData icon;
  final List<Color> iconGradient;
  final String userName;
  final String actionText;
  final String title;
  final String? description;
  final String? itemId; // 原始数据 ID，用于导航跳转
  final String type;
}

/// 对标iOS: ActivityRow - 动态行组件（对标iOS .cardBackground + AppShadow.small）
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity});

  final _RecentActivityData activity;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (activity.itemId == null) return;
        // 根据动态类型跳转到对应详情页（对标 iOS ActivityRow NavigationLink）
        switch (activity.type) {
          case RecentActivityItem.typeForumPost:
            context.safePush('/forum/posts/${activity.itemId}');
            break;
          case RecentActivityItem.typeFleaMarketItem:
            context.safePush('/flea-market/${activity.itemId}');
            break;
          case RecentActivityItem.typeLeaderboardCreated:
            context.push('/leaderboard/${activity.itemId}');
            break;
        }
      },
      child: Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: AppRadius.allLarge,
        // 对标iOS: 0.5pt separator边框
        border: Border.all(
          color: (isDark ? AppColors.separatorDark : AppColors.separatorLight)
              .withValues(alpha: 0.3),
          width: 0.5,
        ),
        // 对标iOS: 双层阴影
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          // 对标iOS: 渐变图标 + 圆形 + 彩色阴影
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: activity.iconGradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: activity.iconGradient.first.withValues(alpha: 0.35),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              activity.icon,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 对标iOS: 合并用户名和动作文本 (body + semibold + secondary)
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: activity.userName,
                        style: AppTypography.body.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                      TextSpan(
                        text: ' ${activity.actionText}',
                        style: AppTypography.body.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  activity.title,
                  style: AppTypography.caption.copyWith(
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (activity.description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    activity.description!,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 16,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
        ],
      ),
      ),
    );
  }
}
