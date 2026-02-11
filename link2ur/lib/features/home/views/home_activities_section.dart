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

/// 发现更多 — 小红书风格瀑布流（6 种卡片类型混排）
class _RecentActivitiesSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HomeBloc, HomeState>(
      buildWhen: (prev, curr) =>
          prev.discoveryItems != curr.discoveryItems ||
          prev.isLoadingDiscovery != curr.isLoadingDiscovery,
      builder: (context, state) {
        if (state.isLoadingDiscovery && state.discoveryItems.isEmpty) {
          return const Padding(
            padding: AppSpacing.allMd,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (state.discoveryItems.isEmpty) {
          return Padding(
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
          );
        }

        return Column(
          children: [
            MasonryGridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: state.discoveryItems.length,
              itemBuilder: (context, index) {
                final item = state.discoveryItems[index];
                return _DiscoveryFeedCard(item: item);
              },
            ),
            if (state.hasMoreDiscovery)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
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
        context.push('/forum/post/$postId');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                  // 底部：用户 + 互动
                  Row(
                    children: [
                      if (item.userAvatar != null)
                        CircleAvatar(
                          radius: 10,
                          backgroundImage: NetworkImage(item.userAvatar!),
                        )
                      else
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: isDark
                              ? AppColors.secondaryBackgroundDark
                              : AppColors.backgroundLight,
                          child: const Icon(Icons.person, size: 12),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.userName ?? '匿名用户',
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
                      if (item.likeCount != null && item.likeCount! > 0)
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
        context.push('/flea-market/$id');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                          '${item.currency ?? "£"}${item.price!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.priceRed,
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
        // 跳转到竞品详情
        if (item.targetItem != null) {
          context.push('/leaderboards/item/${item.targetItem!.itemId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 用户行
            Row(
              children: [
                if (item.userAvatar != null)
                  CircleAvatar(radius: 14, backgroundImage: NetworkImage(item.userAvatar!))
                else
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: isDark
                        ? AppColors.secondaryBackgroundDark
                        : AppColors.backgroundLight,
                    child: const Icon(Icons.person, size: 14),
                  ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    item.userName ?? '匿名用户',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 评分
            if (item.rating != null) ...[
              _StarRating(rating: item.rating!),
              const SizedBox(height: 6),
            ],
            // 评论内容
            if (item.description != null)
              Text(
                item.description!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondaryLight,
                ),
              ),
            const SizedBox(height: 8),
            // 评论的目标竞品
            if (item.targetItem != null) _TargetItemTag(target: item.targetItem!),
            const SizedBox(height: 6),
            // 赞/踩
            Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 14,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                const SizedBox(width: 2),
                Text('${item.upvoteCount ?? 0}',
                    style: TextStyle(fontSize: 11,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
                const SizedBox(width: 10),
                Icon(Icons.thumb_down_outlined, size: 14,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                const SizedBox(width: 2),
                Text('${item.downvoteCount ?? 0}',
                    style: TextStyle(fontSize: 11,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight)),
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
          context.push('/expert-service/${item.targetItem!.itemId}');
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                  // 用户行
                  Row(
                    children: [
                      if (item.userAvatar != null)
                        CircleAvatar(radius: 14, backgroundImage: NetworkImage(item.userAvatar!))
                      else
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: isDark
                              ? AppColors.secondaryBackgroundDark
                              : AppColors.backgroundLight,
                          child: const Icon(Icons.person, size: 14),
                        ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          item.userName ?? '匿名用户',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (item.rating != null) ...[
                    _StarRating(rating: item.rating!),
                    const SizedBox(height: 6),
                  ],
                  if (item.description != null)
                    Text(
                      item.description!,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  const SizedBox(height: 8),
                  // 服务信息
                  if (item.targetItem != null) _TargetItemTag(target: item.targetItem!),
                  // 活动价格
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
        context.push('/leaderboards/$id');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 封面
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
                  // TOP 3 列表
                  if (top3 != null && top3.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...top3.take(3).toList().asMap().entries.map((entry) {
                      final i = entry.key;
                      final data = entry.value;
                      final medals = ['🥇', '🥈', '🥉'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          children: [
                            Text(medals[i], style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                data['name']?.toString() ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                            Text(
                              '⭐ ${(data['rating'] as num?)?.toStringAsFixed(1) ?? '0'}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        ),
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
        context.push('/expert-service/$id');
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.cardBackgroundDark : Colors.white,
          borderRadius: AppRadius.allMedium,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
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
                  const SizedBox(height: 4),
                  // 达人信息
                  Row(
                    children: [
                      if (item.userAvatar != null)
                        CircleAvatar(radius: 10, backgroundImage: NetworkImage(item.userAvatar!))
                      else
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: isDark
                              ? AppColors.secondaryBackgroundDark
                              : AppColors.backgroundLight,
                          child: const Icon(Icons.person, size: 12),
                        ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          item.userName ?? '',
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
                    ],
                  ),
                  const SizedBox(height: 4),
                  // 价格 + 评分
                  Row(
                    children: [
                      if (item.price != null)
                        Text(
                          '${item.currency ?? "£"}${item.price!.toStringAsFixed(0)}起',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.priceRed,
                          ),
                        ),
                      const Spacer(),
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

/// 星级评分
class _StarRating extends StatelessWidget {
  const _StarRating({required this.rating});
  final double rating;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        if (i < rating.floor()) {
          return const Icon(Icons.star, size: 14, color: Color(0xFFFFB300));
        } else if (i < rating.ceil() && rating % 1 >= 0.5) {
          return const Icon(Icons.star_half, size: 14, color: Color(0xFFFFB300));
        }
        return Icon(Icons.star_border, size: 14,
            color: Colors.grey.withValues(alpha: 0.4));
      }),
    );
  }
}

/// 帖子关联内容标签
class _LinkedItemTag extends StatelessWidget {
  const _LinkedItemTag({required this.linkedItem});
  final LinkedItemBrief linkedItem;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typeLabel = _typeLabel(linkedItem.itemType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isDark ? AppColors.primaryDark : AppColors.primaryLight)
            .withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.link, size: 12,
              color: isDark ? AppColors.primaryDark : AppColors.primaryLight),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$typeLabel: ${linkedItem.name ?? ""}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? AppColors.primaryDark : AppColors.primaryLight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'service':
        return '服务';
      case 'activity':
        return '活动';
      case 'product':
        return '商品';
      case 'ranking':
        return '排行榜';
      case 'forum_post':
        return '帖子';
      case 'expert':
        return '达人';
      default:
        return '关联';
    }
  }
}

/// 评论目标标签（竞品/服务）
class _TargetItemTag extends StatelessWidget {
  const _TargetItemTag({required this.target});
  final TargetItemBrief target;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.secondaryBackgroundDark
            : AppColors.backgroundLight.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (target.thumbnail != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
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
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.inventory_2, size: 14),
            ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  target.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
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
          '${activityInfo.currency} ${activityInfo.discountedPrice?.toStringAsFixed(2) ?? ""}',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.priceRed,
          ),
        ),
        const SizedBox(width: 6),
        // 原价（划线）
        Text(
          '${activityInfo.currency} ${activityInfo.originalPrice?.toStringAsFixed(2) ?? ""}',
          style: TextStyle(
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
