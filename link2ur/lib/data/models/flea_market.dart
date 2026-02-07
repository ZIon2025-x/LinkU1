import 'package:equatable/equatable.dart';

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
    this.status = 'active',
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
  bool get isActive => status == 'active';

  /// 是否已售出
  bool get isSold => status == 'sold';

  /// 价格显示
  String get priceDisplay => '£${price.toStringAsFixed(2)}';

  /// 是否有待支付
  bool get hasPendingPayment => pendingPaymentClientSecret != null;

  factory FleaMarketItem.fromJson(Map<String, dynamic> json) {
    return FleaMarketItem(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      price: (json['price'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'GBP',
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      location: json['location'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      category: json['category'] as String?,
      status: json['status'] as String? ?? 'active',
      sellerId: json['seller_id']?.toString() ?? '',
      sellerUserLevel: json['seller_user_level'] as String?,
      viewCount: json['view_count'] as int? ?? 0,
      favoriteCount: json['favorite_count'] as int? ?? 0,
      refreshedAt: json['refreshed_at'] != null
          ? DateTime.parse(json['refreshed_at'])
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
      daysUntilAutoDelist: json['days_until_auto_delist'] as int?,
      pendingPaymentTaskId: json['pending_payment_task_id'] as int?,
      pendingPaymentClientSecret:
          json['pending_payment_client_secret'] as String?,
      pendingPaymentAmount: json['pending_payment_amount'] as int?,
      pendingPaymentAmountDisplay:
          json['pending_payment_amount_display'] as String?,
      pendingPaymentCurrency: json['pending_payment_currency'] as String?,
      pendingPaymentCustomerId:
          json['pending_payment_customer_id'] as String?,
      pendingPaymentEphemeralKeySecret:
          json['pending_payment_ephemeral_key_secret'] as String?,
      pendingPaymentExpiresAt:
          json['pending_payment_expires_at'] as String?,
      isAvailable: json['is_available'] as bool?,
      userPurchaseRequestStatus:
          json['user_purchase_request_status'] as String?,
      userPurchaseRequestProposedPrice:
          (json['user_purchase_request_proposed_price'] as num?)?.toDouble(),
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
    return FleaMarketListResponse(
      items: (json['items'] as List<dynamic>?)
              ?.map(
                  (e) => FleaMarketItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['page_size'] as int? ?? 20,
    );
  }
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
      if (description != null) 'description': description,
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
