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
    let seller: User?
    let status: String
    let viewCount: Int
    let favoriteCount: Int // 收藏数量
    let refreshedAt: String? // 后端返回的字段
    let createdAt: String
    let updatedAt: String?
    let daysUntilAutoDelist: Int? // 距离自动下架还有多少天
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, currency, category, images, seller, status, location, latitude, longitude
        case sellerId = "seller_id"
        case viewCount = "view_count"
        case favoriteCount = "favorite_count"
        case refreshedAt = "refreshed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case daysUntilAutoDelist = "days_until_auto_delist"
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
        seller = try container.decodeIfPresent(User.self, forKey: .seller)
        status = try container.decode(String.self, forKey: .status)
        viewCount = try container.decode(Int.self, forKey: .viewCount)
        favoriteCount = try container.decodeIfPresent(Int.self, forKey: .favoriteCount) ?? 0
        refreshedAt = try container.decodeIfPresent(String.self, forKey: .refreshedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        daysUntilAutoDelist = try container.decodeIfPresent(Int.self, forKey: .daysUntilAutoDelist)
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
        try container.encodeIfPresent(seller, forKey: .seller)
        try container.encode(status, forKey: .status)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(favoriteCount, forKey: .favoriteCount)
        try container.encodeIfPresent(refreshedAt, forKey: .refreshedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(daysUntilAutoDelist, forKey: .daysUntilAutoDelist)
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
    let id: Int
    let itemId: String // 改为 String，因为商品 ID 是字符串格式
    let buyerId: String
    let proposedPrice: Double?
    let message: String?
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, message, status
        case itemId = "item_id"
        case buyerId = "buyer_id"
        case proposedPrice = "proposed_price"
        case createdAt = "created_at"
    }
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


