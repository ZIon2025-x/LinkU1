part of 'home_view.dart';

/// Currency symbol — delegates to Helpers for multi-currency support
String _currencySymbol(String? currency) => Helpers.currencySymbolFor(currency ?? 'GBP');


// =============================================================================
// Discovery Feed 鐎戝竷娴?鈥?鏇夸唬鏃х殑 _RecentActivitiesSection
// =============================================================================

/// 鍙戠幇鏇村鍔犺浇楠ㄦ灦 鈥?涓ゅ垪鍗＄墖鍗犱綅锛堜笌鐑棬娲诲姩楠ㄦ灦椋庢牸涓€鑷达級
class _DiscoveryFeedSkeleton extends StatelessWidget {
  const _DiscoveryFeedSkeleton({required this.horizontalPadding});
  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.cardBackgroundLight;
    final place = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    const spacing = 10.0;
    final crossCount = ResponsiveUtils.gridColumnCount(context);
    final itemCount = (crossCount * 2).clamp(4, 8);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding == 0 ? 10 : horizontalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - spacing * (crossCount - 1)) / crossCount;
          final imageHeight = width * (3 / 4);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (int row = 0; row < (itemCount / crossCount).ceil(); row++) ...[
                if (row > 0) const SizedBox(height: spacing),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int col = 0; col < crossCount; col++) ...[
                      if (col > 0) const SizedBox(width: spacing),
                      SizedBox(
                        width: width,
                        child: Container(
                          decoration: BoxDecoration(
                            color: bg,
                            borderRadius:
                                BorderRadius.circular(_kDiscoveryCardRadius),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                height: imageHeight,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: place,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(_kDiscoveryCardRadius),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      height: 14,
                                      width: 56,
                                      decoration: BoxDecoration(
                                        color: place,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      height: 12,
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        color: place,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      height: 12,
                                      width: 100,
                                      decoration: BoxDecoration(
                                        color: place,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 鍙戠幇鏇村 鈥?Sliver 鐗堟湰鐎戝竷娴侊紙閬垮厤 shrinkWrap: true 鐮村潖瑙嗗彛浼樺寲锛?/// 鏃ф柟妗堬細MasonryGridView + shrinkWrap: true + NeverScrollableScrollPhysics
///   鈫?鎵€鏈夋潯鐩珛鍗冲叏閮?layout锛屾棤瑙嗗彛瑁佸壀锛宨tems 瓒婂瓒婂崱
/// 鏂版柟妗堬細SliverMasonryGrid 澶╃劧鏀寔瑙嗗彛浼樺寲锛屽彧鏋勫缓鍙鍖哄煙
class _SliverDiscoveryFeed extends StatelessWidget {
  const _SliverDiscoveryFeed({
    required this.horizontalPadding,
    this.banners = const [],
  });
  final double horizontalPadding;
  final List<app_banner.Banner> banners;

  /// 把 banner 均匀插入 discoveryItems，返回混合列表
  List<Object> _buildMixedItems(List<DiscoveryFeedItem> items) {
    final allBanners = <_BannerData>[
      const _BannerData(
        localImage: AppAssets.studentVerificationBanner,
        gradient: AppColors.gradientIndigo,
        icon: Icons.school,
        linkUrl: '/student-verification',
      ),
      for (final b in banners)
        _BannerData(
          title: b.title,
          subtitle: b.subtitle,
          networkImage: b.imageUrl,
          gradient: AppColors.gradientPrimary,
          icon: Icons.campaign,
          linkType: b.linkType,
          linkUrl: b.linkUrl,
          badgeType: b.badgeType,
        ),
    ];

    // 每隔 interval 个 feed item 插一个 banner
    final interval = items.length > allBanners.length
        ? (items.length / (allBanners.length + 1)).ceil().clamp(3, 8)
        : 4;

    final mixed = <Object>[];
    int bannerIdx = 0;
    for (int i = 0; i < items.length; i++) {
      if (i > 0 && i % interval == 0 && bannerIdx < allBanners.length) {
        mixed.add(allBanners[bannerIdx++]);
      }
      mixed.add(items[i]);
    }
    while (bannerIdx < allBanners.length) {
      mixed.add(allBanners[bannerIdx++]);
    }
    return mixed;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.discoveryItems != curr.discoveryItems ||
          prev.isLoadingDiscovery != curr.isLoadingDiscovery,
      builder: (context, state) {
        if (state.isLoadingDiscovery && state.discoveryItems.isEmpty) {
          return SliverToBoxAdapter(
            child: _DiscoveryFeedSkeleton(horizontalPadding: horizontalPadding),
          );
        }

        if (state.discoveryItems.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  context.l10n.emptyNoData,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          );
        }

        // 璁＄畻鎬?item 鏁?= feed items + (鍔犺浇鏇村鎸夐挳鍗?1 涓?Sliver)
        final mixedItems = _buildMixedItems(state.discoveryItems);

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding == 0 ? 4 : horizontalPadding),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: ResponsiveUtils.gridColumnCount(context),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childCount: mixedItems.length,
                itemBuilder: (context, index) {
                  final item = mixedItems[index];
                  if (item is _BannerData) {
                    return RepaintBoundary(
                      child: _DiscoveryBannerCard(banner: item),
                    );
                  }
                  return RepaintBoundary(
                    child: _DiscoveryFeedCard(item: item as DiscoveryFeedItem),
                  );
                },
              ),
            ),
            if (state.hasMoreDiscovery)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: state.isLoadingDiscovery
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => context
                                .read<HomeBloc>()
                                .add(const HomeLoadMoreDiscovery()),
                            child: Text(context.l10n.commonLoadMore),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 鍙戠幇 Feed 鍗＄墖璺敱 鈥?鏍规嵁 feedType 閫夋嫨灞曠ず
class _DiscoveryFeedCard extends StatelessWidget {
  const _DiscoveryFeedCard({required this.item});

  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    switch (item.feedType) {
      case 'forum_post':
        return _PostCard(item: item);
      case 'product':
        return _ProductCard(item: item);
      case 'competitor_review':
        return _CompetitorReviewCard(item: item);
      case 'service_review':
        return _ServiceReviewCard(item: item);
      case 'expert':
        return _ExpertCard(item: item);
      case 'service':
        return _ServiceCard(item: item);
      case 'task':
        return _DiscoveryTaskCard(item: item);
      case 'activity':
        return _DiscoveryActivityCard(item: item);
      case 'ai_qa':
        return _DiscoveryAiQaCard(item: item);
      case 'completion':
        return _DiscoveryCompletionCard(item: item);
      default:
        return const SizedBox.shrink();
    }
  }
}

// 涓?discovery_feed_prototype.html 涓€鑷寸殑鍙戠幇鍗＄墖鏍峰紡甯搁噺
const double _kDiscoveryCardRadius = 12;

/// 绫诲瀷寰界珷锛堜笌鍘熷瀷 badge-post / badge-product 绛変竴鑷达級
class _FeedTypeBadge extends StatelessWidget {
  const _FeedTypeBadge({required this.feedType});
  final String feedType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (String label, Color bg, Color fg) = _style(context, feedType, isDark);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }

  (String, Color, Color) _style(BuildContext context, String type, bool isDark) {
    if (isDark) {
      final bg = Colors.white.withValues(alpha: 0.15);
      const fg = Colors.white;
      return (_label(context, type), bg, fg);
    }
    switch (type) {
      case 'forum_post':
        return (_label(context, type), const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case 'product':
        return (_label(context, type), const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case 'competitor_review':
      case 'service_review':
        return (_label(context, type), const Color(0xFFFCE7F3), const Color(0xFFDB2777));
      case 'ranking':
        return (_label(context, type), const Color(0xFFDBEAFE), const Color(0xFF2563EB));
      case 'expert':
        return (_label(context, type), const Color(0xFFF3E8FF), const Color(0xFF7E22CE));
      case 'service':
        return (_label(context, type), const Color(0xFFFFF7ED), const Color(0xFFEA580C));
      case 'personal_skill':
        return (_label(context, type), const Color(0xFFECFDF5), const Color(0xFF059669));
      case 'task':
        return (_label(context, type), const Color(0xFFEFF6FF), const Color(0xFF3B82F6));
      case 'activity':
        return (_label(context, type), const Color(0xFFF0FDF4), const Color(0xFF16A34A));
      case 'ai_qa':
        // 蓝白品牌色 (Apple System Blue 主色),跟 task badge (#3B82F6) 区分
        return (_label(context, type), const Color(0xFFE5F2FF), const Color(0xFF007AFF));
      case 'completion':
        return (_label(context, type), const Color(0xFFF0FDF4), const Color(0xFF15803D));
      default:
        return (_label(context, type), const Color(0xFFE5E7EB), const Color(0xFF6B7280));
    }
  }

  String _label(BuildContext context, String type) {
    final l10n = context.l10n;
    switch (type) {
      case 'forum_post':
        return '📝 ${l10n.discoveryFeedTypePost}';
      case 'product':
        return '🛒 ${l10n.discoveryFeedTypeProduct}';
      case 'competitor_review':
        return '💬 ${l10n.discoveryFeedTypeCompetitorReview}';
      case 'service_review':
        return '💬 ${l10n.discoveryFeedTypeServiceReview}';
      case 'ranking':
        return '🏆 ${l10n.discoveryFeedTypeRanking}';
      case 'expert':
        return '⭐ ${l10n.discoveryFeedTypeExpert}';
      case 'service':
        return '🔧 ${l10n.discoveryFeedTypeService}';
      case 'personal_skill':
        return '✋ ${l10n.discoveryFeedTypePersonalSkill}';
      case 'task':
        return '📋 ${l10n.discoveryFeedTypeTask}';
      case 'activity':
        return '🎪 ${l10n.discoveryFeedTypeActivity}';
      case 'ai_qa':
        return '🤖 ${l10n.discoveryFeedTypeAiQa}';
      case 'completion':
        return '✅ ${l10n.discoveryFeedTypeCompletion}';
      default:
        return l10n.sidebarDiscover;
    }
  }
}

/// 发现更多区域内的 Banner 静态卡片（单张，非轮播）
class _DiscoveryBannerCard extends StatelessWidget {
  const _DiscoveryBannerCard({required this.banner});
  final _BannerData banner;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final displayTitle = banner.title ??
        (banner.linkUrl == '/student-verification'
            ? l10n.homeStudentVerification
            : '');
    final displaySubtitle = banner.subtitle ??
        (banner.linkUrl == '/student-verification'
            ? l10n.homeStudentVerificationSubtitle
            : '');

    return GestureDetector(
      onTap: () {
        final linkUrl = banner.linkUrl;
        if (linkUrl == null || linkUrl.isEmpty) return;
        if (banner.linkType == 'external') {
          ExternalWebView.openInApp(context, url: linkUrl);
        } else {
          context.safePush(linkUrl);
        }
      },
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: !banner.hasImage
              ? LinearGradient(
                  colors: banner.gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (banner.localImage != null)
                Image.asset(
                  banner.localImage!,
                  fit: BoxFit.cover,
                  cacheWidth: 800,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: banner.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                )
              else if (banner.networkImage != null && banner.networkImage!.isNotEmpty)
                AsyncImageView(
                  imageUrl: banner.networkImage!,
                  memCacheWidth: 800,
                  placeholder: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: banner.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  errorWidget: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: banner.gradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                ),
              if (banner.hasImage)
                Positioned(
                  left: 0, right: 0, bottom: 0, height: 60,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.5),
                          Colors.transparent,
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                      ),
                    ),
                  ),
                ),
              if (!banner.hasImage)
                Positioned(
                  right: 10, top: 8,
                  child: Icon(
                    banner.icon,
                    size: 40,
                    color: Colors.white.withValues(alpha: 0.25),
                  ),
                ),
              if (displayTitle.isNotEmpty || displaySubtitle.isNotEmpty)
                Positioned(
                  left: 10, right: 10, bottom: 8,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayTitle.isNotEmpty)
                        Text(
                          displayTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            shadows: [Shadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (displaySubtitle.isNotEmpty)
                        Text(
                          displaySubtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 11,
                            shadows: const [Shadow(color: Colors.black38, blurRadius: 4)],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              // 角标(promotion / new / hot / limited),后端 badge_type 字段控制
              if (banner.badgeType != null && banner.badgeType!.isNotEmpty)
                Positioned(
                  left: 8, top: 8,
                  child: _BannerBadge(badgeType: banner.badgeType!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// banner 角标 — 统一半透明黑底白字风格(对齐 mockup),不同 badgeType 仅文案不同
/// 未知 badgeType 直接渲染空(防御性处理,避免显示乱码)
class _BannerBadge extends StatelessWidget {
  const _BannerBadge({required this.badgeType});
  final String badgeType;

  @override
  Widget build(BuildContext context) {
    final label = _labelFor(badgeType, context);
    if (label == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  /// 后端 badge_type 约定值 → 本地化文案
  static String? _labelFor(String type, BuildContext context) {
    final l10n = context.l10n;
    switch (type) {
      case 'promotion':
        return l10n.bannerBadgePromotion;
      case 'new':
        return l10n.bannerBadgeNew;
      case 'hot':
        return l10n.bannerBadgeHot;
      case 'limited':
        return l10n.bannerBadgeLimited;
      default:
        return null;
    }
  }
}

// Discovery card types (_PostCard, _ProductCard, _CompetitorReviewCard,
// _ServiceReviewCard, _RankingCard, _ServiceCard, _ExpertCard) and shared widgets
// (_DiscoveryUserRow, _TargetItemTag, _ActivityPriceRow, _PosterVeil) are
// defined in home_discovery_cards.dart
// _PostCard 与 _ExpertCard 已改为海报式 — 首图/cover 当背景 + 文字全 overlay

/// 社区 tab(DiscoverView)使用的发现流 Sliver 入口。
///
/// 复用首页 HomeBloc.state.discoveryItems(MainTabView 全局 provider 跨 tab
/// 社区 tab 发现流 sliver
///
/// 数据源:DiscoverBloc.state.communityFeedItems (scope=community,
/// post/expert/review 社交导向),与首页发现流(HomeBloc, scope=home,转化导向)
/// 完全独立。不穿插 banner。
///
/// 复用 _DiscoveryFeedCard 卡片路由 + _DiscoveryFeedSkeleton 骨架,只是把
/// state 来源换成 DiscoverBloc。
class CommunityDiscoveryFeedSliver extends StatelessWidget {
  const CommunityDiscoveryFeedSliver({
    super.key,
    this.horizontalPadding = 0,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DiscoverBloc, DiscoverState>(
      buildWhen: (prev, curr) =>
          prev.communityFeedItems != curr.communityFeedItems ||
          prev.communityFeedStatus != curr.communityFeedStatus ||
          prev.communityFeedHasMore != curr.communityFeedHasMore,
      builder: (context, state) {
        final isLoading =
            state.communityFeedStatus == DiscoverFeedStatus.loading;
        final isError =
            state.communityFeedStatus == DiscoverFeedStatus.error;
        final items = state.communityFeedItems;

        if (isLoading && items.isEmpty) {
          return SliverToBoxAdapter(
            child:
                _DiscoveryFeedSkeleton(horizontalPadding: horizontalPadding),
          );
        }

        // 错误态(首次加载失败 → 列表为空) 给 retry 按钮,避免误导成"社区空空"
        if (isError && items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.cloud_off_outlined,
                      size: 36,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      context.l10n.errorNetworkError,
                      style: TextStyle(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => context
                          .read<DiscoverBloc>()
                          .add(const DiscoverLoadCommunityFeed()),
                      child: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (items.isEmpty) {
          return SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text(
                  context.l10n.emptyNoData,
                  style: TextStyle(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ),
            ),
          );
        }

        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding == 0 ? 4 : horizontalPadding),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: ResponsiveUtils.gridColumnCount(context),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                childCount: items.length,
                itemBuilder: (context, index) {
                  return RepaintBoundary(
                    child: _DiscoveryFeedCard(item: items[index]),
                  );
                },
              ),
            ),
            if (state.communityFeedHasMore)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : TextButton(
                            onPressed: () => context
                                .read<DiscoverBloc>()
                                .add(const DiscoverLoadMoreCommunityFeed()),
                            child: Text(context.l10n.commonLoadMore),
                          ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}