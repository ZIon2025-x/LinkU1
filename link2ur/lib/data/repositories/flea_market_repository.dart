import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/flea_market.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 跳蚤市场仓库
/// 与iOS FleaMarketViewModel + 后端 flea_market_routes 对齐
class FleaMarketRepository {
  FleaMarketRepository({
    required ApiService apiService,
  }) : _apiService = apiService;

  final ApiService _apiService;

  /// 获取跳蚤市场商品列表
  Future<FleaMarketListResponse> getItems({
    int page = 1,
    int pageSize = 20,
    String? category,
    String? keyword,
    String? sortBy,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketItems,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
        if (category != null) 'category': category,
        if (keyword != null) 'keyword': keyword,
        if (sortBy != null) 'sort_by': sortBy,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取商品列表失败');
    }

    return FleaMarketListResponse.fromJson(response.data!);
  }

  /// 获取商品分类
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _apiService.get<List<dynamic>>(
      ApiEndpoints.fleaMarketCategories,
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取分类失败');
    }

    return response.data!.map((e) => e as Map<String, dynamic>).toList();
  }

  /// 获取商品详情
  Future<FleaMarketItem> getItemById(String id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketItemById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取商品详情失败');
    }

    return FleaMarketItem.fromJson(response.data!);
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
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketMyItems,
      queryParameters: {
        'page': page,
        'page_size': pageSize,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取我的商品失败');
    }

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
  }
}

/// 跳蚤市场异常
class FleaMarketException implements Exception {
  FleaMarketException(this.message);

  final String message;

  @override
  String toString() => 'FleaMarketException: $message';
}
