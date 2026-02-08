import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/flea_market.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 跳蚤市场仓库
/// 与iOS FleaMarketViewModel + 后端 flea_market_routes 对齐
class FleaMarketRepository {
  FleaMarketRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;
  final CacheManager _cache = CacheManager.shared;

  /// 获取跳蚤市场商品列表
  Future<FleaMarketListResponse> getItems({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? keyword,
    String? sortBy,
  }) async {
    final params = {
      'page': page,
      'page_size': pageSize,
      if (category != null) 'category': category,
      if (keyword != null) 'keyword': keyword,
      if (sortBy != null) 'sort_by': sortBy,
    };

    final cacheKey = keyword == null
        ? CacheManager.buildKey(CacheManager.prefixFleaMarket, params)
        : null;

    if (cacheKey != null) {
      final cached = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return FleaMarketListResponse.fromJson(cached);
      }
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.fleaMarketItems,
        queryParameters: params,
      );

      if (!response.isSuccess || response.data == null) {
        throw FleaMarketException(response.message ?? '获取商品列表失败');
      }

      if (cacheKey != null) {
        await _cache.set(cacheKey, response.data!, ttl: CacheManager.shortTTL);
      }

      return FleaMarketListResponse.fromJson(response.data!);
    } catch (e) {
      if (cacheKey != null) {
        final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
        if (stale != null) return FleaMarketListResponse.fromJson(stale);
      }
      rethrow;
    }
  }

  /// 获取商品分类
  Future<List<Map<String, dynamic>>> getCategories() async {
    const cacheKey = '${CacheManager.prefixFleaMarketCategories}all';

    final cached = _cache.get<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached.map((e) => e as Map<String, dynamic>).toList();
    }

    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.fleaMarketCategories,
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取分类失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.staticTTL);

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取商品详情
  Future<FleaMarketItem> getItemById(String id) async {
    final cacheKey = '${CacheManager.prefixFleaMarketDetail}$id';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return FleaMarketItem.fromJson(cached);

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.fleaMarketItemById(id),
      );

      if (!response.isSuccess || response.data == null) {
        throw FleaMarketException(response.message ?? '获取商品详情失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.defaultTTL);
      return FleaMarketItem.fromJson(response.data!);
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) return FleaMarketItem.fromJson(stale);
      rethrow;
    }
  }

  /// 发布商品
  Future<FleaMarketItem> createItem(CreateFleaMarketRequest request) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketItems,
      data: request.toJson(),
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '发布商品失败');
    }

    // 创建后失效列表缓存
    await _cache.invalidateFleaMarketCache();
    await _cache.invalidateMyFleaMarketCache();

    return FleaMarketItem.fromJson(response.data!);
  }

  /// 直接购买商品
  Future<Map<String, dynamic>> directPurchase(String id) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketDirectPurchase(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '购买失败');
    }

    return response.data!;
  }

  /// 发送购买请求（议价）
  Future<Map<String, dynamic>> sendPurchaseRequest(
    String id, {
    double? proposedPrice,
    String? message,
  }) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketPurchaseRequest(id),
      data: {
        if (proposedPrice != null) 'proposed_price': proposedPrice,
        if (message != null) 'message': message,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '发送购买请求失败');
    }

    return response.data!;
  }

  /// 收藏/取消收藏商品
  Future<void> toggleFavorite(String id) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketItemFavorite(id),
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '操作失败');
    }
  }

  /// 刷新商品（重新上架）
  Future<void> refreshItem(String id) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketItemRefresh(id),
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '刷新失败');
    }
  }

  /// 举报商品
  Future<void> reportItem(String id, {required String reason}) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketItemReport(id),
      data: {'reason': reason},
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '举报失败');
    }
  }

  /// 获取购买历史
  Future<List<Map<String, dynamic>>> getMyPurchases({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketMyPurchases,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取购买历史失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取收藏商品列表
  Future<FleaMarketListResponse> getFavoriteItems({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketFavorites,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取收藏列表失败');
    }

    return FleaMarketListResponse.fromJson(response.data!);
  }

  /// 获取我的商品
  Future<FleaMarketListResponse> getMyItems({
    int page = 1,
    int pageSize = 20,
  }) async {
    final params = {'page': page, 'page_size': pageSize};
    final cacheKey =
        CacheManager.buildKey('${CacheManager.prefixMyFleaMarket}items_', params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return FleaMarketListResponse.fromJson(cached);
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketMyItems,
      queryParameters: params,
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取我的商品失败');
    }

    await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);

    return FleaMarketListResponse.fromJson(response.data!);
  }

  /// 获取我的购买请求
  Future<List<Map<String, dynamic>>> getMyPurchaseRequests({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketMyPurchaseRequests,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取购买请求失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取我的销售记录
  Future<List<Map<String, dynamic>>> getMySales({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketMySales,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取销售记录失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 批准购买请求（卖家操作）
  Future<Map<String, dynamic>> approvePurchaseRequest(
      String requestId) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketApprovePurchaseRequest(requestId),
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '批准请求失败');
    }

    return response.data!;
  }

  /// 上传图片
  Future<String> uploadImage(Uint8List bytes, String filename) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });

    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketUploadImage,
      data: formData,
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '上传图片失败');
    }

    return response.data!['url'] as String? ?? '';
  }

  /// 更新商品
  Future<FleaMarketItem> updateItem(
    String id, {
    String? title,
    String? description,
    double? price,
    List<String>? images,
    String? category,
  }) async {
    final data = <String, dynamic>{};
    if (title != null) data['title'] = title;
    if (description != null) data['description'] = description;
    if (price != null) data['price'] = price;
    if (images != null) data['images'] = images;
    if (category != null) data['category'] = category;

    final response = await _apiService.put<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketItemById(id),
      data: data,
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '更新商品失败');
    }

    // 失效缓存
    await _cache.remove('${CacheManager.prefixFleaMarketDetail}$id');
    await _cache.invalidateFleaMarketCache();

    return FleaMarketItem.fromJson(response.data!);
  }

  /// 删除商品
  Future<void> deleteItem(String id) async {
    final response = await _apiService.delete(
      ApiEndpoints.fleaMarketItemById(id),
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '删除商品失败');
    }

    await _cache.invalidateFleaMarketCache();
    await _cache.invalidateMyFleaMarketCache();
  }

  /// 获取商品的购买请求列表
  Future<List<Map<String, dynamic>>> getItemPurchaseRequests(String id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketItemPurchaseRequests(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取购买请求失败');
    }

    final items = response.data!['items'] as List<dynamic>? ?? [];
    return items.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 接受购买请求
  Future<void> acceptPurchase(String id) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketAcceptPurchase(id),
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '接受购买请求失败');
    }

    await _cache.invalidateFleaMarketCache();
  }

  /// 拒绝购买请求
  Future<void> rejectPurchase(String id) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketRejectPurchase(id),
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '拒绝购买请求失败');
    }

    await _cache.invalidateFleaMarketCache();
  }

  /// 发起还价
  Future<void> counterOffer(String id, {required double price, String? message}) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketCounterOffer(id),
      data: {
        'price': price,
        if (message != null) 'message': message,
      },
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '发起还价失败');
    }
  }

  /// 回应还价
  Future<void> respondCounterOffer(String id, {required bool accept, double? newPrice}) async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketRespondCounterOffer(id),
      data: {
        'accept': accept,
        if (newPrice != null) 'new_price': newPrice,
      },
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '回应还价失败');
    }

    await _cache.invalidateFleaMarketCache();
  }

  /// 同意跳蚤市场须知
  Future<void> agreeNotice() async {
    final response = await _apiService.post(
      ApiEndpoints.fleaMarketAgreeNotice,
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '操作失败');
    }
  }
}

/// 跳蚤市场异常
class FleaMarketException extends AppException {
  const FleaMarketException(super.message);
}
