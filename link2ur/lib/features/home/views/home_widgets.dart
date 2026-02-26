part of 'home_view.dart';

// ==================== 思考云朵（与 Linker 按钮绑定，随推荐页滚动） ====================

/// Linker 思考云朵 + 问候区：云朵在 Linker 按钮上方，同属推荐 Tab 首屏，下滑后一起移出视口
class _GreetingSectionWithCloud extends StatefulWidget {
  const _GreetingSectionWithCloud();

  @override
  State<_GreetingSectionWithCloud> createState() => _GreetingSectionWithCloudState();
}

class _GreetingSectionWithCloudState extends State<_GreetingSectionWithCloud> {
  bool _showCloud = false;
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _hasShownOnce = false;

  static const _showDuration = Duration(seconds: 4);
  static const _firstShowMin = 4;
  static const _firstShowMax = 8;
  static const _minInterval = Duration(seconds: 22);
  static const _maxInterval = Duration(seconds: 38);

  @override
  void initState() {
    super.initState();
    _scheduleNextShow();
  }

  void _scheduleNextShow() {
    _showTimer?.cancel();
    final int delaySeconds;
    if (!_hasShownOnce) {
      delaySeconds = _firstShowMin + Random().nextInt(_firstShowMax - _firstShowMin + 1);
    } else {
      final span = _maxInterval.inSeconds - _minInterval.inSeconds + 1;
      delaySeconds = _minInterval.inSeconds + Random().nextInt(span);
    }
    _showTimer = Timer(Duration(seconds: delaySeconds), () {
      if (!mounted) return;
      _hasShownOnce = true;
      setState(() => _showCloud = true);
      _hideTimer?.cancel();
      _hideTimer = Timer(_showDuration, () {
        if (!mounted) return;
        setState(() => _showCloud = false);
        _scheduleNextShow();
      });
    });
  }

  @override
  void dispose() {
    _showTimer?.cancel();
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isAuthenticated = context.select<AuthBloc, bool>((bloc) => bloc.state.isAuthenticated);
    final userNameFromState = context.select<AuthBloc, String?>((bloc) => bloc.state.user?.name);
    final userName = isAuthenticated
        ? (userNameFromState ?? context.l10n.homeDefaultUser)
        : context.l10n.homeClassmate;
    final horizontalPadding = isDesktop ? 24.0 : AppSpacing.md;

    // 云朵与 Linker 按钮重叠：Stack 内先画问候行，再在按钮上方叠云朵；顶部不做额外间距，被裁切可接受
    const cloudHeight = 91.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(horizontalPadding, AppSpacing.sm, horizontalPadding, 0),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.centerRight,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LinkerQuotes.randomQuote(Localizations.localeOf(context)),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.homeGreeting(userName),
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => context.push('/support-chat'),
                child: ClipOval(
                  child: Image.asset(
                    AppAssets.any,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ],
          ),
          Positioned(
            top: -cloudHeight + 42,
            right: 0,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showCloud ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                child: Image.asset(
                  AppAssets.cloud,
                  width: 140,
                  height: cloudHeight,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 对标iOS: headerSection — 两行问候 + 右侧 Linker 入口（无云朵，用于非推荐 Tab 或桌面）
class _GreetingSection extends StatelessWidget {
  const _GreetingSection();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    final isAuthenticated = context.select<AuthBloc, bool>((bloc) => bloc.state.isAuthenticated);
    final userNameFromState = context.select<AuthBloc, String?>((bloc) => bloc.state.user?.name);
    final userName = isAuthenticated
        ? (userNameFromState ?? context.l10n.homeDefaultUser)
        : context.l10n.homeClassmate;
    final horizontalPadding = isDesktop ? 24.0 : AppSpacing.md;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          horizontalPadding, AppSpacing.sm, horizontalPadding, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LinkerQuotes.randomQuote(Localizations.localeOf(context)),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.homeGreeting(userName),
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/support-chat'),
            child: ClipOval(
              child: Image.asset(
                AppAssets.any,
                width: 44,
                height: 44,
                fit: BoxFit.cover,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 对标iOS: BannerCarouselSection - 横幅轮播
/// 对齐 iOS 行为：前置 2 个硬编码 banner（跳蚤市场 + 学生认证），后接后端 banner
class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.serverBanners});

  final List<app_banner.Banner> serverBanners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  static const _autoPlayInterval = Duration(seconds: 4);

  late PageController _controller;
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  Timer? _autoPlayTimer;

  List<_BannerData> _allBanners = [];

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.88);
    _buildBannerList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _allBanners.length > 1) _startAutoPlay();
    });
  }

  @override
  void didUpdateWidget(covariant _BannerCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.serverBanners != widget.serverBanners) {
      _buildBannerList();
    }
  }

  void _buildBannerList() {
    _allBanners = [
      const _BannerData(
        localImage: AppAssets.fleaMarketBanner,
        imageAlignment: Alignment(0.0, 0.4),
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
      for (final b in widget.serverBanners)
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
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (_) {
      if (!_controller.hasClients || _allBanners.isEmpty) return;
      final next = (_currentPage.value + 1) % _allBanners.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _stopAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = null;
  }

  @override
  void dispose() {
    _stopAutoPlay();
    _controller.dispose();
    _currentPage.dispose();
    super.dispose();
  }

  void _handleTap(_BannerData banner) {
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
    if (_allBanners.isEmpty) return const SizedBox.shrink();

    final bannerCount = _allBanners.length;
    final l10n = context.l10n;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: SizedBox(
            height: 162,
            child: GestureDetector(
              onPanDown: (_) => _stopAutoPlay(),
              onPanEnd: (_) => _startAutoPlay(),
              onPanCancel: () => _startAutoPlay(),
              child: PageView.builder(
                clipBehavior: Clip.none,
                controller: _controller,
                itemCount: bannerCount,
                onPageChanged: (index) {
                  _currentPage.value = index;
                },
                itemBuilder: (context, index) {
                  final banner = _allBanners[index];
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

                  final child = _BannerItem(
                    title: displayTitle,
                    subtitle: displaySubtitle,
                    gradient: banner.gradient,
                    icon: banner.icon,
                    localImage: banner.localImage,
                    networkImage: banner.networkImage,
                    imageAlignment: banner.imageAlignment,
                    onTap: () => _handleTap(banner),
                  );

                  return AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      final page = _controller.hasClients
                          ? (_controller.page ?? 0.0)
                          : 0.0;
                      final offset = (page - index).abs();
                      final scale = (1.0 - (offset * 0.05)).clamp(0.92, 1.0);
                      return Transform.scale(scale: scale, child: child);
                    },
                    child: child,
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        ValueListenableBuilder<int>(
          valueListenable: _currentPage,
          builder: (context, currentPage, _) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(bannerCount, (index) {
                final isActive = currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: isActive ? 18 : 6,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? const LinearGradient(colors: AppColors.gradientPrimary)
                        : null,
                    color: isActive ? null : AppColors.primary.withValues(alpha: 0.2),
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

/// 统一的 banner 数据（硬编码 + 后端共用）
class _BannerData {
  const _BannerData({
    this.title,
    this.subtitle,
    this.localImage,
    this.networkImage,
    this.imageAlignment = Alignment.center,
    required this.gradient,
    required this.icon,
    this.linkType = 'internal',
    this.linkUrl,
  });

  final String? title;
  final String? subtitle;
  final String? localImage;
  final String? networkImage;
  final Alignment imageAlignment;
  final List<Color> gradient;
  final IconData icon;
  final String linkType;
  final String? linkUrl;

  bool get hasImage => localImage != null || (networkImage != null && networkImage!.isNotEmpty);
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
    this.localImage,
    this.networkImage,
    this.imageAlignment = Alignment.center,
  });

  final String title;
  final String subtitle;
  final List<Color> gradient;
  final IconData icon;
  final VoidCallback onTap;
  final String? localImage;
  final String? networkImage;
  final Alignment imageAlignment;

  bool get _hasImage => localImage != null || (networkImage != null && networkImage!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(4, 4, 4, 10),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: !_hasImage
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
          children: [
            Positioned.fill(
              child: localImage != null
                  ? Image.asset(
                      localImage!,
                      fit: BoxFit.cover,
                      alignment: imageAlignment,
                      cacheWidth: 800,
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
                    )
                  : (networkImage != null && networkImage!.isNotEmpty)
                      ? AsyncImageView(
                          imageUrl: networkImage!,
                          memCacheWidth: 800,
                          placeholder: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                          errorWidget: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
            ),
            if (_hasImage)
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
            if (!_hasImage)
              Positioned(
                right: 16,
                top: 12,
                child: Icon(
                  icon,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            if (title.isNotEmpty || subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                          shadows: const [
                            Shadow(
                              color: Colors.black38,
                              blurRadius: 6,
                              offset: Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
