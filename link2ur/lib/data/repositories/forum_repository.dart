import '../models/forum.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 论坛仓库
/// 与iOS ForumViewModel + 后端 forum_routes 对齐
class ForumRepository {
  ForumRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取可见论坛分类（首页展示用）
  Future<List<ForumCategory>> getVisibleCategories() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.forumVisibleCategories,
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

  /// 获取所有论坛分类
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

  /// 点赞（帖子或回复）
  Future<void> likePost(int postId) async {
    final response = await _apiService.post(
      ApiEndpoints.forumLikes,
      data: {'post_id': postId},
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '点赞失败');
    }
  }

  /// 收藏帖子
  Future<void> favoritePost(int postId) async {
    final response = await _apiService.post(
      ApiEndpoints.forumFavorites,
      data: {'post_id': postId},
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

  /// 获取我的回复
  Future<ForumPostListResponse> getMyReplies({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myForumReplies,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取我的回复失败');
    }

    return ForumPostListResponse.fromJson(response.data!);
  }

  /// 获取我收藏的帖子
  Future<ForumPostListResponse> getFavoritePosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myForumFavorites,
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
      ApiEndpoints.myForumLikes,
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

  /// 搜索帖子
  Future<ForumPostListResponse> searchPosts({
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumSearch,
      queryParameters: {
        'keyword': keyword,
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '搜索失败');
    }

    return ForumPostListResponse.fromJson(response.data!);
  }

  /// 更新帖子
  Future<ForumPost> updatePost(int postId, Map<String, dynamic> data) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      ApiEndpoints.forumPostById(postId),
      data: data,
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '更新帖子失败');
    }

    return ForumPost.fromJson(response.data!);
  }

  /// 删除帖子
  Future<void> deletePost(int postId) async {
    final response = await _apiService.delete(
      ApiEndpoints.forumPostById(postId),
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '删除帖子失败');
    }
  }

  /// 更新回复
  Future<ForumReply> updateReply(
    int replyId, {
    required String content,
  }) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      ApiEndpoints.forumReplyById(replyId),
      data: {'content': content},
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '更新回复失败');
    }

    return ForumReply.fromJson(response.data!);
  }

  /// 删除回复
  Future<void> deleteReply(int replyId) async {
    final response = await _apiService.delete(
      ApiEndpoints.forumReplyById(replyId),
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '删除回复失败');
    }
  }

  /// 举报帖子/回复
  Future<void> reportPost(int postId, {required String reason}) async {
    final response = await _apiService.post(
      ApiEndpoints.forumReports,
      data: {
        'post_id': postId,
        'reason': reason,
      },
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '举报失败');
    }
  }

  /// 请求创建新分类
  Future<void> requestCategory({
    required String name,
    required String description,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.forumCategoryRequest,
      data: {
        'name': name,
        'description': description,
      },
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '请求创建分类失败');
    }
  }

  /// 获取热门帖子
  Future<ForumPostListResponse> getHotPosts({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumHotPosts,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw ForumException(response.message ?? '获取热帖失败');
    }

    return ForumPostListResponse.fromJson(response.data!);
  }

  // ==================== 分类收藏 ====================

  /// 收藏/取消收藏分类
  Future<void> toggleCategoryFavorite(int categoryId) async {
    final response = await _apiService.post(
      ApiEndpoints.forumCategoryFavorite(categoryId),
    );

    if (!response.isSuccess) {
      throw ForumException(response.message ?? '操作失败');
    }
  }

  /// 获取分类收藏状态
  Future<bool> getCategoryFavoriteStatus(int categoryId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumCategoryFavoriteStatus(categoryId),
    );

    if (!response.isSuccess || response.data == null) {
      return false;
    }

    return response.data!['is_favorite'] as bool? ?? false;
  }
}

/// 论坛异常
class ForumException implements Exception {
  ForumException(this.message);

  final String message;

  @override
  String toString() => 'ForumException: $message';
}
