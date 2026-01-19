import Foundation

public struct Message: Codable, Identifiable {
    let messageId: Int? // 后端返回的 id（可选）
    let senderId: String?
    let senderName: String? // 发送者名称
    let senderAvatar: String? // 发送者头像
    let receiverId: String?
    let content: String? // 改为可选，某些 WebSocket 消息可能没有 content
    let msgType: MessageType?
    let createdAt: String? // 改为可选，某些 WebSocket 消息可能没有 created_at
    let isRead: Bool? // 后端返回的是 bool，不是 int
    let imageId: String?
    let taskId: Int? // 任务ID（用于任务聊天消息）
    let attachments: [MessageAttachment]? // 消息附件（图片、文件等）
    
    // Identifiable 协议要求的 id 属性（非可选）
    public var id: String {
        if let messageId = messageId {
            return "\(messageId)"
        } else {
            // 如果没有 id，使用其他字段组合作为标识
            let timestamp = createdAt ?? Date().ISO8601Format()
            return "\(senderId ?? "")_\(receiverId ?? "")_\(timestamp)_\(UUID().uuidString.prefix(8))"
        }
    }
    
    /// 是否有图片附件
    var hasImageAttachment: Bool {
        attachments?.contains { $0.attachmentType == "image" } ?? false
    }
    
    /// 获取第一个图片附件的 URL
    var firstImageUrl: String? {
        attachments?.first { $0.attachmentType == "image" }?.url
    }
    
    enum CodingKeys: String, CodingKey {
        case messageId = "id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderAvatar = "sender_avatar"
        case receiverId = "receiver_id"
        case content
        case msgType = "message_type" // 后端返回的是 message_type，不是 type
        case createdAt = "created_at"
        case isRead = "is_read"
        case imageId = "image_id"
        case taskId = "task_id"
        case attachments
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 所有字段都改为可选，以支持不同类型的 WebSocket 消息
        messageId = try container.decodeIfPresent(Int.self, forKey: .messageId)
        senderId = try container.decodeIfPresent(String.self, forKey: .senderId)
        senderName = try container.decodeIfPresent(String.self, forKey: .senderName)
        senderAvatar = try container.decodeIfPresent(String.self, forKey: .senderAvatar)
        receiverId = try container.decodeIfPresent(String.self, forKey: .receiverId)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        msgType = try container.decodeIfPresent(MessageType.self, forKey: .msgType)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        isRead = try container.decodeIfPresent(Bool.self, forKey: .isRead)
        imageId = try container.decodeIfPresent(String.self, forKey: .imageId)
        taskId = try container.decodeIfPresent(Int.self, forKey: .taskId)
        attachments = try container.decodeIfPresent([MessageAttachment].self, forKey: .attachments)
    }
    
    // 实现编码
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(messageId, forKey: .messageId)
        try container.encodeIfPresent(senderId, forKey: .senderId)
        try container.encodeIfPresent(senderName, forKey: .senderName)
        try container.encodeIfPresent(senderAvatar, forKey: .senderAvatar)
        try container.encodeIfPresent(receiverId, forKey: .receiverId)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(msgType, forKey: .msgType)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(isRead, forKey: .isRead)
        try container.encodeIfPresent(imageId, forKey: .imageId)
        try container.encodeIfPresent(taskId, forKey: .taskId)
        try container.encodeIfPresent(attachments, forKey: .attachments)
    }
}

/// 消息附件模型
public struct MessageAttachment: Codable, Identifiable {
    private let _id: Int?
    public let attachmentType: String // "image", "file" 等
    public let url: String?
    public let blobId: String?
    public let meta: AttachmentMeta?
    
    // Identifiable 需要非可选 id
    public var id: Int {
        _id ?? url.hashValue
    }
    
    enum CodingKeys: String, CodingKey {
        case _id = "id"
        case attachmentType = "attachment_type"
        case url
        case blobId = "blob_id"
        case meta
    }
}

/// 附件元数据
public struct AttachmentMeta: Codable {
    public let originalFilename: String?
    public let width: Int?
    public let height: Int?
    public let size: Int?
    
    enum CodingKeys: String, CodingKey {
        case originalFilename = "original_filename"
        case width, height, size
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

// 任务聊天消息响应（简单版本，用于通用消息列表）
// 注意：完整的 TaskMessagesResponse（包含 task 字段）定义在 APIService+Chat.swift 中
struct SimpleTaskMessagesResponse: Decodable {
    let messages: [Message]
    let nextCursor: String?
    let hasMore: Bool?
    
    enum CodingKeys: String, CodingKey {
        case messages
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        messages = try container.decode([Message].self, forKey: .messages)
        nextCursor = try container.decodeIfPresent(String.self, forKey: .nextCursor)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore)
    }
}

