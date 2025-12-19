import Foundation

// 任务达人
struct TaskExpert: Codable, Identifiable {
    let id: String // user_id
    let name: String
    let avatar: String?
    let bio: String?
    let userLevel: String? // 后端返回的是字符串，如 "normal"
    let avgRating: Double?
    let completedTasks: Int?
    let totalTasks: Int?
    let completionRate: Double?
    let expertiseAreas: [String]?
    let featuredSkills: [String]?
    let status: String? // 改为可选，因为后端可能不返回
    let achievements: [String]? // 后端返回的字段
    let isVerified: Bool? // 后端返回的字段
    let responseTime: String? // 后端返回的字段
    let successRate: Double? // 后端返回的字段
    let location: String? // 后端返回的字段
    let category: String? // 后端返回的字段
    let rating: Double? // 详情页返回的字段（与 avg_rating 相同）
    let totalServices: Int? // 详情页返回的字段
    let createdAt: String? // 详情页返回的字段
    var distance: Double? // 距离用户的位置（公里），用于排序
    
    enum CodingKeys: String, CodingKey {
        case id, avatar, bio, status, location, category, rating
        case name
        case expertName = "expert_name" // 详情页使用的字段名
        case userLevel = "user_level"
        case avgRating = "avg_rating"
        case completedTasks = "completed_tasks"
        case totalTasks = "total_tasks"
        case totalServices = "total_services" // 详情页使用的字段名
        case completionRate = "completion_rate"
        case expertiseAreas = "expertise_areas"
        case featuredSkills = "featured_skills"
        case achievements
        case isVerified = "is_verified"
        case responseTime = "response_time"
        case successRate = "success_rate"
        case createdAt = "created_at"
    }
    
    // 自定义解码，处理不同的字段名
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(String.self, forKey: .id)
        
        // name 字段：可能使用 name 或 expert_name
        if let nameValue = try? container.decode(String.self, forKey: .name) {
            name = nameValue
        } else if let expertNameValue = try? container.decode(String.self, forKey: .expertName) {
            name = expertNameValue
        } else {
            throw DecodingError.keyNotFound(CodingKeys.name, DecodingError.Context(codingPath: container.codingPath, debugDescription: "Neither 'name' nor 'expert_name' found"))
        }
        
        avatar = try container.decodeIfPresent(String.self, forKey: .avatar)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        userLevel = try container.decodeIfPresent(String.self, forKey: .userLevel)
        
        // rating 字段：可能使用 avg_rating 或 rating
        if let avgRatingValue = try? container.decode(Double.self, forKey: .avgRating) {
            avgRating = avgRatingValue
            rating = avgRatingValue
        } else if let ratingValue = try? container.decode(Double.self, forKey: .rating) {
            avgRating = ratingValue
            rating = ratingValue
        } else {
            avgRating = nil
            rating = nil
        }
        
        completedTasks = try container.decodeIfPresent(Int.self, forKey: .completedTasks)
        
        // totalTasks 字段：可能使用 total_tasks 或 total_services
        if let totalTasksValue = try? container.decode(Int.self, forKey: .totalTasks) {
            totalTasks = totalTasksValue
            totalServices = nil
        } else if let totalServicesValue = try? container.decode(Int.self, forKey: .totalServices) {
            totalTasks = totalServicesValue
            totalServices = totalServicesValue
        } else {
            totalTasks = nil
            totalServices = nil
        }
        
        completionRate = try container.decodeIfPresent(Double.self, forKey: .completionRate)
        expertiseAreas = try container.decodeIfPresent([String].self, forKey: .expertiseAreas)
        featuredSkills = try container.decodeIfPresent([String].self, forKey: .featuredSkills)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        achievements = try container.decodeIfPresent([String].self, forKey: .achievements)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified)
        responseTime = try container.decodeIfPresent(String.self, forKey: .responseTime)
        successRate = try container.decodeIfPresent(Double.self, forKey: .successRate)
        location = try container.decodeIfPresent(String.self, forKey: .location)
        category = try container.decodeIfPresent(String.self, forKey: .category)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
    }
    
    // 自定义编码，使用标准字段名
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(avatar, forKey: .avatar)
        try container.encodeIfPresent(bio, forKey: .bio)
        try container.encodeIfPresent(userLevel, forKey: .userLevel)
        try container.encodeIfPresent(avgRating, forKey: .avgRating)
        try container.encodeIfPresent(completedTasks, forKey: .completedTasks)
        try container.encodeIfPresent(totalTasks, forKey: .totalTasks)
        try container.encodeIfPresent(completionRate, forKey: .completionRate)
        try container.encodeIfPresent(expertiseAreas, forKey: .expertiseAreas)
        try container.encodeIfPresent(featuredSkills, forKey: .featuredSkills)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(achievements, forKey: .achievements)
        try container.encodeIfPresent(isVerified, forKey: .isVerified)
        try container.encodeIfPresent(responseTime, forKey: .responseTime)
        try container.encodeIfPresent(successRate, forKey: .successRate)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
}

// 任务达人服务
struct TaskExpertService: Codable, Identifiable {
    let id: Int
    let expertId: String? // 后端返回的字段
    let serviceName: String
    let description: String?
    let images: [String]?
    let basePrice: Double
    let currency: String
    let status: String
    let hasTimeSlots: Bool?
    let participantsPerSlot: Int?
    let displayOrder: Int? // 后端返回的字段
    let viewCount: Int? // 后端返回的字段
    let applicationCount: Int? // 后端返回的字段
    let createdAt: String? // 后端返回的字段
    
    enum CodingKeys: String, CodingKey {
        case id, description, images, status, currency
        case expertId = "expert_id"
        case serviceName = "service_name"
        case basePrice = "base_price"
        case hasTimeSlots = "has_time_slots"
        case participantsPerSlot = "participants_per_slot"
        case displayOrder = "display_order"
        case viewCount = "view_count"
        case applicationCount = "application_count"
        case createdAt = "created_at"
    }
}

// 服务申请
struct ServiceApplication: Codable, Identifiable {
    let id: Int
    let serviceId: Int
    let serviceName: String?
    let expertId: String
    let expertName: String?
    let status: String
    let applicationMessage: String?
    let counterPrice: Double?
    let taskId: Int?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case serviceId = "service_id"
        case serviceName = "service_name"
        case expertId = "expert_id"
        case expertName = "expert_name"
        case applicationMessage = "application_message"
        case counterPrice = "counter_price"
        case taskId = "task_id"
        case createdAt = "created_at"
    }
}

struct ServiceApplicationListResponse: Codable {
    let items: [ServiceApplication]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case items, total, limit, offset
        case hasMore = "has_more"
    }
}

// 任务达人申请
struct TaskExpertApplication: Codable, Identifiable {
    let id: Int
    let userId: String
    let applicationMessage: String
    let status: String
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, status
        case userId = "user_id"
        case applicationMessage = "application_message"
        case createdAt = "created_at"
    }
}

// 服务时间段
struct ServiceTimeSlot: Codable, Identifiable {
    let id: Int
    let serviceId: Int
    let slotStartDatetime: String
    let slotEndDatetime: String
    let currentParticipants: Int
    let maxParticipants: Int
    let isAvailable: Bool
    let activityId: Int? // 关联的活动ID
    let hasActivity: Bool? // 是否有关联的活动
    let activityPrice: Double? // 活动价格
    let pricePerParticipant: Double? // 每个参与者的价格
    let isExpired: Bool? // 是否已过期
    
    enum CodingKeys: String, CodingKey {
        case id
        case serviceId = "service_id"
        case slotStartDatetime = "slot_start_datetime"
        case slotEndDatetime = "slot_end_datetime"
        case currentParticipants = "current_participants"
        case maxParticipants = "max_participants"
        case isAvailable = "is_available"
        case activityId = "activity_id"
        case hasActivity = "has_activity"
        case activityPrice = "activity_price"
        case pricePerParticipant = "price_per_participant"
        case isExpired = "is_expired"
    }
}

