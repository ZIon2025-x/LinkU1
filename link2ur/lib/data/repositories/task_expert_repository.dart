import 'package:dio/dio.dart';

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
    String? category,
    String? location,
    bool forceRefresh = false,
    CancelToken? cancelToken,
  }) async {
    // 后端使用 limit/offset 分页（task_expert_routes.py），支持 keyword 搜索
    final offset = (page - 1) * pageSize;
    final params = {
      'limit': pageSize,
      'offset': offset,
      if (category != null) 'category': category,
      if (location != null) 'location': location,
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword!.trim(),
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
      cancelToken: cancelToken,
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
  Future<TaskExpert> getExpertById(String id, {CancelToken? cancelToken}) async {
    final cacheKey = '${CacheManager.prefixExpertDetail}$id';

    final cached = _cache.getWithOfflineFallback<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return TaskExpert.fromJson(cached);
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.taskExpertById(id),
        cancelToken: cancelToken,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskExpertException(response.message ?? '获取达人详情失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

      return TaskExpert.fromJson(response.data!);
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) return TaskExpert.fromJson(stale);
      rethrow;
    }
  }

  /// 获取达人服务列表
  /// 后端实际返回: { "expert_id": ..., "expert_name": ..., "services": [...] }
  Future<List<TaskExpertService>> getExpertServices(String expertId) async {
    final cacheKey = '${CacheManager.prefixExpertDetail}${expertId}_services';

    final cached = _cache.getWithOfflineFallback<dynamic>(cacheKey);
    if (cached != null) {
      final List<dynamic> items;
      if (cached is Map<String, dynamic>) {
        items = cached['services'] as List<dynamic>? ?? [];
      } else if (cached is List) {
        items = cached;
      } else {
        items = [];
      }
      if (items.isNotEmpty) {
        return items
            .map(
                (e) => TaskExpertService.fromJson(e as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      final response = await _apiService.get<dynamic>(
        ApiEndpoints.taskExpertServices(expertId),
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskExpertException(response.message ?? '获取达人服务失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

      // 后端返回 {expert_id, expert_name, services: [...]}
      final List<dynamic> serviceItems;
      if (response.data is Map<String, dynamic>) {
        serviceItems =
            (response.data as Map<String, dynamic>)['services'] as List<dynamic>? ?? [];
      } else if (response.data is List) {
        serviceItems = response.data as List<dynamic>;
      } else {
        serviceItems = [];
      }

      return serviceItems
          .map(
              (e) => TaskExpertService.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final stale = _cache.getStale<dynamic>(cacheKey);
      if (stale != null) {
        final List<dynamic> items;
        if (stale is Map<String, dynamic>) {
          items = stale['services'] as List<dynamic>? ?? [];
        } else if (stale is List) {
          items = stale;
        } else {
          items = [];
        }
        if (items.isNotEmpty) {
          return items
              .map((e) => TaskExpertService.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      }
      rethrow;
    }
  }

  /// 获取服务详情（原始 Map 格式）
  Future<Map<String, dynamic>> getServiceDetail(int serviceId,
      {bool forceRefresh = false}) async {
    final cacheKey = '${CacheManager.prefixExpertDetail}service_$serviceId';

    if (!forceRefresh) {
      final cached = _cache.getWithOfflineFallback<Map<String, dynamic>>(cacheKey);
      if (cached != null) return cached;
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.taskExpertServiceDetail(serviceId),
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskExpertException(response.message ?? '获取服务详情失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.longTTL);

      return response.data!;
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) return stale;
      rethrow;
    }
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
  /// 对标 iOS ServiceDetailView.applyService + 后端 ServiceApplicationCreate
  /// 字段：application_message, negotiated_price, deadline, is_flexible(0/1), time_slot_id
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
        if (message != null && message.isNotEmpty)
          'application_message': message,
        if (counterPrice != null) 'negotiated_price': counterPrice,
        if (timeSlotId != null) 'time_slot_id': timeSlotId,
        if (preferredDeadline != null) 'deadline': preferredDeadline,
        'is_flexible': isFlexibleTime ? 1 : 0,
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

  /// 获取达人评价列表（支持分页）
  Future<Map<String, dynamic>> getExpertReviews(
    String expertId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertReviews(expertId),
      queryParameters: {'limit': limit, 'offset': offset},
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取达人评价失败');
    }

    final data = response.data!;
    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => e as Map<String, dynamic>)
        .toList();
    return {
      'items': items,
      'total': data['total'] ?? items.length,
    };
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
  /// 后端实际返回: 直接数组 List[ServiceTimeSlotOut]
  Future<List<Map<String, dynamic>>> getServiceTimeSlots(int serviceId) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.serviceTimeSlots(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取时间段失败');
    }

    // 后端直接返回数组，不是 {time_slots: [...]}
    final List<dynamic> items;
    if (response.data is List) {
      items = response.data as List<dynamic>;
    } else if (response.data is Map<String, dynamic>) {
      // 兼容可能的包装格式
      items = (response.data as Map<String, dynamic>)['time_slots']
              as List<dynamic>? ??
          [];
    } else {
      items = [];
    }
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取我的服务时间段（达人管理）
  /// 后端实际返回: 直接数组 List[ServiceTimeSlotOut]
  Future<List<Map<String, dynamic>>> getMyServiceTimeSlots(int serviceId) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.myServiceTimeSlots(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '获取时间段失败');
    }

    // 后端直接返回数组，不是 {time_slots: [...]}
    final List<dynamic> items;
    if (response.data is List) {
      items = response.data as List<dynamic>;
    } else if (response.data is Map<String, dynamic>) {
      // 兼容可能的包装格式
      items = (response.data as Map<String, dynamic>)['time_slots']
              as List<dynamic>? ??
          [];
    } else {
      items = [];
    }
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

  /// 达人同意申请（创建任务+支付）
  Future<Map<String, dynamic>> approveServiceApplication(int applicationId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.approveServiceApplication(applicationId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '同意申请失败');
    }

    return response.data!;
  }

  /// 达人拒绝申请
  Future<void> rejectServiceApplication(int applicationId, {String? reason}) async {
    final response = await _apiService.post(
      ApiEndpoints.rejectServiceApplication(applicationId),
      data: {
        if (reason != null && reason.isNotEmpty) 'reject_reason': reason,
      },
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.message ?? '拒绝申请失败');
    }
  }

  /// 达人再次议价
  Future<Map<String, dynamic>> counterOfferServiceApplication(
    int applicationId, {
    required double counterPrice,
    String? message,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.counterOfferServiceApplication(applicationId),
      data: {
        'counter_price': counterPrice,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.message ?? '议价失败');
    }

    return response.data!;
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
