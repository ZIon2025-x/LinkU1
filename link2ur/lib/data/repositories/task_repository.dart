import '../models/task.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 任务仓库
/// 参考iOS APIService+Endpoints.swift 任务相关
class TaskRepository {
  TaskRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取任务列表
  Future<TaskListResponse> getTasks({
    int page = 1,
    int pageSize = 20,
    String? taskType,
    String? status,
    String? keyword,
    String? sortBy,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.tasks,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (taskType != null) 'task_type': taskType,
        if (status != null) 'status': status,
        if (keyword != null) 'keyword': keyword,
        if (sortBy != null) 'sort_by': sortBy,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取任务列表失败');
    }

    return TaskListResponse.fromJson(response.data!);
  }

  /// 获取推荐任务
  Future<TaskListResponse> getRecommendedTasks({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.recommendedTasks,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取推荐任务失败');
    }

    return TaskListResponse.fromJson(response.data!);
  }

  /// 获取附近任务
  Future<TaskListResponse> getNearbyTasks({
    required double latitude,
    required double longitude,
    int page = 1,
    int pageSize = 20,
    double? radius,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.nearbyTasks,
      queryParameters: {
        'latitude': latitude,
        'longitude': longitude,
        'page': page,
        'page_size': pageSize,
        if (radius != null) 'radius': radius,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取附近任务失败');
    }

    return TaskListResponse.fromJson(response.data!);
  }

  /// 获取任务详情
  Future<Task> getTaskById(int id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取任务详情失败');
    }

    return Task.fromJson(response.data!);
  }

  /// 创建任务
  Future<Task> createTask(CreateTaskRequest request) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.tasks,
      data: request.toJson(),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '创建任务失败');
    }

    return Task.fromJson(response.data!);
  }

  /// 申请任务
  Future<void> applyTask(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.applyTask(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '申请任务失败');
    }
  }

  /// 取消申请
  Future<void> cancelApplication(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelApplication(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '取消申请失败');
    }
  }

  /// 接受申请人
  Future<void> acceptApplicant(int taskId, int applicantId) async {
    final response = await _apiService.post(
      ApiEndpoints.acceptApplicant(taskId, applicantId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '接受申请人失败');
    }
  }

  /// 完成任务
  Future<void> completeTask(int taskId, {String? evidence}) async {
    final response = await _apiService.post(
      ApiEndpoints.completeTask(taskId),
      data: {
        if (evidence != null) 'completion_evidence': evidence,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '完成任务失败');
    }
  }

  /// 确认完成
  Future<void> confirmCompletion(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.confirmCompletion(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '确认完成失败');
    }
  }

  /// 取消任务
  Future<void> cancelTask(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelTask(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '取消任务失败');
    }
  }

  /// 评价任务
  Future<void> reviewTask(
    int taskId, {
    required int rating,
    String? comment,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.reviewTask(taskId),
      data: {
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '评价失败');
    }
  }

  /// 获取我的任务（接取的）
  Future<TaskListResponse> getMyTasks({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myTasks,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (status != null) 'status': status,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取我的任务失败');
    }

    return TaskListResponse.fromJson(response.data!);
  }

  /// 获取我发布的任务
  Future<TaskListResponse> getMyPostedTasks({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myPostedTasks,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (status != null) 'status': status,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取已发布任务失败');
    }

    return TaskListResponse.fromJson(response.data!);
  }
}

/// 任务异常
class TaskException implements Exception {
  TaskException(this.message);

  final String message;

  @override
  String toString() => 'TaskException: $message';
}
