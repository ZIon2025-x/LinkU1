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
}
