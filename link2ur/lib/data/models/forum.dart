import 'dart:ui' show Locale;

import 'package:equatable/equatable.dart';

import '../../core/utils/localized_string.dart';
import 'user.dart';

/// 论坛分类（对标iOS ForumCategory）
class ForumCategory extends Equatable {
  const ForumCategory({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    this.description,
    this.descriptionEn,
    this.descriptionZh,
    this.icon,
    this.postCount = 0,
    this.sortOrder = 0,
    this.type,
    this.country,
    this.universityCode,
    this.isFavorited = false,
    this.lastPostAt,
    this.latestPost,
    this.isAdminOnly = false,
  });

  // ==================== 板块类型常量 ====================

  /// 普通公开板块 — 所有用户可见
  static const String typeGeneral = 'general';

  /// 国家/地区级板块 — 需要学生认证（如"英国留学生"）
  static const String typeRoot = 'root';

  /// 学校专属板块 — 需要学生认证且匹配学校
  static const String typeUniversity = 'university';

  // ---- 预留未来权限类型 ----

  /// 达人专属板块
  static const String typeExpert = 'expert';

  /// 会员专属板块（VIP）
  static const String typeVip = 'vip';

  /// 超级会员专属板块
  static const String typeSuperVip = 'super_vip';

  // ==================== 字段 ====================

  final int id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String? description;
  final String? descriptionEn;
  final String? descriptionZh;
  final String? icon;
  final int postCount;
  final int sortOrder;
  final String? type; // general, root, university, expert, vip, super_vip
  final String? country; // 国家代码，如 "UK"（type=root 时使用）
  final String? universityCode; // 学校代码，如 "UOB"（type=university 时使用）
  final bool isFavorited;
  final DateTime? lastPostAt;
  final LatestPostInfo? latestPost;
  /// 是否仅管理员可发帖（普通用户不可在此板块发帖）
  final bool isAdminOnly;

  // ==================== 权限辅助 ====================

  /// 是否需要学生认证才可见（对标iOS requiresStudentVerification）
  bool get requiresStudentVerification =>
      type == typeRoot || type == typeUniversity;

  /// 是否需要特殊权限（学生/达人/会员）才可见
  bool get requiresSpecialPermission =>
      requiresStudentVerification ||
      type == typeExpert ||
      type == typeVip ||
      type == typeSuperVip;

  // ==================== 显示辅助 ====================

  /// 显示名称（根据 locale 选择 zh/en）
  String displayName(Locale locale) =>
      localizedString(nameZh, nameEn, name, locale);

  /// 显示描述（根据 locale 选择 zh/en）
  String? displayDescription(Locale locale) =>
      localizedStringOrNull(descriptionZh, descriptionEn, description, locale);

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      description: json['description'] as String?,
      descriptionEn: json['description_en'] as String?,
      descriptionZh: json['description_zh'] as String?,
      icon: json['icon'] as String?,
      postCount: json['post_count'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
      type: json['type'] as String?,
      country: json['country'] as String?,
      universityCode: json['university_code'] as String?,
      isFavorited: json['is_favorited'] as bool? ?? false,
      lastPostAt: json['last_post_at'] != null
          ? DateTime.tryParse(json['last_post_at'].toString())
          : null,
      latestPost: json['latest_post'] != null
          ? LatestPostInfo.fromJson(
              json['latest_post'] as Map<String, dynamic>)
          : null,
      isAdminOnly: json['is_admin_only'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, name, type, isFavorited];
}

/// 板块最新帖子摘要（对标iOS LatestPostInfo）
class LatestPostInfo {
  const LatestPostInfo({
    required this.id,
    required this.title,
    this.titleEn,
    this.titleZh,
    this.contentPreview,
    this.contentPreviewEn,
    this.contentPreviewZh,
    this.author,
    this.lastReplyAt,
    this.replyCount = 0,
    this.viewCount = 0,
  });

  final int id;
  final String title;
  final String? titleEn;
  final String? titleZh;
  final String? contentPreview;
  final String? contentPreviewEn;
  final String? contentPreviewZh;
  final UserBrief? author;
  final DateTime? lastReplyAt;
  final int replyCount;
  final int viewCount;

  /// 显示标题（根据 locale 选择 zh/en）
  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, title, locale);

  /// 显示内容预览（根据 locale 选择 zh/en）
  String? displayContentPreview(Locale locale) =>
      localizedStringOrNull(
          contentPreviewZh, contentPreviewEn, contentPreview, locale);

  factory LatestPostInfo.fromJson(Map<String, dynamic> json) {
    return LatestPostInfo(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      titleEn: json['title_en'] as String?,
      titleZh: json['title_zh'] as String?,
      contentPreview: json['content_preview'] as String?,
      contentPreviewEn: json['content_preview_en'] as String?,
      contentPreviewZh: json['content_preview_zh'] as String?,
      author: json['author'] != null
          ? UserBrief.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      lastReplyAt: json['last_reply_at'] != null
          ? DateTime.tryParse(json['last_reply_at'].toString())
          : null,
      replyCount: json['reply_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
    );
  }
}

/// 论坛帖子（对标iOS ForumPost）
class ForumPost extends Equatable {
  const ForumPost({
    required this.id,
    required this.title,
    this.titleEn,
    this.titleZh,
    this.content,
    this.contentEn,
    this.contentZh,
    this.contentPreview,
    this.contentPreviewEn,
    this.contentPreviewZh,
    this.images = const [],
    this.linkedItemType,
    this.linkedItemId,
    required this.categoryId,
    this.category,
    required this.authorId,
    this.author,
    this.likeCount = 0,
    this.replyCount = 0,
    this.viewCount = 0,
    this.isLiked = false,
    this.isFavorited = false,
    this.isPinned = false,
    this.isFeatured = false,
    this.isLocked = false,
    this.createdAt,
    this.updatedAt,
    this.lastReplyAt,
  });

  final int id;
  final String title;
  final String? titleEn;
  final String? titleZh;
  final String? content;
  final String? contentEn;
  final String? contentZh;
  final String? contentPreview;
  final String? contentPreviewEn;
  final String? contentPreviewZh;
  final List<String> images;
  final String? linkedItemType; // service/expert/activity/product/ranking/forum_post
  final String? linkedItemId;
  final int categoryId;
  final ForumCategory? category;
  final String authorId;
  final UserBrief? author;
  final int likeCount;
  final int replyCount;
  final int viewCount;
  final bool isLiked;
  final bool isFavorited;
  final bool isPinned;
  final bool isFeatured;
  final bool isLocked;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastReplyAt;

  /// 显示标题（根据 locale 选择 zh/en）
  String displayTitle(Locale locale) =>
      localizedString(titleZh, titleEn, title, locale);

  /// 显示内容（根据 locale 选择 zh/en，优先完整内容再预览）
  String? displayContent(Locale locale) =>
      localizedStringOrNull(contentZh, contentEn, content, locale) ??
      localizedStringOrNull(
          contentPreviewZh, contentPreviewEn, contentPreview, locale);

  /// 第一张图片
  String? get firstImage => images.isNotEmpty ? images.first : null;

  /// 是否有图片
  bool get hasImages => images.isNotEmpty;

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    // 后端列表接口返回 content_preview/content_preview_en/content_preview_zh
    // 详情接口返回 content/content_en/content_zh
    final contentPreview = (json['content_preview_zh'] as String?) ??
        (json['content_preview_en'] as String?) ??
        (json['content_preview'] as String?);

    return ForumPost(
      id: json['id'] as int,
      title: json['title_zh'] as String? ??
          json['title_en'] as String? ??
          json['title'] as String? ??
          '',
      titleEn: json['title_en'] as String?,
      titleZh: json['title_zh'] as String?,
      content: json['content'] as String?,
      contentEn: json['content_en'] as String?,
      contentZh: json['content_zh'] as String?,
      contentPreview: contentPreview,
      contentPreviewEn: json['content_preview_en'] as String?,
      contentPreviewZh: json['content_preview_zh'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      linkedItemType: json['linked_item_type'] as String?,
      linkedItemId: json['linked_item_id']?.toString(),
      categoryId: json['category_id'] as int? ??
          (json['category'] as Map<String, dynamic>?)?['id'] as int? ??
          0,
      category: json['category'] != null
          ? ForumCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      authorId: (json['author_id'] ??
              (json['author'] as Map<String, dynamic>?)?['id'] ??
              '')
          .toString(),
      author: json['author'] != null
          ? UserBrief.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isFavorited: json['is_favorited'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      isFeatured: json['is_featured'] as bool? ?? false,
      isLocked: json['is_locked'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      lastReplyAt: json['last_reply_at'] != null
          ? DateTime.tryParse(json['last_reply_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'images': images,
      if (linkedItemType != null) 'linked_item_type': linkedItemType,
      if (linkedItemId != null) 'linked_item_id': linkedItemId,
      'category_id': categoryId,
      'author_id': authorId,
      'like_count': likeCount,
      'reply_count': replyCount,
      'view_count': viewCount,
      'is_liked': isLiked,
      'is_favorited': isFavorited,
      'is_pinned': isPinned,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  ForumPost copyWith({
    int? likeCount,
    bool? isLiked,
    bool? isFavorited,
    int? replyCount,
    String? content,
  }) {
    return ForumPost(
      id: id,
      title: title,
      titleEn: titleEn,
      titleZh: titleZh,
      content: content ?? this.content,
      contentEn: contentEn,
      contentZh: contentZh,
      contentPreview: contentPreview,
      contentPreviewEn: contentPreviewEn,
      contentPreviewZh: contentPreviewZh,
      images: images,
      categoryId: categoryId,
      category: category,
      authorId: authorId,
      author: author,
      likeCount: likeCount ?? this.likeCount,
      replyCount: replyCount ?? this.replyCount,
      viewCount: viewCount,
      isLiked: isLiked ?? this.isLiked,
      isFavorited: isFavorited ?? this.isFavorited,
      isPinned: isPinned,
      isFeatured: isFeatured,
      isLocked: isLocked,
      createdAt: createdAt,
      updatedAt: updatedAt,
      lastReplyAt: lastReplyAt,
    );
  }

  @override
  List<Object?> get props => [id, title, likeCount, replyCount, updatedAt];
}

/// 论坛回复
class ForumReply extends Equatable {
  const ForumReply({
    required this.id,
    required this.postId,
    required this.content,
    required this.authorId,
    this.author,
    this.parentReplyId,
    this.parentReplyAuthor,
    this.likeCount = 0,
    this.isLiked = false,
    this.createdAt,
  });

  final int id;
  final int postId;
  final String content;
  final String authorId;
  final UserBrief? author;
  final int? parentReplyId;
  final UserBrief? parentReplyAuthor;
  final int likeCount;
  final bool isLiked;
  final DateTime? createdAt;

  /// 是否是子回复
  bool get isSubReply => parentReplyId != null;

  factory ForumReply.fromJson(Map<String, dynamic> json) {
    return ForumReply(
      id: json['id'] as int,
      postId: json['post_id'] as int,
      content: json['content'] as String? ?? '',
      authorId: (json['author_id'] ?? '').toString(),
      author: json['author'] != null
          ? UserBrief.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      parentReplyId: json['parent_reply_id'] as int?,
      parentReplyAuthor: json['parent_reply_author'] != null
          ? UserBrief.fromJson(
              json['parent_reply_author'] as Map<String, dynamic>)
          : null,
      likeCount: json['like_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, postId, content, createdAt];
}

/// 论坛帖子列表响应
class ForumPostListResponse {
  const ForumPostListResponse({
    required this.posts,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<ForumPost> posts;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => posts.length >= pageSize;

  factory ForumPostListResponse.fromJson(Map<String, dynamic> json) {
    // 后端返回 "posts" key（forum_routes.py）
    final rawList = (json['posts'] as List<dynamic>?) ??
        (json['items'] as List<dynamic>?) ??
        [];
    return ForumPostListResponse(
      posts: rawList
          .map((e) => ForumPost.fromJson(e as Map<String, dynamic>))
          .toList(),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
}

/// 创建帖子请求
class CreatePostRequest {
  const CreatePostRequest({
    required this.title,
    required this.content,
    required this.categoryId,
    this.images = const [],
    this.linkedItemType,
    this.linkedItemId,
  });

  final String title;
  final String content;
  final int categoryId;
  final List<String> images;
  final String? linkedItemType;
  final String? linkedItemId;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'category_id': categoryId,
      if (images.isNotEmpty) 'images': images,
      if (linkedItemType != null &&
          linkedItemType!.isNotEmpty &&
          linkedItemId != null &&
          linkedItemId!.isNotEmpty)
        ...{
          'linked_item_type': linkedItemType!,
          'linked_item_id': linkedItemId!,
        },
    };
  }
}
