import '../models/flea_market.dart';
import '../services/api_service.dart';
import '../../core/constants/api_endpoints.dart';

/// 跳蚤市场仓库
/// 参考iOS APIService+Endpoints.swift 跳蚤市场相关
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
      ApiEndpoints.fleaMarket,
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

  /// 获取商品详情
  Future<FleaMarketItem> getItemById(int id) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.fleaMarketById(id),
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '获取商品详情失败');
    }

    return FleaMarketItem.fromJson(response.data!);
  }

  /// 发布商品
  Future<FleaMarketItem> createItem(CreateFleaMarketRequest request) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.fleaMarket,
      data: request.toJson(),
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '发布商品失败');
    }

    return FleaMarketItem.fromJson(response.data!);
  }

  /// 购买商品
  Future<Map<String, dynamic>> purchaseItem(int id, {double? proposedPrice}) async {
    final response = await _apiService.post<Map<String, dynamic>>(
      ApiEndpoints.purchaseFleaMarket(id),
      data: {
        if (proposedPrice != null) 'proposed_price': proposedPrice,
      },
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '购买失败');
    }

    return response.data!;
  }

  /// 获取我的商品
  Future<FleaMarketListResponse> getMyItems({
    int page = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiService.get<Map<String, dynamic>>(
      ApiEndpoints.myFleaMarketItems,
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

  /// 更新商品
  Future<FleaMarketItem> updateItem(
    int id, {
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
      ApiEndpoints.fleaMarketById(id),
      data: data,
    );

    if (!response.isSuccess || response.data == null) {
      throw FleaMarketException(response.message ?? '更新商品失败');
    }

    return FleaMarketItem.fromJson(response.data!);
  }

  /// 删除商品
  Future<void> deleteItem(int id) async {
    final response = await _apiService.delete(
      ApiEndpoints.fleaMarketById(id),
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
