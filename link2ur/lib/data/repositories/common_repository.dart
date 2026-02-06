import '../models/banner.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 通用仓库
/// 横幅、FAQ、法律文档等
class CommonRepository {
  CommonRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取轮播图/横幅
  Future<List<Banner>> getBanners() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.banners,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取横幅失败');
    }

    final banners = response.data!['banners'] as List<dynamic>? ?? [];
    return banners
        .map((e) => Banner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取FAQ列表
  Future<List<Map<String, dynamic>>> getFAQ() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.faq,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取FAQ失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取法律文档
  Future<Map<String, dynamic>> getLegalDocuments() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.legalDocuments,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取法律文档失败');
    }

    return response.data!;
  }

  /// 获取应用版本
  Future<Map<String, dynamic>> getAppVersion() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.appVersion,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取应用版本失败');
    }

    return response.data!;
  }

  /// 获取客服信息
  Future<Map<String, dynamic>> getCustomerServiceInfo() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.customerServiceInfo,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取客服信息失败');
    }

    return response.data!;
  }
}

/// 通用异常
class CommonException implements Exception {
  CommonException(this.message);

  final String message;

  @override
  String toString() => 'CommonException: $message';
}
