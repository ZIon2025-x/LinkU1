import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/app_exception.dart';

/// 新手任务仓库
class NewbieTasksRepository {
  NewbieTasksRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 获取新手任务进度
  Future<List<Map<String, dynamic>>> getProgress() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.newbieTasksProgress,
    );

    if (!response.isSuccess || response.data == null) {
      throw NewbieTasksException(response.message ?? '获取新手任务进度失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 领取新手任务奖励
  Future<Map<String, dynamic>> claimTask(String taskKey) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '${ApiEndpoints.newbieTasksClaim}/$taskKey/claim',
    );

    if (!response.isSuccess || response.data == null) {
      throw NewbieTasksException(response.message ?? '领取任务奖励失败');
    }

    return response.data!;
  }

  /// 获取阶段进度
  Future<List<Map<String, dynamic>>> getStages() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.newbieTasksStages,
    );

    if (!response.isSuccess || response.data == null) {
      throw NewbieTasksException(response.message ?? '获取阶段进度失败');
    }

    final items = response.data!['data'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 领取阶段奖励
  Future<Map<String, dynamic>> claimStageBonus(int stage) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      '${ApiEndpoints.newbieTasksStages}/$stage/claim',
    );

    if (!response.isSuccess || response.data == null) {
      throw NewbieTasksException(response.message ?? '领取阶段奖励失败');
    }

    return response.data!;
  }
}

/// 新手任务异常
class NewbieTasksException extends AppException {
  const NewbieTasksException(super.message);
}
