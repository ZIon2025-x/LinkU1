import Foundation

struct Message: Codable, Identifiable {
    let id: Int
    let senderId: String?
    let receiverId: String?
    let content: String
    let msgType: MessageType?
    let createdAt: String
    let isRead: Int?
    let imageId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case receiverId = "receiver_id"
        case content
        case msgType = "type"
        case createdAt = "created_at"
        case isRead = "is_read"
        case imageId = "image_id"
    }
}

enum MessageType: String, Codable {
    case text = "text"
    case normal = "normal"
    case system = "system"
    case image = "image"
    case file = "file"
}

// 联系人/对话信息
struct Contact: Codable, Identifiable {
    let id: String // 用户ID
    let name: String?
    let avatar: String?
    let email: String?
    let lastMessageTime: String?
    let unreadCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, avatar, email
        case lastMessageTime = "last_message_time"
        case unreadCount = "unread_count"
    }
}

// 对话列表响应
struct ConversationListResponse: Codable {
    let contacts: [Contact]
    
    // 如果后端返回的是数组，直接解析
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        contacts = try container.decode([Contact].self)
    }
}

