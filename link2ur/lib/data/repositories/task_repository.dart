import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../models/task.dart';
import '../models/task_application.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 在 Isolate 中解析任务列表 JSON，避免大数据量时阻塞主线程
TaskListResponse _parseTaskListResponse(Map<String, dynamic> json) {
  return TaskListResponse.fromJson(json);
}

/// 任务仓库
/// 与iOS TasksViewModel/TaskDetailViewModel + 后端路由对齐
class TaskRepository {
  TaskRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 获取任务列表
  /// 对标iOS TasksViewModel.loadTasks() — 缓存优先 + 离线回退
  Future<TaskListResponse> getTasks({
    int page = 1,
    int pageSize = 20,
    String? taskType,
    String? status,
    String? keyword,
    String? sortBy,
    String? location,
    CancelToken? cancelToken,
  }) async {
    final params = {
      'page': page,
      'page_size': pageSize,
      if (taskType != null) 'task_type': taskType,
      if (status != null) 'status': status,
      if (keyword != null) 'keyword': keyword,
      if (sortBy != null) 'sort_by': sortBy,
      if (location != null) 'location': location,
    };
    final cacheKey = keyword == null
        ? CacheManager.buildKey(CacheManager.prefixTasks, params)
        : null;

    // 1. 检查未过期缓存
    if (cacheKey != null) {
      final cached = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return compute(_parseTaskListResponse, cached);
      }
    }

    // 2. 请求网络
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.tasks,
        queryParameters: params,
        cancelToken: cancelToken,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskException(response.message ?? '获取任务列表失败');
      }

      // 写入缓存
      if (cacheKey != null) {
        await _cache.set(cacheKey, response.data!, ttl: CacheManager.shortTTL);
      }

      return compute(_parseTaskListResponse, response.data!);
    } catch (e) {
      // 3. 网络失败 → 回退到过期缓存
      if (cacheKey != null) {
        final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
        if (stale != null) {
          return compute(_parseTaskListResponse, stale);
        }
      }
      rethrow;
    }
  }

  /// 获取推荐任务
  /// 对标iOS — 缓存优先 + 离线回退
  Future<TaskListResponse> getRecommendedTasks({
    int page = 1,
    int pageSize = 20,
    CancelToken? cancelToken,
  }) async {
    final params = {'page': page, 'page_size': pageSize};
    final cacheKey =
        CacheManager.buildKey(CacheManager.prefixRecommendedTasks, params);

    // 1. 检查未过期缓存
    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return compute(_parseTaskListResponse, cached);
    }

    // 2. 请求网络
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.recommendations,
        queryParameters: params,
        cancelToken: cancelToken,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskException(response.message ?? '获取推荐任务失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.shortTTL);
      return compute(_parseTaskListResponse, response.data!);
    } catch (e) {
      // 3. 网络失败 → 回退到过期缓存
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        return compute(_parseTaskListResponse, stale);
      }
      rethrow;
    }
  }

  /// 推荐反馈
  Future<void> sendRecommendationFeedback(int taskId, {
    required String action,
  }) async {
    await _apiService.post(
      ApiEndpoints.recommendationFeedback(taskId),
      data: {'action': action},
    );
  }

  /// 获取附近任务（通过 /api/tasks 加location参数）
  Future<TaskListResponse> getNearbyTasks({
    required double latitude,
    required double longitude,
    int page = 1,
    int pageSize = 20,
    double? radius,
    String? city,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.tasks,
      queryParameters: {
        'user_latitude': latitude,
        'user_longitude': longitude,
        'page': page,
        'page_size': pageSize,
        if (radius != null) 'radius': radius,
        if (city != null && city.isNotEmpty) 'location': city,
        'sort_by': 'distance',
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取附近任务失败');
    }

    return TaskListResponse.fromJson(response.data!);
  }

  /// 获取任务详情
  Future<Task> getTaskById(int id, {CancelToken? cancelToken}) async {
    final cacheKey = '${CacheManager.prefixTaskDetail}$id';

    // 1. 检查未过期缓存
    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return Task.fromJson(cached);
    }

    // 2. 请求网络
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.taskById(id),
        cancelToken: cancelToken,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskException(response.message ?? '获取任务详情失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.defaultTTL);
      return Task.fromJson(response.data!);
    } catch (e) {
      // 3. 网络失败 → 回退到过期缓存
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        return Task.fromJson(stale);
      }
      rethrow;
    }
  }

  /// 获取任务详情（别名）
  Future<Task> getTaskDetail(int id, {CancelToken? cancelToken}) =>
      getTaskById(id, cancelToken: cancelToken);

  /// 上传任务图片（创建任务前调用，返回公开 URL；使用 V2 接口以便后端迁移到 task_id 目录并更新 DB）
  Future<String> uploadTaskImage(String filePath) async {
    final response = await _apiService.uploadFile<Map<String, dynamic>>(
      '${ApiEndpoints.uploadImageV2}?category=task',
      filePath: filePath,
      fieldName: 'image',
    );
    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '上传图片失败');
    }
    final url = response.data!['url'] as String?;
    if (url == null || url.isEmpty) {
      throw const TaskException('上传成功但未返回图片地址');
    }
    return url;
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

    // 创建后失效任务列表缓存
    await _cache.invalidateTasksCache();
    await _cache.invalidateMyTasksCache();

    return Task.fromJson(response.data!);
  }

  /// 申请任务（支持留言、议价金额与货币）
  Future<void> applyTask(
    int taskId, {
    String? message,
    double? negotiatedPrice,
    String? currency,
  }) async {
    final Map<String, dynamic> data = {};
    if (message != null && message.isNotEmpty) data['message'] = message;
    if (negotiatedPrice != null) data['negotiated_price'] = negotiatedPrice;
    if (currency != null && currency.isNotEmpty) data['currency'] = currency;

    final response = await _apiService.post(
      ApiEndpoints.applyTask(taskId),
      data: data.isEmpty ? null : data,
    );

    if (!response.isSuccess) {
      if (response.statusCode == 428) {
        throw const TaskException('stripe_setup_required');
      }
      throw TaskException(response.message ?? '申请任务失败');
    }

    // 失效相关缓存
    await _cache.invalidateTaskDetailCache(taskId);
    await _cache.invalidateMyTasksCache();
    await _cache.remove('${CacheManager.prefixMyTasks}apps');
  }

  /// 获取我的所有申请（pending applications）
  /// 后端 GET /api/my-applications 返回裸数组 List[dict]，需兼容处理。
  Future<List<TaskApplication>> getMyApplications() async {
    const cacheKey = '${CacheManager.prefixMyTasks}apps';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items
          .map((e) => TaskApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    try {
      // 后端返回裸数组，使用 dynamic 接收
      final response = await _apiService.get<dynamic>(
        ApiEndpoints.myApplications,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskException(response.message ?? 'Failed to load applications');
      }

      // 兼容后端两种返回格式：裸数组 或 { items/applications: [...] }
      final List<dynamic> rawList;
      final data = response.data!;
      if (data is List) {
        rawList = data;
      } else if (data is Map) {
        rawList = (data['items'] as List<dynamic>?) ??
            (data['applications'] as List<dynamic>?) ??
            [];
      } else {
        rawList = [];
      }

      // 缓存时统一包装为 Map 格式
      final normalized = <String, dynamic>{'items': rawList};
      await _cache.set(cacheKey, normalized, ttl: CacheManager.personalTTL);

      return rawList
          .map((e) => TaskApplication.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        final items = stale['items'] as List<dynamic>? ?? [];
        return items
            .map((e) => TaskApplication.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      rethrow;
    }
  }

  /// 获取任务申请列表
  /// 后端 GET /api/tasks/{id}/applications 直接返回数组，不是 { items: [] }
  Future<List<Map<String, dynamic>>> getTaskApplications(int taskId) async {
    final response = await _apiService.get<dynamic>(
      ApiEndpoints.taskApplications(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取申请列表失败');
    }

    final data = response.data!;
    final List<dynamic> rawList = data is List<dynamic>
        ? data
        : (data is Map ? (data['items'] as List<dynamic>? ?? []) : <dynamic>[]);
    return rawList.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 接受申请。返回后端响应（含 client_secret 等），需支付时由调用方打开支付页。
  /// 对齐 iOS approveApplication → 返回 clientSecret 后显示支付界面。
  Future<Map<String, dynamic>?> acceptApplication(
      int taskId, int applicationId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.acceptApplication(taskId, applicationId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '接受申请失败');
    }
    return response.data;
  }

  /// 拒绝申请
  Future<void> rejectApplication(int taskId, int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.rejectApplication(taskId, applicationId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '拒绝申请失败');
    }
  }

  /// 撤回申请
  Future<void> withdrawApplication(int taskId, int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.withdrawApplication(taskId, applicationId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '撤回申请失败');
    }

    await _cache.remove('${CacheManager.prefixMyTasks}apps');
  }

  /// 申请议价
  Future<void> negotiateApplication(
    int taskId,
    int applicationId, {
    required double negotiatedPrice,
    String? message,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.negotiateApplication(taskId, applicationId),
      data: {
        'negotiated_price': negotiatedPrice,
        if (message != null) 'message': message,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '议价失败');
    }
  }

  /// 回复议价（接受/拒绝，需要一次性签名 token 防重放）
  Future<void> respondNegotiation(
    int taskId,
    int applicationId, {
    required String action,
    required String token,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.respondNegotiation(taskId, applicationId),
      data: {
        'action': action,
        'token': token,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '回复议价失败');
    }
  }

  /// 完成任务
  Future<void> completeTask(
    int taskId, {
    List<String>? evidenceImages,
    String? evidenceText,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.completeTask(taskId),
      data: {
        if (evidenceImages != null) 'evidence_images': evidenceImages,
        if (evidenceText != null) 'evidence_text': evidenceText,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '完成任务失败');
    }

    await _cache.invalidateTaskDetailCache(taskId);
    await _cache.invalidateMyTasksCache();
  }

  /// 确认完成
  Future<void> confirmCompletion(
    int taskId, {
    double? partialTransferAmount,
    String? partialTransferReason,
  }) async {
    final Map<String, dynamic> data = {};
    if (partialTransferAmount != null) {
      data['partial_transfer'] = {
        'transfer_amount': partialTransferAmount,
        if (partialTransferReason != null) 'reason': partialTransferReason,
      };
    }
    final response = await _apiService.post(
      ApiEndpoints.confirmCompletion(taskId),
      data: data.isNotEmpty ? data : null,
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '确认完成失败');
    }

    await _cache.invalidateTaskDetailCache(taskId);
    await _cache.invalidateMyTasksCache();
    await _cache.invalidatePaymentCache();
  }

  /// 取消任务
  Future<void> cancelTask(int taskId, {String? reason}) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelTask(taskId),
      data: {
        if (reason != null) 'reason': reason,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '取消任务失败');
    }

    await _cache.invalidateTaskDetailCache(taskId);
    await _cache.invalidateAllTasksCache();
  }

  /// 删除任务
  Future<void> deleteTask(int taskId) async {
    final response = await _apiService.delete(
      ApiEndpoints.deleteTask(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '删除任务失败');
    }

    await _cache.invalidateAllTasksCache();
  }

  /// 更新任务奖励
  Future<void> updateTaskReward(int taskId, {required double reward}) async {
    final response = await _apiService.patch(
      ApiEndpoints.updateTaskReward(taskId),
      data: {'reward': reward},
    );
    if (!response.isSuccess) {
      throw TaskException(response.message ?? '更新奖励失败');
    }
    await _cache.invalidateTaskDetailCache(taskId);
  }

  /// 更新任务可见性
  Future<void> updateTaskVisibility(int taskId,
      {required bool isPublic}) async {
    final response = await _apiService.patch(
      ApiEndpoints.updateTaskVisibility(taskId),
      data: {'is_public': isPublic},
    );
    if (!response.isSuccess) {
      throw TaskException(response.message ?? '更新可见性失败');
    }
    await _cache.invalidateTaskDetailCache(taskId);
  }

  /// 拒绝任务
  Future<void> rejectTask(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.rejectTask(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '拒绝任务失败');
    }
  }

  /// 评价任务
  Future<void> reviewTask(int taskId, CreateReviewRequest review) async {
    final response = await _apiService.post(
      ApiEndpoints.reviewTask(taskId),
      data: review.toJson(),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '评价失败');
    }
  }

  /// 获取任务评价列表
  Future<List<Map<String, dynamic>>> getTaskReviews(int taskId) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.taskReviews(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取评价失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 接受任务
  Future<void> acceptTask(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.acceptTask(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '接受任务失败');
    }
  }

  /// 审批任务
  Future<void> approveTask(int taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.approveTask(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '审批任务失败');
    }
  }

  /// 获取任务匹配分数
  Future<Map<String, dynamic>> getTaskMatchScore(int taskId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskMatchScore(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取匹配分数失败');
    }

    return response.data!;
  }

  /// 获取任务历史记录
  Future<List<Map<String, dynamic>>> getTaskHistory(int taskId) async {
    final cacheKey = '${CacheManager.prefixTaskDetail}${taskId}_history';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.taskHistory(taskId),
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskException(response.message ?? '获取任务历史失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

      final items = response.data!['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        final items = stale['items'] as List<dynamic>? ?? [];
        return items.map((e) => e as Map<String, dynamic>).toList();
      }
      rethrow;
    }
  }

  /// 发起争议
  Future<Map<String, dynamic>> disputeTask(
    int taskId, {
    required String reason,
    List<String>? evidence,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.disputeTask(taskId),
      data: {
        'reason': reason,
        if (evidence != null) 'evidence': evidence,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '发起争议失败');
    }

    return response.data!;
  }

  // ==================== 退款/争议 ====================

  /// 发起退款请求（对齐后端 RefundRequestCreate schema）
  Future<Map<String, dynamic>> requestRefund(
    int taskId, {
    required String reasonType,
    required String reason,
    required String refundType,
    List<String>? evidenceFiles,
    double? refundAmount,
    double? refundPercentage,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.refundRequest(taskId),
      data: {
        'reason_type': reasonType,
        'reason': reason,
        'refund_type': refundType,
        if (evidenceFiles != null) 'evidence_files': evidenceFiles,
        if (refundAmount != null) 'refund_amount': refundAmount,
        if (refundPercentage != null) 'refund_percentage': refundPercentage,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '退款请求失败');
    }

    return response.data!;
  }

  /// 获取退款状态
  Future<Map<String, dynamic>> getRefundStatus(int taskId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.refundStatus(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取退款状态失败');
    }

    return response.data!;
  }

  /// 获取退款历史
  Future<List<Map<String, dynamic>>> getRefundHistory(int taskId) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.refundHistory(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取退款历史失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 取消退款请求
  Future<void> cancelRefundRequest(int taskId, int refundId) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelRefundRequest(taskId, refundId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '取消退款请求失败');
    }
  }

  /// 提交退款反驳（对齐后端 RefundRequestRebuttal schema）
  Future<void> submitRefundRebuttal(
    int taskId,
    int refundId, {
    required String content,
    List<String>? evidence,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.submitRefundRebuttal(taskId, refundId),
      data: {
        'rebuttal_text': content,
        if (evidence != null) 'evidence_files': evidence,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '提交反驳失败');
    }
  }

  /// 获取争议时间线（返回完整响应包含 task_id, task_title, timeline）
  Future<Map<String, dynamic>> getDisputeTimeline(int taskId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.disputeTimeline(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取争议时间线失败');
    }

    return response.data!;
  }

  // ==================== 多参与者 ====================

  /// 获取任务参与者
  Future<List<Map<String, dynamic>>> getTaskParticipants(
      String taskId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.taskParticipants(taskId),
    );

    if (!response.isSuccess || response.data == null) {
      throw TaskException(response.message ?? '获取参与者失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 参与者标记完成
  Future<void> participantComplete(String taskId) async {
    final response = await _apiService.post(
      ApiEndpoints.participantComplete(taskId),
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '标记完成失败');
    }
  }

  /// 参与者请求退出
  Future<void> participantExitRequest(String taskId, {String? reason}) async {
    final response = await _apiService.post(
      ApiEndpoints.participantExitRequest(taskId),
      data: {
        if (reason != null) 'reason': reason,
      },
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '退出请求失败');
    }
  }

  // ==================== 我的任务 ====================

  /// 获取我的任务（支持 role/status 筛选，后端分页）
  /// role: poster=我发布的, taker=我接取的, null=全部
  Future<TaskListResponse> getMyTasks({
    int page = 1,
    int pageSize = 20,
    String? status,
    String? role,
  }) async {
    final params = {
      'page': page,
      'page_size': pageSize,
      if (status != null) 'status': status,
      if (role != null) 'role': role,
    };
    final cacheKey = CacheManager.buildKey(CacheManager.prefixMyTasks, params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return TaskListResponse.fromJson(cached);
    }

    try {
      final response = await _apiService.get(
        ApiEndpoints.myTasks,
        queryParameters: params,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskException(response.message ?? '获取我的任务失败');
      }

      // 兼容后端返回裸数组或分页对象
      final Map<String, dynamic> normalized;
      if (response.data is List) {
        final list = response.data as List;
        normalized = {
          'tasks': list,
          'total': list.length,
          'page': page,
          'page_size': pageSize,
        };
      } else {
        normalized = response.data as Map<String, dynamic>;
      }

      await _cache.set(cacheKey, normalized, ttl: CacheManager.personalTTL);
      return TaskListResponse.fromJson(normalized);
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) return TaskListResponse.fromJson(stale);
      rethrow;
    }
  }

  /// 取消自己的申请（需要 applicationId）
  /// BLoC 应在获取申请列表后传入 applicationId 调用 withdrawApplication
  Future<void> cancelApplication(int taskId,
      {required int applicationId}) async {
    return withdrawApplication(taskId, applicationId);
  }

  /// 接受申请人（便捷方法，applicantId 即 applicationId）
  Future<void> acceptApplicant(int taskId, int applicantId) async {
    await acceptApplication(taskId, applicantId);
  }

  /// 获取我发布的任务（通过tasks接口加filter）
  /// 兼容后端两种返回格式（裸数组 / 分页对象）
  Future<TaskListResponse> getMyPostedTasks({
    int page = 1,
    int pageSize = 20,
    String? status,
  }) async {
    final params = {
      'page': page,
      'page_size': pageSize,
      'role': 'poster',
      if (status != null) 'status': status,
    };
    final cacheKey = CacheManager.buildKey(
      '${CacheManager.prefixMyTasks}posted_',
      params,
    );

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return TaskListResponse.fromJson(cached);
    }

    try {
      final response = await _apiService.get(
        ApiEndpoints.myTasks,
        queryParameters: params,
      );

      if (!response.isSuccess || response.data == null) {
        throw TaskException(response.message ?? '获取已发布任务失败');
      }

      // 兼容后端返回裸数组或分页对象
      final Map<String, dynamic> normalized;
      if (response.data is List) {
        final list = response.data as List;
        normalized = {
          'tasks': list,
          'total': list.length,
          'page': page,
          'page_size': pageSize,
        };
      } else {
        normalized = response.data as Map<String, dynamic>;
      }

      await _cache.set(cacheKey, normalized, ttl: CacheManager.personalTTL);
      return TaskListResponse.fromJson(normalized);
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) return TaskListResponse.fromJson(stale);
      rethrow;
    }
  }

  /// 发送申请消息
  Future<void> sendApplicationMessage(int taskId, int applicationId, {required String content}) async {
    final response = await _apiService.post(
      ApiEndpoints.sendApplicationMessage(taskId, applicationId),
      data: {'content': content},
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '发送消息失败');
    }
  }

  /// 回复申请消息
  Future<void> replyApplicationMessage(int taskId, int applicationId, {required String content}) async {
    final response = await _apiService.post(
      ApiEndpoints.replyApplicationMessage(taskId, applicationId),
      data: {'content': content},
    );

    if (!response.isSuccess) {
      throw TaskException(response.message ?? '回复消息失败');
    }
  }
}

/// 任务异常
class TaskException extends AppException {
  const TaskException(super.message);
}
