import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 用户技能仓库
class UserSkillsRepository {
  UserSkillsRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 获取我的技能列表
  Future<List<Map<String, dynamic>>> getMySkills() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.userSkillsMy,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserSkillsException(response.errorCode ?? response.message ?? '获取技能列表失败', code: response.errorCode);
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 添加技能
  Future<Map<String, dynamic>> addSkill(String category, String name) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.userSkillsMy,
      data: {
        'category': category,
        'name': name,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw UserSkillsException(response.errorCode ?? response.message ?? '添加技能失败', code: response.errorCode);
    }

    return response.data!;
  }

  /// 删除技能
  Future<void> removeSkill(int skillId) async {
    final response = await _apiService.delete<Map<String, dynamic>>(
      '${ApiEndpoints.userSkillsMy}/$skillId',
    );

    if (!response.isSuccess) {
      throw UserSkillsException(response.errorCode ?? response.message ?? '删除技能失败', code: response.errorCode);
    }
  }

  /// 获取技能分类
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.skillCategories,
    );

    if (!response.isSuccess || response.data == null) {
      throw UserSkillsException(response.errorCode ?? response.message ?? '获取技能分类失败', code: response.errorCode);
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }
}

/// 用户技能异常
class UserSkillsException extends AppException {
  const UserSkillsException(super.message, {super.code});
}
