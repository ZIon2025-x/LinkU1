import '../models/discovery_feed.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class DiscoveryException implements Exception {
  DiscoveryException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Discovery Feed 仓库
class DiscoveryRepository {
  DiscoveryRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 获取发现 Feed
  Future<DiscoveryFeedResponse> getFeed({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.discoveryFeed,
      queryParameters: {
        'page': page,
        'limit': limit,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw DiscoveryException(response.message ?? '获取发现 Feed 失败');
    }
    return DiscoveryFeedResponse.fromJson(response.data!);
  }

  /// 搜索可关联内容（用于发帖关联功能）
  Future<List<Map<String, dynamic>>> searchLinkableContent({
    required String query,
    String type = 'all',
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumSearchLinkable,
      queryParameters: {
        'q': query,
        'type': type,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw DiscoveryException(response.message ?? '搜索可关联内容失败');
    }
    final results = response.data!['results'] as List<dynamic>? ?? [];
    return results.cast<Map<String, dynamic>>();
  }

  /// 获取与当前用户相关的可关联内容（发帖关联弹窗中搜索框下方展示）
  Future<List<Map<String, dynamic>>> getLinkableContentForUser() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.forumLinkableForUser,
    );
    if (!response.isSuccess || response.data == null) {
      return [];
    }
    final results = response.data!['results'] as List<dynamic>? ?? [];
    return results.cast<Map<String, dynamic>>();
  }
}
