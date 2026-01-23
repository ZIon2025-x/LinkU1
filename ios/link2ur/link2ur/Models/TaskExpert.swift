import Foundation

// 任务达人
struct TaskExpert: Codable, Identifiable {
    let id: String // user_id
    let name: String
    let avatar: String?
    let bio: String?
    let bioEn: String? // 英文个人简介
    let userLevel: String? // 后端返回的是字符串，如 "normal"
    let avgRating: Double?
    let completedTasks: Int?
    let totalTasks: Int?
    let completionRate: Double?
    let expertiseAreas: [String]?
    let expertiseAreasEn: [String]? // 英文专业领域
    let featuredSkills: [String]?
    let featuredSkillsEn: [String]? // 英文特色技能
    let status: String? // 改为可选，因为后端可能不返回
    let achievements: [String]? // 后端返回的字段
    let achievementsEn: [String]? // 英文成就徽章
    let isVerified: Bool? // 后端返回的字段
    let responseTime: String? // 后端返回的字段
    let responseTimeEn: String? // 英文响应时间
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
        case expertiseAreasEn = "expertise_areas_en"
        case featuredSkills = "featured_skills"
        case featuredSkillsEn = "featured_skills_en"
        case achievements
        case achievementsEn = "achievements_en"
        case isVerified = "is_verified"
        case responseTime = "response_time"
        case responseTimeEn = "response_time_en"
        case successRate = "success_rate"
        case createdAt = "created_at"
        case bioEn = "bio_en"
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
        bioEn = try container.decodeIfPresent(String.self, forKey: .bioEn)
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
        expertiseAreasEn = try container.decodeIfPresent([String].self, forKey: .expertiseAreasEn)
        featuredSkills = try container.decodeIfPresent([String].self, forKey: .featuredSkills)
        featuredSkillsEn = try container.decodeIfPresent([String].self, forKey: .featuredSkillsEn)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        achievements = try container.decodeIfPresent([String].self, forKey: .achievements)
        achievementsEn = try container.decodeIfPresent([String].self, forKey: .achievementsEn)
        isVerified = try container.decodeIfPresent(Bool.self, forKey: .isVerified)
        responseTime = try container.decodeIfPresent(String.self, forKey: .responseTime)
        responseTimeEn = try container.decodeIfPresent(String.self, forKey: .responseTimeEn)
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
        try container.encodeIfPresent(bioEn, forKey: .bioEn)
        try container.encodeIfPresent(userLevel, forKey: .userLevel)
        try container.encodeIfPresent(avgRating, forKey: .avgRating)
        try container.encodeIfPresent(completedTasks, forKey: .completedTasks)
        try container.encodeIfPresent(totalTasks, forKey: .totalTasks)
        try container.encodeIfPresent(completionRate, forKey: .completionRate)
        try container.encodeIfPresent(expertiseAreas, forKey: .expertiseAreas)
        try container.encodeIfPresent(expertiseAreasEn, forKey: .expertiseAreasEn)
        try container.encodeIfPresent(featuredSkills, forKey: .featuredSkills)
        try container.encodeIfPresent(featuredSkillsEn, forKey: .featuredSkillsEn)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(achievements, forKey: .achievements)
        try container.encodeIfPresent(achievementsEn, forKey: .achievementsEn)
        try container.encodeIfPresent(isVerified, forKey: .isVerified)
        try container.encodeIfPresent(responseTime, forKey: .responseTime)
        try container.encodeIfPresent(responseTimeEn, forKey: .responseTimeEn)
        try container.encodeIfPresent(successRate, forKey: .successRate)
        try container.encodeIfPresent(location, forKey: .location)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
    }
    
    // MARK: - 双语字段辅助方法
    
    /// 根据设备语言获取个人简介（优先使用英文，如果没有则使用中文）
    var localizedBio: String? {
        let currentLanguage = LocalizationHelper.currentLanguage
        if currentLanguage.lowercased().hasPrefix("zh") {
            // 中文环境：优先使用中文，如果没有则使用英文
            return bio?.isEmpty == false ? bio : (bioEn?.isEmpty == false ? bioEn : nil)
        } else {
            // 英文环境：优先使用英文，如果没有则使用中文
            return bioEn?.isEmpty == false ? bioEn : (bio?.isEmpty == false ? bio : nil)
        }
    }
    
    /// 根据设备语言获取专业领域（优先使用英文，如果没有则使用中文）
    var localizedExpertiseAreas: [String]? {
        let currentLanguage = LocalizationHelper.currentLanguage
        if currentLanguage.lowercased().hasPrefix("zh") {
            // 中文环境：优先使用中文，如果没有则使用英文
            return (expertiseAreas?.isEmpty == false) ? expertiseAreas : (expertiseAreasEn?.isEmpty == false ? expertiseAreasEn : nil)
        } else {
            // 英文环境：优先使用英文，如果没有则使用中文
            return (expertiseAreasEn?.isEmpty == false) ? expertiseAreasEn : (expertiseAreas?.isEmpty == false ? expertiseAreas : nil)
        }
    }
    
    /// 根据设备语言获取特色技能（优先使用英文，如果没有则使用中文）
    var localizedFeaturedSkills: [String]? {
        let currentLanguage = LocalizationHelper.currentLanguage
        if currentLanguage.lowercased().hasPrefix("zh") {
            // 中文环境：优先使用中文，如果没有则使用英文
            return (featuredSkills?.isEmpty == false) ? featuredSkills : (featuredSkillsEn?.isEmpty == false ? featuredSkillsEn : nil)
        } else {
            // 英文环境：优先使用英文，如果没有则使用中文
            return (featuredSkillsEn?.isEmpty == false) ? featuredSkillsEn : (featuredSkills?.isEmpty == false ? featuredSkills : nil)
        }
    }
    
    /// 根据设备语言获取成就徽章（优先使用英文，如果没有则使用中文）
    var localizedAchievements: [String]? {
        let currentLanguage = LocalizationHelper.currentLanguage
        if currentLanguage.lowercased().hasPrefix("zh") {
            // 中文环境：优先使用中文，如果没有则使用英文
            return (achievements?.isEmpty == false) ? achievements : (achievementsEn?.isEmpty == false ? achievementsEn : nil)
        } else {
            // 英文环境：优先使用英文，如果没有则使用中文
            return (achievementsEn?.isEmpty == false) ? achievementsEn : (achievements?.isEmpty == false ? achievements : nil)
        }
    }
    
    /// 根据设备语言获取响应时间（优先使用英文，如果没有则使用中文）
    var localizedResponseTime: String? {
        let currentLanguage = LocalizationHelper.currentLanguage
        if currentLanguage.lowercased().hasPrefix("zh") {
            // 中文环境：优先使用中文，如果没有则使用英文
            return responseTime?.isEmpty == false ? responseTime : (responseTimeEn?.isEmpty == false ? responseTimeEn : nil)
        } else {
            // 英文环境：优先使用英文，如果没有则使用中文
            return responseTimeEn?.isEmpty == false ? responseTimeEn : (responseTime?.isEmpty == false ? responseTime : nil)
        }
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
    // 用户申请的服务申请信息（如果已申请）
    let userApplicationId: Int? // 用户申请的服务申请ID
    let userApplicationStatus: String? // 申请状态
    let userTaskId: Int? // 申请后创建的任务ID（如果已批准）
    let userTaskStatus: String? // 任务状态
    let userTaskIsPaid: Bool? // 任务是否已支付
    let userApplicationHasNegotiation: Bool? // 是否有议价
    
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
        case userApplicationId = "user_application_id"
        case userApplicationStatus = "user_application_status"
        case userTaskId = "user_task_id"
        case userTaskStatus = "user_task_status"
        case userTaskIsPaid = "user_task_is_paid"
        case userApplicationHasNegotiation = "user_application_has_negotiation"
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

