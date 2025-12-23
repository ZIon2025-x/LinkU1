import Foundation

public struct User: Codable, Identifiable {
    public let id: String  // 后端返回的是字符串（8位数字）
    public let name: String
    public let email: String?  // 改为可选，因为某些场景（如排行榜的 applicant）可能不包含 email
    public let phone: String?
    public let isVerified: Int?
    public let userLevel: String?  // 后端返回的是字符串，如 "normal", "vip", "super"
    public let avatar: String?
    public let createdAt: String?
    public let userType: String?
    public let taskCount: Int?
    public let completedTaskCount: Int?
    public let avgRating: Double?
    public let residenceCity: String?
    public let languagePreference: String?
    public let isAdmin: Bool?  // 是否是管理员/官方
    
    public enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case phone
        case isVerified = "is_verified"
        case userLevel = "user_level"
        case avatar
        case createdAt = "created_at"
        case userType = "user_type"
        case taskCount = "task_count"
        case completedTaskCount = "completed_task_count"
        case avgRating = "avg_rating"
        case residenceCity = "residence_city"
        case languagePreference = "language_preference"
        case isAdmin = "is_admin"
    }
    
    public init(id: String, name: String, email: String? = nil, phone: String? = nil, isVerified: Int? = nil, userLevel: String? = nil, avatar: String? = nil, createdAt: String? = nil, userType: String? = nil, taskCount: Int? = nil, completedTaskCount: Int? = nil, avgRating: Double? = nil, residenceCity: String? = nil, languagePreference: String? = nil, isAdmin: Bool? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.isVerified = isVerified
        self.userLevel = userLevel
        self.avatar = avatar
        self.createdAt = createdAt
        self.userType = userType
        self.taskCount = taskCount
        self.completedTaskCount = completedTaskCount
        self.avgRating = avgRating
        self.residenceCity = residenceCity
        self.languagePreference = languagePreference
        self.isAdmin = isAdmin
    }
}

// 登录响应中的用户信息（简化版，只包含登录时返回的字段）
struct LoginUser: Codable {
    let id: String
    let name: String
    let email: String
    let userLevel: String?
    let isVerified: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case email
        case userLevel = "user_level"
        case isVerified = "is_verified"
    }
}

struct LoginResponse: Codable {
    let message: String
    let user: LoginUser
    let sessionId: String?
    let expiresIn: Int?
    let mobileAuth: Bool?
    let authHeaders: AuthHeaders?
    
    enum CodingKeys: String, CodingKey {
        case message
        case user
        case sessionId = "session_id"
        case expiresIn = "expires_in"
        case mobileAuth = "mobile_auth"
        case authHeaders = "auth_headers"
    }
}

struct AuthHeaders: Codable {
    let sessionId: String?
    let userId: String?
    let authStatus: String?
    
    enum CodingKeys: String, CodingKey {
        case sessionId = "X-Session-ID"
        case userId = "X-User-ID"
        case authStatus = "X-Auth-Status"
    }
}

struct RefreshResponse: Codable {
    let message: String
    let sessionId: String?
    let expiresIn: Int?
    
    enum CodingKeys: String, CodingKey {
        case message
        case sessionId = "session_id"
        case expiresIn = "expires_in"
    }
}

struct RegisterResponse: Codable {
    let message: String
    let email: String?
    let verificationRequired: Bool?
    
    enum CodingKeys: String, CodingKey {
        case message, email
        case verificationRequired = "verification_required"
    }
}

// MARK: - User Profile (用户资料详情)

struct UserProfileResponse: Codable {
    let user: UserProfileUser
    let stats: UserProfileStats
    let recentTasks: [UserProfileTask]
    let reviews: [UserProfileReview]
    
    enum CodingKeys: String, CodingKey {
        case user, stats, reviews
        case recentTasks = "recent_tasks"
    }
}

struct UserProfileUser: Codable {
    let id: String
    let name: String
    let avatar: String?
    let isVerified: Int?
    let userLevel: String?
    let avgRating: Double?
    let daysSinceJoined: Int?
    let taskCount: Int?
    let completedTaskCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, avatar
        case isVerified = "is_verified"
        case userLevel = "user_level"
        case avgRating = "avg_rating"
        case daysSinceJoined = "days_since_joined"
        case taskCount = "task_count"
        case completedTaskCount = "completed_task_count"
    }
}

struct UserProfileStats: Codable {
    let totalTasks: Int
    let postedTasks: Int
    let takenTasks: Int
    let completedTasks: Int
    let totalReviews: Int
    let completionRate: Double?
    
    enum CodingKeys: String, CodingKey {
        case totalTasks = "total_tasks"
        case postedTasks = "posted_tasks"
        case takenTasks = "taken_tasks"
        case completedTasks = "completed_tasks"
        case totalReviews = "total_reviews"
        case completionRate = "completion_rate"
    }
}

struct UserProfileTask: Codable, Identifiable {
    let id: Int
    let title: String
    let status: String
    let createdAt: String
    let reward: Double
    let taskType: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, status, reward
        case createdAt = "created_at"
        case taskType = "task_type"
    }
}

struct UserProfileReview: Codable, Identifiable {
    let id: Int
    let rating: Double
    let comment: String?
    let createdAt: String
    let taskId: Int  // 改为 Int，因为后端返回的是数字
    let isAnonymous: Bool
    let reviewerName: String?
    let reviewerAvatar: String?
    
    enum CodingKeys: String, CodingKey {
        case id, rating, comment
        case createdAt = "created_at"
        case taskId = "task_id"
        case isAnonymous = "is_anonymous"
        case reviewerName = "reviewer_name"
        case reviewerAvatar = "reviewer_avatar"
    }
}

