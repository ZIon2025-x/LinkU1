import Foundation

/// 退款申请模型
struct RefundRequest: Codable, Identifiable {
    let id: Int
    let taskId: Int
    let posterId: String
    let reasonType: String?  // 退款原因类型
    let refundType: String?  // 退款类型（full/partial）
    let reason: String
    let evidenceFiles: [String]?
    let refundAmount: Double?
    let refundPercentage: Double?  // 退款比例
    let status: String  // pending, approved, rejected, processing, completed, cancelled
    let adminComment: String?
    let reviewedBy: String?
    let reviewedAt: String?
    let refundIntentId: String?
    let refundTransferId: String?
    let processedAt: String?
    let completedAt: String?
    let createdAt: String
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case taskId = "task_id"
        case posterId = "poster_id"
        case reasonType = "reason_type"
        case refundType = "refund_type"
        case reason
        case evidenceFiles = "evidence_files"
        case refundAmount = "refund_amount"
        case refundPercentage = "refund_percentage"
        case status
        case adminComment = "admin_comment"
        case reviewedBy = "reviewed_by"
        case reviewedAt = "reviewed_at"
        case refundIntentId = "refund_intent_id"
        case refundTransferId = "refund_transfer_id"
        case processedAt = "processed_at"
        case completedAt = "completed_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

/// 创建退款申请请求
struct RefundRequestCreate: Codable {
    let reasonType: String
    let reason: String
    let refundType: String
    let evidenceFiles: [String]?
    let refundAmount: Double?
    let refundPercentage: Double?
    
    enum CodingKeys: String, CodingKey {
        case reasonType = "reason_type"
        case reason
        case refundType = "refund_type"
        case evidenceFiles = "evidence_files"
        case refundAmount = "refund_amount"
        case refundPercentage = "refund_percentage"
    }
}

/// 退款原因类型
enum RefundReasonType: String, CaseIterable {
    case completionTimeUnsatisfactory = "completion_time_unsatisfactory"
    case notCompleted = "not_completed"
    case qualityIssue = "quality_issue"
    case other = "other"
    
    var displayName: String {
        switch self {
        case .completionTimeUnsatisfactory:
            return "对完成时间不满意"
        case .notCompleted:
            return "接单者完全未完成"
        case .qualityIssue:
            return "质量问题"
        case .other:
            return "其他"
        }
    }
}
