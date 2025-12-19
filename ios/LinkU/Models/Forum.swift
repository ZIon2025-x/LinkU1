import Foundation

// 论坛板块
struct ForumCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let icon: String?
    let postCount: Int
    let lastPostAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon
        case postCount = "post_count"
        case lastPostAt = "last_post_at"
    }
}

struct ForumCategoryListResponse: Codable {
    let categories: [ForumCategory]
    
    // 如果后端返回的是数组，直接解析
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        categories = try container.decode([ForumCategory].self)
    }
}

// 论坛帖子
struct ForumPost: Codable, Identifiable {
    let id: Int
    let title: String
    let content: String?
    let contentPreview: String?
    let category: ForumCategory?
    let author: User?
    let viewCount: Int
    let replyCount: Int
    let likeCount: Int
    let isPinned: Bool
    let isFeatured: Bool
    let isLocked: Bool
    let createdAt: String
    let lastReplyAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, category, author
        case contentPreview = "content_preview"
        case viewCount = "view_count"
        case replyCount = "reply_count"
        case likeCount = "like_count"
        case isPinned = "is_pinned"
        case isFeatured = "is_featured"
        case isLocked = "is_locked"
        case createdAt = "created_at"
        case lastReplyAt = "last_reply_at"
    }
}

struct ForumPostListResponse: Codable {
    let posts: [ForumPost]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case posts, total, page
        case pageSize = "page_size"
    }
}

// 论坛回复
struct ForumReply: Codable, Identifiable {
    let id: Int
    let content: String
    let author: User?
    let postId: Int
    let parentId: Int?
    let likeCount: Int
    let createdAt: String
    let replies: [ForumReply]? // 子回复
    
    enum CodingKeys: String, CodingKey {
        case id, content, author
        case postId = "post_id"
        case parentId = "parent_id"
        case likeCount = "like_count"
        case createdAt = "created_at"
        case replies
    }
}

struct ForumReplyListResponse: Codable {
    let replies: [ForumReply]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case replies, total, page
        case pageSize = "page_size"
    }
}

// 点赞响应
struct ForumLikeResponse: Codable {
    let liked: Bool
    let likeCount: Int
    
    enum CodingKeys: String, CodingKey {
        case liked
        case likeCount = "like_count"
    }
}

// 收藏响应
struct ForumFavoriteResponse: Codable {
    let favorited: Bool
    let message: String
}

// 搜索响应
struct ForumSearchResponse: Codable {
    let posts: [ForumPost]
    let total: Int
}

