import 'package:equatable/equatable.dart';

/// Discovery Feed 内容项
/// 统一表示 6 种类型: forum_post / product / competitor_review / service_review / ranking / service
class DiscoveryFeedItem extends Equatable {
  const DiscoveryFeedItem({
    required this.id,
    required this.feedType,
    this.title,
    this.description,
    this.images,
    this.userName,
    this.userAvatar,
    this.price,
    this.originalPrice,
    this.discountPercentage,
    this.currency,
    this.rating,
    this.likeCount,
    this.commentCount,
    this.upvoteCount,
    this.downvoteCount,
    this.linkedItem,
    this.targetItem,
    this.activityInfo,
    this.isExperienced,
    this.extraData,
    this.createdAt,
  });

  final String id;
  final String feedType;
  final String? title;
  final String? description;
  final List<String>? images;
  final String? userName;
  final String? userAvatar;
  final double? price;
  final double? originalPrice;
  final double? discountPercentage;
  final String? currency;
  final double? rating;
  final int? likeCount;
  final int? commentCount;
  final int? upvoteCount;
  final int? downvoteCount;
  final LinkedItemBrief? linkedItem;
  final TargetItemBrief? targetItem;
  final ActivityBrief? activityInfo;
  final bool? isExperienced;
  final Map<String, dynamic>? extraData;
  final DateTime? createdAt;

  /// 是否是帖子
  bool get isPost => feedType == 'forum_post';

  /// 是否是商品
  bool get isProduct => feedType == 'product';

  /// 是否是竞品评论
  bool get isCompetitorReview => feedType == 'competitor_review';

  /// 是否是达人服务评价
  bool get isServiceReview => feedType == 'service_review';

  /// 是否是排行榜
  bool get isRanking => feedType == 'ranking';

  /// 是否是达人服务
  bool get isService => feedType == 'service';

  /// 是否有图片
  bool get hasImages => images != null && images!.isNotEmpty;

  /// 第一张图片
  String? get firstImage => hasImages ? images!.first : null;

  /// 排行榜 TOP 3 数据
  List<Map<String, dynamic>>? get top3 {
    if (extraData == null) return null;
    final list = extraData!['top3'];
    if (list is List) return list.cast<Map<String, dynamic>>();
    return null;
  }

  factory DiscoveryFeedItem.fromJson(Map<String, dynamic> json) {
    return DiscoveryFeedItem(
      id: json['id'] as String? ?? '',
      feedType: json['feed_type'] as String? ?? '',
      title: json['title'] as String?,
      description: json['description'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      price: (json['price'] as num?)?.toDouble(),
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble(),
      currency: json['currency'] as String?,
      rating: (json['rating'] as num?)?.toDouble(),
      likeCount: json['like_count'] as int?,
      commentCount: json['comment_count'] as int?,
      upvoteCount: json['upvote_count'] as int?,
      downvoteCount: json['downvote_count'] as int?,
      linkedItem: json['linked_item'] != null
          ? LinkedItemBrief.fromJson(json['linked_item'] as Map<String, dynamic>)
          : null,
      targetItem: json['target_item'] != null
          ? TargetItemBrief.fromJson(json['target_item'] as Map<String, dynamic>)
          : null,
      activityInfo: json['activity_info'] != null
          ? ActivityBrief.fromJson(json['activity_info'] as Map<String, dynamic>)
          : null,
      isExperienced: json['is_experienced'] as bool?,
      extraData: json['extra_data'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, feedType];
}

/// 帖子关联的内容简要信息
class LinkedItemBrief extends Equatable {
  const LinkedItemBrief({
    required this.itemType,
    required this.itemId,
    this.name,
    this.thumbnail,
  });

  final String itemType;
  final String itemId;
  final String? name;
  final String? thumbnail;

  factory LinkedItemBrief.fromJson(Map<String, dynamic> json) {
    return LinkedItemBrief(
      itemType: json['item_type'] as String? ?? '',
      itemId: json['item_id']?.toString() ?? '',
      name: json['name'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  @override
  List<Object?> get props => [itemType, itemId];
}

/// 评论针对的目标（竞品/服务）简要信息
class TargetItemBrief extends Equatable {
  const TargetItemBrief({
    required this.itemType,
    required this.itemId,
    this.name,
    this.subtitle,
    this.thumbnail,
  });

  final String itemType;
  final String itemId;
  final String? name;
  final String? subtitle;
  final String? thumbnail;

  factory TargetItemBrief.fromJson(Map<String, dynamic> json) {
    return TargetItemBrief(
      itemType: json['item_type'] as String? ?? '',
      itemId: json['item_id']?.toString() ?? '',
      name: json['name'] as String?,
      subtitle: json['subtitle'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  @override
  List<Object?> get props => [itemType, itemId];
}

/// 达人服务评价来自活动时的活动简要信息
class ActivityBrief extends Equatable {
  const ActivityBrief({
    required this.activityId,
    this.activityTitle,
    this.originalPrice,
    this.discountedPrice,
    this.discountPercentage,
    this.currency = 'GBP',
  });

  final int activityId;
  final String? activityTitle;
  final double? originalPrice;
  final double? discountedPrice;
  final double? discountPercentage;
  final String currency;

  /// 是否有折扣
  bool get hasDiscount =>
      originalPrice != null &&
      discountedPrice != null &&
      originalPrice! > discountedPrice!;

  /// 折扣展示文字（如 "-20%"）
  String? get discountLabel {
    if (discountPercentage != null && discountPercentage! > 0) {
      return '-${discountPercentage!.toInt()}%';
    }
    return null;
  }

  factory ActivityBrief.fromJson(Map<String, dynamic> json) {
    return ActivityBrief(
      activityId: json['activity_id'] as int? ?? 0,
      activityTitle: json['activity_title'] as String?,
      originalPrice: (json['original_price'] as num?)?.toDouble(),
      discountedPrice: (json['discounted_price'] as num?)?.toDouble(),
      discountPercentage: (json['discount_percentage'] as num?)?.toDouble(),
      currency: json['currency'] as String? ?? 'GBP',
    );
  }

  @override
  List<Object?> get props => [activityId];
}

/// Discovery Feed 列表响应
class DiscoveryFeedResponse {
  const DiscoveryFeedResponse({
    required this.items,
    required this.page,
    required this.hasMore,
  });

  final List<DiscoveryFeedItem> items;
  final int page;
  final bool hasMore;

  factory DiscoveryFeedResponse.fromJson(Map<String, dynamic> json) {
    return DiscoveryFeedResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => DiscoveryFeedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      page: json['page'] as int? ?? 1,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
