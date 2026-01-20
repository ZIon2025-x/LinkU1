import Foundation

// 论坛板块
struct ForumCategory: Codable, Identifiable {
    let id: Int
    let name: String  // 保留原字段用于兼容
    let nameEn: String?  // 英文名称
    let nameZh: String?  // 中文名称
    let description: String?  // 保留原字段用于兼容
    let descriptionEn: String?  // 英文描述
    let descriptionZh: String?  // 中文描述
    let icon: String?
    let postCount: Int
    let lastPostAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon
        case nameEn = "name_en"
        case nameZh = "name_zh"
        case descriptionEn = "description_en"
        case descriptionZh = "description_zh"
        case postCount = "post_count"
        case lastPostAt = "last_post_at"
    }
    
    // 自定义解码，处理可选字段可能不存在的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        nameEn = try container.decodeIfPresent(String.self, forKey: .nameEn)
        nameZh = try container.decodeIfPresent(String.self, forKey: .nameZh)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        descriptionEn = try container.decodeIfPresent(String.self, forKey: .descriptionEn)
        descriptionZh = try container.decodeIfPresent(String.self, forKey: .descriptionZh)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        postCount = try container.decode(Int.self, forKey: .postCount)
        lastPostAt = try container.decodeIfPresent(String.self, forKey: .lastPostAt)
    }
    
    // 根据当前语言获取显示名称
    var displayName: String {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        if language.hasPrefix("zh") {
            // 中文环境：优先使用 nameZh，否则使用 name
            return nameZh?.isEmpty == false ? nameZh! : name
        } else {
            // 英文环境：优先使用 nameEn，否则使用 name
            return nameEn?.isEmpty == false ? nameEn! : name
        }
    }
    
    // 根据当前语言获取显示描述
    var displayDescription: String? {
        let language = Locale.current.language.languageCode?.identifier ?? "en"
        if language.hasPrefix("zh") {
            // 中文环境：优先使用 descriptionZh，否则使用 description
            return descriptionZh?.isEmpty == false ? descriptionZh : description
        } else {
            // 英文环境：优先使用 descriptionEn，否则使用 description
            return descriptionEn?.isEmpty == false ? descriptionEn : description
        }
    }
}

struct ForumCategoryListResponse: Codable {
    let categories: [ForumCategory]
    
    // 支持两种格式：包装对象 {categories: [...]} 或直接数组 [...]
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            categories = try container.decode([ForumCategory].self, forKey: .categories)
        } else {
            let container = try decoder.singleValueContainer()
            categories = try container.decode([ForumCategory].self)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case categories
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

