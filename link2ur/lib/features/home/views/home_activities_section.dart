part of 'home_view.dart';

/// 货币符号：GBP 转为 £，否则默认 £
String _currencySymbol(String? currency) {
  if (currency == null || currency.isEmpty) return '£';
  if (currency.toUpperCase() == 'GBP') return '£';
  return '$currency ';
}

/// 热门活动加载骨架（无活动时隐藏区域，加载中显示此骨架）
class _HomeActivitiesSkeleton extends StatelessWidget {
  const _HomeActivitiesSkeleton();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.cardBackgroundDark
        : AppColors.cardBackgroundLight;
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
        children: List.generate(
          3,
          (_) => Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 180,
              decoration: BoxDecoration(
                color: bg,
                borderRadius: AppRadius.allLarge,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 对标iOS: PopularActivitiesSection - 热门活动区域
class _PopularActivitiesSection extends StatelessWidget {
  const _PopularActivitiesSection();

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
          // 单层阴影：减少 GPU 合成开销
          boxShadow: [
            BoxShadow(
              color: gradient.first.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Stack(
          children: [
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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

// =============================================================================
// Discovery Feed 瀑布流 — 替代旧的 _RecentActivitiesSection
// =============================================================================

/// 发现更多加载骨架 — 两列卡片占位（与热门活动骨架风格一致）
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
    const crossCount = 2;
    const itemCount = 6;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding == 0 ? 10 : horizontalPadding,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = (constraints.maxWidth - spacing) / crossCount;
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

/// 发现更多 — Sliver 版本瀑布流（避免 shrinkWrap: true 破坏视口优化）
/// 旧方案：MasonryGridView + shrinkWrap: true + NeverScrollableScrollPhysics
///   → 所有条目立即全部 layout，无视口裁剪，items 越多越卡
/// 新方案：SliverMasonryGrid 天然支持视口优化，只构建可见区域
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
                  '暂无内容',
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

        // 计算总 item 数 = feed items + (加载更多按钮占 1 个 Sliver)
        return SliverMainAxisGroup(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding == 0 ? 10 : horizontalPadding),
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
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
                            child: const Text('加载更多'),
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

/// 发现 Feed 卡片路由 — 根据 feedType 选择展示
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

// 与 discovery_feed_prototype.html 一致的发现卡片样式常量
const double _kDiscoveryCardRadius = 12;

/// 类型徽章（与原型 badge-post / badge-product 等一致）
class _FeedTypeBadge extends StatelessWidget {
  const _FeedTypeBadge({required this.feedType});
  final String feedType;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final (String label, Color bg, Color fg) = _style(feedType, isDark);
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

  (String, Color, Color) _style(String type, bool isDark) {
    if (isDark) {
      final bg = Colors.white.withValues(alpha: 0.15);
      const fg = Colors.white;
      return (_label(type), bg, fg);
    }
    switch (type) {
      case 'forum_post':
        return (_label(type), const Color(0xFFEDE9FE), const Color(0xFF7C3AED));
      case 'product':
        return (_label(type), const Color(0xFFFEF3C7), const Color(0xFFD97706));
      case 'competitor_review':
      case 'service_review':
        return (_label(type), const Color(0xFFFCE7F3), const Color(0xFFDB2777));
      case 'ranking':
        return (_label(type), const Color(0xFFDBEAFE), const Color(0xFF2563EB));
      case 'service':
        return (_label(type), const Color(0xFFFFF7ED), const Color(0xFFEA580C));
      default:
        return (_label(type), const Color(0xFFE5E7EB), const Color(0xFF6B7280));
    }
  }

  String _label(String type) {
    switch (type) {
      case 'forum_post': return '💬 帖子';
      case 'product': return '🏷️ 商品';
      case 'competitor_review': return '⭐ 竞品评价';
      case 'service_review': return '⭐ 服务评价';
      case 'ranking': return '🏆 排行榜';
      case 'service': return '👨‍🏫 达人服务';
      default: return '发现';
    }
  }
}

// =============================================================================
// 卡片类型 1: 帖子卡片
// =============================================================================

class _PostCard extends StatelessWidget {
  const _PostCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final postId = item.id.replaceFirst('post_', '');
        context.push('/forum/posts/$postId');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 图片
            if (item.hasImages)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: AsyncImageView(
                  imageUrl: item.firstImage!,
                  fit: BoxFit.cover,
                ),
              ),
            // 文字内容
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _FeedTypeBadge(feedType: 'forum_post'),
                      if (item.extraData?['category_name'] != null) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            item.extraData!['category_name'] as String,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (item.title != null)
                    Text(
                      item.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  if (item.description != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      item.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                  // 关联内容标签
                  if (item.linkedItem != null) ...[
                    const SizedBox(height: 6),
                    _LinkedItemTag(linkedItem: item.linkedItem!),
                  ],
                  const SizedBox(height: 8),
                  // 底部：用户/达人（有 expertId 时点击进达人详情页）
                  _DiscoveryUserRow(
                    userId: item.userId,
                    userName: item.userName,
                    userAvatar: item.userAvatar,
                    expertId: item.expertId,
                    isDark: isDark,
                  ),
                  // 操作行（与原型 feed-actions 一致）
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Icon(Icons.favorite_border, size: 14,
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                        const SizedBox(width: 3),
                        Text('${item.likeCount ?? 0}',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                        const SizedBox(width: 12),
                        Icon(Icons.chat_bubble_outline, size: 14,
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                        const SizedBox(width: 3),
                        Text('${item.commentCount ?? 0}',
                            style: TextStyle(fontSize: 11, color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
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

// =============================================================================
// 卡片类型 2: 商品卡片（跳蚤市场风格）
// =============================================================================

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final id = item.id.replaceFirst('product_', '');
        if (id.isNotEmpty) {
          context.push('/flea-market/$id');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.hasImages)
              AspectRatio(
                aspectRatio: 1,
                child: AsyncImageView(
                  imageUrl: item.firstImage!,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FeedTypeBadge(feedType: 'product'),
                  const SizedBox(height: 6),
                  if (item.title != null)
                    Text(
                      item.title!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  if (item.description != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      item.description!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      if (item.price != null)
                        Text(
                          '${_currencySymbol(item.currency)}${item.price!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFFF6B9D),
                          ),
                        ),
                      const Spacer(),
                      if (item.likeCount != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite_border,
                                size: 12,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight),
                            const SizedBox(width: 2),
                            Text(
                              '${item.likeCount}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? AppColors.textTertiaryDark
                                    : AppColors.textTertiaryLight,
                              ),
                            ),
                          ],
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

// =============================================================================
// 卡片类型 3: 竞品评论卡片
// =============================================================================

class _CompetitorReviewCard extends StatelessWidget {
  const _CompetitorReviewCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        if (item.targetItem != null) {
          context.push('/leaderboard/item/${item.targetItem!.itemId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _FeedTypeBadge(feedType: 'competitor_review'),
            const SizedBox(height: 8),
            // 引用框（与原型 review-quote 一致）
            if (item.description != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.03)]
                        : [const Color(0xFFF8F7FF), const Color(0xFFFFF0F5)],
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  border: const Border(
                    left: BorderSide(
                      color: AppColors.primary,
                      width: 3,
                    ),
                  ),
                ),
                child: Text(
                  item.description!,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            _DiscoveryUserRow(
              userId: item.userId,
              userName: item.userName,
              userAvatar: item.userAvatar,
              expertId: item.expertId,
              isDark: isDark,
            ),
            const SizedBox(height: 8),
            // 评论的目标竞品（与原型 review-target 一致）
            if (item.targetItem != null) _TargetItemTag(target: item.targetItem!),
            const SizedBox(height: 8),
            // 赞/踩（与原型一致：up 绿色，down 红色）
            Row(
              children: [
                const Icon(Icons.thumb_up_outlined, size: 12, color: Color(0xFF10B981)),
                const SizedBox(width: 3),
                Text('${item.upvoteCount ?? 0}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF10B981))),
                const SizedBox(width: 12),
                const Icon(Icons.thumb_down_outlined, size: 12, color: Color(0xFFEF4444)),
                const SizedBox(width: 3),
                Text('${item.downvoteCount ?? 0}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFFEF4444))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// 卡片类型 4: 达人服务评价卡片（含活动信息）
// =============================================================================

class _ServiceReviewCard extends StatelessWidget {
  const _ServiceReviewCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActivity = item.activityInfo != null;

    return GestureDetector(
      onTap: () {
        if (item.targetItem != null) {
          context.push('/service/${item.targetItem!.itemId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 活动标签
            if (hasActivity)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFF6B6B).withValues(alpha: 0.1),
                      const Color(0xFFFF8E53).withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        size: 14, color: Color(0xFFFF6B6B)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '来自 ${item.activityInfo!.activityTitle ?? "活动"}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFFFF6B6B),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FeedTypeBadge(feedType: 'service_review'),
                  const SizedBox(height: 8),
                  // 引用框（与竞品评价一致）
                  if (item.description != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [Colors.white.withValues(alpha: 0.06), Colors.white.withValues(alpha: 0.03)]
                              : [const Color(0xFFF8F7FF), const Color(0xFFFFF0F5)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: const Border(
                          left: BorderSide(
                            color: AppColors.primary,
                            width: 3,
                          ),
                        ),
                      ),
                      child: Text(
                        item.description!,
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  _DiscoveryUserRow(
                    userId: item.userId,
                    userName: item.userName,
                    userAvatar: item.userAvatar,
                    expertId: item.expertId,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 8),
                  if (item.targetItem != null) _TargetItemTag(target: item.targetItem!),
                  if (hasActivity && item.activityInfo!.hasDiscount) ...[
                    const SizedBox(height: 6),
                    _ActivityPriceRow(activityInfo: item.activityInfo!),
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

// =============================================================================
// 卡片类型 5: 排行榜卡片
// =============================================================================

class _RankingCard extends StatelessWidget {
  const _RankingCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final top3 = item.top3;

    return GestureDetector(
      onTap: () {
        final id = item.id.replaceFirst('ranking_', '');
        context.push('/leaderboard/$id');
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: isDark
              ? null
              : const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8F7FF), Color(0xFFFEFCE8)],
                ),
          color: isDark ? AppColors.cardBackgroundDark : null,
          borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.hasImages)
              AspectRatio(
                aspectRatio: 16 / 9,
                child: AsyncImageView(
                  imageUrl: item.firstImage!,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FeedTypeBadge(feedType: 'ranking'),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.emoji_events,
                          size: 16, color: Color(0xFFFFB300)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.title ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (top3 != null && top3.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...top3.take(3).toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final data = entry.value;
                      final medals = ['🥇', '🥈', '🥉'];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0) Divider(height: 1, color: isDark ? AppColors.secondaryBackgroundDark : const Color(0xFFE5E7EB)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(medals[i], style: const TextStyle(fontSize: 16)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    data['name']?.toString() ?? '',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: isDark
                                          ? AppColors.textPrimaryDark
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                ),
                                Text(
                                  '⭐ ${(data['rating'] as num?)?.toStringAsFixed(1) ?? '0'}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: isDark
                                        ? AppColors.textTertiaryDark
                                        : AppColors.textTertiaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),
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

// =============================================================================
// 卡片类型 6: 达人服务推荐卡片
// =============================================================================

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        final id = item.id.replaceFirst('service_', '');
        context.push('/service/$id');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.hasImages)
              AspectRatio(
                aspectRatio: 4 / 3,
                child: AsyncImageView(
                  imageUrl: item.firstImage!,
                  fit: BoxFit.cover,
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FeedTypeBadge(feedType: 'service'),
                  const SizedBox(height: 6),
                  if (item.title != null)
                    Text(
                      item.title!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimaryLight,
                      ),
                    ),
                  const SizedBox(height: 8),
                  // 底部一行：左下角达人头像+名字，右下角金额+评分
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: _DiscoveryUserRow(
                          userId: item.userId,
                          userName: item.userName,
                          userAvatar: item.userAvatar,
                          expertId: item.expertId,
                          isDark: isDark,
                        ),
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (item.price != null)
                            Text(
                              '${_currencySymbol(item.currency)}${item.price!.toStringAsFixed(0)}起',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFFF6B9D),
                              ),
                            ),
                          if (item.price != null && item.rating != null)
                            const SizedBox(width: 6),
                          if (item.rating != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star,
                                    size: 12, color: Color(0xFFFFB300)),
                                const SizedBox(width: 2),
                                Text(
                                  item.rating!.toStringAsFixed(1),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                        ],
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

// =============================================================================
// 共用组件
// =============================================================================

/// 发现卡片中的用户行：头像 + 昵称，点击跳转个人页或达人详情页
/// 当 [expertId] 非空时跳达人详情页，否则跳用户个人页
class _DiscoveryUserRow extends StatelessWidget {
  const _DiscoveryUserRow({
    this.userId,
    this.userName,
    this.userAvatar,
    this.expertId,
    required this.isDark,
  });

  final String? userId;
  final String? userName;
  final String? userAvatar;
  /// 非空时点击跳达人详情页 (/task-experts/:id)，否则跳用户个人页 (/user/:id)
  final String? expertId;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final isAnonymous = userId == null || userName == '匿名用户';
    final content = Row(
      children: [
        AvatarView(
          imageUrl: isAnonymous ? null : userAvatar,
          name: userName,
          size: 20,
          isAnonymous: isAnonymous,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            userName ?? '匿名用户',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
        ),
      ],
    );
    final canGoExpert = expertId != null && expertId!.isNotEmpty;
    final canGoUser =
        userId != null && userId!.isNotEmpty;
    if (canGoExpert || canGoUser) {
      return GestureDetector(
        onTap: () {
          if (canGoExpert) {
            context.push('/task-experts/$expertId');
          } else {
            context.push('/user/$userId');
          }
        },
        behavior: HitTestBehavior.opaque,
        child: content,
      );
    }
    return content;
  }
}

/// 帖子关联内容标签（与原型 post-link 一致：图标盒 + 文案 + 箭头）
class _LinkedItemTag extends StatelessWidget {
  const _LinkedItemTag({required this.linkedItem});
  final LinkedItemBrief linkedItem;

  static const Color _primaryPurple = Color(0xFF6C5CE7);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : _primaryPurple.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: _iconBgColor(linkedItem.itemType),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(_iconForType(linkedItem.itemType), size: 16, color: _primaryPurple),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              linkedItem.name ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? AppColors.primaryLight : _primaryPurple,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            size: 14,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
          ),
        ],
      ),
    );
  }

  Color _iconBgColor(String type) {
    switch (type) {
      case 'product': return const Color(0xFFFEF3C7);
      case 'service': return const Color(0xFFDBEAFE);
      case 'activity': return const Color(0xFFD1FAE5);
      case 'ranking': return const Color(0xFFDBEAFE);
      default: return const Color(0xFFEDE9FE);
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'product': return Icons.shopping_bag_outlined;
      case 'service': return Icons.school_outlined;
      case 'activity': return Icons.event_outlined;
      case 'ranking': return Icons.emoji_events_outlined;
      case 'forum_post': return Icons.forum_outlined;
      default: return Icons.link;
    }
  }
}

/// 评论目标标签（与原型 review-target 一致）
class _TargetItemTag extends StatelessWidget {
  const _TargetItemTag({required this.target});
  final TargetItemBrief target;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : const Color(0xFF6C5CE7).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (target.thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: SizedBox(
                width: 28,
                height: 28,
                child: AsyncImageView(
                  imageUrl: target.thumbnail!,
                  fit: BoxFit.cover,
                ),
              ),
            )
          else
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.cardBackgroundDark
                    : const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.inventory_2, size: 14),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  target.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
                if (target.subtitle != null)
                  Text(
                    target.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 活动价格行（原价划线 + 折后价高亮）
class _ActivityPriceRow extends StatelessWidget {
  const _ActivityPriceRow({required this.activityInfo});
  final ActivityBrief activityInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // 折后价
        Text(
          '${_currencySymbol(activityInfo.currency)}${activityInfo.discountedPrice?.toStringAsFixed(2) ?? ""}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B9D),
          ),
        ),
        const SizedBox(width: 6),
        // 原价（划线）
        Text(
          '${_currencySymbol(activityInfo.currency)}${activityInfo.originalPrice?.toStringAsFixed(2) ?? ""}',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: 4),
        // 折扣标签
        if (activityInfo.discountLabel != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFF6B6B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              activityInfo.discountLabel!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF6B6B),
              ),
            ),
          ),
      ],
    );
  }
}
