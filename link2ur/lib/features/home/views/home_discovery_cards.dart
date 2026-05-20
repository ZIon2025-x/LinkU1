part of 'home_view.dart';

// =============================================================================
// 卡片类型 1: 帖子卡片
// =============================================================================

class _PostCard extends StatelessWidget {
  const _PostCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;
    final categoryName = item.displayCategoryName(locale);
    final categoryIcon = item.categoryIcon;
    final hasImage = item.hasImages;
    final likeCount = item.likeCount ?? 0;
    final commentCount = item.commentCount ?? 0;
    final isFavorited = item.isFavorited == true;
    final rawUserName = item.userName;
    final isAnonymous = rawUserName == null || rawUserName.isEmpty;
    final displayUserName = isAnonymous ? l10n.discoveryAnonymousUser : rawUserName;
    final timeAgo = item.createdAt != null
        ? DateFormatter.formatRelative(item.createdAt!, l10n: l10n)
        : null;

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
            borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── 背景: 首图 OR 类别渐变 + 大 emoji ──
                if (hasImage)
                  AsyncImageView(
                    imageUrl: Helpers.getThumbnailUrl(item.firstImage!),
                    fallbackUrl: Helpers.getImageUrl(item.firstImage!),
                    memCacheWidth: 600,
                    placeholder: _PostFallbackBackground(icon: categoryIcon),
                    errorWidget: _PostFallbackBackground(icon: categoryIcon),
                  )
                else
                  _PostFallbackBackground(icon: categoryIcon),
                // ── Veil (顶/底双暗,中间留干净的封面区) ──
                const Positioned.fill(child: _PosterVeil()),
                // ── 顶部: 左 板块 badge / 右 互动 chip (Flexible 自适应宽度) ──
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      Flexible(
                        child: _PostCategoryBadge(
                          icon: categoryIcon,
                          name: categoryName,
                        ),
                      ),
                      const SizedBox(width: 6),
                      _PostStatsChip(
                        likeCount: likeCount,
                        commentCount: commentCount,
                        isFavorited: isFavorited,
                      ),
                    ],
                  ),
                ),
                // ── 底部 overlay: 标题 / 描述 / linked / 用户行 ──
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayTitle.isNotEmpty)
                        Text(
                          displayTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                      if (displayDesc != null && displayDesc.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          displayDesc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.92),
                            fontSize: 11,
                            height: 1.4,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 3),
                            ],
                          ),
                        ),
                      ],
                      if (item.linkedItem != null) ...[
                        const SizedBox(height: 6),
                        _PostLinkedItemChip(linkedItem: item.linkedItem!),
                      ],
                      const SizedBox(height: 8),
                      _PostOverlayUserRow(
                        userId: item.userId,
                        userName: rawUserName,
                        displayName: displayUserName,
                        userAvatar: item.userAvatar,
                        expertId: item.expertId,
                        isAnonymous: isAnonymous,
                        timeAgo: timeAgo,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 帖子卡海报式 fallback — 类别渐变 + 大 emoji
/// 用 categoryIcon emoji 字符做稳定哈希,同一板块色一致
class _PostFallbackBackground extends StatelessWidget {
  const _PostFallbackBackground({this.icon});
  final String? icon;

  static const _gradients = <List<Color>>[
    [Color(0xFFFF8033), Color(0xFFFFA600)], // orange — 留学生活
    [Color(0xFF2E86AB), Color(0xFF56CCF2)], // blue — 学习
    [Color(0xFF7359F2), Color(0xFFA78BFA)], // purple — 租房
    [Color(0xFFFF2D55), Color(0xFFFF8FAB)], // pink — 美食
    [Color(0xFF26BF73), Color(0xFF5ED99F)], // green — 技能
    [Color(0xFFEC4899), Color(0xFFBE185D)], // hot pink — 美妆
  ];

  @override
  Widget build(BuildContext context) {
    final key = icon ?? '📝';
    final hash =
        key.codeUnits.fold<int>(0, (a, c) => a * 31 + c).abs();
    final colors = _gradients[hash % _gradients.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Center(
        child: Text(
          icon ?? '📝',
          style: TextStyle(
            fontSize: 90,
            color: Colors.white.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}

/// 海报顶/底双渐变蒙层 — 保证 overlay 文字可读,中间留封面干净
class _PosterVeil extends StatelessWidget {
  const _PosterVeil();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.0, 0.25, 0.5, 0.7, 1.0],
          colors: [
            Colors.black.withValues(alpha: 0.32),
            Colors.black.withValues(alpha: 0.10),
            Colors.transparent,
            Colors.black.withValues(alpha: 0.42),
            Colors.black.withValues(alpha: 0.85),
          ],
        ),
      ),
    );
  }
}

/// 帖子卡左上角板块 badge — emoji + 板块名
class _PostCategoryBadge extends StatelessWidget {
  const _PostCategoryBadge({this.icon, this.name});
  final String? icon;
  final String? name;

  @override
  Widget build(BuildContext context) {
    final emoji = icon ?? '📝';
    final label = name?.isNotEmpty == true
        ? name!
        : context.l10n.discoveryFeedTypePost;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 帖子卡右上角互动 chip — ❤ N · 💬 N
class _PostStatsChip extends StatelessWidget {
  const _PostStatsChip({
    required this.likeCount,
    required this.commentCount,
    required this.isFavorited,
  });
  final int likeCount;
  final int commentCount;
  final bool isFavorited;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isFavorited ? Icons.favorite : Icons.favorite_border,
            size: 11,
            color: isFavorited ? const Color(0xFFFF8FAB) : Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            '$likeCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.chat_bubble_outline, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            '$commentCount',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// 帖子卡 linkedItem 紧凑 overlay chip
class _PostLinkedItemChip extends StatelessWidget {
  const _PostLinkedItemChip({required this.linkedItem});
  final LinkedItemBrief linkedItem;

  @override
  Widget build(BuildContext context) {
    final name = linkedItem.name ?? '';
    if (name.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_iconForType(linkedItem.itemType), size: 12, color: Colors.white),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'product':
        return Icons.shopping_bag_outlined;
      case 'service':
        return Icons.build_outlined;
      case 'task':
        return Icons.assignment_outlined;
      case 'activity':
        return Icons.event_outlined;
      default:
        return Icons.link;
    }
  }
}

/// 帖子卡 overlay 用户行 — 白色文字 + 阴影,点击跳转用户/达人
class _PostOverlayUserRow extends StatelessWidget {
  const _PostOverlayUserRow({
    required this.userId,
    required this.userName,
    required this.displayName,
    required this.userAvatar,
    required this.expertId,
    required this.isAnonymous,
    this.timeAgo,
  });

  final String? userId;
  final String? userName;
  final String displayName;
  final String? userAvatar;
  final String? expertId;
  final bool isAnonymous;
  final String? timeAgo;

  @override
  Widget build(BuildContext context) {
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
            timeAgo != null && timeAgo!.isNotEmpty
                ? '$displayName · $timeAgo'
                : displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
            ),
          ),
        ),
      ],
    );
    final canGoExpert = expertId != null && expertId!.isNotEmpty;
    final canGoUser = userId != null && userId!.isNotEmpty;
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
                      imageUrl: Helpers.getThumbnailUrl(item.firstImage!),
                      fallbackUrl: Helpers.getImageUrl(item.firstImage!),
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
                            color: AppColors.priceRed,
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
    final thumbnail = item.targetItem?.thumbnail;
    final hasThumbnail = thumbnail != null && thumbnail.isNotEmpty;
    final rank = item.targetItem?.rank;

    if (hasThumbnail) {
      return _buildPosterCard(
          context, locale, displayDesc, thumbnail, isUpvote, rank);
    }
    return _buildWhiteCard(context, isDark, displayDesc, isUpvote, rank);
  }

  /// 海报式 — 有 thumbnail 时使用
  Widget _buildPosterCard(
    BuildContext context,
    Locale locale,
    String? displayDesc,
    String thumbnail,
    bool isUpvote,
    int? rank,
  ) {
    final targetName = item.targetItem?.name ?? '';
    final rawUserName = item.userName;
    final displayUserName = (rawUserName == null || rawUserName.isEmpty)
        ? context.l10n.discoveryAnonymousUser
        : rawUserName;
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
            borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                AsyncImageView(
                  imageUrl: thumbnail,
                  memCacheWidth: 600,
                  placeholder: Container(color: Colors.black12),
                  errorWidget: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.image_outlined,
                          size: 40, color: Colors.white54),
                    ),
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.25, 0.55, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
                // 顶部左:类型 badge
                const Positioned(
                  top: 8, left: 8,
                  child: _FeedTypeBadge(feedType: 'competitor_review'),
                ),
                // 顶部右:排名角标(4 档配色)
                if (rank != null && rank > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: _RankBadge(rank: rank),
                  ),
                // 底部:立场 icon + 评价文字 + 用户行
                Positioned(
                  left: 10, right: 10, bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayDesc != null && displayDesc.isNotEmpty) ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StanceIcon(isUpvote: isUpvote),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                displayDesc,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                  shadows: [
                                    Shadow(color: Colors.black54, blurRadius: 4),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          AvatarView(
                            imageUrl: item.userAvatar,
                            name: displayUserName,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              displayUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                          if (targetName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  targetName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFFDB2777),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 白底 fallback — 无 thumbnail 时使用,同样去掉 UP/DOWN 计数,用立场 icon 前置
  Widget _buildWhiteCard(
    BuildContext context,
    bool isDark,
    String? displayDesc,
    bool isUpvote,
    int? rank,
  ) {
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
              Row(
                children: [
                  const _FeedTypeBadge(feedType: 'competitor_review'),
                  if (rank != null && rank > 0) ...[
                    const SizedBox(width: 6),
                    _RankBadge(rank: rank, compact: true),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              if (displayDesc != null && displayDesc.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
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
                                  AppColors.error.withValues(alpha: 0.15),
                                  AppColors.error.withValues(alpha: 0.05),
                                ]
                              : [
                                  const Color(0xFFFEE2E2),
                                  const Color(0xFFFFE4E1),
                                ]),
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                    border: Border(
                      left: BorderSide(
                        color: isUpvote ? AppColors.success : AppColors.error,
                        width: 3,
                      ),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StanceIcon(isUpvote: isUpvote, dropShadow: false),
                      const SizedBox(width: 6),
                      Expanded(
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
                    ],
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
              if (item.targetItem != null)
                _TargetItemTag(target: item.targetItem!),
            ],
          ),
        ),
      ),
    );
  }
}

/// 立场圆 icon — 👍 (绿) / 👎 (红),前置到评价文字旁
class _StanceIcon extends StatelessWidget {
  const _StanceIcon({required this.isUpvote, this.dropShadow = true});
  final bool isUpvote;
  final bool dropShadow;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        color: isUpvote ? const Color(0xFF22C55E) : const Color(0xFFEF4444),
        shape: BoxShape.circle,
        boxShadow: dropShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Icon(
        isUpvote ? Icons.thumb_up : Icons.thumb_down,
        color: Colors.white,
        size: 12,
      ),
    );
  }
}

/// 排名角标 — 4 档配色: #1 金 / #2 银 / #3 铜 / 其他 黑底
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank, this.compact = false});
  final int rank;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tier = _tierFor(rank);
    // 海报版(!compact) 永远在暗背景上 → 用黑底 alpha 0.55 兜底,对比 OK
    // 白底 fallback(compact) 在 dark mode 卡片背景下是深色 → 黑底会"消失",
    // 此时用浅色半透明 + 灰色字
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isOtherTierOnDarkCompact =
        tier.gradient == null && compact && isDark;
    final bgColor = tier.gradient == null
        ? (isOtherTierOnDarkCompact
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.black.withValues(alpha: 0.55))
        : null;
    final fgColor = isOtherTierOnDarkCompact
        ? Colors.white.withValues(alpha: 0.85)
        : Colors.white;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 9,
        vertical: compact ? 1 : 3,
      ),
      decoration: BoxDecoration(
        gradient: tier.gradient,
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        boxShadow: compact
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '#$rank',
            style: TextStyle(
              color: fgColor,
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w800,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (!compact && tier.emoji != null) ...[
            const SizedBox(width: 3),
            Text(tier.emoji!, style: const TextStyle(fontSize: 11)),
          ],
        ],
      ),
    );
  }

  static _RankTier _tierFor(int rank) {
    if (rank == 1) {
      return const _RankTier(
        gradient: LinearGradient(
          colors: [Color(0xFFFFD84D), Color(0xFFFF9500)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        emoji: '🏆',
      );
    }
    if (rank == 2) {
      return const _RankTier(
        gradient: LinearGradient(
          colors: [Color(0xFFC0C0C0), Color(0xFF9AA0AA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        emoji: '🥈',
      );
    }
    if (rank == 3) {
      return const _RankTier(
        gradient: LinearGradient(
          colors: [Color(0xFFCD7F32), Color(0xFF8B5A2B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        emoji: '🥉',
      );
    }
    return const _RankTier(); // 其他名次 → 黑底白字,无 emoji
  }
}

class _RankTier {
  const _RankTier({this.gradient, this.emoji});
  final Gradient? gradient;
  final String? emoji;
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
    final thumbnail = item.targetItem?.thumbnail;
    final hasThumbnail = thumbnail != null && thumbnail.isNotEmpty;
    // 个人技能评价配色 → 绿;达人服务评价 → 粉/橙
    final isPersonal = item.targetItem?.isPersonalSkill ?? false;
    final badgeType = isPersonal ? 'personal_skill' : 'service_review';
    final accent =
        isPersonal ? const Color(0xFF059669) : AppColors.priceRed;

    // 评价目标(服务/技能)有图 → 海报式背景版;否则保持白底引用框版作 fallback
    if (hasThumbnail) {
      return _buildPosterCard(
        context, isDark, locale, displayDesc, thumbnail,
        badgeType: badgeType, accent: accent,
      );
    }

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
                      AppColors.priceRed.withValues(alpha: 0.1),
                      AppColors.priceRed.withValues(alpha: 0.05),
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department,
                        size: 14, color: AppColors.priceRed),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        context.l10n.serviceReviewFrom(item.activityInfo!.displayActivityTitle(locale)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.priceRed,
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
                  _FeedTypeBadge(feedType: badgeType),
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
                              : isPersonal
                                  ? [const Color(0xFFECFDF5), Colors.transparent]
                                  : [const Color(0xFFF8F7FF), const Color(0xFFFFF0F5)],
                        ),
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(8),
                          bottomRight: Radius.circular(8),
                        ),
                        border: Border(
                          left: BorderSide(
                            color: isPersonal
                                ? const Color(0xFF16A34A)
                                : AppColors.primary,
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

  /// 海报式背景卡 — 评价目标有 thumbnail 时使用
  /// 视觉:3:4 比例 + 全屏背景图 + 底部渐变蒙层 + 白色文字 overlay
  /// [badgeType] 决定顶部类型徽章(service_review 粉 / personal_skill 绿)
  /// [accent] 决定底部 target tag 文字颜色
  Widget _buildPosterCard(
    BuildContext context,
    bool isDark,
    Locale locale,
    String? displayDesc,
    String thumbnail, {
    required String badgeType,
    required Color accent,
  }) {
    final rating = item.rating;
    final targetName = item.targetItem?.name ?? '';
    // 匿名评价(userName 为 null/空)显示本地化的"匿名用户"
    final rawUserName = item.userName;
    final displayUserName = (rawUserName == null || rawUserName.isEmpty)
        ? context.l10n.discoveryAnonymousUser
        : rawUserName;
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
            borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 背景图
                AsyncImageView(
                  imageUrl: thumbnail,
                  memCacheWidth: 600,
                  placeholder: Container(color: Colors.black12),
                  errorWidget: Container(
                    color: Colors.black26,
                    child: const Center(
                      child: Icon(Icons.image_outlined,
                          size: 40, color: Colors.white54),
                    ),
                  ),
                ),
                // 双向渐变蒙层(顶部 + 底部)以保证文字可读
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0.0, 0.25, 0.55, 1.0],
                        colors: [
                          Colors.black.withValues(alpha: 0.28),
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                      ),
                    ),
                  ),
                ),
                // 顶部左:类型 badge
                Positioned(
                  top: 8, left: 8,
                  child: _FeedTypeBadge(feedType: badgeType),
                ),
                // 顶部右:星级
                if (rating != null && rating > 0)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded,
                              size: 12, color: Color(0xFFFFB300)),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // 底部:评价文字 + 用户行(头像/名字/目标 chip)
                Positioned(
                  left: 10, right: 10, bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (displayDesc != null && displayDesc.isNotEmpty) ...[
                        Text(
                          displayDesc,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(color: Colors.black54, blurRadius: 4),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Row(
                        children: [
                          AvatarView(
                            imageUrl: item.userAvatar,
                            name: displayUserName,
                            size: 20,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              displayUserName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 3),
                                ],
                              ),
                            ),
                          ),
                          if (targetName.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.95),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  targetName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// 卡片类型 5: 达人推荐卡片（取代排行榜）
// =============================================================================

// 达人卡片封面的类别渐变取自 ServiceCategoryHelper.getGradient（与详情页共用）

class _ExpertCard extends StatelessWidget {
  const _ExpertCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final l10n = context.l10n;
    final name = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final cover = item.firstImage;
    final avatar = item.userAvatar;
    final category = item.expertCategory;
    final location = item.expertLocation;
    final rating = item.rating;
    final completed = item.expertCompletedTasks ?? 0;
    final skills = locale.languageCode.startsWith('zh')
        ? item.expertFeaturedSkills
        : (item.expertFeaturedSkillsEn.isNotEmpty
            ? item.expertFeaturedSkillsEn
            : item.expertFeaturedSkills);
    final hasCover = cover != null && cover.isNotEmpty;
    // 副标题: 地点 · 类别 (任一缺则只显示另一个)
    final categoryLabel = (category != null && category.isNotEmpty)
        ? ServiceCategoryHelper.getLocalizedLabel(category, l10n)
        : null;
    final subtitleParts = <String>[
      if (location != null && location.isNotEmpty) location,
      if (categoryLabel != null) categoryLabel,
    ];
    final subtitle = subtitleParts.join(' · ');

    return Semantics(
      button: true,
      label: 'View expert',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          final expertId = item.expertId ?? item.id.replaceFirst('expert_', '');
          if (expertId.isNotEmpty) {
            context.push('/expert-teams/$expertId');
          }
        },
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(_kDiscoveryCardRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          clipBehavior: Clip.hardEdge,
          child: AspectRatio(
            aspectRatio: 3 / 4,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // ── 背景: cover OR 类别渐变 + 大类别图标 ──
                if (hasCover)
                  AsyncImageView(
                    imageUrl: Helpers.getThumbnailUrl(cover),
                    fallbackUrl: Helpers.getImageUrl(cover),
                    memCacheWidth: 600,
                    placeholder: _ExpertCoverFallback(category: category),
                    errorWidget: _ExpertCoverFallback(category: category),
                  )
                else
                  _ExpertCoverFallback(category: category),
                // ── Veil: 顶/底双暗,头像区附近留干净 ──
                const Positioned.fill(child: _PosterVeil()),
                // ── 顶部: 左 徽章组 / 右 营业状态 (Flexible 自适应) ──
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Flexible(
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            if (item.expertIsOfficial)
                              _ExpertOverlayBadge(
                                label: l10n.discoveryExpertBadgeOfficial,
                                color: const Color(0xFF2563EB),
                              ),
                            if (item.expertIsVerified)
                              _ExpertOverlayBadge(
                                label: l10n.discoveryExpertBadgeVerified,
                                color: const Color(0xFF10B981),
                                icon: Icons.verified,
                              ),
                            if (item.expertIsFeatured)
                              _ExpertOverlayBadge(
                                label: l10n.discoveryExpertBadgeFeatured,
                                color: const Color(0xFFF97316),
                                icon: Icons.star,
                              ),
                          ],
                        ),
                      ),
                      if (item.expertIsOpen != null) ...[
                        const SizedBox(width: 6),
                        _ExpertOpenStatusPill(isOpen: item.expertIsOpen!),
                      ],
                    ],
                  ),
                ),
                // ── 底部 overlay: 头像 + 名字 + 技能 + 评分 ──
                Positioned(
                  left: 10,
                  right: 10,
                  bottom: 10,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 头像 + 名字 / 副标题
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.35),
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            child: AvatarView(
                              imageUrl: avatar,
                              name: name,
                              size: 36,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    height: 1.2,
                                    shadows: [
                                      Shadow(color: Colors.black54, blurRadius: 4),
                                    ],
                                  ),
                                ),
                                if (subtitle.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.88),
                                      fontSize: 10,
                                      height: 1.3,
                                      shadows: const [
                                        Shadow(color: Colors.black54, blurRadius: 3),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      // 技能 chip — 半透白底
                      if (skills.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: skills.take(3).map((s) => Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.22),
                                width: 0.5,
                              ),
                            ),
                            child: Text(
                              s,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                shadows: [
                                  Shadow(color: Colors.black54, blurRadius: 3),
                                ],
                              ),
                            ),
                          )).toList(),
                        ),
                      ],
                      // 评分 · 完单数
                      const SizedBox(height: 6),
                      _ExpertOverlayRatingRow(
                          rating: rating, completed: completed),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 达人卡海报式 cover fallback — 类别渐变 + 大类别 icon
class _ExpertCoverFallback extends StatelessWidget {
  const _ExpertCoverFallback({this.category});
  final String? category;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: ServiceCategoryHelper.getGradient(category),
        ),
      ),
      child: Center(
        child: Icon(
          ServiceCategoryHelper.getIcon(category),
          size: 90,
          color: Colors.white.withValues(alpha: 0.45),
        ),
      ),
    );
  }
}

/// 达人卡左上角徽章 (overlay 用) — 半透色底 + 白字 + 模糊阴影
class _ExpertOverlayBadge extends StatelessWidget {
  const _ExpertOverlayBadge({
    required this.label,
    required this.color,
    this.icon,
  });
  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: Colors.white),
            const SizedBox(width: 2),
          ],
          Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// 达人卡评分行 (overlay 用) — 白字 + 阴影 + 新手 tag
class _ExpertOverlayRatingRow extends StatelessWidget {
  const _ExpertOverlayRatingRow({
    required this.rating,
    required this.completed,
  });
  final double? rating;
  final int completed;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isNew = completed == 0;
    const shadow = Shadow(color: Colors.black54, blurRadius: 3);

    if (isNew || rating == null || rating! <= 0) {
      // 新达人 — 黄底"★ 新" tag + "刚开业"
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD84D).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFFFFD84D).withValues(alpha: 0.5),
                width: 0.5,
              ),
            ),
            child: Text(
              '★ ${l10n.discoveryExpertRatingNew}',
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: Color(0xFFFFE07A),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            l10n.discoveryExpertCompletedTasks(completed),
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.88),
              shadows: const [shadow],
            ),
          ),
        ],
      );
    }
    return Row(
      children: [
        const Icon(Icons.star_rounded,
            size: 14,
            color: Color(0xFFFFD84D),
            shadows: [Shadow(color: Colors.black54, blurRadius: 3)]),
        const SizedBox(width: 2),
        Text(
          rating!.toStringAsFixed(1),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFFFFD84D),
            shadows: [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          l10n.discoveryExpertCompletedTasks(completed),
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withValues(alpha: 0.88),
            shadows: const [shadow],
          ),
        ),
      ],
    );
  }
}

/// 封面右上角的营业状态小胶囊
class _ExpertOpenStatusPill extends StatelessWidget {
  const _ExpertOpenStatusPill({required this.isOpen});
  final bool isOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bg = isOpen ? const Color(0xE6FFFFFF) : const Color(0xCC1F2937);
    final fg = isOpen ? const Color(0xFF059669) : Colors.white;
    final dotColor = isOpen ? const Color(0xFF10B981) : const Color(0xFF9CA3AF);
    final label = isOpen
        ? l10n.expertTeamStatusActive
        : l10n.expertTeamStatusResting;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: dotColor,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 卡片类型 6: 服务推荐卡片（达人服务 / 个人技能）
// =============================================================================

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final isExpert = item.expertId != null;

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
            border: isExpert
                ? Border.all(
                    color: const Color(0xFFDAA520).withValues(alpha: 0.4),
                    width: 1.5,
                  )
                : null,
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
                      imageUrl: Helpers.getThumbnailUrl(item.firstImage!),
                      fallbackUrl: Helpers.getImageUrl(item.firstImage!),
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
                    final colors = ServiceCategoryHelper.getGradient(category);
                    return Container(
                      width: w,
                      height: h,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: colors,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        ServiceCategoryHelper.getIcon(category),
                        size: 48,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    );
                  },
                ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FeedTypeBadge(feedType: isExpert ? 'service' : 'personal_skill'),
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
                                color: AppColors.priceRed,
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
                            TaskTypeHelper.getLocalizedLabel(item.taskType!, context.l10n),
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
                                : AppColors.priceRed.withValues(alpha: 0.08),
                            AppColors.priceRed,
                            isBold: true,
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

  Widget _buildImage(bool isDark) {
    if (item.hasImages) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = w * 3 / 4;
          return ClipRect(
            child: AsyncImageView(
              imageUrl: Helpers.getThumbnailUrl(item.firstImage!),
              fallbackUrl: Helpers.getImageUrl(item.firstImage!),
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
    final colors = TaskTypeHelper.getGradient(item.taskType);
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
        child: Icon(icon, size: 48, color: Colors.white.withValues(alpha: 0.9)),
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
                              color: AppColors.priceRed,
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
              imageUrl: Helpers.getThumbnailUrl(item.firstImage!),
              fallbackUrl: Helpers.getImageUrl(item.firstImage!),
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
// 卡片类型 8b: AI 限时问答卡片（瀑布流） — 跟 _DiscoveryActivityCard 平行
// 复用 activity_info 字段:
//   - activityInfo.deadline (倒计时)
//   - extraData['ai_question_id'] (onTap 跳详情)
//   - extraData['reward_pool_pence'] / ['participation_points']
// =============================================================================

class _DiscoveryAiQaCard extends StatelessWidget {
  const _DiscoveryAiQaCard({required this.item});
  final DiscoveryFeedItem item;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final locale = Localizations.localeOf(context);
    final displayTitle = Helpers.normalizeContentNewlines(item.displayTitle(locale));
    final displayDesc = item.displayDescription(locale) != null
        ? Helpers.normalizeContentNewlines(item.displayDescription(locale)!)
        : null;

    final extra = item.extraData ?? const {};
    // 优先从 extra_data 取(后端推荐),否则 activity_info.activity_id 兜底(应不发生)
    final aiQuestionId = extra['ai_question_id']?.toString() ??
        item.id.replaceFirst('ai_qa_', '');
    final rewardPoolPence = (extra['reward_pool_pence'] as num?)?.toInt();

    return Semantics(
      button: true,
      label: 'View AI Q&A',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (aiQuestionId.isNotEmpty) {
            context.push('/ai-qa/$aiQuestionId');
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
              // Gradient header with robot emoji (ai_qa 永远无图)
              // 蓝白渐变 (品牌色规范 mockups/blue-white-gradient-preview.html 方案 B): #007AFF → #B3D9FF
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF007AFF), Color(0xFFB3D9FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🤖', style: TextStyle(fontSize: 36)),
                ),
              ),
              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _FeedTypeBadge(feedType: 'ai_qa'),
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
                    // Reward pool — 跟 activity 的价格行视觉对齐
                    if (rewardPoolPence != null && rewardPoolPence > 0)
                      Text(
                        '💰 ${_currencySymbol(item.currency)}${(rewardPoolPence / 100).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.priceRed,
                          fontWeight: FontWeight.w600,
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
            color: AppColors.priceRed,
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
              color: AppColors.priceRed.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              activityInfo.discountLabel!,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: AppColors.priceRed,
              ),
            ),
          ),
      ],
    );
  }
}
