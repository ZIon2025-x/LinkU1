import Foundation

// 最新帖子信息（用于板块预览）
struct LatestPostInfo: Codable {
    let id: Int
    let title: String
    let author: User?
    let lastReplyAt: String?
    let replyCount: Int
    let viewCount: Int
    
    enum CodingKeys: String, CodingKey {
        case id, title, author
        case lastReplyAt = "last_reply_at"
        case replyCount = "reply_count"
        case viewCount = "view_count"
    }
}

// 论坛板块
struct ForumCategory: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let icon: String?
    let postCount: Int?  // 改为可选，因为在帖子中嵌套时可能不包含此字段
    let lastPostAt: String?
    let latestPost: LatestPostInfo?  // 最新帖子信息（可选，仅在 include_latest_post=True 时包含）
    let isAdminOnly: Bool?  // 是否仅管理员可发帖
    let type: String?  // 板块类型: general(普通), root(国家/地区级大板块), university(大学级小板块)
    let country: String?  // 国家代码（如 UK），仅 type=root 时使用
    let universityCode: String?  // 大学编码（如 UOB），仅 type=university 时使用
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, type, country
        case postCount = "post_count"
        case lastPostAt = "last_post_at"
        case latestPost = "latest_post"
        case isAdminOnly = "is_admin_only"
        case universityCode = "university_code"
    }
    
    // 自定义解码，处理可选字段可能不存在的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        icon = try container.decodeIfPresent(String.self, forKey: .icon)
        postCount = try container.decodeIfPresent(Int.self, forKey: .postCount)
        lastPostAt = try container.decodeIfPresent(String.self, forKey: .lastPostAt)
        latestPost = try container.decodeIfPresent(LatestPostInfo.self, forKey: .latestPost)
        isAdminOnly = try container.decodeIfPresent(Bool.self, forKey: .isAdminOnly)
        type = try container.decodeIfPresent(String.self, forKey: .type) ?? "general"
        country = try container.decodeIfPresent(String.self, forKey: .country)
        universityCode = try container.decodeIfPresent(String.self, forKey: .universityCode)
    }
    
    // 检查是否需要学生认证才能访问
    var requiresStudentVerification: Bool {
        return type == "root" || type == "university"
    }
}

struct ForumCategoryListResponse: Decodable {
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
    let favoriteCount: Int
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
        case favoriteCount = "favorite_count"
        case isPinned = "is_pinned"
        case isFeatured = "is_featured"
        case isLocked = "is_locked"
        case createdAt = "created_at"
        case lastReplyAt = "last_reply_at"
    }
    
    // 自定义解码，处理计数字段可能是字符串或整数的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        contentPreview = try container.decodeIfPresent(String.self, forKey: .contentPreview)
        category = try container.decodeIfPresent(ForumCategory.self, forKey: .category)
        author = try container.decodeIfPresent(User.self, forKey: .author)
        
        // 处理 view_count 可能是字符串或整数
        if let viewCountString = try? container.decode(String.self, forKey: .viewCount) {
            viewCount = Int(viewCountString) ?? 0
        } else {
            viewCount = try container.decode(Int.self, forKey: .viewCount)
        }
        
        // 处理 reply_count 可能是字符串或整数
        if let replyCountString = try? container.decode(String.self, forKey: .replyCount) {
            replyCount = Int(replyCountString) ?? 0
        } else {
            replyCount = try container.decode(Int.self, forKey: .replyCount)
        }
        
        // 处理 like_count 可能是字符串或整数
        if let likeCountString = try? container.decode(String.self, forKey: .likeCount) {
            likeCount = Int(likeCountString) ?? 0
        } else {
            likeCount = try container.decode(Int.self, forKey: .likeCount)
        }
        
        // 处理 favorite_count 可能是字符串、整数或不存在（使用可选解码）
        if let favoriteCountString = try? container.decode(String.self, forKey: .favoriteCount) {
            favoriteCount = Int(favoriteCountString) ?? 0
        } else if let favoriteCountInt = try? container.decode(Int.self, forKey: .favoriteCount) {
            favoriteCount = favoriteCountInt
        } else {
            // 字段不存在，使用默认值 0
            favoriteCount = 0
        }
        
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        isFeatured = try container.decode(Bool.self, forKey: .isFeatured)
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        lastReplyAt = try container.decodeIfPresent(String.self, forKey: .lastReplyAt)
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
    let postId: Int?
    let parentId: Int?
    let replyLevel: Int?
    let likeCount: Int
    let isLiked: Bool?
    let createdAt: String
    let updatedAt: String?
    let replies: [ForumReply]? // 子回复
    
    enum CodingKeys: String, CodingKey {
        case id, content, author
        case postId = "post_id"
        case parentId = "parent_reply_id"
        case replyLevel = "reply_level"
        case likeCount = "like_count"
        case isLiked = "is_liked"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case replies
    }
    
    // 自定义解码，处理可选字段
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        author = try container.decodeIfPresent(User.self, forKey: .author)
        postId = try container.decodeIfPresent(Int.self, forKey: .postId)
        parentId = try container.decodeIfPresent(Int.self, forKey: .parentId)
        replyLevel = try container.decodeIfPresent(Int.self, forKey: .replyLevel)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount) ?? 0
        isLiked = try container.decodeIfPresent(Bool.self, forKey: .isLiked)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decodeIfPresent(String.self, forKey: .updatedAt)
        replies = try container.decodeIfPresent([ForumReply].self, forKey: .replies)
    }
}

struct ForumReplyListResponse: Codable {
    let replies: [ForumReply]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    
    enum CodingKeys: String, CodingKey {
        case replies, total, page
        case pageSize = "page_size"
    }
    
    // 自定义解码，支持两种格式：包装对象或直接数组
    init(from decoder: Decoder) throws {
        // 先尝试作为包装对象解码
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            replies = try container.decode([ForumReply].self, forKey: .replies)
            total = try container.decodeIfPresent(Int.self, forKey: .total)
            page = try container.decodeIfPresent(Int.self, forKey: .page)
            pageSize = try container.decodeIfPresent(Int.self, forKey: .pageSize)
        } else {
            // 如果失败，尝试作为直接数组解码
            let container = try decoder.singleValueContainer()
            replies = try container.decode([ForumReply].self)
            total = nil
            page = nil
            pageSize = nil
        }
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

