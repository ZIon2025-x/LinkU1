import Foundation

// 自定义排行榜
struct CustomLeaderboard: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let location: String?
    let coverImage: String?
    let applicationReason: String?
    let applicantId: String?
    let applicant: User?
    let status: String
    let itemCount: Int
    let voteCount: Int
    let viewCount: Int
    let createdAt: String
    let updatedAt: String
    var distance: Double? // 距离用户的位置（公里），用于排序
    var isFavorited: Bool?  // 是否已收藏（可变，用于UI更新）
    
    // 使用自定义解码，处理计数字段可能是字符串或整数的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        coverImage = try container.decodeIfPresent(String.self, forKey: .coverImage)
        applicationReason = try container.decodeIfPresent(String.self, forKey: .applicationReason)
        applicantId = try container.decodeIfPresent(String.self, forKey: .applicantId)
        applicant = try container.decodeIfPresent(User.self, forKey: .applicant)
        status = try container.decode(String.self, forKey: .status)
        
        // 处理 item_count 可能是字符串或整数
        if let itemCountString = try? container.decode(String.self, forKey: .itemCount) {
            itemCount = Int(itemCountString) ?? 0
        } else {
            itemCount = try container.decode(Int.self, forKey: .itemCount)
        }
        
        // 处理 vote_count 可能是字符串或整数
        if let voteCountString = try? container.decode(String.self, forKey: .voteCount) {
            voteCount = Int(voteCountString) ?? 0
        } else {
            voteCount = try container.decode(Int.self, forKey: .voteCount)
        }
        
        // 处理 view_count 可能是字符串或整数（后端可能格式化为字符串，如 "38", "1.2k", "1.2万", "10万+"）
        if let viewCountString = try? container.decode(String.self, forKey: .viewCount) {
            viewCount = parseFormattedCount(viewCountString)
        } else {
            viewCount = try container.decode(Int.self, forKey: .viewCount)
        }
        
        createdAt = try container.decode(String.self, forKey: .createdAt)
        updatedAt = try container.decode(String.self, forKey: .updatedAt)
        isFavorited = try container.decodeIfPresent(Bool.self, forKey: .isFavorited)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(coverImage, forKey: .coverImage)
        try container.encodeIfPresent(applicationReason, forKey: .applicationReason)
        try container.encodeIfPresent(applicantId, forKey: .applicantId)
        try container.encodeIfPresent(applicant, forKey: .applicant)
        try container.encode(status, forKey: .status)
        try container.encode(itemCount, forKey: .itemCount)
        try container.encode(voteCount, forKey: .voteCount)
        try container.encode(viewCount, forKey: .viewCount)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, location, applicant, status
        case coverImage = "cover_image"
        case applicationReason = "application_reason"
        case applicantId = "applicant_id"
        case itemCount = "item_count"
        case voteCount = "vote_count"
        case viewCount = "view_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isFavorited = "is_favorited"
    }
}

struct CustomLeaderboardListResponse: Decodable {
    var items: [CustomLeaderboard]
    var total: Int?
    var limit: Int?
    var offset: Int?
    let hasMore: Bool?
    
    // 支持多种格式：包装对象 {items: [...]}, {leaderboards: [...]}, {data: [...]} 或直接数组 [...]
    init(from decoder: Decoder) throws {
        // 先尝试作为包装对象解析
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 尝试不同的键名（按优先级顺序）
        if container.contains(.items) {
            items = try container.decode([CustomLeaderboard].self, forKey: .items)
        } else if container.contains(.leaderboards) {
            items = try container.decode([CustomLeaderboard].self, forKey: .leaderboards)
        } else if container.contains(.data) {
            items = try container.decode([CustomLeaderboard].self, forKey: .data)
        } else {
            // 如果所有键都不存在，抛出明确的错误
            throw DecodingError.keyNotFound(
                CodingKeys.items,
                DecodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "响应中未找到 items、leaderboards 或 data 键"
                )
            )
        }
        
        // 成功解析数组后，尝试解析其他字段（使用可选解码，避免因缺少字段而失败）
        total = try? container.decodeIfPresent(Int.self, forKey: .total)
        limit = try? container.decodeIfPresent(Int.self, forKey: .limit)
        offset = try? container.decodeIfPresent(Int.self, forKey: .offset)
        hasMore = try? container.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
    
    enum CodingKeys: String, CodingKey {
        case items, total, limit, offset, data
        case leaderboards
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
    let viewCount: Int?  // 浏览量（可选，因为某些接口可能不返回）
    let rank: Int?
    let submitter: User?
    let createdAt: String
    let userVote: String?  // "upvote", "downvote", 或 nil
    let userVoteComment: String?  // 用户投票时的留言
    let userVoteIsAnonymous: Bool?  // 用户投票是否匿名
    var distance: Double?  // 距离用户的位置（公里），用于排序
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, images, address, phone, website, submitter
        case upvotes, downvotes
        case netVotes = "net_votes"
        case voteScore = "vote_score"
        case viewCount = "view_count"
        case rank
        case createdAt = "created_at"
        case userVote = "user_vote"
        case userVoteComment = "user_vote_comment"
        case userVoteIsAnonymous = "user_vote_is_anonymous"
    }
    
    // 自定义解码，处理可选字段
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        images = try container.decodeIfPresent([String].self, forKey: .images)
        address = try container.decodeIfPresent(String.self, forKey: .address)
        phone = try container.decodeIfPresent(String.self, forKey: .phone)
        website = try container.decodeIfPresent(String.self, forKey: .website)
        upvotes = try container.decode(Int.self, forKey: .upvotes)
        downvotes = try container.decode(Int.self, forKey: .downvotes)
        netVotes = try container.decode(Int.self, forKey: .netVotes)
        voteScore = try container.decode(Double.self, forKey: .voteScore)
        // 处理 view_count 可能是字符串、整数或不存在
        if let viewCountString = try? container.decode(String.self, forKey: .viewCount) {
            viewCount = Int(viewCountString) ?? 0
        } else if let viewCountInt = try? container.decode(Int.self, forKey: .viewCount) {
            viewCount = viewCountInt
        } else {
            // 字段不存在，使用 nil
            viewCount = nil
        }
        rank = try container.decodeIfPresent(Int.self, forKey: .rank)
        submitter = try container.decodeIfPresent(User.self, forKey: .submitter)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        userVote = try container.decodeIfPresent(String.self, forKey: .userVote)
        userVoteComment = try container.decodeIfPresent(String.self, forKey: .userVoteComment)
        userVoteIsAnonymous = try container.decodeIfPresent(Bool.self, forKey: .userVoteIsAnonymous)
        distance = nil  // 距离在客户端计算，不从后端获取
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

// 排行榜竞品留言（投票留言）
struct LeaderboardItemComment: Codable, Identifiable {
    let id: Int
    let content: String?  // 可选，因为可能只有投票没有留言
    let author: User?  // 可选，匿名用户可能没有 author
    let itemId: Int?
    let createdAt: String
    let voteType: String?  // "upvote" 或 "downvote"
    let isAnonymous: Bool?
    let userId: String?  // 用户ID（匿名时为 nil）
    let likeCount: Int?
    let userLiked: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, content, author, comment
        case itemId = "item_id"
        case createdAt = "created_at"
        case voteType = "vote_type"
        case isAnonymous = "is_anonymous"
        case userId = "user_id"
        case likeCount = "like_count"
        case userLiked = "user_liked"
    }
    
    // 自定义解码，处理可选字段
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        
        // API返回的是 comment 字段，但模型使用 content 属性
        // 优先尝试 comment 字段，如果没有则尝试 content 字段
        if let commentValue = try? container.decodeIfPresent(String.self, forKey: .comment) {
            content = commentValue
        } else {
            content = try container.decodeIfPresent(String.self, forKey: .content)
        }
        
        author = try container.decodeIfPresent(User.self, forKey: .author)
        itemId = try container.decodeIfPresent(Int.self, forKey: .itemId)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        voteType = try container.decodeIfPresent(String.self, forKey: .voteType)
        isAnonymous = try container.decodeIfPresent(Bool.self, forKey: .isAnonymous)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        likeCount = try container.decodeIfPresent(Int.self, forKey: .likeCount)
        userLiked = try container.decodeIfPresent(Bool.self, forKey: .userLiked)
    }
    
    // 自定义编码，将 content 编码为 comment 字段
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(content, forKey: .comment) // 将 content 编码为 comment
        try container.encodeIfPresent(author, forKey: .author)
        try container.encodeIfPresent(itemId, forKey: .itemId)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(voteType, forKey: .voteType)
        try container.encodeIfPresent(isAnonymous, forKey: .isAnonymous)
        try container.encodeIfPresent(userId, forKey: .userId)
        try container.encodeIfPresent(likeCount, forKey: .likeCount)
        try container.encodeIfPresent(userLiked, forKey: .userLiked)
    }
}

struct LeaderboardItemCommentListResponse: Codable {
    let comments: [LeaderboardItemComment]
    let total: Int?
    let page: Int?
    let pageSize: Int?
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case comments, total, page, items
        case pageSize = "page_size"
        case hasMore = "has_more"
    }
    
    // 自定义解码，支持多种格式：包装对象（items/comments）或直接数组
    init(from decoder: Decoder) throws {
        var decodedComments: [LeaderboardItemComment] = []
        var decodedTotal: Int?
        var decodedPage: Int?
        var decodedPageSize: Int?
        var decodedHasMore: Bool?
        
        // 首先尝试作为键值容器解析
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            // 尝试从 items 字段解码（前端返回的格式）
            if let items = try? container.decode([LeaderboardItemComment].self, forKey: .items) {
                decodedComments = items
                decodedTotal = try? container.decodeIfPresent(Int.self, forKey: .total)
                decodedPage = try? container.decodeIfPresent(Int.self, forKey: .page)
                decodedPageSize = try? container.decodeIfPresent(Int.self, forKey: .pageSize)
                decodedHasMore = try? container.decodeIfPresent(Bool.self, forKey: .hasMore)
            }
            // 尝试从 comments 字段解码
            else if let commentsArray = try? container.decode([LeaderboardItemComment].self, forKey: .comments) {
                decodedComments = commentsArray
                decodedTotal = try? container.decodeIfPresent(Int.self, forKey: .total)
                decodedPage = try? container.decodeIfPresent(Int.self, forKey: .page)
                decodedPageSize = try? container.decodeIfPresent(Int.self, forKey: .pageSize)
                decodedHasMore = try? container.decodeIfPresent(Bool.self, forKey: .hasMore)
            }
            // 如果都没有找到数组字段，尝试解析其他字段
            else {
                decodedTotal = try? container.decodeIfPresent(Int.self, forKey: .total)
                decodedPage = try? container.decodeIfPresent(Int.self, forKey: .page)
                decodedPageSize = try? container.decodeIfPresent(Int.self, forKey: .pageSize)
                decodedHasMore = try? container.decodeIfPresent(Bool.self, forKey: .hasMore)
            }
        }
        
        // 如果还没有解析到comments，尝试直接解码数组
        if decodedComments.isEmpty {
            do {
                let singleContainer = try decoder.singleValueContainer()
                decodedComments = try singleContainer.decode([LeaderboardItemComment].self)
            } catch {
                // 如果所有尝试都失败，返回空数组
                decodedComments = []
            }
        }
        
        // 统一初始化所有属性
        self.comments = decodedComments
        self.total = decodedTotal
        self.page = decodedPage
        self.pageSize = decodedPageSize
        self.hasMore = decodedHasMore
    }
    
    // 自定义编码，将 comments 编码为 items 字段（匹配前端格式）
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(comments, forKey: .items)
        try container.encodeIfPresent(total, forKey: .total)
        try container.encodeIfPresent(page, forKey: .page)
        try container.encodeIfPresent(pageSize, forKey: .pageSize)
        try container.encodeIfPresent(hasMore, forKey: .hasMore)
    }
}

// 点赞留言响应
struct LikeCommentResponse: Codable {
    let message: String?
    let liked: Bool
    let likeCount: Int
    
    enum CodingKeys: String, CodingKey {
        case message
        case liked
        case likeCount = "like_count"
    }
}

// MARK: - 辅助函数

/// 解析格式化的计数字符串（如 "38", "1k+", "1.2k+", "1万+", "10万+"）
/// 前端显示格式规则（带 "+" 号）：
/// - 小于1000：返回纯数字字符串，如 "38"
/// - 1000及以上：返回 k 格式带 "+"，如 "1k+", "1.2k+"
/// - 10000及以上：返回万格式带 "+"，如 "1万+", "1.2万+"
/// - 100000及以上：返回 "10万+" 格式
func parseFormattedCount(_ formattedString: String) -> Int {
    let trimmed = formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
    
    // 如果是纯数字，直接转换
    if let number = Int(trimmed) {
        return number
    }
    
    // 处理 k+ 格式（如 "1.2k+", "1k+"）
    if trimmed.hasSuffix("k+") || trimmed.hasSuffix("K+") {
        let numberString = String(trimmed.dropLast(2))
        if let number = Double(numberString) {
            // 向上取整到最近的1000
            return Int(ceil(number) * 1000)
        }
    }
    
    // 处理 k 格式（不带 +，如 "1.2k", "1k"）
    if trimmed.hasSuffix("k") || trimmed.hasSuffix("K") {
        let numberString = String(trimmed.dropLast())
        if let number = Double(numberString) {
            return Int(number * 1000)
        }
    }
    
    // 处理万+格式（如 "1.2万+", "1万+", "10万+"）
    if trimmed.hasSuffix("万+") {
        let numberString = String(trimmed.dropLast(2))
        if let number = Double(numberString) {
            // 向上取整到最近的10000
            return Int(ceil(number) * 10000)
        }
    }
    
    // 处理万格式（不带 +，如 "1.2万", "1万"）
    if trimmed.hasSuffix("万") {
        let numberString = String(trimmed.dropLast())
        if let number = Double(numberString) {
            return Int(number * 10000)
        }
    }
    
    // 如果无法解析，返回 0
    return 0
}

