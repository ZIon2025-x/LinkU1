import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class PersonalServiceRepository {
  PersonalServiceRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  Future<Map<String, dynamic>> createService(Map<String, dynamic> data) async {
    final response = await _apiService.post(
      ApiEndpoints.myPersonalServices,
      data: data,
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'create_service_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<List<Map<String, dynamic>>> getMyServices() async {
    final response = await _apiService.get(ApiEndpoints.myPersonalServices);
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'load_services_failed');
    }
    final data = response.data;
    if (data is List) {
      return List<Map<String, dynamic>>.from(data);
    }
    return [];
  }

  Future<Map<String, dynamic>> getServiceById(String id) async {
    final response = await _apiService.get(ApiEndpoints.myPersonalServiceById(id));
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'load_service_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    final response = await _apiService.put(
      ApiEndpoints.myPersonalServiceById(id),
      data: data,
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'update_service_failed');
    }
  }

  Future<void> deleteService(String id) async {
    final response = await _apiService.delete(ApiEndpoints.myPersonalServiceById(id));
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'delete_service_failed');
    }
  }

  Future<Map<String, dynamic>> browseServices({
    String type = 'all',
    String? query,
    String sort = 'recommended',
    int page = 1,
    int pageSize = 20,
    double? lat,
    double? lng,
    int? radius,
  }) async {
    final params = <String, dynamic>{
      'type': type,
      'sort': sort,
      'page': page,
      'page_size': pageSize,
    };
    if (query != null && query.isNotEmpty) params['q'] = query;
    if (lat != null) params['lat'] = lat;
    if (lng != null) params['lng'] = lng;
    if (radius != null) params['radius'] = radius;

    final response = await _apiService.get(
      ApiEndpoints.browseServices,
      queryParameters: params,
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'browse_services_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  // ==================== 申请者的申请列表 ====================

  Future<Map<String, dynamic>> getMyServiceApplications({
    String? status,
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'page': page,
      'page_size': pageSize,
    };
    if (status != null && status.isNotEmpty) params['status'] = status;

    final response = await _apiService.get(
      ApiEndpoints.myServiceApplications,
      queryParameters: params,
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'load_applications_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> respondCounterOffer(int applicationId, {required bool accept}) async {
    final response = await _apiService.post(
      ApiEndpoints.respondServiceCounterOffer(applicationId),
      data: {'accept': accept},
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'respond_counter_offer_failed');
    }
  }

  Future<void> cancelApplication(int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.cancelServiceApplication(applicationId),
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'cancel_application_failed');
    }
  }

  // ==================== 服务状态开关 ====================

  Future<Map<String, dynamic>> toggleServiceStatus(String id) async {
    final response = await _apiService.patch(
      ApiEndpoints.personalServiceToggleStatus(id),
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'toggle_status_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  // ==================== 服务评价 ====================

  Future<Map<String, dynamic>> getServiceReviews(int serviceId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get(
      ApiEndpoints.serviceReviews(serviceId),
      queryParameters: {'page': page, 'page_size': pageSize},
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'load_reviews_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> getServiceReviewSummary(int serviceId) async {
    final response = await _apiService.get(
      ApiEndpoints.serviceReviewSummary(serviceId),
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'load_review_summary_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  // ==================== 收到的申请管理 ====================

  Future<Map<String, dynamic>> getReceivedApplications({
    String? status,
    int? serviceId,
    int limit = 20,
    int offset = 0,
  }) async {
    final params = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (status != null) params['status'] = status;
    if (serviceId != null) params['service_id'] = serviceId;

    final response = await _apiService.get(
      ApiEndpoints.myReceivedApplications,
      queryParameters: params,
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'load_applications_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<Map<String, dynamic>> approveApplication(int applicationId) async {
    final response = await _apiService.post(
      ApiEndpoints.ownerApproveApplication(applicationId),
    );
    if (!response.isSuccess || response.data == null) {
      throw Exception(response.message ?? 'approve_failed');
    }
    return Map<String, dynamic>.from(response.data);
  }

  Future<void> rejectApplication(int applicationId, {String? reason}) async {
    final response = await _apiService.post(
      ApiEndpoints.ownerRejectApplication(applicationId),
      data: {'reject_reason': reason},
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'reject_failed');
    }
  }

  Future<void> counterOffer(
    int applicationId, {
    required double counterPrice,
    String? message,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.ownerCounterOffer(applicationId),
      data: {
        'counter_price': counterPrice,
        if (message != null) 'message': message,
      },
    );
    if (!response.isSuccess) {
      throw Exception(response.message ?? 'counter_offer_failed');
    }
  }
}
