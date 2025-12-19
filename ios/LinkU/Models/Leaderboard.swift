import Foundation

// 自定义排行榜
struct CustomLeaderboard: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let location: String?
    let coverImage: String?
    let applicant: User?
    let status: String
    let itemCount: Int
    let voteCount: Int
    let viewCount: Int
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, location, applicant, status
        case coverImage = "cover_image"
        case itemCount = "item_count"
        case voteCount = "vote_count"
        case viewCount = "view_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct CustomLeaderboardListResponse: Codable {
    let items: [CustomLeaderboard]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case items, total, limit, offset
        case hasMore = "has_more"
    }
}

// 排行榜竞品
struct LeaderboardItem: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let images: [String]?
    let address: String?
    let phone: String?
    let website: String?
    let upvotes: Int
    let downvotes: Int
    let netVotes: Int
    let voteScore: Double
    let rank: Int?
    let submitter: User?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, images, address, phone, website, submitter
        case upvotes, downvotes
        case netVotes = "net_votes"
        case voteScore = "vote_score"
        case rank
        case createdAt = "created_at"
    }
    
    // 兼容旧字段名
    var image: String? {
        return images?.first
    }
}

struct LeaderboardItemListResponse: Codable {
    let items: [LeaderboardItem]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case items, total, limit, offset
        case hasMore = "has_more"
    }
}

// 投票响应
struct VoteResponse: Codable {
    let message: String?
    let upvotes: Int
    let downvotes: Int
    let netVotes: Int
    let voteScore: Double?
    
    enum CodingKeys: String, CodingKey {
        case message
        case upvotes, downvotes
        case netVotes = "net_votes"
        case voteScore = "vote_score"
    }
}

