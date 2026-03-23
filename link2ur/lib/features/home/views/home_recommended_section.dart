part of 'home_view.dart';

/// 推荐Tab — Xiaohongshu/Pinterest 风格: Story Row + Ticker Banner + 瀑布流
class _RecommendedTab extends StatelessWidget {
  const _RecommendedTab();

  @override
  Widget build(BuildContext context) {
    final isDesktop = ResponsiveUtils.isDesktop(context);

    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.status != curr.status ||
          prev.isRefreshing != curr.isRefreshing ||
          prev.banners != curr.banners ||
          prev.tickerItems != curr.tickerItems ||
          prev.discoveryItems != curr.discoveryItems ||
          prev.isLoadingDiscovery != curr.isLoadingDiscovery ||
          prev.hasMoreDiscovery != curr.hasMoreDiscovery,
      builder: (context, state) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return RefreshIndicator(
          onRefresh: () async {
            final bloc = context.read<HomeBloc>();
            bloc.add(const HomeRefreshRequested());
            await bloc.stream.firstWhere(
              (s) => !s.isRefreshing,
              orElse: () => state,
            );
          },
          child: CustomScrollView(
            slivers: [
              // 1. Story Row — 水平圆形入口
              SliverToBoxAdapter(
                child: isDesktop
                    ? const ContentConstraint(child: _StoryRow())
                    : const _StoryRow(),
              ),

              // 2. Ticker + Banner
              SliverToBoxAdapter(
                child: isDesktop
                    ? ContentConstraint(
                        child: _TickerBanner(
                          tickerItems: state.tickerItems,
                          banners: state.banners,
                        ),
                      )
                    : _TickerBanner(
                        tickerItems: state.tickerItems,
                        banners: state.banners,
                      ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 8)),

              // 3. "为你推荐" 标题
              SliverToBoxAdapter(
                child: isDesktop
                    ? ContentConstraint(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.auto_awesome,
                                size: 22,
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                context.l10n.homeDiscoverMore,
                                style: AppTypography.title3.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 18,
                                  color: isDark
                                      ? AppColors.textPrimaryDark
                                      : AppColors.desktopTextLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              context.l10n.homeDiscoverMore,
                              style: AppTypography.title3.copyWith(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.desktopTextLight,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // 4. 瀑布流 — 复用 _SliverDiscoveryFeed
              SliverLayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.crossAxisExtent;
                  final double outerPad;
                  final double innerPad;
                  if (isDesktop) {
                    outerPad = ((w - Breakpoints.maxContentWidth) / 2)
                        .clamp(0.0, double.infinity);
                    innerPad = 24;
                  } else {
                    outerPad = w > 520 ? (w - 520) / 2 : 10;
                    innerPad = 0;
                  }
                  return SliverPadding(
                    padding: EdgeInsets.symmetric(horizontal: outerPad),
                    sliver: _SliverDiscoveryFeed(horizontalPadding: innerPad),
                  );
                },
              ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Story Row — 水平圆形快捷入口
// =============================================================================

class _StoryEntry {
  const _StoryEntry({required this.emoji, required this.label, this.route});
  final String emoji;
  final String label;
  final String? route;
}

class _StoryRow extends StatelessWidget {
  const _StoryRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entries = [
      const _StoryEntry(emoji: '\u{1F916}', label: 'Linker AI', route: '/ai-chat'),
      _StoryEntry(emoji: '\u{1F4D0}', label: l10n.homeExperts, route: '/task-experts'),
      _StoryEntry(emoji: '\u{1F6D2}', label: l10n.homeSecondHandMarket, route: '/flea-market'),
      const _StoryEntry(emoji: '\u{1F4F7}', label: '\u{6444}\u{5F71}'),
      const _StoryEntry(emoji: '\u{1F4BB}', label: '\u{7F16}\u{7A0B}'),
      const _StoryEntry(emoji: '\u{1F3B5}', label: '\u{97F3}\u{4E50}'),
      const _StoryEntry(emoji: '\u{1F4DD}', label: '\u{6587}\u{6848}'),
      _StoryEntry(emoji: '\u{1F3AA}', label: l10n.homeActivities),
    ];

    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final e = entries[i];
          return GestureDetector(
            onTap: () {
              if (e.route != null) context.push(e.route!);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFF093FB), Color(0xFFF5576C)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(2.5),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    alignment: Alignment.center,
                    child: Text(e.emoji, style: const TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  e.label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF666666)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// =============================================================================
// Ticker + Banner — 滚动公告 + 促销横幅
// =============================================================================

class _TickerBanner extends StatefulWidget {
  const _TickerBanner({required this.tickerItems, required this.banners});
  final List<TickerItem> tickerItems;
  final List<app_banner.Banner> banners;

  @override
  State<_TickerBanner> createState() => _TickerBannerState();
}

class _TickerBannerState extends State<_TickerBanner> {
  int _tickerIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTickerTimer();
  }

  @override
  void didUpdateWidget(covariant _TickerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tickerItems != widget.tickerItems) {
      _timer?.cancel();
      _tickerIndex = 0;
      _startTickerTimer();
    }
  }

  void _startTickerTimer() {
    if (widget.tickerItems.isNotEmpty) {
      _timer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (mounted) {
          setState(() =>
              _tickerIndex = (_tickerIndex + 1) % widget.tickerItems.length);
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final hasTicker = widget.tickerItems.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Ticker bar
          if (hasTicker)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [Color(0xFF5A52D5), Color(0xFF8B7DE8)]),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(12)),
              ),
              child: Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(56),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('\u{52A8}\u{6001}',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 500),
                      child: Text(
                        widget.tickerItems[_tickerIndex].displayText(locale),
                        key: ValueKey(_tickerIndex),
                        style: TextStyle(
                            color: Colors.white.withAlpha(230), fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Banner area — reuse existing _BannerCarousel for dynamic banners,
          // or show a static promo card if no banners
          if (widget.banners.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.vertical(
                top: hasTicker ? Radius.zero : const Radius.circular(16),
                bottom: const Radius.circular(16),
              ),
              child: SizedBox(
                height: 162,
                child: _BannerCarousel(serverBanners: widget.banners),
              ),
            )
          else
            _StaticPromoBanner(hasTicker: hasTicker),
        ],
      ),
    );
  }
}

/// 静态促销卡片 — 当没有后端 banner 时显示
class _StaticPromoBanner extends StatelessWidget {
  const _StaticPromoBanner({required this.hasTicker});
  final bool hasTicker;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(
          top: hasTicker ? Radius.zero : const Radius.circular(16),
          bottom: const Radius.circular(16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('\u{1F389} ${l10n.homeSecondHandMarket}',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            l10n.homeSecondHandSubtitle,
            style: TextStyle(
                color: Colors.white.withAlpha(217), fontSize: 13),
          ),
          const SizedBox(height: 14),
          GestureDetector(
            onTap: () => context.push('/flea-market'),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                '\u{7ACB}\u{5373}\u{4F53}\u{9A8C} \u{2192}',
                style: TextStyle(
                    color: Color(0xFF667EEA),
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 以下保留旧的辅助 widgets，供桌面端或其他 Tab 使用
// =============================================================================

/// "查看全部" 按钮 — Notion 风格
class _ViewAllButton extends StatefulWidget {
  const _ViewAllButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ViewAllButton> createState() => _ViewAllButtonState();
}

class _ViewAllButtonState extends State<_ViewAllButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: 'View all',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.commonViewAll,
              style: TextStyle(
                fontSize: 14,
                color: _isHovered ? AppColors.primary : AppColors.primary.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: _isHovered ? AppColors.primary : AppColors.primary.withValues(alpha: 0.8),
              size: 16,
            ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 桌面端 Banner 并排行（硬编码 + 后端 banner 合并，最多展示 4 个）
class _DesktopBannerRow extends StatelessWidget {
  const _DesktopBannerRow({required this.serverBanners});

  final List<app_banner.Banner> serverBanners;

  void _handleTap(BuildContext context, _BannerData banner) {
    final linkUrl = banner.linkUrl;
    if (linkUrl == null || linkUrl.isEmpty) return;

    if (banner.linkType == 'external') {
      ExternalWebView.openInApp(context, url: linkUrl);
    } else {
      context.safePush(linkUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allBanners = <_BannerData>[
      const _BannerData(
        localImage: AppAssets.fleaMarketBanner,
        gradient: AppColors.gradientGreen,
        icon: Icons.storefront,
        linkUrl: '/flea-market',
      ),
      const _BannerData(
        localImage: AppAssets.studentVerificationBanner,
        gradient: AppColors.gradientIndigo,
        icon: Icons.school,
        linkUrl: '/student-verification',
      ),
      for (final b in serverBanners)
        _BannerData(
          title: b.title,
          subtitle: b.subtitle,
          networkImage: b.imageUrl,
          gradient: AppColors.gradientPrimary,
          icon: Icons.campaign,
          linkType: b.linkType,
          linkUrl: b.linkUrl,
        ),
    ];

    final display = allBanners.take(4).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 180,
        child: Row(
          children: [
            for (int i = 0; i < display.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: Builder(builder: (context) {
                  final banner = display[i];
                  final displayTitle = banner.title ??
                      (banner.linkUrl == '/flea-market'
                          ? l10n.homeSecondHandMarket
                          : banner.linkUrl == '/student-verification'
                              ? l10n.homeStudentVerification
                              : '');
                  final displaySubtitle = banner.subtitle ??
                      (banner.linkUrl == '/flea-market'
                          ? l10n.homeSecondHandSubtitle
                          : banner.linkUrl == '/student-verification'
                              ? l10n.homeStudentVerificationSubtitle
                              : '');
                  return _BannerItem(
                    title: displayTitle,
                    subtitle: displaySubtitle,
                    gradient: banner.gradient,
                    icon: banner.icon,
                    localImage: banner.localImage,
                    networkImage: banner.networkImage,
                    onTap: () => _handleTap(context, banner),
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 桌面端活动行（使用真实数据，最多展示 3 个）
class _DesktopActivitiesRow extends StatelessWidget {
  const _DesktopActivitiesRow({required this.activities});

  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    final display = activities.take(3).toList();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SizedBox(
        height: 280,
        child: Row(
          children: [
            for (int i = 0; i < display.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              Expanded(
                child: _RealActivityCard(
                  activity: display[i],
                  locale: locale,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 桌面端任务卡片（自适应宽度，带 hover 效果）
class _DesktopTaskCard extends StatefulWidget {
  const _DesktopTaskCard({super.key, required this.task});
  final Task task;

  @override
  State<_DesktopTaskCard> createState() => _DesktopTaskCardState();
}

class _DesktopTaskCardState extends State<_DesktopTaskCard> {
  bool _isHovered = false;

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
    final locale = Localizations.localeOf(context);
    final task = widget.task;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: Semantics(
        button: true,
        label: 'View task',
        excludeSemantics: true,
        child: GestureDetector(
          onTap: () => context.safePush('/tasks/${task.id}'),
          child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: _isHovered ? 0.85 : 1.0,
          child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isDark ? AppColors.cardBackgroundDark : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.desktopBorderLight,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 图片区域
              Expanded(
                flex: 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: task.firstImage != null
                          ? AsyncImageView(
                                imageUrl: task.firstImage!,
                                width: 280,
                                height: 210,
                                memCacheWidth: 360,
                              )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.08),
                                    AppColors.primary.withValues(alpha: 0.03),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  _taskTypeIcon(task.taskType),
                                  color: AppColors.primary.withValues(alpha: 0.2),
                                  size: 36,
                                ),
                              ),
                            ),
                    ),
                    // 位置标签
                    if (task.location != null)
                      Positioned(
                        top: 8, left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                task.isOnline ? Icons.language : Icons.location_on,
                                size: 11, color: isDark ? Colors.white : AppColors.desktopTextLight,
                              ),
                              const SizedBox(width: 3),
                              ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 80),
                                child: Text(
                                  task.location ?? 'Online',
                                  style: TextStyle(
                                    fontSize: 11, fontWeight: FontWeight.w500,
                                    color: isDark ? Colors.white : AppColors.desktopTextLight,
                                  ),
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // 右上: 推荐徽章
                    Positioned(
                      top: 8, right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.gradientOrange,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.busy.withValues(alpha: 0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.auto_awesome, size: 10, color: Colors.white),
                            const SizedBox(width: 3),
                            Text(
                              context.l10n.homeRecommendedBadge,
                              style: const TextStyle(
                                fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // 内容区域
              Expanded(
                flex: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.displayTitle(locale),
                        style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.desktopTextLight,
                        ),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                      if (task.displayDescription(locale) != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          task.displayDescription(locale)!,
                          style: TextStyle(
                            fontSize: 12, color: isDark ? AppColors.textSecondaryDark : AppColors.desktopPlaceholderLight,
                            height: 1.4,
                          ),
                          maxLines: 2, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const Spacer(),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: AppColors.taskTypeBadgeGradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(_taskTypeIcon(task.taskType), size: 10, color: Colors.white),
                                const SizedBox(width: 2),
                                Text(
                                  TaskTypeHelper.getLocalizedLabel(task.taskType, context.l10n),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (task.deadline != null) ...[
                            Icon(Icons.schedule, size: 12,
                                color: isDark ? AppColors.textSecondaryDark : AppColors.desktopPlaceholderLight),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                _formatDeadline(context, task.deadline!),
                                style: TextStyle(fontSize: 11,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.desktopPlaceholderLight),
                                maxLines: 1, overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            const Spacer(),
                          if (task.isPriceToBeQuoted)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.textSecondary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                context.l10n.taskRewardToBeQuoted,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                              ),
                            )
                          else if (task.reward > 0)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                Helpers.formatPrice(task.reward),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
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
}

/// 推荐任务骨架屏 — 匹配横向滚动卡片布局
class _SkeletonHorizontalCards extends StatelessWidget {
  const _SkeletonHorizontalCards({required this.isDesktop});

  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);

    if (isDesktop) {
      return SkeletonGrid(
        crossAxisCount: ResponsiveUtils.gridColumnCount(context, type: GridItemType.task),
        aspectRatio: 0.82,
      );
    }

    return ListView.separated(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.only(
        left: AppSpacing.md, right: AppSpacing.lg, top: 4, bottom: 10,
      ),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(width: 12),
      itemBuilder: (context, index) {
        return Container(
          width: 220,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: isDark
                ? AppColors.cardBackgroundDark
                : AppColors.cardBackgroundLight,
            borderRadius: AppRadius.allLarge,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 170,
                width: double.infinity,
                color: baseColor,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 14,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          height: 12,
                          width: 80,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          height: 22,
                          width: 48,
                          decoration: BoxDecoration(
                            color: baseColor,
                            borderRadius: BorderRadius.circular(11),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 筛选弹窗中的选择标签
class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.1)
                : (isDark ? Colors.white.withValues(alpha: 0.06) : AppColors.skeletonBase),
            borderRadius: BorderRadius.circular(20),
            border: isSelected
                ? Border.all(color: AppColors.primary, width: 1.5)
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
            ),
          ),
        ),
      ),
    );
  }
}
