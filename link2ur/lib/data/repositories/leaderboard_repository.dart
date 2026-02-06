import '../models/leaderboard.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 排行榜仓库
/// 参考iOS APIService+Endpoints.swift 排行榜相关
class LeaderboardRepository {
  LeaderboardRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取排行榜列表
  Future<LeaderboardListResponse> getLeaderboards({
    int page = 1,
    int pageSize = 20,
    String? keyword,
    String? location,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboards,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (keyword != null) 'keyword': keyword,
        if (location != null) 'location': location,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取排行榜列表失败');
    }

    return LeaderboardListResponse.fromJson(response.data!);
  }

  /// 获取排行榜详情
  Future<Leaderboard> getLeaderboardById(int id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取排行榜详情失败');
    }

    return Leaderboard.fromJson(response.data!);
  }

  /// 获取排行榜项目列表
  Future<List<LeaderboardItem>> getLeaderboardItems(
    int leaderboardId, {
    int page = 1,
    int pageSize = 20,
    String? sortBy,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardItems(leaderboardId),
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (sortBy != null) 'sort_by': sortBy,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取排行榜项目失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items
        .map((e) => LeaderboardItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 投票
  Future<LeaderboardItem> voteItem(
    int itemId, {
    required String voteType, // upvote, downvote
    String? comment,
    bool isAnonymous = false,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.voteItem(itemId),
      data: {
        'vote_type': voteType,
        if (comment != null) 'comment': comment,
        'is_anonymous': isAnonymous,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '投票失败');
    }

    return LeaderboardItem.fromJson(response.data!);
  }

  /// 获取我的排行榜
  Future<LeaderboardListResponse> getMyLeaderboards({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myLeaderboards,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw LeaderboardException(response.message ?? '获取我的排行榜失败');
    }

    return LeaderboardListResponse.fromJson(response.data!);
  }
}

/// 排行榜异常
class LeaderboardException implements Exception {
  LeaderboardException(this.message);

  final String message;

  @override
  String toString() => 'LeaderboardException: $message';
}
