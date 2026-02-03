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
    let posterUserLevel: String?  // 发布者会员等级：用于「会员发布」角标
    let pointsReward: Int?
    let isMultiParticipant: Bool?
    let maxParticipants: Int?
    let minParticipants: Int?
    let currentParticipants: Int?
    let poster: User?  // 后端可能返回 poster 对象
    let isRecommended: Bool?  // 是否为推荐任务
    let matchScore: Double?  // 推荐匹配分数
    let recommendationReason: String?  // 推荐原因
    let taskSource: String?  // 任务来源：normal（普通任务）、expert_service（达人服务）、expert_activity（达人活动）、flea_market（跳蚤市场）
    let confirmationDeadline: String?  // 确认截止时间（completed_at + 5天）
    let confirmedAt: String?  // 实际确认时间
    let autoConfirmed: Bool?  // 是否自动确认
    let confirmationReminderSent: Int?  // 提醒状态位掩码
    let paymentExpiresAt: String?  // 支付过期时间（ISO 格式），待支付任务有效
    /// 当前用户是否已申请（与活动详情一致，由任务详情接口返回，用于直接显示「已申请」状态）
    let hasApplied: Bool?
    /// 当前用户申请状态：pending / approved / rejected
    let userApplicationStatus: String?
    /// 任务完成证据（接单者标记完成时上传的图片/文件与文字说明，仅当任务已标记完成时返回）
    let completionEvidence: [EvidenceItem]?
    
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
        case posterUserLevel = "poster_user_level"
        case pointsReward = "points_reward"
        case isMultiParticipant = "is_multi_participant"
        case maxParticipants = "max_participants"
        case minParticipants = "min_participants"
        case currentParticipants = "current_participants"
        case poster
        case isRecommended = "is_recommended"
        case matchScore = "match_score"
        case recommendationReason = "recommendation_reason"
        case taskSource = "task_source"
        case confirmationDeadline = "confirmation_deadline"
        case confirmedAt = "confirmed_at"
        case autoConfirmed = "auto_confirmed"
        case confirmationReminderSent = "confirmation_reminder_sent"
        case paymentExpiresAt = "payment_expires_at"
        case hasApplied = "has_applied"
        case userApplicationStatus = "user_application_status"
        case completionEvidence = "completion_evidence"
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
    
    /// 是否为跳蚤市场任务
    var isFleaMarketTask: Bool {
        return taskSource == "flea_market"
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
    let titleEn: String?  // 英文标题
    let titleZh: String?  // 中文标题
    let description: String
    let taskType: String
    let location: String
    let reward: Double
    let deadline: String?
    let taskLevel: String?
    let matchScore: Double?
    let recommendationReason: String?
    let createdAt: String
    let images: [String]?  // 图片字段
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case title
        case titleEn = "title_en"
        case titleZh = "title_zh"
        case description
        case taskType = "task_type"
        case location
        case reward
        case deadline
        case taskLevel = "task_level"
        case matchScore = "match_score"
        case recommendationReason = "recommendation_reason"
        case createdAt = "created_at"
        case images
    }
    
    /// 转换为 Task 对象
    func toTask() -> Task {
        return Task(
            id: taskId,
            title: title,
            titleEn: titleEn,  // 使用后端返回的英文翻译
            titleZh: titleZh,  // 使用后端返回的中文翻译
            description: description,
            descriptionEn: nil,  // 描述翻译暂时不返回
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
            images: images,  // 使用后端返回的图片数据
            createdAt: createdAt,
            deadline: deadline,
            isFlexible: nil,
            isPublic: 1,
            posterId: nil,
            takerId: nil,
            originatingUserId: nil,
            taskLevel: taskLevel,
            posterUserLevel: nil,
            pointsReward: nil,
            isMultiParticipant: nil,
            maxParticipants: nil,
            minParticipants: nil,
            currentParticipants: nil,
            poster: nil,
            isRecommended: true,
            matchScore: matchScore,
            recommendationReason: recommendationReason,
            taskSource: nil,  // 推荐任务默认为普通任务
            confirmationDeadline: nil,
            confirmedAt: nil,
            autoConfirmed: nil,
            confirmationReminderSent: nil,
            paymentExpiresAt: nil,
            hasApplied: nil,
            userApplicationStatus: nil
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

// 公开评价模型（不包含评价人私人信息）
struct PublicReview: Codable, Identifiable {
    let id: Int
    let taskId: Int
    let rating: Double
    let comment: String?
    let createdAt: String
    
    enum CodingKeys: String, CodingKey {
        case id, rating, comment
        case taskId = "task_id"
        case createdAt = "created_at"
    }
}
