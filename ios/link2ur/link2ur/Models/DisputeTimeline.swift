import Foundation

/// 争议时间线响应
struct DisputeTimelineResponse: Codable {
    let taskId: Int
    let taskTitle: String
    let timeline: [TimelineItem]
    
    enum CodingKeys: String, CodingKey {
        case taskId = "task_id"
        case taskTitle = "task_title"
        case timeline
    }
}

/// 时间线项
struct TimelineItem: Codable, Identifiable {
    let id: String  // 使用timestamp+type作为唯一ID
    let type: String  // task_completed, task_confirmed, refund_request, rebuttal, admin_review, dispute, dispute_resolution
    let title: String
    let description: String
    let timestamp: String?
    let actor: String  // poster, taker, admin
    let evidence: [EvidenceItem]?
    let reasonType: String?
    let refundType: String?
    let refundAmount: Double?
    let status: String?
    let reviewerName: String?
    let resolverName: String?
    let refundRequestId: Int?
    let disputeId: Int?
    
    enum CodingKeys: String, CodingKey {
        case type, title, description, timestamp, actor, evidence, status
        case reasonType = "reason_type"
        case refundType = "refund_type"
        case refundAmount = "refund_amount"
        case reviewerName = "reviewer_name"
        case resolverName = "resolver_name"
        case refundRequestId = "refund_request_id"
        case disputeId = "dispute_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        timestamp = try container.decodeIfPresent(String.self, forKey: .timestamp)
        actor = try container.decode(String.self, forKey: .actor)
        evidence = try container.decodeIfPresent([EvidenceItem].self, forKey: .evidence)
        reasonType = try container.decodeIfPresent(String.self, forKey: .reasonType)
        refundType = try container.decodeIfPresent(String.self, forKey: .refundType)
        refundAmount = try container.decodeIfPresent(Double.self, forKey: .refundAmount)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        reviewerName = try container.decodeIfPresent(String.self, forKey: .reviewerName)
        resolverName = try container.decodeIfPresent(String.self, forKey: .resolverName)
        refundRequestId = try container.decodeIfPresent(Int.self, forKey: .refundRequestId)
        disputeId = try container.decodeIfPresent(Int.self, forKey: .disputeId)
        
        // 生成唯一ID
        id = "\(type)_\(timestamp ?? "")_\(refundRequestId ?? 0)_\(disputeId ?? 0)"
    }
}

/// 证据项（支持图片/文件 URL 与文字说明）
struct EvidenceItem: Codable, Identifiable, Equatable {
    let id: String
    let type: String
    let url: String?
    let fileId: String?
    let content: String?
    
    enum CodingKeys: String, CodingKey {
        case type, url, content
        case fileId = "file_id"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        url = try container.decodeIfPresent(String.self, forKey: .url)
        fileId = try container.decodeIfPresent(String.self, forKey: .fileId)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        id = fileId ?? url ?? content ?? UUID().uuidString
    }
    
    /// 可用于展示的 URL（图片/文件类型）
    var displayURL: String? {
        if type == "text" { return nil }
        return url?.isEmpty == false ? url : nil
    }
}
