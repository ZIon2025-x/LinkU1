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
    final metaColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final metaStyle = TextStyle(fontSize: 11, color: metaColor);
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;
    final categoryName = item.displayCategoryName(locale);

    return Semantics(
      button: true,
      label: 'View post',
      excludeSemantics: true,
      child: GestureDetector(
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
                      ),
                    );
                  },
                )
              else
                _PostCategoryPlaceholder(icon: item.categoryIcon),
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
                        Icon(
                            item.isFavorited == true
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 14,
                            color: item.isFavorited == true
                                ? AppColors.error
                                : metaColor),
                        const SizedBox(width: 3),
                        Text('${item.likeCount ?? 0}',
                            style: metaStyle),
                        const SizedBox(width: 12),
                        Icon(Icons.chat_bubble_outline, size: 14,
                            color: metaColor),
                        const SizedBox(width: 3),
                        Text('${item.commentCount ?? 0}',
                            style: metaStyle),
                      ],
                    ),
                  ),
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

/// 帖子无图时的板块 icon 占位
class _PostCategoryPlaceholder extends StatelessWidget {
  const _PostCategoryPlaceholder({this.icon});

  final String? icon;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: 100,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF2C2C3E), const Color(0xFF1C1C2E)]
              : [const Color(0xFFF0F0FF), const Color(0xFFE8E0F0)],
        ),
      ),
      child: Center(
        child: Text(
          icon ?? '💬',
          style: const TextStyle(fontSize: 36),
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

    return Semantics(
      button: true,
      label: 'View product',
      excludeSemantics: true,
      child: GestureDetector(
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
                            Icon(
                                item.isFavorited == true
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                size: 12,
                                color: item.isFavorited == true
                                    ? AppColors.error
                                    : isDark
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

    return Semantics(
      button: true,
      label: 'View review',
      excludeSemantics: true,
      child: GestureDetector(
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
                Icon(
                    item.userVoteType == 'upvote'
                        ? Icons.thumb_up
                        : Icons.thumb_up_outlined,
                    size: 12, color: AppColors.success),
                const SizedBox(width: 3),
                Text('${item.upvoteCount ?? 0}',
                    style: const TextStyle(fontSize: 12, color: AppColors.success)),
                const SizedBox(width: 12),
                Icon(
                    item.userVoteType == 'downvote'
                        ? Icons.thumb_down
                        : Icons.thumb_down_outlined,
                    size: 12, color: AppColors.error),
                const SizedBox(width: 3),
                Text('${item.downvoteCount ?? 0}',
                    style: const TextStyle(fontSize: 12, color: AppColors.error)),
              ],
            ),
          ],
        ),
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

    return Semantics(
      button: true,
      label: 'View service review',
      excludeSemantics: true,
      child: GestureDetector(
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
                        context.l10n.serviceReviewFrom(item.activityInfo!.displayActivityTitle(locale)),
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

    return Semantics(
      button: true,
      label: 'View ranking',
      excludeSemantics: true,
      child: GestureDetector(
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
                          size: 16, color: AppColors.warning),
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

    return Semantics(
      button: true,
      label: 'View service',
      excludeSemantics: true,
      child: GestureDetector(
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
                    ),
                  );
                },
              )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final h = w * 3 / 4;
                    final category = item.extraData?['category'] as String?;
                    return Container(
                      width: w,
                      height: h,
                      color: isDark ? Colors.grey[850] : const Color(0xFFF5F5F5),
                      child: Center(
                        child: Icon(
                          ServiceCategoryHelper.getIcon(category),
                          size: 48,
                          color: isDark ? Colors.grey[500] : Colors.grey[400],
                        ),
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
                              context.l10n.servicePriceFrom('${_currencySymbol(item.currency)}${item.price!.toStringAsFixed(0)}'),
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
                                    size: 12, color: AppColors.warning),
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
      return Semantics(
        button: true,
        label: 'View profile',
        child: GestureDetector(
          onTap: () {
            if (canGoExpert) {
              context.push('/task-experts/$expertId');
            } else {
              context.push('/user/$userId');
            }
          },
          behavior: HitTestBehavior.opaque,
          child: content,
        ),
      );
    }
    return content;
  }
}

class _LinkedItemTag extends StatelessWidget {
  const _LinkedItemTag({required this.linkedItem});
  final LinkedItemBrief linkedItem;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : AppColors.purple.withValues(alpha: 0.04),
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
            child: Icon(_iconForType(linkedItem.itemType), size: 16, color: AppColors.purple),
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
                color: isDark ? AppColors.primaryLight : AppColors.purple,
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
            : AppColors.purple.withValues(alpha: 0.04),
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

// =============================================================================
// 卡片类型 7: 任务卡片
// =============================================================================

class _DiscoveryTaskCard extends StatelessWidget {
  const _DiscoveryTaskCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));

    return Semantics(
      button: true,
      label: 'View task',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          final taskId = item.id.replaceFirst('task_', '');
          if (taskId.isNotEmpty) context.push('/tasks/$taskId');
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
              // Image or gradient placeholder
              _buildImage(isDark),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FeedTypeBadge(feedType: 'task'),
                    const SizedBox(height: 6),
                    if (displayTitle.isNotEmpty)
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    // Tags: task type + price
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      children: [
                        if (item.taskType != null)
                          _buildTag(
                            item.taskType!,
                            isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFF0F0FF),
                            isDark ? Colors.white70 : const Color(0xFF667EEA),
                          ),
                        if (item.price != null)
                          _buildTag(
                            item.rewardToBeQuoted == true
                                ? context.l10n.taskRewardToBeQuoted
                                : '${Helpers.currencySymbolFor(item.currency ?? 'GBP')}${item.price!.toStringAsFixed(0)}',
                            isDark
                                ? Colors.white.withValues(alpha: 0.12)
                                : const Color(0xFFFFF0F0),
                            isDark ? const Color(0xFFFF8A65) : const Color(0xFFEE5A24),
                            isBold: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    // Footer: avatar + name
                    _DiscoveryUserRow(
                      userId: item.userId,
                      userName: item.userName,
                      userAvatar: item.userAvatar,
                      expertId: item.expertId,
                      isDark: isDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage(bool isDark) {
    if (item.hasImages) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * 3 / 4;
          return ClipRect(
            child: AsyncImageView(
              imageUrl: item.firstImage!,
              width: w,
              height: h,
              memCacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
            ),
          );
        },
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    const gradients = {
      // 新格式
      'delivery': [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
      'shopping': [Color(0xFFF8BBD0), Color(0xFFF48FB1)],
      'tutoring': [Color(0xFFBBDEFB), Color(0xFF90CAF9)],
      'translation': [Color(0xFFB2EBF2), Color(0xFF80DEEA)],
      'design': [Color(0xFFA8EDEA), Color(0xFFFED6E3)],
      'programming': [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
      'writing': [Color(0xFFFDDB92), Color(0xFFD1FDFF)],
      'photography': [Color(0xFFFFECD2), Color(0xFFFCB69F)],
      'moving': [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
      'cleaning': [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
      'repair': [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
      'pet_care': [Color(0xFFFFCDD2), Color(0xFFEF9A9A)],
      'errand': [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
      'other': [Color(0xFFE8E8E8), Color(0xFFD0D0D0)],
      // 旧格式
      'Housekeeping': [Color(0xFFC8E6C9), Color(0xFFA5D6A7)],
      'Campus Life': [Color(0xFFBBDEFB), Color(0xFF90CAF9)],
      'Second-hand & Rental': [Color(0xFFF8BBD0), Color(0xFFF48FB1)],
      'Errand Running': [Color(0xFFFFE0B2), Color(0xFFFFCC80)],
      'Skill Service': [Color(0xFFE0C3FC), Color(0xFF8EC5FC)],
      'Social Help': [Color(0xFFB2EBF2), Color(0xFF80DEEA)],
      'Transportation': [Color(0xFFD7CCC8), Color(0xFFBCAAA4)],
      'Pet Care': [Color(0xFFFFCDD2), Color(0xFFEF9A9A)],
      'Life Convenience': [Color(0xFFFDDB92), Color(0xFFD1FDFF)],
      'Other': [Color(0xFFE8E8E8), Color(0xFFD0D0D0)],
    };
    final colors = gradients[item.taskType] ?? const [Color(0xFFE8E8E8), Color(0xFFD0D0D0)];
    final icon = TaskTypeHelper.getIcon(item.taskType ?? 'other');
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.85)),
      ),
    );
  }

  Widget _buildTag(String text, Color bg, Color fg, {bool isBold = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: fg,
          fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}

// =============================================================================
// 卡片类型 8: 活动卡片（瀑布流）
// =============================================================================

class _DiscoveryActivityCard extends StatelessWidget {
  const _DiscoveryActivityCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;

    return Semantics(
      button: true,
      label: 'View activity',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          final activityId = item.id.replaceFirst('activity_', '');
          if (activityId.isNotEmpty) context.push('/activities/$activityId');
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
              // Image or gradient
              _buildImage(),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FeedTypeBadge(feedType: 'activity'),
                    const SizedBox(height: 6),
                    if (displayTitle.isNotEmpty)
                      Text(
                        displayTitle,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (displayDesc != null && displayDesc.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        displayDesc,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    // Participants + price row
                    Wrap(
                      spacing: 8,
                      children: [
                        if (item.activityInfo?.currentParticipants != null)
                          Text(
                            '👥 ${item.activityInfo!.currentParticipants}/${item.activityInfo?.maxParticipants ?? '∞'}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            ),
                          ),
                        if (item.price != null && item.price! > 0)
                          Text(
                            '${_currencySymbol(item.currency)}${item.price!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFEE5A24),
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        else
                          Text(
                            context.l10n.homeActivityFree,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFF66BB6A) : const Color(0xFF4CAF50),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (item.hasImages) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * 9 / 16;
          return ClipRect(
            child: AsyncImageView(
              imageUrl: item.firstImage!,
              width: w,
              height: h,
              memCacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).round(),
            ),
          );
        },
      );
    }
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        alignment: Alignment.center,
        child: const Text('🎪', style: TextStyle(fontSize: 36)),
      ),
    );
  }
}

// =============================================================================
// 卡片类型 9: 完成记录卡片（关注 Feed）
// =============================================================================

class _DiscoveryCompletionCard extends StatelessWidget {
  const _DiscoveryCompletionCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));

    return Container(
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
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          if (item.userAvatar != null)
            CircleAvatar(
              radius: 20,
              backgroundImage: NetworkImage(Helpers.getImageUrl(item.userAvatar)),
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: isDark
                  ? Colors.white.withValues(alpha: 0.15)
                  : const Color(0xFFE8E8E8),
              child: Icon(
                Icons.person,
                size: 20,
                color: isDark ? Colors.white54 : const Color(0xFF999999),
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.userName != null && item.userName!.isNotEmpty)
                  Text(
                    item.userName!,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                const SizedBox(height: 2),
                if (displayTitle.isNotEmpty)
                  Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Text('✅', style: TextStyle(fontSize: 20)),
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
