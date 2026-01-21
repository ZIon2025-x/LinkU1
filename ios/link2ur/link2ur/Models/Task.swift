import Foundation
import CoreLocation

struct Task: Codable, Identifiable, Equatable {
    let id: Int
    let title: String
    let titleEn: String?  // 英文标题（可选）
    let titleZh: String?  // 中文标题（可选）
    let description: String
    let descriptionEn: String?  // 英文描述（可选）
    let descriptionZh: String?  // 中文描述（可选）
    let taskType: String  // 后端使用 task_type
    let location: String  // 后端使用 location（不是 city）
    let latitude: Double?  // 纬度（用于地图选点和距离计算）
    let longitude: Double?  // 经度（用于地图选点和距离计算）
    let reward: Double  // 后端使用 reward（不是 price）
    let baseReward: Double?
    let agreedReward: Double?
    let currency: String?
    let status: TaskStatus
    let images: [String]?
    let createdAt: String
    let deadline: String?
    let isFlexible: Int?
    let isPublic: Int?
    let posterId: String?  // 后端使用 poster_id
    let takerId: String?  // 后端使用 taker_id
    let originatingUserId: String?  // 后端使用 originating_user_id（申请活动创建的任务的申请人ID）
    let taskLevel: String?
    let pointsReward: Int?
    let isMultiParticipant: Bool?
    let maxParticipants: Int?
    let minParticipants: Int?
    let currentParticipants: Int?
    let poster: User?  // 后端可能返回 poster 对象
    let isRecommended: Bool?  // 是否为推荐任务
    let matchScore: Double?  // 推荐匹配分数
    let recommendationReason: String?  // 推荐原因
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status, images, currency, latitude, longitude
        case titleEn = "title_en"
        case titleZh = "title_zh"
        case descriptionEn = "description_en"
        case descriptionZh = "description_zh"
        case taskType = "task_type"
        case location
        case reward
        case baseReward = "base_reward"
        case agreedReward = "agreed_reward"
        case createdAt = "created_at"
        case deadline
        case isFlexible = "is_flexible"
        case isPublic = "is_public"
        case posterId = "poster_id"
        case takerId = "taker_id"
        case originatingUserId = "originating_user_id"
        case taskLevel = "task_level"
        case pointsReward = "points_reward"
        case isMultiParticipant = "is_multi_participant"
        case maxParticipants = "max_participants"
        case minParticipants = "min_participants"
        case currentParticipants = "current_participants"
        case poster
        case isRecommended = "is_recommended"
        case matchScore = "match_score"
        case recommendationReason = "recommendation_reason"
    }
    
    // 兼容旧代码的 computed properties
    var category: String { taskType }
    var city: String { location }
    var price: Double? { reward }
    var author: User? { poster }
    
    /// 任务坐标（如果有经纬度）
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
    
    /// 计算距离用户当前位置的距离（公里）
    func distanceFromUser() -> Double? {
        guard let taskCoord = coordinate,
              let userLocation = LocationService.shared.currentLocation else {
            return nil
        }
        let userCoord = CLLocationCoordinate2D(
            latitude: userLocation.latitude, 
            longitude: userLocation.longitude
        )
        return taskCoord.distance(to: userCoord)
    }
    
    /// 格式化的距离字符串
    var formattedDistanceFromUser: String? {
        guard let distance = distanceFromUser() else { return nil }
        return distance.formattedAsDistance
    }
    
    /// 是否为线上任务
    var isOnline: Bool {
        location.lowercased() == "online"
    }
    
    /// 根据当前语言获取显示标题
    var displayTitle: String {
        let language = LocalizationHelper.currentLanguage
        if language.hasPrefix("zh") {
            return titleZh?.isEmpty == false ? titleZh! : title
        } else {
            return titleEn?.isEmpty == false ? titleEn! : title
        }
    }
    
    /// 根据当前语言获取显示描述
    var displayDescription: String {
        let language = LocalizationHelper.currentLanguage
        if language.hasPrefix("zh") {
            return descriptionZh?.isEmpty == false ? descriptionZh! : description
        } else {
            return descriptionEn?.isEmpty == false ? descriptionEn! : description
        }
    }
}

enum TaskStatus: String, Codable {
    case open = "open"
    case inProgress = "in_progress"
    case completed = "completed"
    case cancelled = "cancelled"
    case pendingConfirmation = "pending_confirmation"
    case pendingPayment = "pending_payment"
    
    var displayText: String {
        switch self {
        case .open: return LocalizationKey.taskStatusOpen.localized
        case .inProgress: return LocalizationKey.taskStatusInProgress.localized
        case .completed: return LocalizationKey.taskStatusCompleted.localized
        case .cancelled: return LocalizationKey.taskStatusCancelled.localized
        case .pendingConfirmation: return LocalizationKey.taskStatusPendingConfirmation.localized
        case .pendingPayment: return LocalizationKey.taskStatusPendingPayment.localized
        }
    }
}

// MARK: - 推荐任务响应模型
struct RecommendationTask: Codable {
    let taskId: Int
    let title: String
    let description: String
    let taskType: String
    let location: String
    let reward: Double
    let deadline: String?
    let taskLevel: String?
    let matchScore: Double?
    let recommendationReason: String?
    let createdAt: String
    let images: [String]?  // 添加图片字段
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case title
        case description
        case taskType = "task_type"
        case location
        case reward
        case deadline
        case taskLevel = "task_level"
        case matchScore = "match_score"
        case recommendationReason = "recommendation_reason"
        case createdAt = "created_at"
        case images  // 添加图片字段的 CodingKey
    }
    
    /// 转换为 Task 对象
    func toTask() -> Task {
        return Task(
            id: taskId,
            title: title,
            titleEn: nil,  // 推荐任务可能没有翻译
            titleZh: nil,
            description: description,
            descriptionEn: nil,
            descriptionZh: nil,
            taskType: taskType,
            location: location,
            latitude: nil,
            longitude: nil,
            reward: reward,
            baseReward: reward,
            agreedReward: nil,
            currency: nil,
            status: .open, // 推荐任务默认是开放状态
            images: images,  // 使用实际的图片数据，而不是 nil
            createdAt: createdAt,
            deadline: deadline,
            isFlexible: nil,
            isPublic: 1,
            posterId: nil,
            takerId: nil,
            originatingUserId: nil,
            taskLevel: taskLevel,
            pointsReward: nil,
            isMultiParticipant: nil,
            maxParticipants: nil,
            minParticipants: nil,
            currentParticipants: nil,
            poster: nil,
            isRecommended: true,
            matchScore: matchScore,
            recommendationReason: recommendationReason
        )
    }
}

struct TaskRecommendationResponse: Codable {
    let recommendations: [RecommendationTask]
}

struct TaskListResponse: Codable {
    let tasks: [Task]
    let total: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case tasks
        case total
        case page
        case pageSize = "page_size"
    }
}

// 任务评价模型
struct Review: Codable, Identifiable {
    let id: Int
    let taskId: Int
    let reviewerId: String
    let revieweeId: String
    let rating: Double
    let comment: String?
    let isAnonymous: Bool?
    let createdAt: String
    let reviewer: User?
    
    enum CodingKeys: String, CodingKey {
        case id, rating, comment
        case taskId = "task_id"
        case reviewerId = "reviewer_id"
        case revieweeId = "reviewee_id"
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
        case reviewer
    }
}
