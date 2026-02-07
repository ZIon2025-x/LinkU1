import '../models/task_expert.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 任务达人仓库
/// 与iOS TaskExpertViewModel + 后端 task_expert_routes 对齐
class TaskExpertRepository {
  TaskExpertRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取任务达人列表
  Future<TaskExpertListResponse> getExperts({
    int page = 1,
    int pageSize = 20,
    String? keyword,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExperts,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (keyword != null) 'keyword': keyword,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人列表失败');
    }

    return TaskExpertListResponse.fromJson(response.data!);
  }

  /// 获取达人详情
  Future<TaskExpert> getExpertById(String id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人详情失败');
    }

    return TaskExpert.fromJson(response.data!);
  }

  /// 获取达人服务列表
  Future<List<TaskExpertService>> getExpertServices(String expertId) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.taskExpertServices(expertId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人服务失败');
    }

    return response.data!
        .map(
            (e) => TaskExpertService.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取服务详情
  Future<Map<String, dynamic>> getServiceDetail(int serviceId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertServiceDetail(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取服务详情失败');
    }

    return response.data!;
  }

  /// 获取服务评价
  Future<List<Map<String, dynamic>>> getServiceReviews(
      int serviceId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertServiceReviews(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取评价失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 申请达人服务
  Future<Map<String, dynamic>> applyService(
    int serviceId, {
    String? message,
    String? preferredTimeSlot,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.applyForService(serviceId),
      data: {
        if (message != null) 'message': message,
        if (preferredTimeSlot != null) 'preferred_time_slot': preferredTimeSlot,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '申请服务失败');
    }

    return response.data!;
  }

  /// 申请成为达人
  Future<Map<String, dynamic>> applyToBeExpert({
    required Map<String, dynamic> applicationData,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.applyToBeExpert,
      data: applicationData,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '申请成为达人失败');
    }

    return response.data!;
  }

  /// 搜索达人
  Future<List<TaskExpert>> searchExperts({
    required String keyword,
    int page = 1,
    int pageSize = 20,
  }) async {
    final result = await getExperts(
      keyword: keyword,
      page: page,
      pageSize: pageSize,
    );
    return result.experts;
  }

  /// 获取我的服务申请
  Future<List<Map<String, dynamic>>> getMyServiceApplications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myServiceApplications,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取服务申请失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }
}

/// 任务达人异常
class TaskExpertException implements Exception {
  TaskExpertException(this.message);

  final String message;

  @override
  String toString() => 'TaskExpertException: $message';
}
