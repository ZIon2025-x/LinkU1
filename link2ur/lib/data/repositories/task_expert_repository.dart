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
    String? sort, // 'rating_desc', 'completed_desc', 'newest'
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
      if (keyword != null && keyword.trim().isNotEmpty) 'keyword': keyword.trim(),
      if (sort != null) 'sort': sort,
    };

    final cacheKey =
        CacheManager.buildKey(CacheManager.prefixTaskExperts, params);

    // 无搜索且非强制刷新时使用缓存（达人列表变动少，使用长TTL）
    if (keyword == null && !forceRefresh) {
      final cached = _cache.get<dynamic>(cacheKey);
      if (cached != null) {
        if (cached is List) {
          return TaskExpertListResponse.fromList(cached,
              page: page, pageSize: pageSize);
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取达人列表失败', errorCode: response.errorCode);
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
  Future<TaskExpert> getExpertById(String id, {CancelToken? cancelToken, bool forceRefresh = false}) async {
    final cacheKey = '${CacheManager.prefixExpertDetail}$id';

    if (!forceRefresh) {
      final cached = _cache.getWithOfflineFallback<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return TaskExpert.fromJson(cached);
      }
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.taskExpertById(id),
        cancelToken: cancelToken,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskExpertException(response.errorCode ?? response.message ?? '获取达人详情失败', errorCode: response.errorCode);
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
        throw TaskExpertException(response.errorCode ?? response.message ?? '获取达人服务失败', errorCode: response.errorCode);
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
        throw TaskExpertException(response.errorCode ?? response.message ?? '获取服务详情失败', errorCode: response.errorCode);
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
  Future<Map<String, dynamic>> getServiceReviews(
    int serviceId, {
    int limit = 20,
    int offset = 0,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertServiceReviews(serviceId),
      queryParameters: {'limit': limit, 'offset': offset},
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取评价失败', errorCode: response.errorCode);
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '申请服务失败', errorCode: response.errorCode);
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '申请成为达人失败', errorCode: response.errorCode);
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取服务申请失败', errorCode: response.errorCode);
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取达人评价失败', errorCode: response.errorCode);
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取申请状态失败', errorCode: response.errorCode);
    }

    return response.data;
  }

  /// 获取达人资料
  Future<Map<String, dynamic>?> getExpertProfile(String expertId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertById(expertId),
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取达人资料失败', errorCode: response.errorCode);
    }

    return response.data;
  }

  /// 获取达人申请记录（别人申请该达人的服务）
  /// 后端用 limit/offset 分页，返回 List（非 {items: [...]}）
  Future<List<Map<String, dynamic>>> getExpertApplications(
    String expertId, {
    int page = 1,
    int pageSize = 20,
    String? statusFilter,
  }) async {
    final offset = (page - 1) * pageSize;
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.expertApplicationsList(expertId),
      queryParameters: {
        'limit': pageSize,
        'offset': offset,
        if (statusFilter != null) 'status': statusFilter,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取申请记录失败', errorCode: response.errorCode);
    }

    // 后端直接返回数组
    if (response.data is List) {
      return (response.data as List<dynamic>)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    // 兼容可能的包装格式
    if (response.data is Map<String, dynamic>) {
      final items = (response.data as Map<String, dynamic>)['items']
              as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    }
    return [];
  }

  /// 获取达人仪表盘统计
  Future<Map<String, dynamic>> getExpertStats(String expertId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.expertDashboardStats(expertId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取统计数据失败', errorCode: response.errorCode);
    }

    return response.data!;
  }

  /// 获取达人管理的服务列表
  /// 后端返回: { "expert_id": ..., "expert_name": ..., "services": [...] } 或 直接数组
  Future<List<Map<String, dynamic>>> getExpertManagedServices(String expertId) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.taskExpertServices(expertId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取服务列表失败', errorCode: response.errorCode);
    }

    final List<dynamic> items;
    if (response.data is Map<String, dynamic>) {
      items = (response.data as Map<String, dynamic>)['services'] as List<dynamic>? ?? [];
    } else if (response.data is List) {
      items = response.data as List<dynamic>;
    } else {
      items = [];
    }
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 创建服务
  Future<Map<String, dynamic>> createService(String expertId, Map<String, dynamic> data) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskExpertServices(expertId),
      data: data,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(
        response.errorCode ?? response.message ?? '创建服务失败',
        errorCode: response.errorCode,
      );
    }

    return response.data!;
  }

  /// 更新服务
  Future<Map<String, dynamic>> updateService(String expertId, int serviceId, Map<String, dynamic> data) async {
    final response = await _apiService.put<Map<String, dynamic>>(
      ApiEndpoints.expertServiceById(expertId, serviceId),
      data: data,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(
        response.errorCode ?? response.message ?? '更新服务失败',
        errorCode: response.errorCode,
      );
    }

    return response.data!;
  }

  /// 上架/下架服务
  Future<Map<String, dynamic>> toggleServiceStatus(
      String expertId, int serviceId) async {
    final response = await _apiService.patch(
      ApiEndpoints.expertServiceToggleStatus(expertId, serviceId),
    );

    if (!response.isSuccess) {
      throw TaskExpertException(
        response.errorCode ?? response.message ?? '操作失败',
        errorCode: response.errorCode,
      );
    }
    return response.data as Map<String, dynamic>? ?? {};
  }

  /// 获取团队任务列表（我参与的）
  Future<List<Map<String, dynamic>>> getMyTasks(String expertId) async {
    final response = await _apiService.get(
      ApiEndpoints.expertMyTasks(expertId),
    );
    if (!response.isSuccess) {
      throw TaskExpertException(
        response.errorCode ?? response.message ?? '加载任务失败',
        errorCode: response.errorCode,
      );
    }
    final data = response.data;
    if (data is Map<String, dynamic>) {
      final items = data['items'];
      if (items is List) {
        return items.cast<Map<String, dynamic>>();
      }
    }
    return [];
  }

  /// 删除服务
  Future<void> deleteService(String expertId, int serviceId) async {
    final response = await _apiService.delete(
      ApiEndpoints.expertServiceById(expertId, serviceId),
    );

    if (!response.isSuccess) {
      throw TaskExpertException(
        response.errorCode ?? response.message ?? '删除服务失败',
        errorCode: response.errorCode,
      );
    }
  }

  /// 获取达人服务时间段
  /// 后端返回 ISO 格式 slot_start_datetime/slot_end_datetime；
  /// 本方法拆分为 UI 期望的 slot_date/start_time/end_time/is_expired 字段。
  Future<List<Map<String, dynamic>>> getExpertServiceTimeSlots(String expertId, int serviceId) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.expertServiceTimeSlots(expertId, serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取时间段失败', errorCode: response.errorCode);
    }

    final List<dynamic> items;
    if (response.data is List) {
      items = response.data as List<dynamic>;
    } else if (response.data is Map<String, dynamic>) {
      items = (response.data as Map<String, dynamic>)['time_slots']
              as List<dynamic>? ??
          [];
    } else {
      items = [];
    }
    return items
        .map((e) => _enrichTimeSlot(e as Map<String, dynamic>))
        .toList();
  }

  /// 将后端 ISO datetime 格式的时间段转换为 UI 期望的分离字段格式。
  Map<String, dynamic> _enrichTimeSlot(Map<String, dynamic> slot) {
    final enriched = Map<String, dynamic>.from(slot);

    // 已有 slot_date 则跳过（向后兼容）
    if (enriched['slot_date'] == null) {
      final startIso = enriched['slot_start_datetime'] as String?;
      final endIso = enriched['slot_end_datetime'] as String?;

      if (startIso != null) {
        final start = DateTime.tryParse(startIso)?.toLocal();
        if (start != null) {
          enriched['slot_date'] =
              '${start.year.toString().padLeft(4, '0')}-'
              '${start.month.toString().padLeft(2, '0')}-'
              '${start.day.toString().padLeft(2, '0')}';
          enriched['start_time'] =
              '${start.hour.toString().padLeft(2, '0')}:'
              '${start.minute.toString().padLeft(2, '0')}:00';
          // 过期判断：结束时间早于当前时间
          final end = endIso != null ? DateTime.tryParse(endIso)?.toLocal() : null;
          enriched['is_expired'] =
              (end ?? start).isBefore(DateTime.now());
        }
      }
      if (endIso != null) {
        final end = DateTime.tryParse(endIso)?.toLocal();
        if (end != null) {
          enriched['end_time'] =
              '${end.hour.toString().padLeft(2, '0')}:'
              '${end.minute.toString().padLeft(2, '0')}:00';
        }
      }
    }

    return enriched;
  }

  /// 将 UI 格式（slot_date + start_time + end_time）转换为后端 ISO datetime 格式。
  Map<String, dynamic> _timeSlotToBackendFormat(Map<String, dynamic> data) {
    // 如果已经是 ISO 格式，直接使用
    if (data.containsKey('slot_start_datetime') &&
        data.containsKey('slot_end_datetime')) {
      return data;
    }

    final slotDate = data['slot_date'] as String?;
    final startTime = data['start_time'] as String?;
    final endTime = data['end_time'] as String?;

    if (slotDate == null || startTime == null || endTime == null) {
      // 不足以转换，原样返回让后端报错
      return data;
    }

    // 本地时间 -> UTC ISO
    final startLocal = DateTime.parse('${slotDate}T$startTime');
    final endLocal = DateTime.parse('${slotDate}T$endTime');

    return <String, dynamic>{
      'slot_start_datetime': startLocal.toUtc().toIso8601String(),
      'slot_end_datetime': endLocal.toUtc().toIso8601String(),
      if (data['price_per_participant'] != null)
        'price_per_participant': data['price_per_participant'],
      if (data['max_participants'] != null)
        'max_participants': data['max_participants'],
    };
  }

  /// 创建服务时间段
  ///
  /// [force] 为 true 时跳过后端营业时间校验，直接创建（用户已在确认框中选择"仍然创建"）。
  Future<Map<String, dynamic>> createServiceTimeSlot(
    String expertId,
    int serviceId,
    Map<String, dynamic> data, {
    bool force = false,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.expertServiceTimeSlots(expertId, serviceId),
      data: _timeSlotToBackendFormat(data),
      queryParameters: force ? {'force': 'true'} : null,
    );

    if (!response.isSuccess || response.data == null) {
      // 把营业时间软警告原样抛给上层，让 BLoC/UI 决定是否二次确认
      if (response.errorCode == 'outside_business_hours') {
        throw const TaskExpertException(
          'outside_business_hours',
          errorCode: 'outside_business_hours',
        );
      }
      throw TaskExpertException(response.errorCode ?? response.message ?? '创建时间段失败', errorCode: response.errorCode);
    }

    return response.data!;
  }

  /// 删除服务时间段
  Future<void> deleteServiceTimeSlot(String expertId, int serviceId, int slotId) async {
    final response = await _apiService.delete(
      ApiEndpoints.expertServiceTimeSlotById(expertId, serviceId, slotId),
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '删除时间段失败', errorCode: response.errorCode);
    }
  }

  /// 获取达人每周营业时间
  /// 从达人详情接口 (GET /api/experts/{id}) 读取 business_hours 字段
  /// 返回: {"mon": {"open": "09:00", "close": "18:00"}, "sun": null, ...} 或 {}(未设置)
  Future<Map<String, dynamic>> getBusinessHours(String expertId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskExpertById(expertId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取营业时间失败', errorCode: response.errorCode);
    }

    final bh = response.data!['business_hours'];
    if (bh is Map<String, dynamic>) return bh;
    if (bh is Map) return Map<String, dynamic>.from(bh);
    return <String, dynamic>{};
  }

  /// 更新达人每周营业时间 (Owner/Admin)
  /// hours: {"mon": {"open": "09:00", "close": "18:00"}, "sun": null, ...}
  /// 传空 Map 表示清空
  Future<void> updateBusinessHours(String expertId, Map<String, dynamic> hours) async {
    final response = await _apiService.put(
      ApiEndpoints.expertTeamBusinessHours(expertId),
      data: hours,
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '更新营业时间失败', errorCode: response.errorCode);
    }
  }

  /// 获取达人休息日列表
  /// 后端返回: 直接数组 List[ExpertClosedDateOut]
  Future<List<Map<String, dynamic>>> getClosedDates(String expertId) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.expertClosedDates(expertId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取休息日失败', errorCode: response.errorCode);
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 创建休息日
  Future<Map<String, dynamic>> createClosedDate(String expertId, String date, {String? reason}) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.expertClosedDates(expertId),
      data: {
        'closed_date': date,
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '创建休息日失败', errorCode: response.errorCode);
    }

    return response.data!;
  }

  /// 删除休息日
  Future<void> deleteClosedDate(String expertId, int closedDateId) async {
    final response = await _apiService.delete(
      ApiEndpoints.expertClosedDateById(expertId, closedDateId),
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '删除休息日失败', errorCode: response.errorCode);
    }
  }

  /// 获取服务时间段（公开）
  /// 后端实际返回: 直接数组 List[ServiceTimeSlotOut]
  Future<List<Map<String, dynamic>>> getServiceTimeSlots(int serviceId) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.serviceTimeSlots(serviceId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '获取时间段失败', errorCode: response.errorCode);
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

  /// 服务主同意申请（个人服务用）
  Future<Map<String, dynamic>> ownerApproveApplication(int applicationId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.ownerApproveApplication(applicationId),
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '同意申请失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 达人同意申请（创建任务+支付）
  Future<Map<String, dynamic>> approveServiceApplication(int applicationId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.approveServiceApplication(applicationId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '同意申请失败', errorCode: response.errorCode);
    }

    return response.data!;
  }

  /// 申请方在 price_agreed 下确认订单并进入付款（团队咨询 + 个人服务统一路径）
  Future<Map<String, dynamic>> payAndFinalizeApplication(
    int applicationId, {
    String? deadline,
    bool? isFlexible,
  }) async {
    final body = <String, dynamic>{};
    if (deadline != null) body['deadline'] = deadline;
    if (isFlexible != null) body['is_flexible'] = isFlexible;

    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.payAndFinalize(applicationId),
      data: body,
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(
        response.errorCode ?? response.message ?? '创建订单失败',
        errorCode: response.errorCode,
      );
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '拒绝申请失败', errorCode: response.errorCode);
    }
  }

  /// 达人再次议价
  Future<Map<String, dynamic>> counterOfferServiceApplication(
    int applicationId, {
    required double counterPrice,
    String? message,
    int? serviceId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.counterOfferServiceApplication(applicationId),
      data: {
        'price': counterPrice,
        if (message != null && message.isNotEmpty) 'message': message,
        if (serviceId != null) 'service_id': serviceId,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '议价失败', errorCode: response.errorCode);
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
      throw TaskExpertException(response.errorCode ?? response.message ?? '回应还价失败', errorCode: response.errorCode);
    }
  }

  /// 创建咨询申请
  Future<Map<String, dynamic>> createConsultation(int serviceId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.consultService(serviceId),
      data: {},
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '创建咨询失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 用户发起议价
  Future<Map<String, dynamic>> negotiatePrice(
    int applicationId, {
    required double proposedPrice,
    int? serviceId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.negotiateConsultation(applicationId),
      data: {
        'price': proposedPrice,
        if (serviceId != null) 'service_id': serviceId,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '议价失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 达人报价
  Future<Map<String, dynamic>> quotePrice(
    int applicationId, {
    required double quotedPrice,
    String? message,
    int? serviceId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.quoteApplication(applicationId),
      data: {
        'price': quotedPrice,
        if (message != null && message.isNotEmpty) 'message': message,
        if (serviceId != null) 'service_id': serviceId,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '报价失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 回应议价/报价
  Future<Map<String, dynamic>> respondToNegotiation(
    int applicationId, {
    required String action,
    double? counterPrice,
    int? serviceId,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.negotiateResponse(applicationId),
      data: {
        'action': action,
        if (counterPrice != null) 'price': counterPrice,
        if (serviceId != null) 'service_id': serviceId,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '操作失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 咨询转正式申请
  Future<Map<String, dynamic>> formalApply(
    int applicationId, {
    double? proposedPrice,
    String? message,
    int? timeSlotId,
    String? deadline,
    int isFlexible = 0,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.formalApply(applicationId),
      data: {
        if (proposedPrice != null) 'proposed_price': proposedPrice,
        if (message != null && message.isNotEmpty) 'message': message,
        if (timeSlotId != null) 'time_slot_id': timeSlotId,
        if (deadline != null) 'deadline': deadline,
        'is_flexible': isFlexible,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '提交申请失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 关闭咨询
  Future<void> closeConsultation(int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.closeConsultation(applicationId),
    );
    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '关闭咨询失败', errorCode: response.errorCode);
    }
  }

  // ==================== Task consultation methods ====================

  /// 创建任务咨询
  Future<Map<String, dynamic>> createTaskConsultation(int taskId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.consultTask(taskId),
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '创建咨询失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 任务咨询议价
  Future<Map<String, dynamic>> negotiateTaskConsultation(
    int taskId,
    int applicationId, {
    required double proposedPrice,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskConsultNegotiate(taskId, applicationId),
      data: {'proposed_price': proposedPrice},
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '议价失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 任务咨询报价
  Future<Map<String, dynamic>> quoteTaskConsultation(
    int taskId,
    int applicationId, {
    required double quotedPrice,
    String? message,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskConsultQuote(taskId, applicationId),
      data: {
        'quoted_price': quotedPrice,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '报价失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 回应任务咨询议价
  Future<Map<String, dynamic>> respondTaskNegotiation(
    int taskId,
    int applicationId, {
    required String action,
    double? counterPrice,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskConsultRespond(taskId, applicationId),
      data: {
        'action': action,
        if (counterPrice != null) 'counter_price': counterPrice,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '操作失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 任务咨询转正式申请
  Future<Map<String, dynamic>> formalApplyTaskConsultation(
    int taskId,
    int applicationId, {
    double? proposedPrice,
    String? message,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskConsultFormalApply(taskId, applicationId),
      data: {
        if (proposedPrice != null) 'proposed_price': proposedPrice,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '提交申请失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 发布者在咨询中直接"批准并支付"(合并 formal-apply + approve,返回 Stripe 支付信息)
  Future<Map<String, dynamic>> approveTaskConsultation(
    int taskId,
    int applicationId,
  ) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.taskConsultApprove(taskId, applicationId),
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(
        response.errorCode ?? response.message ?? '咨询批准失败',
        errorCode: response.errorCode,
      );
    }
    return response.data!;
  }

  /// 关闭任务咨询
  Future<void> closeTaskConsultation(int taskId, int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.taskConsultClose(taskId, applicationId),
    );
    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '关闭咨询失败', errorCode: response.errorCode);
    }
  }

  // ==================== Flea market consultation methods ====================

  /// 创建跳蚤市场咨询
  Future<Map<String, dynamic>> createFleaMarketConsultation(String itemId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.consultFleaMarketItem(itemId),
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '创建咨询失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 跳蚤市场咨询议价
  Future<Map<String, dynamic>> negotiateFleaMarketConsultation(
    int requestId, {
    required double proposedPrice,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketConsultNegotiate(requestId),
      data: {'proposed_price': proposedPrice},
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '议价失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 跳蚤市场咨询报价
  Future<Map<String, dynamic>> quoteFleaMarketConsultation(
    int requestId, {
    required double quotedPrice,
    String? message,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketConsultQuote(requestId),
      data: {
        'quoted_price': quotedPrice,
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '报价失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 回应跳蚤市场咨询议价
  Future<Map<String, dynamic>> respondFleaMarketNegotiation(
    int requestId, {
    required String action,
    double? counterPrice,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketConsultRespond(requestId),
      data: {
        'action': action,
        if (counterPrice != null) 'counter_price': counterPrice,
      },
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '操作失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 跳蚤市场咨询转正式购买
  Future<Map<String, dynamic>> formalBuyFleaMarket(int requestId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketConsultFormalBuy(requestId),
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '购买失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 卖家批准跳蚤市场购买请求
  Future<Map<String, dynamic>> approveFleaMarketPurchase(int requestId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketApprovePurchaseRequest(requestId.toString()),
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '审批失败', errorCode: response.errorCode);
    }
    return response.data!;
  }

  /// 关闭跳蚤市场咨询
  Future<void> closeFleaMarketConsultation(int requestId) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketConsultClose(requestId),
    );
    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '关闭咨询失败', errorCode: response.errorCode);
    }
  }

  /// 取消服务申请
  Future<void> cancelServiceApplication(int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelServiceApplication(applicationId),
    );

    if (!response.isSuccess) {
      throw TaskExpertException(response.errorCode ?? response.message ?? '取消申请失败', errorCode: response.errorCode);
    }
  }

  /// 获取服务的公开申请列表
  Future<List<Map<String, dynamic>>> getServiceApplications(
    int serviceId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _apiService.get(
      ApiEndpoints.serviceApplications(serviceId),
      queryParameters: {'limit': limit, 'offset': offset},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'load_service_applications_failed');
    }
    final data = response.data;
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  /// 服务所有者回复申请
  Future<Map<String, dynamic>> replyServiceApplication(
    int serviceId,
    int applicationId,
    String message,
  ) async {
    final response = await _apiService.post(
      ApiEndpoints.replyServiceApplication(serviceId, applicationId),
      data: {'message': message},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'reply_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }
}

/// 任务达人异常
///
/// [errorCode] 对应后端 `error_code` 响应字段,与 BLoC state.errorCode / l10n
/// 路径对齐。内部委托给父类 [AppException.code],同时暴露 [errorCode] getter
/// 作为语义名。
class TaskExpertException extends AppException {
  const TaskExpertException(super.message, {String? errorCode})
      : super(code: errorCode);

  /// Semantic alias for [code] — matches backend `error_code` field name.
  String? get errorCode => code;
}
