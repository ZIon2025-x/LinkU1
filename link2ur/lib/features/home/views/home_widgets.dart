part of 'home_view.dart';

/// 对标iOS: headerSection — 两行问候 + 右侧通知按钮
class _GreetingSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = ResponsiveUtils.isDesktop(context);
    // 使用 select 只监听用户名变化，避免 AuthBloc 任何状态变更都触发重建
    final isAuthenticated = context.select<AuthBloc, bool>((bloc) => bloc.state.isAuthenticated);
    final userNameFromState = context.select<AuthBloc, String?>((bloc) => bloc.state.user?.name);
    final userName = isAuthenticated
        ? (userNameFromState ?? context.l10n.homeDefaultUser)
        : context.l10n.homeClassmate;

    final horizontalPadding = isDesktop ? 40.0 : AppSpacing.md;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          horizontalPadding, AppSpacing.sm, horizontalPadding, 0),
      child: Row(
        children: [
          // 左侧：两行问候文字（对标iOS headerSection）
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 小字副标题
                Text(
                  context.l10n.homeWhatToDo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                // 大字用户名
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
          // 右侧：AI 助手按钮（后续接入 AI 对话功能）
          GestureDetector(
            onTap: () => context.push('/ai-chat'),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.gradientPrimary,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 20,
              ),
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
  static const _bannerCount = 3;
  static const _autoPlayInterval = Duration(seconds: 4);

  final PageController _controller = PageController(viewportFraction: 0.88);
  final ValueNotifier<int> _currentPage = ValueNotifier<int>(0);
  final ValueNotifier<double> _pageOffset = ValueNotifier<double>(0.0);

  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
    _startAutoPlay();
  }

  void _onScroll() {
    if (_controller.hasClients) {
      _pageOffset.value = _controller.page ?? 0.0;
    }
  }

  void _startAutoPlay() {
    _autoPlayTimer?.cancel();
    _autoPlayTimer = Timer.periodic(_autoPlayInterval, (_) {
      if (!_controller.hasClients) return;
      final next = (_currentPage.value + 1) % _bannerCount;
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
                return GestureDetector(
                  // 手指按下时暂停自动轮播，抬起后恢复
                  onPanDown: (_) => _stopAutoPlay(),
                  onPanEnd: (_) => _startAutoPlay(),
                  onPanCancel: () => _startAutoPlay(),
                  child: PageView.builder(
                  clipBehavior: Clip.none,
                  controller: _controller,
                  itemCount: _bannerCount,
                  onPageChanged: (index) {
                    _currentPage.value = index;
                  },
                  itemBuilder: (context, index) {
                    // 视差偏移量：图片移动速度慢于卡片（0.3倍率）
                    final parallaxOffset = (pageOffset - index) * 30;
                    // 当前页略大，相邻页略小
                    final offset = (pageOffset - index).abs();
                    final scale = (1.0 - (offset * 0.05)).clamp(0.92, 1.0);

                    final banners = [
                      // 跳蚤市场Banner
                      _BannerItem(
                        title: context.l10n.homeSecondHandMarket,
                        subtitle: context.l10n.homeSecondHandSubtitle,
                        gradient: AppColors.gradientGreen,
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
                        gradient: AppColors.gradientIndigo,
                        icon: Icons.school,
                        imagePath: AppAssets.studentVerificationBanner,
                        onTap: () => context.push('/student-verification'),
                        parallaxOffset: parallaxOffset,
                      ),
                      // 任务达人Banner
                      _BannerItem(
                        title: context.l10n.homeBecomeExpert,
                        subtitle: context.l10n.homeBecomeExpertSubtitle,
                        gradient: AppColors.gradientOrange,
                        icon: Icons.star,
                        onTap: () => context.push('/task-experts/intro'),
                        parallaxOffset: parallaxOffset,
                      ),
                    ];

                    return Transform.scale(
                      scale: scale,
                      alignment: Alignment.center,
                      child: banners[index],
                    );
                  },
                ),
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
              children: List.generate(_bannerCount, (index) {
                final isActive = currentPage == index;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  height: 6,
                  width: isActive ? 18 : 6,
                  decoration: BoxDecoration(
                    gradient: isActive
                        ? const LinearGradient(
                            colors: AppColors.gradientPrimary,
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          )
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
            // 装饰图标（无图片时显示）— 右上角，避免与底部文字重叠
            if (imagePath == null)
              Positioned(
                right: 16,
                top: 12,
                child: Icon(
                  icon,
                  size: 64,
                  color: Colors.white.withValues(alpha: 0.25),
                ),
              ),
            // 文字内容 — 底部对齐，配合渐变遮罩保证可读性
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
