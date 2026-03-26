import 'package:dio/dio.dart';

import '../models/version_check_response.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/logger.dart';

class VersionCheckRepository {
  VersionCheckRepository({required ApiService apiService})
      : _apiService = apiService;

  final ApiService _apiService;

  /// 检查 App 版本，失败时返回 null（不阻塞用户）
  Future<VersionCheckResponse?> checkVersion({
    required String platform,
    required String currentVersion,
  }) async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.versionCheck,
        queryParameters: {
          'platform': platform,
          'current_version': currentVersion,
        },
        options: Options(extra: {'skipAuth': true}),
      );
      if (response.isSuccess && response.data != null) {
        return VersionCheckResponse.fromJson(response.data!);
      }
      return null;
    } catch (e) {
      AppLogger.error('Version check failed', e);
      return null;
    }
  }
}
