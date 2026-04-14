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
      ApiEndpoints.leaderboardSkills,
    );

    if (!response.isSuccess || response.data == null) {
      throw SkillLeaderboardException(response.errorCode ?? response.message ?? '获取排行榜分类失败', code: response.errorCode);
    }

    final data = response.data!;
    // Handle both wrapped {"data": [...]} and raw list responses
    if (data['data'] is List) {
      return (data['data'] as List).map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  /// 获取指定分类的排行榜
  Future<List<Map<String, dynamic>>> getLeaderboard(String category) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '${ApiEndpoints.leaderboardSkills}/${Uri.encodeComponent(category)}',
    );

    if (!response.isSuccess || response.data == null) {
      throw SkillLeaderboardException(response.errorCode ?? response.message ?? '获取排行榜失败', code: response.errorCode);
    }

    final data = response.data!;
    if (data['data'] is List) {
      return (data['data'] as List).map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  /// 获取我在指定分类的排名
  Future<Map<String, dynamic>> getMyRank(String category) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '${ApiEndpoints.leaderboardSkills}/${Uri.encodeComponent(category)}/my-rank',
    );

    if (!response.isSuccess || response.data == null) {
      throw SkillLeaderboardException(response.errorCode ?? response.message ?? '获取我的排名失败', code: response.errorCode);
    }

    return response.data!;
  }
}

/// 技能排行榜异常
class SkillLeaderboardException extends AppException {
  const SkillLeaderboardException(super.message, {super.code});
}
