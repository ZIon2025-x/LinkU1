import Foundation

// 任务达人
struct TaskExpert: Codable, Identifiable {
    let id: String // user_id
    let name: String
    let avatar: String?
    let bio: String?
    let userLevel: Int?
    let avgRating: Double?
    let completedTasks: Int?
    let totalTasks: Int?
    let completionRate: Double?
    let expertiseAreas: [String]?
    let featuredSkills: [String]?
    let status: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, avatar, bio, status
        case userLevel = "user_level"
        case avgRating = "avg_rating"
        case completedTasks = "completed_tasks"
        case totalTasks = "total_tasks"
        case completionRate = "completion_rate"
        case expertiseAreas = "expertise_areas"
        case featuredSkills = "featured_skills"
    }
}

// 任务达人服务
struct TaskExpertService: Codable, Identifiable {
    let id: Int
    let serviceName: String
    let description: String?
    let images: [String]?
    let basePrice: Double
    let currency: String
    let status: String
    let hasTimeSlots: Bool?
    let participantsPerSlot: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, description, images, status, currency
        case serviceName = "service_name"
        case basePrice = "base_price"
        case hasTimeSlots = "has_time_slots"
        case participantsPerSlot = "participants_per_slot"
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
    
    enum CodingKeys: String, CodingKey {
        case id
        case serviceId = "service_id"
        case slotStartDatetime = "slot_start_datetime"
        case slotEndDatetime = "slot_end_datetime"
        case currentParticipants = "current_participants"
        case maxParticipants = "max_participants"
        case isAvailable = "is_available"
    }
}

