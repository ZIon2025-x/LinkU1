import '../services/api_service.dart';
import '../models/discovery_feed.dart';
import '../../core/utils/app_exception.dart';

class FollowException extends AppException {
  const FollowException(super.message, {super.code});
}

class FollowRepository {
  FollowRepository({required ApiService apiService}) : _apiService = apiService;
  final ApiService _apiService;

  Future<Map<String, dynamic>> followUser(String userId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '/api/users/$userId/follow',
    );
    if (!response.isSuccess || response.data == null) {
      throw FollowException(response.errorCode ?? response.message ?? 'follow_failed', code: response.errorCode);
    }
    return response.data!;
  }

  Future<Map<String, dynamic>> unfollowUser(String userId) async {
    final response = await _apiService.delete<Map<String, dynamic>>(
      '/api/users/$userId/follow',
    );
    if (!response.isSuccess || response.data == null) {
      throw FollowException(response.errorCode ?? response.message ?? 'unfollow_failed', code: response.errorCode);
    }
    return response.data!;
  }

  Future<Map<String, dynamic>> getFollowers(String userId, {int page = 1, int pageSize = 20}) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/api/users/$userId/followers',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    if (!response.isSuccess || response.data == null) {
      throw FollowException(response.errorCode ?? response.message ?? 'get_followers_failed', code: response.errorCode);
    }
    return response.data!;
  }

  Future<Map<String, dynamic>> getFollowing(String userId, {int page = 1, int pageSize = 20}) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/api/users/$userId/following',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    if (!response.isSuccess || response.data == null) {
      throw FollowException(response.errorCode ?? response.message ?? 'get_following_failed', code: response.errorCode);
    }
    return response.data!;
  }

  Future<DiscoveryFeedResponse> getFollowFeed({int page = 1, int pageSize = 20}) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '/api/follow/feed',
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    if (!response.isSuccess || response.data == null) {
      throw FollowException(response.errorCode ?? response.message ?? 'get_follow_feed_failed', code: response.errorCode);
    }
    return DiscoveryFeedResponse.fromJson(response.data!);
  }
}
