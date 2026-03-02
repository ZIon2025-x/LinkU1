part of 'home_view.dart';

// =============================================================================
// 卡片类型 1: 帖子卡片
// =============================================================================

class _PostCard extends StatelessWidget {
  const _PostCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;
    final categoryName = item.displayCategoryName(locale);

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
            if (item.hasImages)
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = w * 4 / 3;
                  return ClipRect(
                    child: AsyncImageView(
                      imageUrl: item.firstImage!,
                      width: w,
                      height: h,
                      memCacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
                      memCacheHeight: (h * MediaQuery.devicePixelRatioOf(context)).round(),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const _FeedTypeBadge(feedType: 'forum_post'),
                      if (categoryName != null && categoryName.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            categoryName,
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
                  if (displayTitle.isNotEmpty)
                    Text(
                      displayTitle,
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
                  if (displayDesc != null && displayDesc.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      displayDesc,
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
                  if (item.linkedItem != null) ...[
                    const SizedBox(height: 6),
                    _LinkedItemTag(linkedItem: item.linkedItem!),
                  ],
                  const SizedBox(height: 8),
                  _DiscoveryUserRow(
                    userId: item.userId,
                    userName: item.userName,
                    userAvatar: item.userAvatar,
                    expertId: item.expertId,
                    isDark: isDark,
                  ),
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
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;

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
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  return ClipRect(
                    child: AsyncImageView(
                      imageUrl: item.firstImage!,
                      width: w,
                      height: w,
                      memCacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
                      memCacheHeight: (w * MediaQuery.devicePixelRatioOf(context)).round(),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FeedTypeBadge(feedType: 'product'),
                  const SizedBox(height: 6),
                  if (displayTitle.isNotEmpty)
                    Text(
                      displayTitle,
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
                  if (displayDesc != null && displayDesc.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      displayDesc,
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
                          '${_currencySymbol(item.currency)}${Helpers.formatAmountNumber(item.price!)}',
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
    final locale = Localizations.localeOf(context);
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;
    final isUpvote = item.voteType == 'upvote';

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
            if (displayDesc != null && displayDesc.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isUpvote
                        ? (isDark
                            ? [
                                AppColors.success.withValues(alpha: 0.15),
                                AppColors.success.withValues(alpha: 0.06),
                              ]
                            : [
                                AppColors.successLight,
                                const Color(0xFFC8E6C9),
                              ])
                        : (isDark
                            ? [
                                Colors.white.withValues(alpha: 0.06),
                                Colors.white.withValues(alpha: 0.03),
                              ]
                            : [
                                const Color(0xFFF8F7FF),
                                const Color(0xFFFFF0F5),
                              ]),
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
                  displayDesc,
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
            const SizedBox(height: 8),
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
    final locale = Localizations.localeOf(context);
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;
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
                        '来自 ${item.activityInfo!.displayActivityTitle(locale)}',
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
                  if (displayDesc != null && displayDesc.isNotEmpty)
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
                        displayDesc,
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
    final locale = Localizations.localeOf(context);
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
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = w * 9 / 16;
                  return ClipRect(
                    child: AsyncImageView(
                      imageUrl: item.firstImage!,
                      width: w,
                      height: h,
                      memCacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
                      memCacheHeight: (h * MediaQuery.devicePixelRatioOf(context)).round(),
                    ),
                  );
                },
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
                          Helpers.normalizeContentNewlines(item.displayTitle(locale)),
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
                      final rankLabels = [
                        context.l10n.leaderboardRankFirst,
                        context.l10n.leaderboardRankSecond,
                        context.l10n.leaderboardRankThird,
                      ];
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (i > 0) Divider(height: 1, color: isDark ? AppColors.secondaryBackgroundDark : const Color(0xFFE5E7EB)),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              children: [
                                Text(
                                  rankLabels[i],
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2563EB),
                                  ),
                                ),
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
                                  context.l10n.leaderboardNetVotesCount(
                                    ((data['rating'] as num?)?.round() ?? 0),
                                  ),
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
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));

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
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = w * 3 / 4;
                  return ClipRect(
                    child: AsyncImageView(
                      imageUrl: item.firstImage!,
                      width: w,
                      height: h,
                      memCacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
                      memCacheHeight: (h * MediaQuery.devicePixelRatioOf(context)).round(),
                    ),
                  );
                },
              ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _FeedTypeBadge(feedType: 'service'),
                  const SizedBox(height: 6),
                  if (displayTitle.isNotEmpty)
                    Text(
                      displayTitle,
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
                  Row(
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
                  memCacheWidth: 84,
                  memCacheHeight: 84,
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

class _ActivityPriceRow extends StatelessWidget {
  const _ActivityPriceRow({required this.activityInfo});
  final ActivityBrief activityInfo;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          activityInfo.discountedPrice != null
            ? '${_currencySymbol(activityInfo.currency)}${Helpers.formatAmountNumber(activityInfo.discountedPrice!)}'
            : '',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFFFF6B9D),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          activityInfo.originalPrice != null
            ? '${_currencySymbol(activityInfo.currency)}${Helpers.formatAmountNumber(activityInfo.originalPrice!)}'
            : '',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            decoration: TextDecoration.lineThrough,
          ),
        ),
        const SizedBox(width: 4),
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
