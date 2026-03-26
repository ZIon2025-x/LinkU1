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
  String? _cachedQuote;
  Timer? _showTimer;
  Timer? _hideTimer;
  bool _hasShownOnce = false;

  static const _showDuration = Duration(seconds: 4);
  static const _firstShowMin = 4;
  static const _firstShowMax = 8;
  static const _minInterval = Duration(seconds: 22);
  static const _maxInterval = Duration(seconds: 38);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedQuote ??= LinkerQuotes.randomQuote(Localizations.localeOf(context));
  }

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
    const cloudWidth = 100.0;
    const cloudHeight = 65.0;

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
                      _cachedQuote ?? '',
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
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: 'Open support chat',
                child: GestureDetector(
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
              ),
            ],
          ),
          Positioned(
            top: -cloudHeight + 42,
            right: 16,
            child: IgnorePointer(
              child: AnimatedOpacity(
                opacity: _showCloud ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 700),
                curve: Curves.easeInOut,
                child: Image.asset(
                  AppAssets.cloud,
                  width: cloudWidth,
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
class _GreetingSection extends StatefulWidget {
  const _GreetingSection();

  @override
  State<_GreetingSection> createState() => _GreetingSectionState();
}

class _GreetingSectionState extends State<_GreetingSection> {
  String? _cachedQuote;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _cachedQuote ??= LinkerQuotes.randomQuote(Localizations.localeOf(context));
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
                  _cachedQuote ?? '',
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
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
          Semantics(
            button: true,
            label: 'Open support chat',
            child: GestureDetector(
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
    _controller = PageController();
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
        SizedBox(
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

// =============================================================================
// Ticker Only — 只有公告滚动条（流程图替代了 Banner，Ticker 独立显示）
// =============================================================================

class _TickerOnly extends StatefulWidget {
  const _TickerOnly({required this.tickerItems});
  final List<TickerItem> tickerItems;

  @override
  State<_TickerOnly> createState() => _TickerOnlyState();
}

class _TickerOnlyState extends State<_TickerOnly> {
  int _tickerIndex = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTickerTimer();
  }

  @override
  void didUpdateWidget(covariant _TickerOnly oldWidget) {
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
    if (widget.tickerItems.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: AppColors.gradientPrimary,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(56),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                context.l10n.homeTickerLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: SizedBox(
                height: 22,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (child, animation) {
                    final isEntering = child.key == ValueKey(_tickerIndex);
                    final begin = isEntering
                        ? const Offset(0, 1)
                        : const Offset(0, -1);
                    return ClipRect(
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: begin,
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    widget.tickerItems[_tickerIndex].displayText(locale),
                    key: ValueKey(_tickerIndex),
                    style: TextStyle(
                      color: Colors.white.withAlpha(230),
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Platform Flow Banner — 方案D: 极简进度条式流程图
// =============================================================================

class _PlatformFlowBanner extends StatelessWidget {
  const _PlatformFlowBanner();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    final steps = [
      (icon: Icons.edit_note_rounded, label: l10n.homeFlowStepPost),
      (icon: Icons.person_add_rounded, label: l10n.homeFlowStepApply),
      (icon: Icons.account_balance_wallet_rounded, label: l10n.homeFlowStepPay),
      (icon: Icons.handshake_rounded, label: l10n.homeFlowStepConfirm),
      (icon: Icons.payments_rounded, label: l10n.homeFlowStepRelease),
    ];

    final guarantees = [
      (icon: Icons.account_balance_rounded, label: l10n.homeFlowGuaranteeEscrow),
      (icon: Icons.shield_rounded, label: l10n.homeFlowGuaranteeRefund),
      (icon: Icons.gavel_rounded, label: l10n.homeFlowGuaranteeDispute),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF007AFF), Color(0xFF409CFF), Color(0xFF5AC8FA)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              l10n.homeFlowTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              l10n.homeFlowSubtitle,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 14),

            // Progress nodes
            SizedBox(
              height: 62,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return Stack(
                    children: [
                      // Connection line
                      Positioned(
                        top: 16,
                        left: constraints.maxWidth / (steps.length * 2),
                        right: constraints.maxWidth / (steps.length * 2),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Nodes
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: steps.map((step) {
                          return Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.25),
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  step.icon,
                                  size: 16,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                step.label,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Guarantee bar
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: guarantees.map((g) {
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(g.icon, size: 14, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        g.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
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
    return Semantics(
      button: true,
      label: 'View banner',
      excludeSemantics: true,
      child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 10),
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
      ),
    );
  }
}
