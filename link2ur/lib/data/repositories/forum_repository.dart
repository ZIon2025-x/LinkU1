import '../models/forum.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 论坛仓库
/// 参考iOS APIService+Endpoints.swift 论坛相关
class ForumRepository {
  ForumRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取论坛分类
  Future<List<ForumCategory>> getCategories() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.forumCategories,
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取论坛分类失败');
    }

    return response.data!
        .map((e) => ForumCategory.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取帖子列表
  Future<ForumPostListResponse> getPosts({
    int page = 1,
    int pageSize = 20,
    int? categoryId,
    String? keyword,
    String? sortBy,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumPosts,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (categoryId != null) 'category_id': categoryId,
        if (keyword != null) 'keyword': keyword,
        if (sortBy != null) 'sort_by': sortBy,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取帖子列表失败');
    }

    return ForumPostListResponse.fromJson(response.data!);
  }

  /// 获取帖子详情
  Future<ForumPost> getPostById(int id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumPostById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取帖子详情失败');
    }

    return ForumPost.fromJson(response.data!);
  }

  /// 创建帖子
  Future<ForumPost> createPost(CreatePostRequest request) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.forumPosts,
      data: request.toJson(),
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '发帖失败');
    }

    return ForumPost.fromJson(response.data!);
  }

  /// 获取帖子回复
  Future<List<ForumReply>> getPostReplies(
    int postId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumPostReplies(postId),
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取回复失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => ForumReply.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 回复帖子
  Future<ForumReply> replyPost(
    int postId, {
    required String content,
    int? parentReplyId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.forumPostReplies(postId),
      data: {
        'content': content,
        if (parentReplyId != null) 'parent_reply_id': parentReplyId,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '回复失败');
    }

    return ForumReply.fromJson(response.data!);
  }

  /// 点赞帖子
  Future<void> likePost(int postId) async {
    final response = await _apiService.post(
      ApiEndpoints.likePost(postId),
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '点赞失败');
    }
  }

  /// 收藏帖子
  Future<void> favoritePost(int postId) async {
    final response = await _apiService.post(
      ApiEndpoints.favoritePost(postId),
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '收藏失败');
    }
  }

  /// 获取我的帖子
  Future<ForumPostListResponse> getMyPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myForumPosts,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取我的帖子失败');
    }

    return ForumPostListResponse.fromJson(response.data!);
  }

  /// 获取我收藏的帖子
  Future<ForumPostListResponse> getFavoritePosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.favoriteForumPosts,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取收藏帖子失败');
    }

    return ForumPostListResponse.fromJson(response.data!);
  }
  /// 获取我点赞的帖子
  Future<ForumPostListResponse> getLikedPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.likedForumPosts,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取点赞帖子失败');
    }

    return ForumPostListResponse.fromJson(response.data!);
  }
}

/// 论坛异常
class ForumException implements Exception {
  ForumException(this.message);

  final String message;

  @override
  String toString() => 'ForumException: $message';
}
