import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 技能排行榜仓库
class SkillLeaderboardRepository {
  SkillLeaderboardRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 获取排行榜分类
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '${ApiEndpoints.leaderboardSkills}/categories',
    );

    if (!response.isSuccess || response.data == null) {
      throw SkillLeaderboardException(response.message ?? '获取排行榜分类失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取指定分类的排行榜
  Future<List<Map<String, dynamic>>> getLeaderboard(String category) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.leaderboardSkills,
      queryParameters: {'category': category},
    );

    if (!response.isSuccess || response.data == null) {
      throw SkillLeaderboardException(response.message ?? '获取排行榜失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取我在指定分类的排名
  Future<Map<String, dynamic>> getMyRank(String category) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '${ApiEndpoints.leaderboardSkills}/my-rank',
      queryParameters: {'category': category},
    );

    if (!response.isSuccess || response.data == null) {
      throw SkillLeaderboardException(response.message ?? '获取我的排名失败');
    }

    return response.data!;
  }
}

/// 技能排行榜异常
class SkillLeaderboardException extends AppException {
  const SkillLeaderboardException(super.message);
}
