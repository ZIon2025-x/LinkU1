import '../models/banner.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/translation_cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 通用仓库
/// 与iOS + 后端路由对齐
class CommonRepository {
  CommonRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 获取轮播图/横幅
  Future<List<Banner>> getBanners() async {
    const cacheKey = '${CacheManager.prefixBanners}all';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final banners = cached['banners'] as List<dynamic>? ?? [];
      return banners
          .map((e) => Banner.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.banners,
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取横幅失败');
    }

    // Banner 变动少，使用静态TTL（1小时）
    await _cache.set(cacheKey, response.data!, ttl: CacheManager.staticTTL);

    final banners = response.data!['banners'] as List<dynamic>? ?? [];
    return banners
        .map((e) => Banner.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 获取FAQ列表
  Future<List<Map<String, dynamic>>> getFAQ({String lang = 'zh'}) async {
    final cacheKey = '${CacheManager.prefixCommon}faq_$lang';

    final cached = _cache.get<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached.map((e) => e as Map<String, dynamic>).toList();
    }

    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.faq(lang: lang),
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取FAQ失败');
    }

    // FAQ 内容稳定，使用静态TTL
    await _cache.set(cacheKey, response.data!, ttl: CacheManager.staticTTL);

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取法律文档
  Future<Map<String, dynamic>> getLegalDocument({
    required String type,
    String lang = 'zh',
  }) async {
    final cacheKey = '${CacheManager.prefixCommon}legal_${type}_$lang';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return cached;

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.legalDocument(type: type, lang: lang),
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取法律文档失败');
    }

    // 法律文档极少更新，使用静态TTL
    await _cache.set(cacheKey, response.data!, ttl: CacheManager.staticTTL);

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

  /// 翻译文本（带缓存，参考iOS TranslationCacheManager）
  Future<Map<String, dynamic>> translate({
    required String text,
    required String targetLang,
    String? sourceLang,
  }) async {
    // 检查翻译缓存
    final cachedTranslation =
        TranslationCacheManager.shared.getCachedTranslation(
      text: text,
      targetLang: targetLang,
      sourceLang: sourceLang ?? 'auto',
    );
    if (cachedTranslation != null) {
      return {'translated_text': cachedTranslation, 'cached': true};
    }

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

    // 缓存翻译结果
    final translatedText =
        response.data!['translated_text'] as String? ?? '';
    if (translatedText.isNotEmpty) {
      await TranslationCacheManager.shared.saveTranslation(
        text: text,
        translatedText: translatedText,
        targetLang: targetLang,
        sourceLang: sourceLang ?? 'auto',
      );
    }

    return response.data!;
  }

  /// 批量翻译（带缓存）
  Future<Map<String, dynamic>> translateBatch({
    required List<String> texts,
    required String targetLang,
    String? sourceLang,
  }) async {
    // 分离已缓存和未缓存的文本
    final uncachedTexts = <String>[];
    final cachedResults = <int, String>{};

    for (int i = 0; i < texts.length; i++) {
      final cached = TranslationCacheManager.shared.getCachedTranslation(
        text: texts[i],
        targetLang: targetLang,
        sourceLang: sourceLang ?? 'auto',
      );
      if (cached != null) {
        cachedResults[i] = cached;
      } else {
        uncachedTexts.add(texts[i]);
      }
    }

    // 全部命中缓存
    if (uncachedTexts.isEmpty) {
      final results = List.generate(
          texts.length, (i) => cachedResults[i] ?? texts[i]);
      return {'translations': results, 'cached': true};
    }

    // 请求未缓存的部分
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.translateBatch,
      data: {
        'texts': uncachedTexts,
        'target_lang': targetLang,
        if (sourceLang != null) 'source_lang': sourceLang,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '批量翻译失败');
    }

    // 缓存新翻译结果
    final newTranslations =
        response.data!['translations'] as List<dynamic>? ?? [];
    if (newTranslations.length == uncachedTexts.length) {
      await TranslationCacheManager.shared.saveTranslationBatch(
        texts: uncachedTexts,
        translatedTexts: newTranslations.map((e) => e.toString()).toList(),
        targetLang: targetLang,
        sourceLang: sourceLang ?? 'auto',
      );
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

  /// 获取私有图片URL
  Future<String> getPrivateImage(String imageId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.privateImage(imageId),
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取私有图片失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  /// 获取私有文件URL
  Future<String> getPrivateFile(String fileId) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.privateFile,
      queryParameters: {'file_id': fileId},
    );

    if (!response.isSuccess || response.data == null) {
      throw CommonException(response.message ?? '获取私有文件失败');
    }

    return response.data!['url'] as String? ?? '';
  }
}

/// 通用异常
class CommonException extends AppException {
  const CommonException(super.message);
}
