import '../models/banner.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 通用仓库
/// 与iOS + 后端路由对齐
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
  Future<List<Map<String, dynamic>>> getFAQ({String lang = 'zh'}) async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.faq(lang: lang),
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取FAQ失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取法律文档
  Future<Map<String, dynamic>> getLegalDocument({
    required String type,
    String lang = 'zh',
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.legalDocument(type: type, lang: lang),
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取法律文档失败');
    }

    return response.data!;
  }

  /// 获取隐私政策
  Future<Map<String, dynamic>> getPrivacyPolicy({String lang = 'zh'}) async {
    return getLegalDocument(type: 'privacy', lang: lang);
  }

  /// 获取用户协议
  Future<Map<String, dynamic>> getTermsOfService({String lang = 'zh'}) async {
    return getLegalDocument(type: 'terms', lang: lang);
  }

  /// 获取Cookie政策
  Future<Map<String, dynamic>> getCookiePolicy({String lang = 'zh'}) async {
    return getLegalDocument(type: 'cookie', lang: lang);
  }

  /// 健康检查
  Future<bool> healthCheck() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.healthCheck,
      );
      return response.isSuccess;
    } catch (e) {
      return false;
    }
  }

  // ==================== 客服相关 ====================

  /// 分配客服
  Future<Map<String, dynamic>> assignCustomerService() async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.customerServiceAssign,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '分配客服失败');
    }

    return response.data!;
  }

  /// 获取客服聊天列表
  Future<List<Map<String, dynamic>>> getCustomerServiceChats() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.customerServiceChats,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取客服聊天失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取客服聊天消息
  Future<List<Map<String, dynamic>>> getCustomerServiceMessages(
      String chatId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.customerServiceMessages(chatId),
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取客服消息失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 结束客服聊天
  Future<void> endCustomerServiceChat(String chatId) async {
    final response = await _apiService.post(
      ApiEndpoints.customerServiceEndChat(chatId),
    );

    if (!response.isSuccess) {
      throw CommonException(response.message ?? '结束聊天失败');
    }
  }

  /// 评价客服
  Future<void> rateCustomerService(
    String chatId, {
    required int rating,
    String? comment,
  }) async {
    final response = await _apiService.post(
      ApiEndpoints.customerServiceRate(chatId),
      data: {
        'rating': rating,
        if (comment != null) 'comment': comment,
      },
    );

    if (!response.isSuccess) {
      throw CommonException(response.message ?? '评价失败');
    }
  }

  /// 获取客服排队状态
  Future<Map<String, dynamic>> getCustomerServiceQueueStatus() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.customerServiceQueueStatus,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取排队状态失败');
    }

    return response.data!;
  }

  // ==================== 系统设置 ====================

  /// 获取公开系统设置
  Future<Map<String, dynamic>> getPublicSystemSettings() async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.systemSettingsPublic,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取系统设置失败');
    }

    return response.data!;
  }

  /// 获取职位列表
  Future<List<Map<String, dynamic>>> getJobPositions() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.jobPositions,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取职位列表失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  // ==================== 翻译 ====================

  /// 翻译文本
  Future<Map<String, dynamic>> translate({
    required String text,
    required String targetLang,
    String? sourceLang,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.translate,
      data: {
        'text': text,
        'target_lang': targetLang,
        if (sourceLang != null) 'source_lang': sourceLang,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '翻译失败');
    }

    return response.data!;
  }

  /// 批量翻译
  Future<Map<String, dynamic>> translateBatch({
    required List<String> texts,
    required String targetLang,
    String? sourceLang,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.translateBatch,
      data: {
        'texts': texts,
        'target_lang': targetLang,
        if (sourceLang != null) 'source_lang': sourceLang,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '批量翻译失败');
    }

    return response.data!;
  }

  /// 刷新图片URL
  Future<String> refreshImageUrl(String imageUrl) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.refreshImageUrl,
      data: {'url': imageUrl},
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '刷新图片URL失败');
    }

    return response.data!['url'] as String? ?? '';
  }
}

/// 通用异常
class CommonException implements Exception {
  CommonException(this.message);

  final String message;

  @override
  String toString() => 'CommonException: $message';
}
