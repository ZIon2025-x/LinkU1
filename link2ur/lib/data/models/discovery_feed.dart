import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/json_utils.dart';
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
    this.isFavorited,
    this.commentCount,
    this.upvoteCount,
    this.downvoteCount,
    this.voteType,
    this.userVoteType,
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
  final bool? isFavorited;
  final int? commentCount;
  final int? upvoteCount;
  final int? downvoteCount;
  /// 竞品评论的投票类型：upvote=赞成，downvote=反对
  final String? voteType;
  /// 当前用户对该排行榜条目的投票类型：upvote/downvote/null
  final String? userVoteType;
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

  /// 是否是达人推荐卡
  bool get isExpert => feedType == 'expert';

  // Expert-specific getters (from extra_data)
  String? get expertCategory => extraData?['category'] as String?;
  String? get expertLocation => extraData?['location'] as String?;
  int? get expertCompletedTasks => extraData?['completed_tasks'] as int?;
  List<String> get expertFeaturedSkills =>
      (extraData?['featured_skills'] as List?)?.cast<String>() ?? const [];
  List<String> get expertFeaturedSkillsEn =>
      (extraData?['featured_skills_en'] as List?)?.cast<String>() ?? const [];
  bool get expertIsOfficial => extraData?['is_official'] == true;
  bool get expertIsVerified => extraData?['is_verified'] == true;
  bool get expertIsFeatured => extraData?['is_featured'] == true;
  /// 当前是否营业。null 表示未设置营业时间（前端不显示状态条）
  bool? get expertIsOpen => extraData?['is_open'] as bool?;
  /// 推荐理由码：same_city / category_match / featured / null
  String? get expertReasonCode => extraData?['reason_code'] as String?;

  /// 是否是达人服务
  bool get isService => feedType == 'service';

  /// 是否是任务
  bool get isTask => feedType == 'task';

  /// 是否是活动
  bool get isActivity => feedType == 'activity';

  /// 是否是完成记录（仅关注 Feed）
  bool get isCompletion => feedType == 'completion';

  // Task-specific getters (from extra_data)
  String? get taskType => extraData?['task_type'];
  double? get reward => extraData?['reward'] != null ? (extraData!['reward'] as num).toDouble() : null;
  String? get taskLocation => extraData?['location'];
  String? get taskDeadline => extraData?['deadline'];
  int? get applicationCount => extraData?['application_count'] as int?;
  double? get matchScore => extraData?['match_score'] != null ? (extraData!['match_score'] as num).toDouble() : null;
  String? get recommendationReason => extraData?['recommendation_reason'];
  bool? get rewardToBeQuoted => extraData?['reward_to_be_quoted'] as bool?;

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

  /// 板块图标（仅帖子有 extra_data.category_icon，emoji 字符串）
  String? get categoryIcon => extraData?['category_icon'] as String?;

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
      isFavorited: parseBoolNullable(json['is_favorited']),
      commentCount: json['comment_count'] as int?,
      upvoteCount: json['upvote_count'] as int?,
      downvoteCount: json['downvote_count'] as int?,
      voteType: json['vote_type'] as String?,
      userVoteType: json['user_vote_type'] as String?,
      linkedItem: json['linked_item'] != null
          ? LinkedItemBrief.fromJson(json['linked_item'] as Map<String, dynamic>)
          : null,
      targetItem: json['target_item'] != null
          ? TargetItemBrief.fromJson(json['target_item'] as Map<String, dynamic>)
          : null,
      activityInfo: json['activity_info'] != null
          ? ActivityBrief.fromJson(json['activity_info'] as Map<String, dynamic>)
          : null,
      isExperienced: parseBoolNullable(json['is_experienced']),
      extraData: json['extra_data'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  @override
  List<Object?> get props => [id, feedType, voteType];
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
    this.maxParticipants,
    this.currentParticipants,
  });

  final int activityId;
  final String? activityTitle;
  final String? activityTitleZh;
  final String? activityTitleEn;
  final double? originalPrice;
  final double? discountedPrice;
  final double? discountPercentage;
  final String currency;
  final int? maxParticipants;
  final int? currentParticipants;

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
      maxParticipants: json['max_participants'] as int?,
      currentParticipants: json['current_participants'] as int?,
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
    this.seed,
  });

  final List<DiscoveryFeedItem> items;
  final int page;
  final bool hasMore;
  /// 随机种子，翻页时回传保证排序一致
  final int? seed;

  factory DiscoveryFeedResponse.fromJson(Map<String, dynamic> json) {
    return DiscoveryFeedResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => DiscoveryFeedItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      page: json['page'] as int? ?? 1,
      hasMore: parseBool(json['has_more']),
      seed: json['seed'] as int?,
    );
  }
}
