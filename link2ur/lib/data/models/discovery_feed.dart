import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/localized_string.dart';

/// Discovery Feed 内容项
/// 统一表示 6 种类型: forum_post / product / competitor_review / service_review / ranking / service
/// 支持双语字段 title_zh/title_en、description_zh/description_en，按 locale 展示
class DiscoveryFeedItem extends Equatable {
  const DiscoveryFeedItem({
    required this.id,
    required this.feedType,
    this.title,
    this.titleZh,
    this.titleEn,
    this.description,
    this.descriptionZh,
    this.descriptionEn,
    this.images,
    this.userId,
    this.userName,
    this.userAvatar,
    this.expertId,
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
  final String? titleZh;
  final String? titleEn;
  final String? description;
  final String? descriptionZh;
  final String? descriptionEn;
  final List<String>? images;
  final String? userId;
  final String? userName;
  final String? userAvatar;
  /// 当展示的是达人时由后端返回，点击头像/名字跳达人详情页
  final String? expertId;
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

  /// 按语言展示标题（优先 zh/en 列，缺则回退 title）
  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, title ?? '', locale);

  /// 按语言展示描述（优先 zh/en 列，缺则回退 description）
  String? displayDescription(Locale locale) =>
      localizedStringOrNull(descriptionZh, descriptionEn, description, locale);

  /// 板块名称（仅帖子有 extra_data.category_name_zh / _en / category_name）
  String? displayCategoryName(Locale locale) {
    final extra = extraData;
    if (extra == null) return null;
    final preferZh = locale.languageCode.startsWith('zh');
    if (preferZh) {
      return extra['category_name_zh'] as String? ??
          extra['category_name_en'] as String? ??
          extra['category_name'] as String?;
    }
    return extra['category_name_en'] as String? ??
        extra['category_name_zh'] as String? ??
        extra['category_name'] as String?;
  }

  factory DiscoveryFeedItem.fromJson(Map<String, dynamic> json) {
    return DiscoveryFeedItem(
      id: json['id'] as String? ?? '',
      feedType: json['feed_type'] as String? ?? '',
      title: json['title'] as String?,
      titleZh: json['title_zh'] as String?,
      titleEn: json['title_en'] as String?,
      description: json['description'] as String?,
      descriptionZh: json['description_zh'] as String?,
      descriptionEn: json['description_en'] as String?,
      images: (json['images'] as List<dynamic>?)?.map((e) => e as String).toList(),
      userId: json['user_id'] as String?,
      userName: json['user_name'] as String?,
      userAvatar: json['user_avatar'] as String?,
      expertId: json['expert_id'] as String?,
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
    this.activityTitleZh,
    this.activityTitleEn,
    this.originalPrice,
    this.discountedPrice,
    this.discountPercentage,
    this.currency = 'GBP',
  });

  final int activityId;
  final String? activityTitle;
  final String? activityTitleZh;
  final String? activityTitleEn;
  final double? originalPrice;
  final double? discountedPrice;
  final double? discountPercentage;
  final String currency;

  /// 按语言展示活动标题
  String displayActivityTitle(Locale locale) =>
      localizedString(activityTitleZh, activityTitleEn, activityTitle ?? '', locale);

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
      activityTitleZh: json['activity_title_zh'] as String?,
      activityTitleEn: json['activity_title_en'] as String?,
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
