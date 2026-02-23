import Foundation

// MARK: - Activity (活动)

struct Activity: Codable, Identifiable {
    let id: Int
    let title: String
    let description: String
    let expertId: String
    let expertServiceId: Int?
    let location: String
    let taskType: String
    let rewardType: String
    let originalPricePerParticipant: Double
    let discountPercentage: Double?
    let discountedPricePerParticipant: Double?
    let currency: String
    let pointsReward: Int?
    let maxParticipants: Int
    let minParticipants: Int
    let currentParticipants: Int // 动态计算字段
    let status: String
    let isPublic: Bool
    let deadline: String?
    let activityEndDate: String?
    let images: [String]?
    let hasTimeSlots: Bool
    let hasApplied: Bool? // 当前用户是否已申请（可选，需要用户认证）
    // 用户申请的任务信息（如果已申请）
    let userTaskId: Int? // 用户申请后创建的任务ID
    let userTaskStatus: String? // 任务状态
    let userTaskIsPaid: Bool? // 任务是否已支付
    let userTaskHasNegotiation: Bool? // 是否有议价
    let activityType: String? // 活动类型：lottery / first_come
    let prizeType: String? // 奖品类型
    let prizeDescription: String? // 奖品描述
    let prizeDescriptionEn: String? // 奖品描述（英文）
    let prizeCount: Int? // 奖品数量
    let drawMode: String? // 抽奖模式
    let drawAt: String? // 计划抽奖时间
    let drawnAt: String? // 实际抽奖时间
    let winners: [ActivityWinner]? // 中奖者列表
    let isDrawn: Bool? // 是否已抽奖
    let isOfficial: Bool? // 是否为官方活动
    let currentApplicants: Int? // 当前申请人数（抽奖活动专用）
    
    enum CodingKeys: String, CodingKey {
        case id, title, description
        case expertId = "expert_id"
        case expertServiceId = "expert_service_id"
        case location
        case taskType = "task_type"
        case rewardType = "reward_type"
        case originalPricePerParticipant = "original_price_per_participant"
        case discountPercentage = "discount_percentage"
        case discountedPricePerParticipant = "discounted_price_per_participant"
        case currency
        case pointsReward = "points_reward"
        case maxParticipants = "max_participants"
        case minParticipants = "min_participants"
        case currentParticipants = "current_participants"
        case status
        case isPublic = "is_public"
        case deadline
        case activityEndDate = "activity_end_date"
        case images
        case hasTimeSlots = "has_time_slots"
        case hasApplied = "has_applied"
        case userTaskId = "user_task_id"
        case userTaskStatus = "user_task_status"
        case userTaskIsPaid = "user_task_is_paid"
        case userTaskHasNegotiation = "user_task_has_negotiation"
        case activityType = "activity_type"
        case prizeType = "prize_type"
        case prizeDescription = "prize_description"
        case prizeDescriptionEn = "prize_description_en"
        case prizeCount = "prize_count"
        case drawMode = "draw_mode"
        case drawAt = "draw_at"
        case drawnAt = "drawn_at"
        case winners
        case isDrawn = "is_drawn"
        case isOfficial = "is_official"
        case currentApplicants = "current_applicants"
    }
    
    /// 活动是否已结束（状态为 ended/cancelled/completed 或已过截止日期/结束日期）
    var isEnded: Bool {
        // 检查状态
        let endedStatuses = ["ended", "cancelled", "completed", "closed"]
        if endedStatuses.contains(status.lowercased()) {
            return true
        }
        
        // 检查截止日期
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        let now = Date()
        
        // 检查 activityEndDate
        if let endDateStr = activityEndDate,
           let endDate = dateFormatter.date(from: endDateStr) ?? parseDate(endDateStr) {
            if endDate < now {
                return true
            }
        }
        
        // 检查 deadline
        if let deadlineStr = deadline,
           let deadlineDate = dateFormatter.date(from: deadlineStr) ?? parseDate(deadlineStr) {
            if deadlineDate < now {
                return true
            }
        }
        
        return false
    }
    
    /// 是否满员
    var isFull: Bool {
        currentParticipants >= maxParticipants
    }
    
    /// 是否可以申请
    var canApply: Bool {
        !isEnded && !isFull
    }
    
    // Is lottery activity
    var isLottery: Bool { activityType == "lottery" }
    
    // Is first-come-first-served activity
    var isFirstCome: Bool { activityType == "first_come" }
    
    // Is official activity (lottery or first-come)
    var isOfficialActivity: Bool { activityType == "lottery" || activityType == "first_come" }
    
    /// 辅助方法：解析日期字符串
    private func parseDate(_ dateStr: String) -> Date? {
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSZ",
            "yyyy-MM-dd'T'HH:mm:ssZ",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd"
        ]
        
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        
        for format in formats {
            formatter.dateFormat = format
            if let date = formatter.date(from: dateStr) {
                return date
            }
        }
        return nil
    }
}

// MARK: - Activity Winner & Official Result

struct ActivityWinner: Codable, Identifiable {
    let userId: String
    let name: String
    let avatarUrl: String?
    let prizeIndex: Int?
    
    var id: String { userId }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case name
        case avatarUrl = "avatar_url"
        case prizeIndex = "prize_index"
    }
}

struct OfficialActivityResult: Codable {
    let isDrawn: Bool
    let drawnAt: String?
    let winners: [ActivityWinner]
    let myStatus: String?
    let myVoucherCode: String?
    
    enum CodingKeys: String, CodingKey {
        case isDrawn = "is_drawn"
        case drawnAt = "drawn_at"
        case winners
        case myStatus = "my_status"
        case myVoucherCode = "my_voucher_code"
    }
}

// MARK: - Task Participant (任务参与者)

struct TaskParticipant: Codable, Identifiable {
    let id: Int
    let taskId: String // 后端可能是 Int 或 String，schema 中用 format_task_id 处理
    let userId: String
    let userName: String?
    let userAvatar: String?
    let status: String
    let timeSlotId: Int?
    let appliedAt: String?
    let acceptedAt: String?
    let startedAt: String?
    let completedAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case status
        case timeSlotId = "time_slot_id"
        case appliedAt = "applied_at"
        case acceptedAt = "accepted_at"
        case startedAt = "started_at"
        case completedAt = "completed_at"
    }
}

struct TaskParticipantsResponse: Codable {
    let participants: [TaskParticipant]
    let total: Int
}

// MARK: - Request Models

struct ActivityApplyRequest: Encodable {
    let timeSlotId: Int?
    let preferredDeadline: String?
    let isFlexibleTime: Bool
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case timeSlotId = "time_slot_id"
        case preferredDeadline = "preferred_deadline"
        case isFlexibleTime = "is_flexible_time"
        case idempotencyKey = "idempotency_key"
    }
}

struct TaskApplyRequest: Encodable {
    let timeSlotId: Int?
    let preferredDeadline: String?
    let isFlexibleTime: Bool
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case timeSlotId = "time_slot_id"
        case preferredDeadline = "preferred_deadline"
        case isFlexibleTime = "is_flexible_time"
        case idempotencyKey = "idempotency_key"
    }
}

struct TaskParticipantCompleteRequest: Encodable {
    let completionNotes: String?
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case completionNotes = "completion_notes"
        case idempotencyKey = "idempotency_key"
    }
}

struct TaskParticipantExitRequest: Encodable {
    let exitReason: String
    let idempotencyKey: String
    
    enum CodingKeys: String, CodingKey {
        case exitReason = "exit_reason"
        case idempotencyKey = "idempotency_key"
    }
}

// MARK: - Activity Favorite Response Models

struct ActivityFavoriteToggleResponse: Decodable {
    let success: Bool
    let data: ActivityFavoriteData
    let message: String?
    
    struct ActivityFavoriteData: Decodable {
        let isFavorited: Bool
        
        enum CodingKeys: String, CodingKey {
            case isFavorited = "is_favorited"
        }
    }
}

struct ActivityFavoriteStatusResponse: Decodable {
    let success: Bool
    let data: ActivityFavoriteStatusData
    
    struct ActivityFavoriteStatusData: Decodable {
        let isFavorited: Bool
        let favoriteCount: Int
        
        enum CodingKeys: String, CodingKey {
            case isFavorited = "is_favorited"
            case favoriteCount = "favorite_count"
        }
    }
}

// 我的活动响应（用于获取收藏的活动ID列表）
// 简化版本：只包含我们需要的字段
struct MyActivitiesResponse: Decodable {
    let success: Bool
    let data: MyActivitiesData
    
    struct MyActivitiesData: Decodable {
        // 只解码 id 字段，忽略其他字段
        let activities: [ActivityIdOnly]
        let total: Int
        let limit: Int
        let offset: Int
        let hasMore: Bool
        
        enum CodingKeys: String, CodingKey {
            case activities, total, limit, offset
            case hasMore = "has_more"
        }
    }
    
    // 只包含 id 的活动模型（用于提取收藏的活动ID）
    struct ActivityIdOnly: Decodable {
        let id: Int
    }
}

// 我的活动完整响应（用于"我的活动"页面，包含完整的活动信息）
struct MyActivitiesFullResponse: Decodable {
    let success: Bool
    let data: MyActivitiesFullData
    
    struct MyActivitiesFullData: Decodable {
        let activities: [ActivityWithType]
        let total: Int
        let limit: Int
        let offset: Int
        let hasMore: Bool
        
        enum CodingKeys: String, CodingKey {
            case activities, total, limit, offset
            case hasMore = "has_more"
        }
    }
}

