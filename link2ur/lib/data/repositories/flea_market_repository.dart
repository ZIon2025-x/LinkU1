import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/constants/app_constants.dart';
import '../models/flea_market.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../../core/constants/api_endpoints.dart';
import '../../core/utils/cache_manager.dart';
import '../../core/utils/app_exception.dart';

/// 在 Isolate 中解析跳蚤市场列表 JSON
FleaMarketListResponse _parseFleaMarketListResponse(Map<String, dynamic> json) {
  return FleaMarketListResponse.fromJson(json);
}

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
    CancelToken? cancelToken,
  }) async {
    // 「全部」或空字符串时不传 category，后端不按分类筛选
    final effectiveCategory = (category != null && category.isNotEmpty && category != 'all')
        ? category
        : null;
    final params = {
      'page': page,
      'page_size': pageSize,
      if (effectiveCategory != null) 'category': effectiveCategory,
      if (keyword != null) 'keyword': keyword,
      if (sortBy != null) 'sort_by': sortBy,
    };

    final cacheKey = keyword == null
        ? CacheManager.buildKey(CacheManager.prefixFleaMarket, params)
        : null;

    if (cacheKey != null) {
      final cached = _cache.get<Map<String, dynamic>>(cacheKey);
      if (cached != null) {
        return compute(_parseFleaMarketListResponse, cached);
      }
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.fleaMarketItems,
        queryParameters: params,
        cancelToken: cancelToken,
      );

      if (!response.isSuccess || response.data == null) {
        throw FleaMarketException(response.message ?? '获取商品列表失败');
      }

      if (cacheKey != null) {
        await _cache.set(cacheKey, response.data!, ttl: CacheManager.shortTTL);
      }

      return compute(_parseFleaMarketListResponse, response.data!);
    } catch (e) {
      if (cacheKey != null) {
        final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
        if (stale != null) return compute(_parseFleaMarketListResponse, stale);
      }
      rethrow;
    }
  }

  /// 获取商品分类
  Future<List<Map<String, dynamic>>> getCategories() async {
    const cacheKey = '${CacheManager.prefixFleaMarketCategories}all';

    final cached = _cache.getWithOfflineFallback<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached.map((e) => e as Map<String, dynamic>).toList();
    }

    try {
      final response = await _apiService.get<List<dynamic>>(
        ApiEndpoints.fleaMarketCategories,
      );

      if (!response.isSuccess || response.data == null) {
        throw FleaMarketException(response.message ?? '获取分类失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.staticTTL);

      return response.data!.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      final stale = _cache.getStale<List<dynamic>>(cacheKey);
      if (stale != null) return stale.map((e) => e as Map<String, dynamic>).toList();
      rethrow;
    }
  }

  /// 获取商品详情
  Future<FleaMarketItem> getItemById(String id, {CancelToken? cancelToken}) async {
    final idTrim = id.trim();
    if (idTrim.isEmpty || idTrim == '0') {
      throw const FleaMarketException('无效的商品 ID');
    }

    final cacheKey = '${CacheManager.prefixFleaMarketDetail}$id';

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) return FleaMarketItem.fromJson(cached);

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.fleaMarketItemById(id),
        cancelToken: cancelToken,
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

    // 购买后失效缓存：
    // 1. 主列表缓存（商品已被预留，不应再出现在公开列表中）
    // 2. 我的购买/销售缓存
    // 对标 iOS CacheManager.shared.invalidateFleaMarketCache()
    await _cache.invalidateFleaMarketCache();
    await _cache.invalidateMyFleaMarketCache();

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

    // 发送请求后失效我的购买请求缓存
    await _cache.invalidateMyFleaMarketCache();

    return response.data!;
  }

  /// 收藏/取消收藏商品，返回新的收藏状态
  Future<bool> toggleFavorite(String id) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketItemFavorite(id),
    );

    if (!response.isSuccess) {
      throw FleaMarketException(response.message ?? '操作失败');
    }

    return response.data?['is_favorited'] as bool? ?? false;
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

  /// 与我相关的跳蚤市场商品（一次拉取，前端按 出售中/收的闲置/已售出 筛选）
  /// 基于任务来源=跳蚤市场+用户关联，通过任务 id 关联到商品
  Future<List<FleaMarketItem>> getMyRelatedFleaItems({bool forceRefresh = false}) async {
    const cacheKey = '${CacheManager.prefixMyFleaMarket}related';
    if (forceRefresh) await _cache.invalidateMyFleaMarketCache();
    final cached = forceRefresh ? null : _cache.get<List<dynamic>>(cacheKey);
    if (cached != null) {
      return cached
          .map((e) => FleaMarketItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketMyRelatedItems,
    );
    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取与我相关的闲置失败');
    }
    final data = response.data!;
    final rawItems = data['items'] as List<dynamic>? ?? [];
    final items = rawItems
        .map((e) => FleaMarketItem.fromJson(e as Map<String, dynamic>))
        .toList();
    await _cache.set(
      cacheKey,
      rawItems.map((e) => e as Map<String, dynamic>).toList(),
      ttl: CacheManager.personalTTL,
    );
    return items;
  }

  /// 获取购买历史（含待支付 + 已购，对齐 iOS pageSize 100 + 分页）
  Future<MyPurchasesResponse> getMyPurchases({
    int page = 1,
    int pageSize = 100,
    bool forceRefresh = false,
  }) async {
    if (forceRefresh) {
      await _cache.invalidateMyFleaMarketCache();
    }

    final cacheKey = CacheManager.buildKey(
      '${CacheManager.prefixMyFleaMarket}purchases_',
      {'p': page, 'ps': pageSize},
    );

    final cached = forceRefresh ? null : _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return MyPurchasesResponse(
        items: items.map((e) => e as Map<String, dynamic>).toList(),
        total: cached['total'] as int? ?? 0,
        hasMore: cached['hasMore'] as bool? ?? false,
      );
    }

    try {
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

      final data = response.data!;
      await _cache.set(cacheKey, data, ttl: CacheManager.personalTTL);

      final items = data['items'] as List<dynamic>? ?? [];
      return MyPurchasesResponse(
        items: items.map((e) => e as Map<String, dynamic>).toList(),
        total: data['total'] as int? ?? 0,
        hasMore: data['hasMore'] as bool? ?? data['has_more'] as bool? ?? false,
      );
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) {
        final items = stale['items'] as List<dynamic>? ?? [];
        return MyPurchasesResponse(
          items: items.map((e) => e as Map<String, dynamic>).toList(),
          total: stale['total'] as int? ?? 0,
          hasMore: stale['hasMore'] as bool? ?? false,
        );
      }
      rethrow;
    }
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

  /// 获取我的在售商品（对齐iOS loadSellingItems）
  /// 使用 GET /api/flea-market/items?seller_id={userId}&status=active
  Future<FleaMarketListResponse> getMyItems({
    int page = 1,
    int pageSize = 20,
  }) async {
    final userId = StorageService.instance.getUserId();
    if (userId == null) {
      throw const FleaMarketException('用户未登录');
    }

    final params = {
      'page': page,
      'page_size': pageSize,
      'seller_id': userId,
      'status': AppConstants.fleaMarketStatusActive,
    };
    final cacheKey =
        CacheManager.buildKey('${CacheManager.prefixMyFleaMarket}items_', params);

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return FleaMarketListResponse.fromJson(cached);
    }

    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketItems,
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
    final cacheKey = CacheManager.buildKey(
      '${CacheManager.prefixMyFleaMarket}requests_',
      {'p': page, 'ps': pageSize},
    );

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      final items = cached['items'] as List<dynamic>? ?? [];
      return items.map((e) => e as Map<String, dynamic>).toList();
    }

    try {
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

  /// 获取我的已售商品（对齐iOS loadSoldItems）
  /// 使用 GET /api/flea-market/items?seller_id={userId}&status=sold
  Future<FleaMarketListResponse> getMySales({
    int page = 1,
    int pageSize = 20,
  }) async {
    final userId = StorageService.instance.getUserId();
    if (userId == null) {
      throw const FleaMarketException('用户未登录');
    }

    final params = {
      'page': page,
      'page_size': pageSize,
      'seller_id': userId,
      'status': AppConstants.fleaMarketStatusSold,
    };
    final cacheKey = CacheManager.buildKey(
      '${CacheManager.prefixMyFleaMarket}sales_',
      params,
    );

    final cached = _cache.get<Map<String, dynamic>>(cacheKey);
    if (cached != null) {
      return FleaMarketListResponse.fromJson(cached);
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiEndpoints.fleaMarketItems,
        queryParameters: params,
      );

      if (!response.isSuccess || response.data == null) {
        throw FleaMarketException(response.message ?? '获取销售记录失败');
      }

      await _cache.set(cacheKey, response.data!, ttl: CacheManager.personalTTL);
      return FleaMarketListResponse.fromJson(response.data!);
    } catch (e) {
      final stale = _cache.getStale<Map<String, dynamic>>(cacheKey);
      if (stale != null) return FleaMarketListResponse.fromJson(stale);
      rethrow;
    }
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

  /// 上传图片（后端接口要求 multipart 字段名为 image）
  /// [itemId] 编辑时传入，图片直接存到商品目录；新建时不传，存临时目录后由创建接口 move_from_temp
  Future<String> uploadImage(
    Uint8List bytes,
    String filename, {
    String? itemId,
  }) async {
    final name = filename.trim().isNotEmpty ? filename : 'image.jpg';
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: name),
    });

    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketUploadImage,
      data: formData,
      queryParameters: itemId != null ? {'item_id': itemId} : null,
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

    final item = FleaMarketItem.fromJson(response.data!);
    // 先返回结果让 UI 立即关闭 loading，再在后台失效缓存
    Future.microtask(() async {
      await _cache.remove('${CacheManager.prefixFleaMarketDetail}$id');
      await _cache.invalidateFleaMarketCache();
    });
    return item;
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
    await _cache.invalidateMyFleaMarketCache();
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
    await _cache.invalidateMyFleaMarketCache();
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
