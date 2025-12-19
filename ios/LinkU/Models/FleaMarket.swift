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
    let id: Int
    let title: String
    let description: String?
    let price: Double
    let currency: String
    let category: String
    let images: [String]?
    let sellerId: String
    let seller: User?
    let status: String
    let viewCount: Int
    let createdAt: String
    let updatedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, currency, category, images, seller, status
        case sellerId = "seller_id"
        case viewCount = "view_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct FleaMarketItemListResponse: Codable {
    let items: [FleaMarketItem]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case items, total, page
        case pageSize = "page_size"
    }
}

// 购买申请
struct PurchaseRequest: Codable, Identifiable {
    let id: Int
    let itemId: Int
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

