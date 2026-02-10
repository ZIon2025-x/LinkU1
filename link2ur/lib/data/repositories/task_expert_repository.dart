import '../models/task_expert.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 任务达人仓库
/// 与iOS TaskExpertViewModel + 后端 task_expert_routes 对齐
class TaskExpertRepository {
  TaskExpertRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 获取任务达人列表
  Future<TaskExpertListResponse> getExperts({
    int page = 1,
    int pageSize = 50,
    String? keyword,
    bool forceRefresh = false,
  }) async {
    // 后端使用 limit/offset 分页，不支持 keyword（task_expert_routes.py）
    final offset = (page - 1) * pageSize;
    final params = {
      'limit': pageSize,
      'offset': offset,
    };

    final cacheKey =
        CacheManager.buildKey(CacheManager.prefixTaskExperts, params);

    // 无搜索且非强制刷新时使用缓存（达人列表变动少，使用长TTL）
    if (keyword == null && !forceRefresh) {
      final cached = _cache.get<dynamic>(cacheKey);
      if (cached != null) {
        if (cached is List) {
          // 跳过缓存的空列表（可能是暂时性问题导致的空数据）
          if (cached.isNotEmpty) {
            return TaskExpertListResponse.fromList(cached,
                page: page, pageSize: pageSize);
          }
        } else if (cached is Map<String, dynamic>) {
          return TaskExpertListResponse.fromJson(cached);
        }
      }
    }

    // 后端返回原始数组（List），非分页对象
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.taskExperts,
      queryParameters: params,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人列表失败');
    }

    if (keyword == null) {
      await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);
    }

    // 处理后端返回的数组或对象
    if (response.data is List) {
      return TaskExpertListResponse.fromList(response.data as List<dynamic>,
          page: page, pageSize: pageSize);
    }
    return TaskExpertListResponse.fromJson(
        response.data as Map<String, dynamic>);
  }

  /// 获取达人详情
  Future<TaskExpert> getExpertById(String id) async {
    final cacheKey = '${CacheManager.prefixExpertDetail}$id';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return TaskExpert.fromJson(cached);
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人详情失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

    return TaskExpert.fromJson(response.data!);
  }

  /// 获取达人服务列表
  Future<List<TaskExpertService>> getExpertServices(String expertId) async {
    final cacheKey = '${CacheManager.prefixExpertDetail}${expertId}_services';

    final cached = _cache.get<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached
          .map((e) => TaskExpertService.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.taskExpertServices(expertId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人服务失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

    return response.data!
        .map(
            (e) => TaskExpertService.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取服务详情（原始 Map 格式）
  Future<Map<String, dynamic>> getServiceDetail(int serviceId,
      {bool forceRefresh = false}) async {
    final cacheKey = '${CacheManager.prefixExpertDetail}service_$serviceId';

    if (!forceRefresh) {
      final cached = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertServiceDetail(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取服务详情失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

    return response.data!;
  }

  /// 获取服务详情（解析为 TaskExpertService 模型）
  Future<TaskExpertService> getServiceDetailParsed(int serviceId,
      {bool forceRefresh = false}) async {
    final raw = await getServiceDetail(serviceId, forceRefresh: forceRefresh);
    return TaskExpertService.fromJson(raw);
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
  /// 对标iOS ServiceDetailView.applyService
  Future<Map<String, dynamic>> applyService(
    int serviceId, {
    String? message,
    double? counterPrice,
    int? timeSlotId,
    String? preferredDeadline,
    bool isFlexibleTime = false,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.applyForService(serviceId),
      data: {
        if (message != null && message.isNotEmpty) 'message': message,
        if (counterPrice != null) 'counter_price': counterPrice,
        if (timeSlotId != null) 'time_slot_id': timeSlotId,
        if (preferredDeadline != null) 'preferred_deadline': preferredDeadline,
        'is_flexible_time': isFlexibleTime,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '申请服务失败');
    }

    // 清除相关缓存以便刷新服务详情
    _cache.removeByPrefix('${CacheManager.prefixExpertDetail}service_$serviceId');

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

  /// 获取达人评价列表
  Future<List<Map<String, dynamic>>> getExpertReviews(String expertId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertReviews(expertId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人评价失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取我的达人申请状态
  Future<Map<String, dynamic>?> getMyExpertApplication() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myExpertApplication,
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.message ?? '获取申请状态失败');
    }

    return response.data;
  }

  /// 获取我的达人资料
  Future<Map<String, dynamic>?> getMyExpertProfile() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myExpertProfile,
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.message ?? '获取达人资料失败');
    }

    return response.data;
  }

  /// 获取我的达人服务列表
  Future<List<Map<String, dynamic>>> getMyExpertServices() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myExpertServices,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取服务列表失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取我的达人申请记录（别人申请我的服务）
  Future<List<Map<String, dynamic>>> getMyExpertApplications({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myExpertApplications,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取申请记录失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取达人仪表盘统计
  Future<Map<String, dynamic>> getMyExpertDashboardStats() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myExpertDashboardStats,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取统计数据失败');
    }

    return response.data!;
  }

  /// 获取达人日程
  Future<Map<String, dynamic>> getMyExpertSchedule() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myExpertSchedule,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取日程失败');
    }

    return response.data!;
  }

  /// 获取达人休息日
  Future<List<String>> getMyExpertClosedDates() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myExpertClosedDates,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取休息日失败');
    }

    final dates = response.data!['dates'] as List<dynamic>? ?? [];
    return dates.map((e) => e.toString()).toList();
  }

  /// 获取服务时间段
  Future<List<Map<String, dynamic>>> getServiceTimeSlots(int serviceId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.serviceTimeSlots(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取时间段失败');
    }

    final items = response.data!['time_slots'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取我的服务时间段（达人管理）
  Future<List<Map<String, dynamic>>> getMyServiceTimeSlots(int serviceId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myServiceTimeSlots(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取时间段失败');
    }

    final items = response.data!['time_slots'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 请求更新达人资料
  Future<void> requestExpertProfileUpdate(Map<String, dynamic> data) async {
    final response = await _apiService.post(
      ApiEndpoints.myExpertProfileUpdateRequest,
      data: data,
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.message ?? '提交资料更新请求失败');
    }
  }

  /// 回应服务还价
  Future<void> respondServiceCounterOffer(int applicationId, {required bool accept}) async {
    final response = await _apiService.post(
      ApiEndpoints.respondServiceCounterOffer(applicationId),
      data: {'accept': accept},
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.message ?? '回应还价失败');
    }
  }

  /// 取消服务申请
  Future<void> cancelServiceApplication(int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelServiceApplication(applicationId),
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.message ?? '取消申请失败');
    }
  }
}

/// 任务达人异常
class TaskExpertException extends AppException {
  const TaskExpertException(super.message);
}
