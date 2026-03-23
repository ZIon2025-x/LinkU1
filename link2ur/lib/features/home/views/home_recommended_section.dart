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
      _StoryEntry(emoji: '\u{1F4F7}', label: l10n.homeStoryPhotography),
      _StoryEntry(emoji: '\u{1F4BB}', label: l10n.homeStoryCoding),
      _StoryEntry(emoji: '\u{1F3B5}', label: l10n.homeStoryMusic),
      _StoryEntry(emoji: '\u{1F4DD}', label: l10n.homeStoryWriting),
      _StoryEntry(emoji: '\u{1F3AA}', label: l10n.homeActivities),
    ];

    return SizedBox(
      height: 100,
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
                    child: Text(context.l10n.homeTickerLabel,
                        style: const TextStyle(
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

          // Banner — static promo card
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
              child: Text(
                context.l10n.homeExploreNow,
                style: const TextStyle(
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

