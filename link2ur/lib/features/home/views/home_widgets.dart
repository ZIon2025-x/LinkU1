part of 'home_view.dart';

/// 对标iOS: GreetingSection - 个性化问候语
class _GreetingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final authState = context.watch<AuthBloc>().state;
    final userName = authState.isAuthenticated
        ? (authState.user?.name ?? context.l10n.homeDefaultUser)
        : context.l10n.homeClassmate;

    final horizontalPadding = isDesktop ? 40.0 : AppSpacing.md;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          horizontalPadding, AppSpacing.lg, horizontalPadding, AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GradientText.brand(
                  text: context.l10n.homeGreeting(userName),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  context.l10n.homeWhatToDo,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          // 对标iOS: Image(systemName: "sparkles") + .ultraThinMaterial + Circle
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: AppColors.primary,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

/// 对标iOS: BannerCarouselSection - 横幅轮播
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel();

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final PageController _controller = PageController();
  // 使用 ValueNotifier 替代 setState，缩小重建范围
  // 只有依赖这些值的子 Widget 会重建，而非整个 _BannerCarousel
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  final ValueNotifier<double> _pageOffset = ValueNotifier<double>(0.0);

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  void _onScroll() {
    if (_controller.hasClients) {
      _pageOffset.value = _controller.page ?? 0.0;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    _currentPage.dispose();
    _pageOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SizedBox(
            height: 162,
            // ValueListenableBuilder 仅在 _pageOffset 变化时重建 PageView 内容
            child: ValueListenableBuilder<double>(
              valueListenable: _pageOffset,
              builder: (context, pageOffset, _) {
                return PageView.builder(
                  clipBehavior: Clip.none,
                  controller: _controller,
                  itemCount: 3,
                  onPageChanged: (index) {
                    _currentPage.value = index;
                  },
                  itemBuilder: (context, index) {
                    // 视差偏移量：图片移动速度慢于卡片（0.3倍率）
                    final parallaxOffset = (pageOffset - index) * 30;

                    final banners = [
                      // 跳蚤市场Banner
                      _BannerItem(
                        title: context.l10n.homeSecondHandMarket,
                        subtitle: context.l10n.homeSecondHandSubtitle,
                        gradient: const [Color(0xFF34C759), Color(0xFF30D158)],
                        icon: Icons.storefront,
                        imagePath: AppAssets.fleaMarketBanner,
                        imageAlignment: const Alignment(0.0, 0.4),
                        onTap: () => context.push('/flea-market'),
                        parallaxOffset: parallaxOffset,
                      ),
                      // 学生认证Banner
                      _BannerItem(
                        title: context.l10n.homeStudentVerification,
                        subtitle: context.l10n.homeStudentVerificationSubtitle,
                        gradient: const [Color(0xFF5856D6), Color(0xFF007AFF)],
                        icon: Icons.school,
                        imagePath: AppAssets.studentVerificationBanner,
                        onTap: () => context.push('/student-verification'),
                        parallaxOffset: parallaxOffset,
                      ),
                      // 任务达人Banner
                      _BannerItem(
                        title: context.l10n.homeBecomeExpert,
                        subtitle: context.l10n.homeBecomeExpertSubtitle,
                        gradient: const [Color(0xFFFF9500), Color(0xFFFF6B00)],
                        icon: Icons.star,
                        onTap: () => context.push('/task-experts/intro'),
                        parallaxOffset: parallaxOffset,
                      ),
                    ];

                    return banners[index];
                  },
                );
              },
            ),
          ),
        ),
        // 页面指示器 — 仅在 _currentPage 变化时重建
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _currentPage,
          builder: (context, currentPage, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: currentPage == index ? 18 : 6,
                  decoration: BoxDecoration(
                    color: currentPage == index
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.2),
                    borderRadius: AppRadius.allPill,
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.imagePath,
    this.parallaxOffset = 0.0,
    this.imageAlignment = Alignment.center,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final String? imagePath;
  final double parallaxOffset;
  final Alignment imageAlignment;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          gradient: imagePath == null
              ? LinearGradient(
                  colors: gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: AppRadius.allLarge,
          boxShadow: [
            BoxShadow(
              color: Colors.white.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // 真实图片背景 — 带视差效果
            if (imagePath != null)
              Transform.translate(
                offset: Offset(parallaxOffset, 0),
                child: Image.asset(
                  imagePath!,
                  fit: BoxFit.cover,
                  alignment: imageAlignment,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: gradient,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    );
                  },
                ),
              ),
            // 底部渐变遮罩，仅覆盖下方保证文字可读（与 iOS 原生一致）
            if (imagePath != null)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 100,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.black.withValues(alpha: 0.6),
                        Colors.black.withValues(alpha: 0.2),
                        Colors.transparent,
                      ],
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                    ),
                  ),
                ),
              ),
            // 装饰图标（无图片时显示）
            if (imagePath == null)
              Positioned(
                right: 20,
                bottom: 10,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
            // 文字内容
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                      shadows: const [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            gradient: const [Color(0xFFFF6B6B), Color(0xFFFF4757)],
            icon: Icons.card_giftcard,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: context.l10n.homeInviteFriends,
            subtitle: context.l10n.homeInviteFriendsSubtitle,
            gradient: const [Color(0xFF7C5CFC), Color(0xFF5F27CD)],
            icon: Icons.people,
            onTap: () => context.push('/activities'),
          ),
          const SizedBox(width: 12),
          _ActivityCard(
            title: context.l10n.homeDailyCheckIn,
            subtitle: context.l10n.homeDailyCheckInSubtitle,
            gradient: const [Color(0xFF2ED573), Color(0xFF00B894)],
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                ),
                AppSpacing.vXs,
                Text(
                  context.l10n.homeNoActivityMessage,
                  style: AppTypography.caption.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ],
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
        return const [Color(0xFF007AFF), Color(0xFF5856D6)];
      // 跳蚤市场 → 橙色（warning 风格）
      case RecentActivityItem.typeFleaMarketItem:
        return const [Color(0xFFFF9500), Color(0xFFFF6B00)];
      // 排行榜 → 绿色（success 风格）
      case RecentActivityItem.typeLeaderboardCreated:
        return const [Color(0xFF34C759), Color(0xFF30D158)];
      default:
        return const [Color(0xFF8E8E93), Color(0xFF636366)];
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
            context.push('/forum/posts/${activity.itemId}');
            break;
          case RecentActivityItem.typeFleaMarketItem:
            context.push('/flea-market/${activity.itemId}');
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

/// 对标iOS: 横向任务卡片 (完全对标 iOS TaskCard 风格)
/// 图片(160px) + 3段渐变遮罩 + ultraThinMaterial毛玻璃标签 + 任务类型标签 + 双层阴影
class _HorizontalTaskCard extends StatelessWidget {
  const _HorizontalTaskCard({required this.task});

  final Task task;

  // 任务类型图标 — 使用统一映射
  IconData _taskTypeIcon(String taskType) => TaskTypeHelper.getIcon(taskType);

  String _formatDeadline(BuildContext context, DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return context.l10n.homeDeadlineExpired;
    if (diff.inDays > 0) return context.l10n.homeDeadlineDays(diff.inDays);
    if (diff.inHours > 0) return context.l10n.homeDeadlineHours(diff.inHours);
    return context.l10n.homeDeadlineMinutes(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.push('/tasks/${task.id}');
      },
      child: Container(
        width: 220,
        clipBehavior: Clip.antiAlias,
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
          // 对标iOS: 双层阴影 - primary色柔和扩散 + 黑色紧密底部
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 图片区域 (对标iOS + 3段渐变 + 毛玻璃标签) =====
            SizedBox(
              height: 170,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片或占位背景（对标iOS placeholderBackground）
                  if (task.firstImage != null)
                    Hero(
                      tag: 'task_image_${task.id}',
                      child: AsyncImageView(
                        imageUrl: task.firstImage!,
                        width: 220,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                      child: Icon(
                        _taskTypeIcon(task.taskType),
                        color: AppColors.primary.withValues(alpha: 0.25),
                        size: 44,
                      ),
                    ),

                  // 对标iOS: 3段渐变遮罩（0.2→0.0→0.4）
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.20),
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.40),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // 左上: 位置标签 (对标iOS .ultraThinMaterial + Capsule)
                  if (task.location != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: AppRadius.allPill,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: AppRadius.allPill,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.isOnline
                                      ? Icons.language
                                      : Icons.location_on,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 80),
                                  child: Text(
                                    task.location!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 右下: 任务类型标签 (对标iOS taskType capsule + .ultraThinMaterial)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: ClipRRect(
                      borderRadius: AppRadius.allPill,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: AppRadius.allPill,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _taskTypeIcon(task.taskType),
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                task.taskTypeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  // 右上: 推荐徽章
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF9500), Color(0xFFFF6B00)],
                        ),
                        borderRadius: AppRadius.allPill,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF9500)
                                .withValues(alpha: 0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            context.l10n.homeRecommendedBadge,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== 内容区域 (对标iOS - title + deadline + price badge) =====
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 标题（对标iOS .body字号 + lineLimit(2)）
                  Text(
                    task.displayTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                      height: 1.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // 底部: 截止时间 + 价格标签（对标iOS底部信息栏）
                  Row(
                      children: [
                        // 截止时间 (对标iOS clock.fill + formatDeadline)
                        if (task.deadline != null) ...[
                          Icon(
                            Icons.schedule,
                            size: 12,
                            color: task.isExpired
                                ? AppColors.error
                                : (isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight),
                          ),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              _formatDeadline(context, task.deadline!),
                              style: TextStyle(
                                fontSize: 11,
                                color: task.isExpired
                                    ? AppColors.error
                                    : (isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ] else
                          const Spacer(),
                        // 价格标签 (对标iOS 绿色Capsule + £符号分离)
                        if (task.reward > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success,
                              borderRadius: AppRadius.allPill,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  task.currency == 'GBP' ? '£' : '\$',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  task.reward.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: NearbyTasksView (附近Tab)
/// 使用 Geolocator 获取设备位置，加载附近任务
class _NearbyTab extends StatefulWidget {
  const _NearbyTab();

  @override
  State<_NearbyTab> createState() => _NearbyTabState();
}

class _NearbyTabState extends State<_NearbyTab> {
  bool _locationLoading = false;

  @override
  void initState() {
    super.initState();
    _loadLocation();
  }

  Future<void> _loadLocation() async {
    setState(() {
      _locationLoading = true;
    });

    try {
      // 检查位置服务是否启用
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // 位置服务未开启，使用默认坐标（伦敦）
        _loadWithCoordinates(51.5074, -0.1278);
        return;
      }

      // 检查权限
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // 权限被拒绝，使用默认坐标
          _loadWithCoordinates(51.5074, -0.1278);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // 永久拒绝，使用默认坐标
        _loadWithCoordinates(51.5074, -0.1278);
        return;
      }

      // 获取位置
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () async {
          // 超时使用最后已知位置
          final last = await Geolocator.getLastKnownPosition();
          if (last != null) return last;
          throw Exception('Location timeout');
        },
      );

      _loadWithCoordinates(position.latitude, position.longitude);
    } catch (e) {
      // 获取位置失败，使用默认坐标
      _loadWithCoordinates(51.5074, -0.1278);
    }
  }

  void _loadWithCoordinates(double lat, double lng) {
    if (!mounted) return;
    setState(() => _locationLoading = false);
    context.read<HomeBloc>().add(HomeLoadNearby(
          latitude: lat,
          longitude: lng,
        ));
  }

  @override
  Widget build(BuildContext context) {
    if (_locationLoading) {
      return const SkeletonTopImageCardList(itemCount: 3, imageHeight: 140);
    }

    return BlocBuilder<HomeBloc, HomeState>(
      // 仅在附近任务数据或加载状态变化时重建
      buildWhen: (prev, curr) =>
          prev.nearbyTasks != curr.nearbyTasks ||
          prev.isLoading != curr.isLoading,
      builder: (context, state) {
        if (state.isLoading && state.nearbyTasks.isEmpty) {
          return const SkeletonTopImageCardList(itemCount: 3, imageHeight: 140);
        }

        if (state.nearbyTasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.location_off_outlined,
                  size: 64,
                  color: AppColors.textTertiaryLight,
                ),
                AppSpacing.vMd,
                Text(
                  context.l10n.homeNoNearbyTasks,
                  style: const TextStyle(color: AppColors.textSecondaryLight),
                ),
                AppSpacing.vMd,
                TextButton.icon(
                  onPressed: _loadLocation,
                  icon: const Icon(Icons.refresh),
                  label: Text(context.l10n.homeLoadNearbyTasks),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async {
            await _loadLocation();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: ListView.separated(
            padding: AppSpacing.allMd,
            itemCount: state.nearbyTasks.length,
            separatorBuilder: (_, __) => AppSpacing.vMd,
            itemBuilder: (context, index) {
              return AnimatedListItem(
                index: index,
                child: _TaskCard(task: state.nearbyTasks[index]),
              );
            },
          ),
        );
      },
    );
  }
}

/// 对标iOS: TaskExpertListContentView (达人Tab)
/// 内嵌达人列表，点击搜索框跳转到完整搜索页
class _ExpertsTab extends StatelessWidget {
  const _ExpertsTab();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => TaskExpertBloc(
        taskExpertRepository: context.read<TaskExpertRepository>(),
      )..add(const TaskExpertLoadRequested()),
      child: const _ExpertsTabContent(),
    );
  }
}

class _ExpertsTabContent extends StatefulWidget {
  const _ExpertsTabContent();

  @override
  State<_ExpertsTabContent> createState() => _ExpertsTabContentState();
}

class _ExpertsTabContentState extends State<_ExpertsTabContent> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  static const _debounceDuration = Duration(milliseconds: 400);

  @override
  void dispose() {
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () {
      if (!mounted) return;
      context.read<TaskExpertBloc>().add(
            TaskExpertLoadRequested(skill: query.isEmpty ? null : query),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // 内联搜索框：直接输入，下方实时过滤
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            style: AppTypography.subheadline.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
            decoration: InputDecoration(
              hintText: context.l10n.homeSearchExperts,
              hintStyle: AppTypography.subheadline.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiaryLight,
                size: 20,
              ),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      _onSearchChanged('');
                    },
                    child: Icon(
                      Icons.close,
                      size: 18,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  );
                },
              ),
              filled: true,
              fillColor: isDark
                  ? AppColors.cardBackgroundDark
                  : AppColors.cardBackgroundLight,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              border: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
                borderSide: BorderSide(
                  color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                      .withValues(alpha: 0.3),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
                borderSide: BorderSide(
                  color: (isDark ? AppColors.dividerDark : AppColors.dividerLight)
                      .withValues(alpha: 0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.allMedium,
                borderSide: const BorderSide(
                  color: AppColors.primary,
                  width: 1,
                ),
              ),
            ),
          ),
        ),

        // 对标iOS: 达人卡片列表
        Expanded(
          child: BlocBuilder<TaskExpertBloc, TaskExpertState>(
            builder: (context, state) {
              if (state.status == TaskExpertStatus.loading &&
                  state.experts.isEmpty) {
                return const SkeletonList(imageSize: 68);
              }

              if (state.status == TaskExpertStatus.error &&
                  state.experts.isEmpty) {
                return ErrorStateView.loadFailed(
                  message: state.errorMessage,
                  onRetry: () {
                    context.read<TaskExpertBloc>().add(
                          const TaskExpertLoadRequested(),
                        );
                  },
                );
              }

              if (state.experts.isEmpty) {
                return EmptyStateView.noData(
                  title: context.l10n.homeExperts,
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<TaskExpertBloc>().add(
                        const TaskExpertRefreshRequested(),
                      );
                  await Future.delayed(const Duration(milliseconds: 500));
                },
                child: ListView.separated(
                  padding: AppSpacing.allMd,
                  itemCount: state.experts.length + (state.hasMore ? 1 : 0),
                  separatorBuilder: (_, __) => AppSpacing.vMd,
                  itemBuilder: (context, index) {
                    if (index == state.experts.length) {
                      context.read<TaskExpertBloc>().add(
                            const TaskExpertLoadMore(),
                          );
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16.0),
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }
                    return AnimatedListItem(
                      index: index,
                      child: _ExpertCard(expert: state.experts[index]),
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 达人卡片 - 对标iOS ExpertCard
/// 头像光晕(74背景+68头像) + 认证徽章 + 名称/简介/统计 + chevron
class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.expert});

  final TaskExpert expert;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        final expertId = int.tryParse(expert.id) ?? 0;
        if (expertId > 0) {
          context.push('/task-experts/$expertId');
        }
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
        ),
        child: Row(
          children: [
            // 头像 + 光晕 (对标iOS: 74背景圆 + 68头像 + shadow)
            Container(
              width: 74,
              height: 74,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: AvatarView(
                  imageUrl: expert.avatar,
                  name: expert.displayName,
                  size: 68,
                ),
              ),
            ),
            AppSpacing.hMd,
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 名称 + 认证徽章 (对标iOS checkmark.seal.fill)
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          expert.displayName,
                          style: AppTypography.bodyBold.copyWith(
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ],
                  ),
                  // 简介（双语）— 为空时显示占位文本 (对标iOS)
                  const SizedBox(height: 4),
                  Text(
                    (expert.displayBio != null && expert.displayBio!.isNotEmpty)
                        ? expert.displayBio!
                        : context.l10n.taskExpertNoIntro,
                    style: AppTypography.caption.copyWith(
                      color: (expert.displayBio != null && expert.displayBio!.isNotEmpty)
                          ? (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight)
                          : (isDark
                              ? AppColors.textTertiaryDark
                              : AppColors.textTertiaryLight),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  // 统计行 (对标iOS: 胶囊评分 + 完成数·完成率)
                  Row(
                    children: [
                      // 评分胶囊
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: AppRadius.allPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 12, color: AppColors.warning),
                            const SizedBox(width: 3),
                            Text(
                              expert.ratingDisplay,
                              style: AppTypography.caption2.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      // 完成单数 · 完成率
                      Text(
                        context.l10n
                            .leaderboardCompletedCount(expert.completedTasks),
                        style: AppTypography.caption2.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      if (expert.totalServices > 0) ...[
                        Text(
                          ' · ',
                          style: AppTypography.caption2.copyWith(
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                        ),
                        Text(
                          context.l10n.taskExpertServiceCount(
                              expert.totalServices),
                          style: AppTypography.caption2.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            // Chevron
            Icon(
              Icons.chevron_right_rounded,
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
}

/// 任务卡片 - 垂直列表（对标iOS TaskCard风格：图片在上 + 内容在下）
class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final Task task;

  // 任务类型图标 — 使用统一映射
  IconData _taskTypeIcon(String taskType) => TaskTypeHelper.getIcon(taskType);

  String _formatDeadline(BuildContext context, DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now);
    if (diff.isNegative) return context.l10n.homeDeadlineExpired;
    if (diff.inDays > 0) return context.l10n.homeDeadlineDays(diff.inDays);
    if (diff.inHours > 0) return context.l10n.homeDeadlineHours(diff.inHours);
    return context.l10n.homeDeadlineMinutes(diff.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        AppHaptics.selection();
        context.push('/tasks/${task.id}');
      },
      child: Container(
        clipBehavior: Clip.antiAlias,
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
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ===== 图片区域 (对标iOS 140px + 渐变 + 毛玻璃标签) =====
            SizedBox(
              height: 140,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 图片或占位背景
                  if (task.firstImage != null)
                    AsyncImageView(
                      imageUrl: task.firstImage!,
                      width: double.infinity,
                      height: 140,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.12),
                            AppColors.primary.withValues(alpha: 0.04),
                          ],
                        ),
                      ),
                      child: Icon(
                        _taskTypeIcon(task.taskType),
                        color: AppColors.primary.withValues(alpha: 0.25),
                        size: 48,
                      ),
                    ),

                  // 3段渐变遮罩
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.15),
                          Colors.black.withValues(alpha: 0.0),
                          Colors.black.withValues(alpha: 0.35),
                        ],
                        stops: const [0.0, 0.4, 1.0],
                      ),
                    ),
                  ),

                  // 左上: 位置标签 (毛玻璃)
                  if (task.location != null)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: ClipRRect(
                        borderRadius: AppRadius.allPill,
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.18),
                              borderRadius: AppRadius.allPill,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                                width: 0.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  task.isOnline
                                      ? Icons.language
                                      : Icons.location_on,
                                  size: 12,
                                  color: Colors.white,
                                ),
                                const SizedBox(width: 3),
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    task.location!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                  // 右下: 任务类型标签 (毛玻璃)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: ClipRRect(
                      borderRadius: AppRadius.allPill,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: AppRadius.allPill,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 0.5,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _taskTypeIcon(task.taskType),
                                size: 12,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                task.taskTypeText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ===== 内容区域 =====
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题
                  Text(
                    task.displayTitle,
                    style: AppTypography.bodyBold.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (task.displayDescription != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      task.displayDescription!,
                      style: AppTypography.caption.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 10),
                  // 底部信息栏（对标iOS: 截止时间 + 状态 + 价格）
                  Row(
                    children: [
                      // 截止时间
                      if (task.deadline != null) ...[
                        Icon(
                          Icons.schedule,
                          size: 13,
                          color: task.isExpired
                              ? AppColors.error
                              : (isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight),
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            _formatDeadline(context, task.deadline!),
                            style: TextStyle(
                              fontSize: 12,
                              color: task.isExpired
                                  ? AppColors.error
                                  : (isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ] else
                        const Spacer(),
                      // 状态标签（对标iOS StatusBadge: 圆点+文字）
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.taskStatusColor(task.status)
                              .withValues(alpha: 0.1),
                          borderRadius: AppRadius.allPill,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.taskStatusColor(task.status),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              task.statusText,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.taskStatusColor(task.status),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // 价格标签（对标iOS绿色Capsule）
                      if (task.reward > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            borderRadius: AppRadius.allPill,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                task.currency == 'GBP' ? '£' : '\$',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                task.reward.toStringAsFixed(0),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 对标iOS: MenuView - 菜单视图
class _MenuView extends StatelessWidget {
  const _MenuView();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // 标题栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.l10n.menuMenu,
                  style: AppTypography.title3.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.menuClose),
                ),
              ],
            ),
          ),
          // 对标iOS: 菜单项列表
          Expanded(
            child: ListView(
              padding: AppSpacing.horizontalMd,
              children: [
                _MenuListItem(
                  icon: Icons.person,
                  title: context.l10n.menuMy,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/profile');
                  },
                ),
                _MenuListItem(
                  icon: Icons.list_alt,
                  title: context.l10n.menuTaskHall,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/tasks');
                  },
                ),
                _MenuListItem(
                  icon: Icons.star,
                  title: context.l10n.menuTaskExperts,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/task-experts');
                  },
                ),
                _MenuListItem(
                  icon: Icons.forum,
                  title: context.l10n.menuForum,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/forum');
                  },
                ),
                _MenuListItem(
                  icon: Icons.emoji_events,
                  title: context.l10n.menuLeaderboard,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/leaderboard');
                  },
                ),
                _MenuListItem(
                  icon: Icons.shopping_cart,
                  title: context.l10n.menuFleaMarket,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/flea-market');
                  },
                ),
                _MenuListItem(
                  icon: Icons.calendar_month,
                  title: context.l10n.menuActivity,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/activities');
                  },
                ),
                _MenuListItem(
                  icon: Icons.stars,
                  title: context.l10n.menuPointsCoupons,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/coupon-points');
                  },
                ),
                _MenuListItem(
                  icon: Icons.verified_user,
                  title: context.l10n.menuStudentVerification,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/student-verification');
                  },
                ),
                const Divider(height: 32),
                _MenuListItem(
                  icon: Icons.settings,
                  title: context.l10n.menuSettings,
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MenuListItem extends StatelessWidget {
  const _MenuListItem({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDark
            ? AppColors.textPrimaryDark
            : AppColors.textPrimaryLight,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTypography.body.copyWith(
          color: isDark
              ? AppColors.textPrimaryDark
              : AppColors.textPrimaryLight,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiaryLight,
        size: 18,
      ),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }
}

/// 对标iOS: SearchView - 搜索视图
class _SearchView extends StatefulWidget {
  const _SearchView();

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  String _searchQuery = '';

  // 热门搜索关键词
  List<String> _getHotKeywords(BuildContext context) => [
    context.l10n.taskCategoryPickup,
    context.l10n.taskCategoryTutoring,
    context.l10n.taskCategoryMoving,
    context.l10n.taskCategoryPurchasing,
    context.l10n.taskCategoryDogWalking,
    context.l10n.taskCategoryTranslation,
    context.l10n.taskCategoryPhotography,
    context.l10n.taskCategoryTutor,
  ];

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.cardBackgroundDark
            : AppColors.cardBackgroundLight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 拖拽指示器
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          AppSpacing.vSm,

          // 搜索栏
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    focusNode: _focusNode,
                    onChanged: (value) =>
                        setState(() => _searchQuery = value),
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        Navigator.pop(context);
                        context.push('/tasks');
                      }
                    },
                    decoration: InputDecoration(
                      hintText: context.l10n.searchPlaceholder,
                      prefixIcon: const Icon(Icons.search, size: 20),
                      filled: true,
                      fillColor: isDark
                          ? AppColors.secondaryBackgroundDark
                          : AppColors.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.allSmall,
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ),
                AppSpacing.hSm,
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(context.l10n.commonCancel),
                ),
              ],
            ),
          ),

          // 搜索内容
          Expanded(
            child: _searchQuery.isEmpty
                ? _buildSearchHome(isDark)
                : _buildSearchResults(isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHome(bool isDark) {
    return SingleChildScrollView(
      padding: AppSpacing.allMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.homeHotSearches,
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: _getHotKeywords(context).map((keyword) {
              return GestureDetector(
                onTap: () {
                  _searchController.text = keyword;
                  setState(() => _searchQuery = keyword);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.secondaryBackgroundDark
                        : AppColors.backgroundLight,
                    borderRadius: AppRadius.allPill,
                  ),
                  child: Text(
                    keyword,
                    style: AppTypography.caption.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          AppSpacing.vXl,

          // 搜索分类
          Text(
            context.l10n.homeSearchCategory,
            style: AppTypography.title3.copyWith(
              color: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimaryLight,
            ),
          ),
          AppSpacing.vMd,
          _SearchCategoryItem(
            icon: Icons.task_alt,
            title: context.l10n.homeSearchTasks,
            color: AppColors.primary,
            onTap: () {
              Navigator.pop(context);
              context.push('/tasks');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.star,
            title: context.l10n.homeSearchExperts,
            color: AppColors.accent,
            onTap: () {
              Navigator.pop(context);
              context.push('/task-experts');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.storefront,
            title: context.l10n.homeSearchFleaMarket,
            color: AppColors.success,
            onTap: () {
              Navigator.pop(context);
              context.push('/flea-market');
            },
          ),
          _SearchCategoryItem(
            icon: Icons.forum,
            title: context.l10n.homeSearchPosts,
            color: AppColors.teal,
            onTap: () {
              Navigator.pop(context);
              context.push('/forum');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search,
            size: 48,
            color: isDark
                ? AppColors.textTertiaryDark
                : AppColors.textTertiaryLight,
          ),
          AppSpacing.vMd,
          Text(
            context.l10n.homeSearchQueryResult(_searchQuery),
            style: AppTypography.body.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          AppSpacing.vSm,
          Text(
            context.l10n.homePressEnterToSearch,
            style: AppTypography.caption.copyWith(
              color: isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiaryLight,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchCategoryItem extends StatelessWidget {
  const _SearchCategoryItem({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.allSmall,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            AppSpacing.hMd,
            Expanded(
              child: Text(
                title,
                style: AppTypography.body.copyWith(
                  color: isDark
                      ? AppColors.textPrimaryDark
                      : AppColors.textPrimaryLight,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
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
