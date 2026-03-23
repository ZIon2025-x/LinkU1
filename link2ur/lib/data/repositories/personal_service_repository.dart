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
    return response.data;
  }

  Future<List<Map<String, dynamic>>> getMyServices() async {
    final response = await _apiService.get(ApiEndpoints.myPersonalServices);
    return List<Map<String, dynamic>>.from(response.data);
  }

  Future<void> updateService(String id, Map<String, dynamic> data) async {
    await _apiService.put(
      ApiEndpoints.myPersonalServiceById(id),
      data: data,
    );
  }

  Future<void> deleteService(String id) async {
    await _apiService.delete(ApiEndpoints.myPersonalServiceById(id));
  }

  Future<Map<String, dynamic>> browseServices({
    String type = 'all',
    String? query,
    String sort = 'recommended',
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = <String, dynamic>{
      'type': type,
      'sort': sort,
      'page': page,
      'page_size': pageSize,
    };
    if (query != null && query.isNotEmpty) params['q'] = query;

    final response = await _apiService.get(
      ApiEndpoints.browseServices,
      queryParameters: params,
    );
    return Map<String, dynamic>.from(response.data);
  }
}
