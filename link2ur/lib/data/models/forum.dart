import 'package:equatable/equatable.dart';
import 'user.dart';

/// 论坛分类
class ForumCategory extends Equatable {
  const ForumCategory({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    this.description,
    this.icon,
    this.postCount = 0,
    this.sortOrder = 0,
  });

  final int id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String? description;
  final String? icon;
  final int postCount;
  final int sortOrder;

  /// 显示名称
  String get displayName => nameZh ?? nameEn ?? name;

  factory ForumCategory.fromJson(Map<String, dynamic> json) {
    return ForumCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      nameEn: json['name_en'] as String?,
      nameZh: json['name_zh'] as String?,
      description: json['description'] as String?,
      icon: json['icon'] as String?,
      postCount: json['post_count'] as int? ?? 0,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name];
}

/// 论坛帖子
class ForumPost extends Equatable {
  const ForumPost({
    required this.id,
    required this.title,
    this.content,
    this.images = const [],
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
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String title;
  final String? content;
  final List<String> images;
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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// 第一张图片
  String? get firstImage => images.isNotEmpty ? images.first : null;

  /// 是否有图片
  bool get hasImages => images.isNotEmpty;

  factory ForumPost.fromJson(Map<String, dynamic> json) {
    return ForumPost(
      id: json['id'] as int,
      title: json['title'] as String? ?? '',
      content: json['content'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      categoryId: json['category_id'] as int? ?? 0,
      category: json['category'] != null
          ? ForumCategory.fromJson(json['category'] as Map<String, dynamic>)
          : null,
      authorId: (json['author_id'] ?? '').toString(),
      author: json['author'] != null
          ? UserBrief.fromJson(json['author'] as Map<String, dynamic>)
          : null,
      likeCount: json['like_count'] as int? ?? 0,
      replyCount: json['reply_count'] as int? ?? 0,
      viewCount: json['view_count'] as int? ?? 0,
      isLiked: json['is_liked'] as bool? ?? false,
      isFavorited: json['is_favorited'] as bool? ?? false,
      isPinned: json['is_pinned'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'images': images,
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
  }) {
    return ForumPost(
      id: id,
      title: title,
      content: content,
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
      createdAt: createdAt,
      updatedAt: updatedAt,
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
    return ForumPostListResponse(
      posts: (json['items'] as List<dynamic>?)
              ?.map((e) => ForumPost.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
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
  });

  final String title;
  final String content;
  final int categoryId;
  final List<String> images;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'content': content,
      'category_id': categoryId,
      'images': images,
    };
  }
}
