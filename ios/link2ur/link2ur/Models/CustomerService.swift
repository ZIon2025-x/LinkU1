import Foundation

// MARK: - 客服对话相关模型

/// 客服分配响应
struct CustomerServiceAssignResponse: Codable {
    let service: CustomerServiceInfo?
    let chat: CustomerServiceChat?
    let error: String?
    let message: String?
    let queueStatus: CustomerServiceQueueStatus?
    let systemMessage: SystemMessage?
    
    enum CodingKeys: String, CodingKey {
        case service, chat, error, message
        case queueStatus = "queue_status"
        case systemMessage = "system_message"
    }
}

/// 客服信息
struct CustomerServiceInfo: Codable {
    let id: String
    let name: String
    let avatar: String?
    let avgRating: Double?
    let totalRatings: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, avatar
        case avgRating = "avg_rating"
        case totalRatings = "total_ratings"
    }
}

/// 客服会话
struct CustomerServiceChat: Codable, Identifiable {
    let chatId: String
    let userId: String
    let serviceId: String
    let isEnded: Int
    let createdAt: String?
    let totalMessages: Int?
    
    var id: String { chatId }
    
    enum CodingKeys: String, CodingKey {
        case chatId = "chat_id"
        case userId = "user_id"
        case serviceId = "service_id"
        case isEnded = "is_ended"
        case createdAt = "created_at"
        case totalMessages = "total_messages"
    }
}

/// 客服消息
struct CustomerServiceMessage: Codable, Identifiable {
    let messageId: Int? // 后端可能返回整数ID
    let chatId: String?
    let senderId: String?
    let senderType: String? // "user" 或 "customer_service"
    let content: String
    let messageType: String? // "text", "task_card", "image", "file"
    let taskId: Int?
    let imageId: String?
    let createdAt: String?
    let isRead: Bool?
    
    // Identifiable 协议要求的 id 属性
    var id: String {
        if let messageId = messageId {
            return "\(messageId)"
        } else {
            // 如果没有 id，使用其他字段组合作为标识
            let timestamp = createdAt ?? Date().ISO8601Format()
            return "\(senderId ?? "")_\(chatId ?? "")_\(timestamp)_\(UUID().uuidString.prefix(8))"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case messageId = "id"
        case chatId = "chat_id"
        case senderId = "sender_id"
        case senderType = "sender_type"
        case content
        case messageType = "message_type"
        case taskId = "task_id"
        case imageId = "image_id"
        case createdAt = "created_at"
        case isRead = "is_read"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 尝试解码为整数，如果失败则尝试字符串
        if let intId = try? container.decode(Int.self, forKey: .messageId) {
            messageId = intId
        } else if let stringId = try? container.decode(String.self, forKey: .messageId) {
            messageId = Int(stringId)
        } else {
            messageId = nil
        }
        
        chatId = try container.decodeIfPresent(String.self, forKey: .chatId)
        senderId = try container.decodeIfPresent(String.self, forKey: .senderId)
        senderType = try container.decodeIfPresent(String.self, forKey: .senderType)
        content = try container.decode(String.self, forKey: .content)
        messageType = try container.decodeIfPresent(String.self, forKey: .messageType)
        taskId = try container.decodeIfPresent(Int.self, forKey: .taskId)
        imageId = try container.decodeIfPresent(String.self, forKey: .imageId)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        
        // 后端返回 is_read 为整数 (0/1)，需要转换为 Bool
        if let isReadInt = try? container.decode(Int.self, forKey: .isRead) {
            isRead = isReadInt != 0
        } else if let isReadBool = try? container.decodeIfPresent(Bool.self, forKey: .isRead) {
            isRead = isReadBool
        } else {
            isRead = nil
        }
    }
}

/// 客服排队状态
struct CustomerServiceQueueStatus: Codable {
    let position: Int?
    let estimatedWaitTime: Int? // 预计等待时间（秒）
    let status: String? // "waiting", "assigned", "none"
    
    enum CodingKeys: String, CodingKey {
        case position
        case estimatedWaitTime = "estimated_wait_time"
        case status
    }
}

/// 系统消息
struct SystemMessage: Codable {
    let content: String
}
