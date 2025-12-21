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

