import 'package:equatable/equatable.dart';
import '../../core/constants/app_constants.dart';

/// 跳蚤市场商品模型
/// 参考后端 FleaMarketItemResponse
class FleaMarketItem extends Equatable {
  const FleaMarketItem({
    required this.id,
    required this.title,
    this.description,
    required this.price,
    this.currency = 'GBP',
    this.images = const [],
    this.location,
    this.latitude,
    this.longitude,
    this.category,
    this.status = AppConstants.fleaMarketStatusActive,
    required this.sellerId,
    this.sellerUserLevel,
    this.viewCount = 0,
    this.favoriteCount = 0,
    this.refreshedAt,
    this.createdAt,
    this.updatedAt,
    this.daysUntilAutoDelist,
    this.pendingPaymentTaskId,
    this.pendingPaymentClientSecret,
    this.pendingPaymentAmount,
    this.pendingPaymentAmountDisplay,
    this.pendingPaymentCurrency,
    this.pendingPaymentCustomerId,
    this.pendingPaymentEphemeralKeySecret,
    this.pendingPaymentExpiresAt,
    this.isAvailable,
    this.userPurchaseRequestStatus,
    this.userPurchaseRequestProposedPrice,
  });

  final String id;
  final String title;
  final String? description;
  final double price;
  final String currency;
  final List<String> images;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? category;
  final String status; // active, sold, deleted
  final String sellerId;
  final String? sellerUserLevel; // normal, vip, super
  final int viewCount;
  final int favoriteCount;
  final DateTime? refreshedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final int? daysUntilAutoDelist;

  // 待支付信息
  final int? pendingPaymentTaskId;
  final String? pendingPaymentClientSecret;
  final int? pendingPaymentAmount; // 单位：便士
  final String? pendingPaymentAmountDisplay;
  final String? pendingPaymentCurrency;
  final String? pendingPaymentCustomerId;
  final String? pendingPaymentEphemeralKeySecret;
  final String? pendingPaymentExpiresAt;
  final bool? isAvailable;
  final String? userPurchaseRequestStatus; // pending, seller_negotiating
  final double? userPurchaseRequestProposedPrice;

  /// 第一张图片
  String? get firstImage => images.isNotEmpty ? images.first : null;

  /// 是否有图片
  bool get hasImages => images.isNotEmpty;

  /// 是否在售
  bool get isActive => status == AppConstants.fleaMarketStatusActive;

  /// 是否已售出
  bool get isSold => status == AppConstants.fleaMarketStatusSold;

  /// 价格显示
  String get priceDisplay => '£${price.toStringAsFixed(2)}';

  /// 是否有待支付
  bool get hasPendingPayment => pendingPaymentClientSecret != null;

  static List<String> _parseImages(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.map((e) => e?.toString()).whereType<String>().where((s) => s.isNotEmpty).toList();
    }
    if (value is String && value.isNotEmpty) return [value];
    return [];
  }

  factory FleaMarketItem.fromJson(Map<String, dynamic> json) {
    final imagesRaw = json['images'] ?? json['image_urls'];
    final images = imagesRaw != null
        ? FleaMarketItem._parseImages(imagesRaw)
        : (json['image_url'] != null && json['image_url'] is String
            ? [json['image_url'] as String]
            : <String>[]);
    return FleaMarketItem(
      id: json['id']?.toString() ?? '',
      title: _toStringNullable(json['title']) ?? '',
      description: _toStringNullable(json['description']),
      price: _toDouble(json['price']),
      currency: _toStringNullable(json['currency']) ?? 'GBP',
      images: images,
      location: _toStringNullable(json['location']),
      latitude: _toDoubleNullable(json['latitude']),
      longitude: _toDoubleNullable(json['longitude']),
      category: _toStringNullable(json['category']),
      status: _toStringNullable(json['status']) ??
          AppConstants.fleaMarketStatusActive,
      sellerId: json['seller_id']?.toString() ?? '',
      sellerUserLevel: _toStringNullable(json['seller_user_level']),
      viewCount: _toInt(json['view_count']),
      favoriteCount: _toInt(json['favorite_count']),
      refreshedAt: _toDateTimeNullable(json['refreshed_at']),
      createdAt: _toDateTimeNullable(json['created_at']),
      updatedAt: _toDateTimeNullable(json['updated_at']),
      daysUntilAutoDelist: _toIntNullable(json['days_until_auto_delist']),
      pendingPaymentTaskId: _toIntNullable(json['pending_payment_task_id']),
      pendingPaymentClientSecret:
          _toStringNullable(json['pending_payment_client_secret']),
      pendingPaymentAmount: _toIntNullable(json['pending_payment_amount']),
      pendingPaymentAmountDisplay:
          _toStringNullable(json['pending_payment_amount_display']),
      pendingPaymentCurrency: _toStringNullable(json['pending_payment_currency']),
      pendingPaymentCustomerId:
          _toStringNullable(json['pending_payment_customer_id']),
      pendingPaymentEphemeralKeySecret:
          _toStringNullable(json['pending_payment_ephemeral_key_secret']),
      pendingPaymentExpiresAt:
          _toStringNullable(json['pending_payment_expires_at']),
      isAvailable: _toBoolNullable(json['is_available']),
      userPurchaseRequestStatus:
          _toStringNullable(json['user_purchase_request_status']),
      userPurchaseRequestProposedPrice:
          _toDoubleNullable(json['user_purchase_request_proposed_price']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'currency': currency,
      'images': images,
      'location': location,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'status': status,
      'seller_id': sellerId,
      'seller_user_level': sellerUserLevel,
      'view_count': viewCount,
      'favorite_count': favoriteCount,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  FleaMarketItem copyWith({
    String? id,
    String? title,
    String? description,
    double? price,
    String? currency,
    List<String>? images,
    String? location,
    double? latitude,
    double? longitude,
    String? category,
    String? status,
    String? sellerId,
    String? sellerUserLevel,
    int? viewCount,
    int? favoriteCount,
    DateTime? refreshedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? daysUntilAutoDelist,
    int? pendingPaymentTaskId,
    String? pendingPaymentClientSecret,
    int? pendingPaymentAmount,
    String? pendingPaymentAmountDisplay,
    String? pendingPaymentCurrency,
    String? pendingPaymentCustomerId,
    String? pendingPaymentEphemeralKeySecret,
    String? pendingPaymentExpiresAt,
    bool? isAvailable,
    String? userPurchaseRequestStatus,
    double? userPurchaseRequestProposedPrice,
  }) {
    return FleaMarketItem(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      currency: currency ?? this.currency,
      images: images ?? this.images,
      location: location ?? this.location,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      category: category ?? this.category,
      status: status ?? this.status,
      sellerId: sellerId ?? this.sellerId,
      sellerUserLevel: sellerUserLevel ?? this.sellerUserLevel,
      viewCount: viewCount ?? this.viewCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      refreshedAt: refreshedAt ?? this.refreshedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      daysUntilAutoDelist: daysUntilAutoDelist ?? this.daysUntilAutoDelist,
      pendingPaymentTaskId: pendingPaymentTaskId ?? this.pendingPaymentTaskId,
      pendingPaymentClientSecret: pendingPaymentClientSecret ?? this.pendingPaymentClientSecret,
      pendingPaymentAmount: pendingPaymentAmount ?? this.pendingPaymentAmount,
      pendingPaymentAmountDisplay: pendingPaymentAmountDisplay ?? this.pendingPaymentAmountDisplay,
      pendingPaymentCurrency: pendingPaymentCurrency ?? this.pendingPaymentCurrency,
      pendingPaymentCustomerId: pendingPaymentCustomerId ?? this.pendingPaymentCustomerId,
      pendingPaymentEphemeralKeySecret: pendingPaymentEphemeralKeySecret ?? this.pendingPaymentEphemeralKeySecret,
      pendingPaymentExpiresAt: pendingPaymentExpiresAt ?? this.pendingPaymentExpiresAt,
      isAvailable: isAvailable ?? this.isAvailable,
      userPurchaseRequestStatus: userPurchaseRequestStatus ?? this.userPurchaseRequestStatus,
      userPurchaseRequestProposedPrice: userPurchaseRequestProposedPrice ?? this.userPurchaseRequestProposedPrice,
    );
  }

  @override
  List<Object?> get props => [id, title, status, price, updatedAt];
}

/// 我的购买列表响应（含待支付 + 已购）
class MyPurchasesResponse {
  const MyPurchasesResponse({
    required this.items,
    required this.total,
    required this.hasMore,
  });

  final List<Map<String, dynamic>> items;
  final int total;
  final bool hasMore;
}

/// 跳蚤市场列表响应
class FleaMarketListResponse {
  const FleaMarketListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  final List<FleaMarketItem> items;
  final int total;
  final int page;
  final int pageSize;

  bool get hasMore => items.length >= pageSize;

  factory FleaMarketListResponse.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List<dynamic>? ?? [];
    final parsedItems = <FleaMarketItem>[];
    for (final raw in rawItems) {
      if (raw is! Map) continue;
      try {
        parsedItems.add(FleaMarketItem.fromJson(Map<String, dynamic>.from(raw)));
      } catch (_) {
        // 单条脏数据不应导致整个列表失败
      }
    }

    return FleaMarketListResponse(
      items: parsedItems,
      total: _toInt(json['total']),
      page: json['page'] != null ? _toInt(json['page']) : 1,
      // 后端 Pydantic 可能返回 pageSize 或 page_size
      pageSize: json['page_size'] != null
          ? _toInt(json['page_size'])
          : json['pageSize'] != null
              ? _toInt(json['pageSize'])
              : 20,
    );
  }
}

/// 购买申请模型
/// 参考后端 PurchaseRequestResponse
class PurchaseRequest extends Equatable {
  const PurchaseRequest({
    required this.id,
    required this.buyerId,
    this.buyerName,
    this.buyerAvatar,
    this.proposedPrice,
    this.message,
    this.status = 'pending',
    this.sellerCounterPrice,
    this.createdAt,
  });

  final String id;
  final String buyerId;
  final String? buyerName;
  final String? buyerAvatar;
  final double? proposedPrice;
  final String? message;
  final String status; // pending, seller_negotiating, accepted, rejected
  final double? sellerCounterPrice;
  final DateTime? createdAt;

  factory PurchaseRequest.fromJson(Map<String, dynamic> json) {
    return PurchaseRequest(
      id: json['id']?.toString() ?? '',
      buyerId: json['buyer_id']?.toString() ?? '',
      buyerName: json['buyer_name'] as String? ??
          json['buyer']?['name'] as String?,
      buyerAvatar: json['buyer_avatar'] as String? ??
          json['buyer']?['avatar'] as String?,
      proposedPrice: _toDoubleNullable(json['proposed_price']),
      message: json['message'] as String?,
      status: json['status'] as String? ?? 'pending',
      sellerCounterPrice: _toDoubleNullable(json['seller_counter_price']),
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [id, status, sellerCounterPrice];
}

/// 创建跳蚤市场商品请求
class CreateFleaMarketRequest {
  const CreateFleaMarketRequest({
    required this.title,
    this.description,
    required this.price,
    this.currency = 'GBP',
    this.images = const [],
    this.location,
    this.latitude,
    this.longitude,
    this.category,
  });

  final String title;
  final String? description;
  final double price;
  final String currency;
  final List<String> images;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? category;

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description ?? '',
      'price': price,
      'currency': currency,
      'images': images,
      if (location != null) 'location': location,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (category != null) 'category': category,
    };
  }
}

/// 安全地将 JSON 值转为 int（兼容 String/num/null）
int _toInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}

/// 安全地将 JSON 值转为 int?（兼容 String/num/null）
int? _toIntNullable(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

/// 安全地将 JSON 值转为 double（兼容 String/num/null）
double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.trim().replaceAll(',', '');
    return double.tryParse(normalized) ?? 0;
  }
  return 0;
}

/// 安全地将 JSON 值转为 double?（兼容 String/num/null）
double? _toDoubleNullable(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  if (value is String) {
    final normalized = value.trim().replaceAll(',', '');
    return double.tryParse(normalized);
  }
  return null;
}

/// 安全地将 JSON 值转为 String?（兼容 num/bool/String/null）
String? _toStringNullable(dynamic value) {
  if (value == null) return null;
  final s = value.toString();
  return s.isEmpty ? null : s;
}

/// 安全地将 JSON 值转为 bool?（兼容 bool/num/String/null）
bool? _toBoolNullable(dynamic value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1') return true;
    if (normalized == 'false' || normalized == '0') return false;
  }
  return null;
}

/// 安全地将 JSON 值转为 DateTime?（兼容 String/DateTime/null）
DateTime? _toDateTimeNullable(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String && value.trim().isNotEmpty) {
    return DateTime.tryParse(value.trim());
  }
  return null;
}
