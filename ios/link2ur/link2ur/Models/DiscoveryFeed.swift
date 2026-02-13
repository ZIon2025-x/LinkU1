import Foundation
import SwiftUI

/// 发现 Feed 单项（与后端 /api/discovery/feed 一致）
struct DiscoveryFeedItem: Identifiable, Decodable {
    let id: String
    let feedType: String
    let title: String?
    let description: String?
    let images: [String]?
    let userId: String?
    let userName: String?
    let userAvatar: String?
    let expertId: String?
    let price: Double?
    let originalPrice: Double?
    let discountPercentage: Double?
    let currency: String?
    let rating: Double?
    let likeCount: Int?
    let commentCount: Int?
    let upvoteCount: Int?
    let downvoteCount: Int?
    let extraData: [String: AnyCodable]?
    let createdAt: String?
    let targetItem: TargetItemBrief?
    
    enum CodingKeys: String, CodingKey {
        case id
        case feedType = "feed_type"
        case title, description, images
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case expertId = "expert_id"
        case price
        case originalPrice = "original_price"
        case discountPercentage = "discount_percentage"
        case currency, rating
        case likeCount = "like_count"
        case commentCount = "comment_count"
        case upvoteCount = "upvote_count"
        case downvoteCount = "downvote_count"
        case extraData = "extra_data"
        case createdAt = "created_at"
        case targetItem = "target_item"
    }
    
    var hasImages: Bool { (images?.isEmpty ?? true) == false }
    var firstImage: String? { images?.first }
    
    /// 帖子分类名（extra_data.category_name）
    var categoryName: String? {
        guard let data = extraData else { return nil }
        return data["category_name"]?.value as? String
    }
}

/// 评论针对的目标（竞品/服务）简要信息，用于跳转
struct TargetItemBrief: Decodable {
    let itemType: String
    let itemId: String
    let name: String?
    let subtitle: String?
    let thumbnail: String?
    
    enum CodingKeys: String, CodingKey {
        case itemType = "item_type"
        case itemId = "item_id"
        case name, subtitle, thumbnail
    }
}

/// 发现 Feed 列表响应
struct DiscoveryFeedResponse: Decodable {
    let items: [DiscoveryFeedItem]
    let page: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case items, page
        case hasMore = "has_more"
    }
}
