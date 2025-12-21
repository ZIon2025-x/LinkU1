import Foundation

// 跳蚤市场分类
struct FleaMarketCategory: Codable {
    let id: String
    let name: String
    let icon: String?
}

struct FleaMarketCategoryResponse: Codable {
    let categories: [FleaMarketCategory]
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
    let refreshedAt: String? // 后端返回的字段
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, currency, category, images, seller, status, location, latitude, longitude
        case sellerId = "seller_id"
        case viewCount = "view_count"
        case refreshedAt = "refreshed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
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
        refreshedAt = try container.decodeIfPresent(String.self, forKey: .refreshedAt)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
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
        try container.encodeIfPresent(refreshedAt, forKey: .refreshedAt)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(updatedAt, forKey: .updatedAt)
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

