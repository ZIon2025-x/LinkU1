import Foundation

// 跳蚤市场分类
struct FleaMarketCategory: Codable {
    let id: String
    let name: String
    let icon: String?
}

// 跳蚤市场分类响应 - 处理 API 返回的 {success: true, data: {categories: [...]}} 结构
struct FleaMarketCategoryResponse: Decodable {
    let success: Bool
    let data: FleaMarketCategoryData
    let message: String?
    
    struct FleaMarketCategoryData: Decodable {
        let categories: [String] // API 返回的是字符串数组
    }
    
    // 计算属性：将字符串数组转换为 FleaMarketCategory 数组
    var categoryList: [FleaMarketCategory] {
        return data.categories.map { name in
            FleaMarketCategory(
                id: name, // 使用分类名称作为 ID（与后端一致）
                name: name,
                icon: nil
            )
        }
    }
}

// 跳蚤市场商品
struct FleaMarketItem: Codable, Identifiable {
    let id: String // 后端返回的是字符串，如 "S0006"
    let title: String
    let description: String?
    let price: Double
    let currency: String
    let category: String
    let images: [String]?
    let location: String? // 后端返回的字段
    let latitude: Double?  // 纬度（用于地图选点和距离计算）
    let longitude: Double?  // 经度（用于地图选点和距离计算）
    let sellerId: String
    let sellerUserLevel: String?  // 卖家会员等级：用于「会员卖家」角标
    let seller: User?
    let status: String
    let viewCount: Int
    let favoriteCount: Int // 收藏数量
    let refreshedAt: String? // 后端返回的字段
    let createdAt: String
    let updatedAt: String?
    let daysUntilAutoDelist: Int? // 距离自动下架还有多少天
    // 未付款购买信息（仅当当前用户有未付款的购买时返回）
    let pendingPaymentTaskId: Int? // 待支付任务ID
    let pendingPaymentClientSecret: String? // Stripe支付client_secret
    let pendingPaymentAmount: Int? // 支付金额（便士）
    let pendingPaymentAmountDisplay: String? // 支付金额显示
    let pendingPaymentCurrency: String? // 支付货币
    let pendingPaymentCustomerId: String? // Stripe客户ID
    let pendingPaymentEphemeralKeySecret: String? // Stripe临时密钥
    let pendingPaymentExpiresAt: String? // 支付过期时间（ISO 格式）
    // 当前用户的购买申请信息（仅当用户有待处理的议价请求时返回）
    let userPurchaseRequestStatus: String? // 购买申请状态：pending, seller_negotiating
    let userPurchaseRequestProposedPrice: Double? // 议价金额
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, currency, category, images, seller, status, location, latitude, longitude
        case sellerId = "seller_id"
        case sellerUserLevel = "seller_user_level"
        case viewCount = "view_count"
        case favoriteCount = "favorite_count"
        case refreshedAt = "refreshed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case daysUntilAutoDelist = "days_until_auto_delist"
        case pendingPaymentTaskId = "pending_payment_task_id"
        case pendingPaymentClientSecret = "pending_payment_client_secret"
        case pendingPaymentAmount = "pending_payment_amount"
        case pendingPaymentAmountDisplay = "pending_payment_amount_display"
        case pendingPaymentCurrency = "pending_payment_currency"
        case pendingPaymentCustomerId = "pending_payment_customer_id"
        case pendingPaymentEphemeralKeySecret = "pending_payment_ephemeral_key_secret"
        case pendingPaymentExpiresAt = "pending_payment_expires_at"
        case userPurchaseRequestStatus = "user_purchase_request_status"
        case userPurchaseRequestProposedPrice = "user_purchase_request_proposed_price"
    }
    
    // 自定义解码，处理 price 可能是字符串的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        
        // price 字段：可能是 Double 或 String
        if let priceValue = try? container.decode(Double.self, forKey: .price) {
            price = priceValue
        } else if let priceString = try? container.decode(String.self, forKey: .price),
                  let priceValue = Double(priceString) {
            price = priceValue
        } else {
            throw DecodingError.typeMismatch(Double.self, DecodingError.Context(codingPath: container.codingPath + [CodingKeys.price], debugDescription: "Expected Double or String for price"))
        }
        
        currency = try container.decode(String.self, forKey: .currency)
        category = try container.decode(String.self, forKey: .category)
        images = try container.decodeIfPresent([String].self, forKey: .images)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        latitude = try container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try container.decodeIfPresent(Double.self, forKey: .longitude)
        sellerId = try container.decode(String.self, forKey: .sellerId)
        sellerUserLevel = try container.decodeIfPresent(String.self, forKey: .sellerUserLevel)
        seller = try container.decodeIfPresent(User.self, forKey: .seller)
        status = try container.decode(String.self, forKey: .status)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        refreshedAt = try container.decodeIfPresent(String.self, forKey: .refreshedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        daysUntilAutoDelist = try container.decodeIfPresent(Int.self, forKey: .daysUntilAutoDelist)
        pendingPaymentTaskId = try container.decodeIfPresent(Int.self, forKey: .pendingPaymentTaskId)
        pendingPaymentClientSecret = try container.decodeIfPresent(String.self, forKey: .pendingPaymentClientSecret)
        pendingPaymentAmount = try container.decodeIfPresent(Int.self, forKey: .pendingPaymentAmount)
        pendingPaymentAmountDisplay = try container.decodeIfPresent(String.self, forKey: .pendingPaymentAmountDisplay)
        pendingPaymentCurrency = try container.decodeIfPresent(String.self, forKey: .pendingPaymentCurrency)
        pendingPaymentCustomerId = try container.decodeIfPresent(String.self, forKey: .pendingPaymentCustomerId)
        pendingPaymentEphemeralKeySecret = try container.decodeIfPresent(String.self, forKey: .pendingPaymentEphemeralKeySecret)
        pendingPaymentExpiresAt = try container.decodeIfPresent(String.self, forKey: .pendingPaymentExpiresAt)
        userPurchaseRequestStatus = try container.decodeIfPresent(String.self, forKey: .userPurchaseRequestStatus)
        
        // user_purchase_request_proposed_price 字段：可能是 Double 或 String
        if let priceValue = try? container.decode(Double.self, forKey: .userPurchaseRequestProposedPrice) {
            userPurchaseRequestProposedPrice = priceValue
        } else if let priceString = try? container.decode(String.self, forKey: .userPurchaseRequestProposedPrice),
                  let priceValue = Double(priceString) {
            userPurchaseRequestProposedPrice = priceValue
        } else {
            userPurchaseRequestProposedPrice = nil
        }
    }
    
    // 自定义编码
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encode(price, forKey: .price)
        try container.encode(currency, forKey: .currency)
        try container.encode(category, forKey: .category)
        try container.encodeIfPresent(images, forKey: .images)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(latitude, forKey: .latitude)
        try container.encodeIfPresent(longitude, forKey: .longitude)
        try container.encode(sellerId, forKey: .sellerId)
        try container.encodeIfPresent(sellerUserLevel, forKey: .sellerUserLevel)
        try container.encodeIfPresent(seller, forKey: .seller)
        try container.encode(status, forKey: .status)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(favoriteCount, forKey: .favoriteCount)
        try container.encodeIfPresent(refreshedAt, forKey: .refreshedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(daysUntilAutoDelist, forKey: .daysUntilAutoDelist)
        try container.encodeIfPresent(pendingPaymentTaskId, forKey: .pendingPaymentTaskId)
        try container.encodeIfPresent(pendingPaymentClientSecret, forKey: .pendingPaymentClientSecret)
        try container.encodeIfPresent(pendingPaymentAmount, forKey: .pendingPaymentAmount)
        try container.encodeIfPresent(pendingPaymentAmountDisplay, forKey: .pendingPaymentAmountDisplay)
        try container.encodeIfPresent(pendingPaymentCurrency, forKey: .pendingPaymentCurrency)
        try container.encodeIfPresent(pendingPaymentCustomerId, forKey: .pendingPaymentCustomerId)
        try container.encodeIfPresent(pendingPaymentEphemeralKeySecret, forKey: .pendingPaymentEphemeralKeySecret)
    }
}

struct FleaMarketItemListResponse: Decodable {
    let items: [FleaMarketItem]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // items 是必需的
        items = try container.decode([FleaMarketItem].self, forKey: .items)
        
        // 分页字段是可选的
        total = try container.decodeIfPresent(Int.self, forKey: .total)
        page = try container.decodeIfPresent(Int.self, forKey: .page)
        pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
    }
}

// 创建商品响应
struct CreateFleaMarketItemResponse: Decodable {
    let success: Bool
    let data: CreateFleaMarketItemData
    let message: String?
    
    struct CreateFleaMarketItemData: Decodable {
        let id: String
    }
}

// 购买申请
struct PurchaseRequest: Codable, Identifiable {
    let id: String // 格式化的ID（如S0020）
    let itemId: String
    let buyerId: String
    let buyerName: String
    let proposedPrice: Double?
    let sellerCounterPrice: Double?
    let message: String?
    let status: String
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, message, status
        case itemId = "item_id"
        case buyerId = "buyer_id"
        case buyerName = "buyer_name"
        case proposedPrice = "proposed_price"
        case sellerCounterPrice = "seller_counter_price"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// 购买申请列表响应
struct PurchaseRequestListResponse: Decodable {
    let success: Bool
    let data: PurchaseRequestListData
    let message: String?
    
    struct PurchaseRequestListData: Decodable {
        let requests: [PurchaseRequest]
        let total: Int
    }
}

// 同意购买申请响应
struct ApprovePurchaseRequestResponse: Decodable {
    let success: Bool
    let data: ApprovePurchaseRequestData?
    let message: String?
    
    struct ApprovePurchaseRequestData: Decodable {
        let taskId: String
        let taskStatus: String
        let clientSecret: String?
        let amount: Int?
        let amountDisplay: String?
        let currency: String?
        let customerId: String?
        let ephemeralKeySecret: String?
        
        enum CodingKeys: String, CodingKey {
            case taskId = "task_id"
            case taskStatus = "task_status"
            case clientSecret = "client_secret"
            case amount
            case amountDisplay = "amount_display"
            case currency
            case customerId = "customer_id"
            case ephemeralKeySecret = "ephemeral_key_secret"
        }
    }
}

// 创建购买申请响应
struct CreatePurchaseRequestResponse: Decodable {
    let success: Bool
    let data: CreatePurchaseRequestData
    let message: String?
    
    struct CreatePurchaseRequestData: Decodable {
        let purchaseRequestId: String
        let status: String
        let proposedPrice: Double?
        let createdAt: String
        
        enum CodingKeys: String, CodingKey {
            case purchaseRequestId = "purchase_request_id"
            case status
            case proposedPrice = "proposed_price"
            case createdAt = "created_at"
        }
    }
}

// 拒绝购买申请响应
struct RejectPurchaseRequestResponse: Decodable {
    let success: Bool
    let message: String?
}

// 收藏操作响应
struct FavoriteToggleResponse: Decodable {
    let success: Bool
    let data: FavoriteData
    let message: String?
    
    struct FavoriteData: Decodable {
        let isFavorited: Bool
        
        enum CodingKeys: String, CodingKey {
            case isFavorited = "is_favorited"
        }
    }
}

// 我的收藏列表响应
struct MyFavoritesResponse: Decodable {
    let items: [FavoriteItem]
    let total: Int
    let page: Int
    let pageSize: Int
    let hasMore: Bool?
    
    struct FavoriteItem: Decodable {
        let id: Int
        let itemId: String
        let createdAt: String
        
        enum CodingKeys: String, CodingKey {
            case id
            case itemId = "item_id"
            case createdAt = "created_at"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize
        case hasMore
    }
}

// 直接购买响应
struct DirectPurchaseResponse: Decodable {
    let success: Bool
    let data: DirectPurchaseData
    let message: String?
    
    struct DirectPurchaseData: Decodable {
        let taskId: String
        let itemStatus: String
        let taskStatus: String
        let paymentIntentId: String?
        let clientSecret: String?
        let amount: Int?
        let amountDisplay: String?
        let currency: String?
        let customerId: String?
        let ephemeralKeySecret: String?
        let paymentExpiresAt: String?  // 支付过期时间（ISO 格式）
        
        enum CodingKeys: String, CodingKey {
            case taskId = "task_id"
            case itemStatus = "item_status"
            case taskStatus = "task_status"
            case paymentIntentId = "payment_intent_id"
            case clientSecret = "client_secret"
            case amount
            case amountDisplay = "amount_display"
            case currency
            case customerId = "customer_id"
            case ephemeralKeySecret = "ephemeral_key_secret"
            case paymentExpiresAt = "payment_expires_at"
        }
    }
}


