import 'package:dio/dio.dart';

import '../models/trending_search.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

class TrendingSearchRepository {
  TrendingSearchRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  Future<TrendingSearchResponse> getTrendingSearches() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.trendingSearches,
      options: Options(extra: {'skipAuth': true}),
    );
    return TrendingSearchResponse.fromJson(response.data!);
  }

  /// 记录搜索行为（fire-and-forget，失败不影响搜索）
  Future<void> logSearch(String query) async {
    try {
      await _apiService.post(
        ApiEndpoints.trendingLogSearch,
        data: {'query': query},
      );
    } catch (_) {
      // 静默失败
    }
  }
}
