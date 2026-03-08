import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 徽章仓库
class BadgesRepository {
  BadgesRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 获取我的徽章
  Future<List<Map<String, dynamic>>> getMyBadges() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.badgesMy,
    );

    if (!response.isSuccess || response.data == null) {
      throw BadgesException(response.message ?? '获取我的徽章失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 切换徽章展示状态
  Future<Map<String, dynamic>> toggleBadgeDisplay(int badgeId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '${ApiEndpoints.badgesMy}/$badgeId/toggle-display',
    );

    if (!response.isSuccess || response.data == null) {
      throw BadgesException(response.message ?? '切换徽章展示失败');
    }

    return response.data!;
  }

  /// 获取指定用户的徽章
  Future<List<Map<String, dynamic>>> getUserBadges(String userId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '${ApiEndpoints.badgesUser}/$userId',
    );

    if (!response.isSuccess || response.data == null) {
      throw BadgesException(response.message ?? '获取用户徽章失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }
}

/// 徽章异常
class BadgesException extends AppException {
  const BadgesException(super.message);
}
