import '../models/leaderboard.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 排行榜仓库
/// 与iOS LeaderboardViewModel + 后端 custom_leaderboard_routes 对齐
class LeaderboardRepository {
  LeaderboardRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 获取排行榜列表
  Future<LeaderboardListResponse> getLeaderboards({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? location,
    String? sort,
  }) async {
    final offset = (page - 1) * pageSize;
    final params = {
      'limit': pageSize,
      'offset': offset,
      if (keyword != null) 'keyword': keyword,
      if (location != null) 'location': location,
      if (sort != null) 'sort': sort,
    };

    // 无搜索时使用缓存
    if (keyword == null) {
      final cacheKey =
          CacheManager.buildKey(CacheManager.prefixLeaderboard, params);
      final cached = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return LeaderboardListResponse.fromJson(cached);
      }
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboards,
      queryParameters: params,
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取排行榜列表失败');
    }

    // 排行榜变动少，使用长TTL
    if (keyword == null) {
      final cacheKey =
          CacheManager.buildKey(CacheManager.prefixLeaderboard, params);
      await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);
    }

    return LeaderboardListResponse.fromJson(response.data!);
  }

  /// 获取排行榜详情
  Future<Leaderboard> getLeaderboardById(int id) async {
    final cacheKey = '${CacheManager.prefixLeaderboardDetail}$id';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return Leaderboard.fromJson(cached);
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取排行榜详情失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

    return Leaderboard.fromJson(response.data!);
  }

  /// 获取排行榜项目列表
  Future<List<LeaderboardItem>> getLeaderboardItems(
    int leaderboardId, {
    int page = 1,
    int pageSize = 50,
    String? sortBy,
  }) async {
    // 后端使用 limit/offset 分页 + sort 参数
    final offset = (page - 1) * pageSize;
    final params = {
      'lb_id': leaderboardId,
      'limit': pageSize,
      'offset': offset,
      if (sortBy != null) 'sort': sortBy,
    };
    final cacheKey =
        CacheManager.buildKey('${CacheManager.prefixLeaderboard}items_', params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => LeaderboardItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardItems(leaderboardId),
      queryParameters: {
        'limit': pageSize,
        'offset': offset,
        if (sortBy != null) 'sort': sortBy,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取排行榜项目失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => LeaderboardItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 投票
  Future<Map<String, dynamic>> voteItem(
    int itemId, {
    required String voteType,
    String? comment,
    bool isAnonymous = false,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.leaderboardItemVote(itemId),
      queryParameters: {
        'vote_type': voteType,
        if (comment != null) 'comment': comment,
        'is_anonymous': isAnonymous,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '投票失败');
    }

    return response.data!;
  }

  /// 获取排行榜条目详情
  Future<Map<String, dynamic>> getItemDetail(int itemId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardItemDetail(itemId),
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取条目详情失败');
    }

    return response.data!;
  }

  /// 获取条目投票列表
  Future<List<Map<String, dynamic>>> getItemVotes(int itemId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardItemVotes(itemId),
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取投票列表失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 上传排行榜封面图（公开图片，使用 V2 接口；创建时由后端迁移到正式目录）
  Future<String> uploadImage(String filePath, {String category = 'leaderboard_cover'}) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      '${ApiEndpoints.uploadImageV2}?category=$category',
      filePath: filePath,
      fieldName: 'image',
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '图片上传失败');
    }

    final url = response.data!['url'] as String? ??
        response.data!['image_url'] as String? ??
        '';
    if (url.isEmpty) {
      throw const LeaderboardException('图片上传返回了空 URL');
    }
    return url;
  }

  /// 申请创建排行榜
  Future<Leaderboard> applyLeaderboard({
    required String name,
    required String location,
    String? description,
    String? coverImage,
    String? applicationReason,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.leaderboardApply,
      data: {
        'name': name,
        'location': location,
        if (description != null) 'description': description,
        if (coverImage != null) 'cover_image': coverImage,
        if (applicationReason != null) 'application_reason': applicationReason,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '申请排行榜失败');
    }

    return Leaderboard.fromJson(response.data!);
  }

  /// 提交排行榜条目
  Future<LeaderboardItem> submitItem({
    required int leaderboardId,
    required String name,
    String? description,
    String? address,
    String? phone,
    String? website,
    List<String>? images,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.leaderboardCreateItem,
      data: {
        'leaderboard_id': leaderboardId,
        'name': name,
        if (description != null) 'description': description,
        if (address != null) 'address': address,
        if (phone != null) 'phone': phone,
        if (website != null) 'website': website,
        if (images != null) 'images': images,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '提交条目失败');
    }

    return LeaderboardItem.fromJson(response.data!);
  }

  /// 审核排行榜
  Future<void> reviewLeaderboard(
    int leaderboardId, {
    required String action,
    String? comment,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.leaderboardReview(leaderboardId),
      queryParameters: {
        'action': action,
        if (comment != null) 'comment': comment,
      },
    );

    if (!response.isSuccess) {
      throw LeaderboardException(response.message ?? '审核失败');
    }
  }

  /// 点赞投票
  Future<void> likeVote(int voteId) async {
    final response = await _apiService.post(
      ApiEndpoints.leaderboardVoteLike(voteId),
    );

    if (!response.isSuccess) {
      throw LeaderboardException(response.message ?? '点赞失败');
    }
  }

  // ==================== 收藏/举报 ====================

  /// 收藏/取消收藏排行榜
  Future<void> toggleFavorite(int leaderboardId) async {
    final response = await _apiService.post(
      ApiEndpoints.leaderboardFavorite(leaderboardId),
    );

    if (!response.isSuccess) {
      throw LeaderboardException(response.message ?? '操作失败');
    }
  }

  /// 获取收藏状态
  Future<bool> getFavoriteStatus(int leaderboardId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardFavoriteStatus(leaderboardId),
    );

    if (!response.isSuccess || response.data == null) {
      return false;
    }

    return response.data!['favorited'] as bool? ?? false;
  }

  /// 获取我收藏的排行榜
  Future<LeaderboardListResponse> getMyFavorites({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myLeaderboardFavorites,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取收藏排行榜失败');
    }

    return LeaderboardListResponse.fromJson(response.data!);
  }

  /// 举报排行榜
  Future<void> reportLeaderboard(int leaderboardId,
      {required String reason, String? description}) async {
    final response = await _apiService.post(
      ApiEndpoints.leaderboardReport(leaderboardId),
      data: {
        'reason': reason,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );

    if (!response.isSuccess) {
      throw LeaderboardException(response.message ?? '举报失败');
    }
  }

  /// 举报排行榜条目
  Future<void> reportItem(int itemId,
      {required String reason, String? description}) async {
    final response = await _apiService.post(
      ApiEndpoints.leaderboardItemReport(itemId),
      data: {
        'reason': reason,
        if (description != null && description.isNotEmpty)
          'description': description,
      },
    );

    if (!response.isSuccess) {
      throw LeaderboardException(response.message ?? '举报失败');
    }
  }
}

/// 排行榜异常
class LeaderboardException extends AppException {
  const LeaderboardException(super.message);
}
