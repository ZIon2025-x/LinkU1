import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 官方任务仓库
class OfficialTasksRepository {
  OfficialTasksRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 获取官方任务列表
  Future<List<Map<String, dynamic>>> getOfficialTasks() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.officialTasks,
    );

    if (!response.isSuccess || response.data == null) {
      throw OfficialTasksException(response.message ?? '获取官方任务列表失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取官方任务详情
  Future<Map<String, dynamic>> getOfficialTaskDetail(int id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      '${ApiEndpoints.officialTasks}/$id',
    );

    if (!response.isSuccess || response.data == null) {
      throw OfficialTasksException(response.message ?? '获取官方任务详情失败');
    }

    return response.data!;
  }

  /// 提交官方任务（关联论坛帖子）
  Future<Map<String, dynamic>> submitOfficialTask(
      int taskId, int forumPostId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '${ApiEndpoints.officialTasks}/$taskId/submit',
      data: {'forum_post_id': forumPostId},
    );

    if (!response.isSuccess || response.data == null) {
      throw OfficialTasksException(response.message ?? '提交官方任务失败');
    }

    return response.data!;
  }

  /// 领取官方任务奖励
  Future<Map<String, dynamic>> claimOfficialTask(int taskId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '${ApiEndpoints.officialTasks}/$taskId/claim',
    );

    if (!response.isSuccess || response.data == null) {
      throw OfficialTasksException(response.message ?? '领取官方任务奖励失败');
    }

    return response.data!;
  }
}

/// 官方任务异常
class OfficialTasksException extends AppException {
  const OfficialTasksException(super.message);
}
