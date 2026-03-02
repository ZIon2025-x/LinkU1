part of 'home_view.dart';

/// Currency symbol (unified to £)
String _currencySymbol(String? currency) => '£';

/// Hot activities loading skeleton.
/// Matches iOS ActivityCardSkeleton: width 280, image 160 + content.
class _HomeActivitiesSkeleton extends StatelessWidget {
  const _HomeActivitiesSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.cardBackgroundLight;
    final place = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : Colors.black.withValues(alpha: 0.06);
    return SizedBox(
      height: 280,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.lg,
          top: 4,
          bottom: 10,
        ),
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Container(
              width: 280,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.allLarge,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 160,
                    decoration: BoxDecoration(
                      color: place,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(height: 14, width: 160, decoration: BoxDecoration(color: place, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 10),
                        Container(height: 12, width: 80, decoration: BoxDecoration(color: place, borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 8),
                        Container(height: 12, width: 120, decoration: BoxDecoration(color: place, borderRadius: BorderRadius.circular(4))),
                      ],
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

/// 瀵规爣iOS: PopularActivitiesSection - 鐑棬娲诲姩鍖哄煙锛堜娇鐢ㄧ湡瀹炴暟鎹級
/// iOS 鍗＄墖瀹?280锛屽浘鐗囬珮 160锛屼笅鏂瑰唴瀹瑰尯绾?100
class _PopularActivitiesSection extends StatelessWidget {
  const _PopularActivitiesSection({required this.activities});

  final List<Activity> activities;

  @override
  Widget build(BuildContext context) {
    if (activities.isEmpty) return const SizedBox.shrink();
    final locale = Localizations.localeOf(context);
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        padding: const EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.lg,
          top: 4,
          bottom: 10,
        ),
        itemCount: activities.length > 10 ? 10 : activities.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (context, index) {
          final activity = activities[index];
          return _RealActivityCard(activity: activity, locale: locale);
        },
      ),
    );
  }
}

/// 瀵规爣 iOS ActivityCardView 鈥?涓婁笅鍒嗗尯锛氬浘鐗囧尯 + 鍐呭鍖?/// 瀹?280锛屽浘鐗囬珮 160锛屽唴瀹瑰尯鑷€傚簲
class _RealActivityCard extends StatelessWidget {
  const _RealActivityCard({required this.activity, required this.locale});

  final Activity activity;
  final Locale locale;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final l10n = context.l10n;
    final title = activity.displayTitle(locale);
    final image = activity.firstImage;
    final price = activity.discountedPricePerParticipant ??
        activity.originalPricePerParticipant;

    return GestureDetector(
      onTap: () => context.push('/activities/${activity.id}'),
      child: Container(
        width: 280,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allLarge,
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.06),
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image area
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
              child: SizedBox(
                height: 160,
                width: double.infinity,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: image != null && image.isNotEmpty
                          ? AsyncImageView(
                                imageUrl: image,
                                width: 280,
                                height: 160,
                                memCacheWidth: 560,
                                memCacheHeight: 320,
                              )
                          : Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColors.primary.withValues(alpha: 0.1),
                                    AppColors.primary.withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Icon(
                                Icons.calendar_month,
                                size: 40,
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                    ),

                    // 鐘舵€佹爣绛撅紙鍙充笂瑙掞級
                    if (activity.isFull)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            l10n.activityFullCapacity,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Content area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 鏍囬
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 浠锋牸 + 鍙備笌浜烘暟
                    Row(
                      children: [
                        if (price != null && price > 0) ...[
                          const Text(
                            '拢',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          Text(
                            price.toStringAsFixed(0),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                        const Spacer(),
                        Icon(
                          Icons.people,
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${activity.currentParticipants ?? 0}/${activity.maxParticipants}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),

                    // Location + appointment tag
                    Row(
                      children: [
                        if (activity.location.isNotEmpty) ...[
                          Icon(
                            Icons.location_on,
                            size: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            child: Text(
                              activity.location,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ),
                        ] else
                          const Spacer(),
                        if (activity.hasTimeSlots)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              l10n.activityByAppointment,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: AppColors.warning,
                              ),
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
    );
  }
}

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
  const _SliverDiscoveryFeed({required this.horizontalPadding});
  final double horizontalPadding;

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
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding == 0 ? 10 : horizontalPadding),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: ResponsiveUtils.gridColumnCount(context),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childCount: state.discoveryItems.length,
                itemBuilder: (context, index) {
                  final item = state.discoveryItems[index];
                  return RepaintBoundary(
                    child: _DiscoveryFeedCard(item: item),
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
      case 'ranking':
        return _RankingCard(item: item);
      case 'service':
        return _ServiceCard(item: item);
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
      case 'service':
        return (_label(context, type), const Color(0xFFFFF7ED), const Color(0xFFEA580C));
      default:
        return (_label(context, type), const Color(0xFFE5E7EB), const Color(0xFF6B7280));
    }
  }

  String _label(BuildContext context, String type) {
    final l10n = context.l10n;
    switch (type) {
      case 'forum_post': return '馃挰 ${l10n.discoveryFeedTypePost}';
      case 'product': return '馃彿锔?${l10n.discoveryFeedTypeProduct}';
      case 'competitor_review': return '猸?${l10n.discoveryFeedTypeCompetitorReview}';
      case 'service_review': return '猸?${l10n.discoveryFeedTypeServiceReview}';
      case 'ranking': return '馃弳 ${l10n.discoveryFeedTypeRanking}';
      case 'service': return '馃懆鈥嶐煆?${l10n.discoveryFeedTypeService}';
      default: return l10n.sidebarDiscover;
    }
  }
}

// Discovery card types (_PostCard, _ProductCard, _CompetitorReviewCard,
// _ServiceReviewCard, _RankingCard, _ServiceCard) and shared widgets
// (_DiscoveryUserRow, _LinkedItemTag, _TargetItemTag, _ActivityPriceRow)
// are defined in home_discovery_cards.dart