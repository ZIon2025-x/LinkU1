import Foundation

// 系统通知
struct SystemNotification: Codable, Identifiable, Equatable {
    let id: Int
    let userId: String?  // 后端返回 user_id
    let title: String
    let content: String
    let type: String?
    let isRead: Int?
    let createdAt: String
    let relatedId: Int?  // 后端返回 related_id
    let link: String?  // iOS 扩展字段，可能为空
    let taskId: Int?  // 对于 application_message 和 negotiation_offer 类型，存储 task_id
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, content, type
        case isRead = "is_read"
        case createdAt = "created_at"
        case relatedId = "related_id"
        case link  // 可选字段，如果后端不返回则为 nil
        case taskId = "task_id"  // 可选字段，后端可能返回
    }
    
    // 创建一个标记为已读的新实例
    func markingAsRead() -> SystemNotification {
        return SystemNotification(
            id: self.id,
            userId: self.userId,
            title: self.title,
            content: self.content,
            type: self.type,
            isRead: 1,
            createdAt: self.createdAt,
            relatedId: self.relatedId,
            link: self.link,
            taskId: self.taskId
        )
    }
}

// 任务聊天项（用于任务聊天列表）
struct TaskChatItem: Codable, Identifiable, Equatable {
    let id: Int // 任务ID
    let title: String
    let taskType: String?
    let posterId: String?
    let takerId: String?
    let status: String?
    let taskStatus: String?
    let unreadCount: Int?
    let lastMessageTime: String?
    let lastMessage: LastMessage?
    let images: [String]? // 任务图片
    
    // 多人任务字段
    let isMultiParticipant: Bool?
    let expertCreatorId: String?
    
    enum CodingKeys: String, CodingKey {
        case id, title, status, images
        case taskType = "task_type"
        case posterId = "poster_id"
        case takerId = "taker_id"
        case lastMessageTime = "last_message_time"
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
        case taskStatus = "task_status"
        case isMultiParticipant = "is_multi_participant"
        case expertCreatorId = "expert_creator_id"
    }
    
    // 自定义解码，如果 last_message_time 不存在，从 last_message.created_at 提取
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        taskType = try container.decodeIfPresent(String.self, forKey: .taskType)
        posterId = try container.decodeIfPresent(String.self, forKey: .posterId)
        takerId = try container.decodeIfPresent(String.self, forKey: .takerId)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        taskStatus = try container.decodeIfPresent(String.self, forKey: .taskStatus)
        unreadCount = try container.decodeIfPresent(Int.self, forKey: .unreadCount)
        
        // images 字段可能是数组或字典，需要特殊处理
        if container.contains(.images) {
            // 先尝试作为数组解码
            if let imagesArray = try? container.decode([String].self, forKey: .images) {
                images = imagesArray
            } else {
                // 如果是字典或其他格式，设置为空数组
                images = []
            }
        } else {
            images = nil
        }
        
        isMultiParticipant = try container.decodeIfPresent(Bool.self, forKey: .isMultiParticipant)
        expertCreatorId = try container.decodeIfPresent(String.self, forKey: .expertCreatorId)
        
        // 先解码 lastMessage
        lastMessage = try container.decodeIfPresent(LastMessage.self, forKey: .lastMessage)
        
        // 如果 last_message_time 存在，使用它；否则从 last_message.created_at 提取
        do {
            if let lastMessageTimeValue = try container.decodeIfPresent(String.self, forKey: .lastMessageTime),
               !lastMessageTimeValue.isEmpty {
                lastMessageTime = lastMessageTimeValue
            } else {
                // 从 last_message.created_at 提取
                lastMessageTime = lastMessage?.createdAt
            }
        } catch {
            // 如果解码失败，从 last_message.created_at 提取
            lastMessageTime = lastMessage?.createdAt
        }
    }
}

// 最后一条消息
struct LastMessage: Codable, Equatable {
    let id: Int?
    let content: String?
    let senderId: String?
    let senderName: String?
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id, content
        case senderId = "sender_id"
        case senderName = "sender_name"
        case createdAt = "created_at"
    }
}

// 任务聊天列表响应
struct TaskChatListResponse: Decodable {
    let taskChats: [TaskChatItem]
    
    // 支持多种格式：包装对象 {tasks: [...]} 或 {task_chats: [...]} 或直接数组 [...]
    init(from decoder: Decoder) throws {
        // 先尝试作为包装对象解析
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // 尝试不同的键名（按Web端格式优先）
        if container.contains(.tasks) {
            // 尝试解码 tasks 数组，如果部分项解码失败，只保留成功的项
            let tasksArray = try container.decode([TaskChatItem].self, forKey: .tasks)
            taskChats = tasksArray
        } else if container.contains(.taskChatsSnake) {
            taskChats = try container.decode([TaskChatItem].self, forKey: .taskChatsSnake)
        } else if container.contains(.taskChatsCamel) {
            taskChats = try container.decode([TaskChatItem].self, forKey: .taskChatsCamel)
        } else {
            // 如果都失败，尝试直接数组格式
            let singleContainer = try decoder.singleValueContainer()
            taskChats = try singleContainer.decode([TaskChatItem].self)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case tasks // Web端使用的键名
        case taskChatsSnake = "task_chats"
        case taskChatsCamel = "taskChats"
    }
}

// 通知列表响应
struct NotificationListResponse: Decodable {
    let notifications: [SystemNotification]
    
    // 支持两种格式：包装对象 {notifications: [...]} 或直接数组 [...]
    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            notifications = try container.decode([SystemNotification].self, forKey: .notifications)
        } else {
            let container = try decoder.singleValueContainer()
            notifications = try container.decode([SystemNotification].self)
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case notifications
    }
}

// 论坛通知（ForumNotificationOut）
struct ForumNotification: Codable, Identifiable {
    let id: Int
    let notificationType: String  // notification_type
    let targetType: String        // target_type: "post" 或 "reply"
    let targetId: Int             // target_id
    let postId: Int?              // post_id（当target_type="reply"时，表示该回复所属的帖子ID）
    let fromUser: User?           // from_user
    let isRead: Bool              // is_read (注意是Bool，不是Int)
    let createdAt: String        // created_at
    
    enum CodingKeys: String, CodingKey {
        case id
        case notificationType = "notification_type"
        case targetType = "target_type"
        case targetId = "target_id"
        case postId = "post_id"
        case fromUser = "from_user"
        case isRead = "is_read"
        case createdAt = "created_at"
    }
    
    // 自定义解码，处理可选字段和日期格式
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        notificationType = try container.decode(String.self, forKey: .notificationType)
        targetType = try container.decode(String.self, forKey: .targetType)
        targetId = try container.decode(Int.self, forKey: .targetId)
        postId = try container.decodeIfPresent(Int.self, forKey: .postId)
        fromUser = try container.decodeIfPresent(User.self, forKey: .fromUser)
        isRead = try container.decode(Bool.self, forKey: .isRead)
        
        // 处理日期时间格式（后端返回的是ISO 8601格式的字符串）
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = dateString
        } else {
            // 如果解析失败，使用当前时间
            let formatter = ISO8601DateFormatter()
            createdAt = formatter.string(from: Date())
        }
    }
}

// 论坛通知列表响应
struct ForumNotificationListResponse: Codable {
    let notifications: [ForumNotification]
    let total: Int
    let unreadCount: Int
    let page: Int
    let pageSize: Int
    
    enum CodingKeys: String, CodingKey {
        case notifications
        case total
        case unreadCount = "unread_count"
        case page
        case pageSize = "page_size"
    }
}

// 统一的通知显示模型（用于合并普通通知和论坛通知）
struct UnifiedNotification: Identifiable {
    let id: String  // 使用 "system_\(id)" 或 "forum_\(id)" 作为唯一标识
    let source: NotificationSource  // 来源：系统通知或论坛通知
    let type: String  // 统一的通知类型
    let title: String
    let content: String
    let relatedId: Int?  // 关联ID（用于跳转）
    let postId: Int?     // 帖子ID（论坛通知专用）
    let isRead: Bool
    let createdAt: String
    let fromUser: User?  // 发送者（论坛通知专用）
    
    enum NotificationSource {
        case system(SystemNotification)
        case forum(ForumNotification)
    }
    
    // 从系统通知创建
    init(from systemNotification: SystemNotification) {
        self.id = "system_\(systemNotification.id)"
        self.source = .system(systemNotification)
        self.type = systemNotification.type ?? "unknown"
        self.title = systemNotification.title
        self.content = systemNotification.content
        self.relatedId = systemNotification.relatedId
        self.postId = nil
        self.isRead = (systemNotification.isRead ?? 0) == 1
        self.createdAt = systemNotification.createdAt
        self.fromUser = nil
    }
    
    // 从论坛通知创建
    init(from forumNotification: ForumNotification) {
        self.id = "forum_\(forumNotification.id)"
        self.source = .forum(forumNotification)
        
        // 映射论坛通知类型到统一类型
        let mappedType: String
        switch forumNotification.notificationType {
        case "reply_post":
            mappedType = "forum_reply"
        case "reply_reply":
            mappedType = "forum_reply"
        case "like_post":
            mappedType = "forum_like"
        case "like_reply":
            mappedType = "forum_like"
        case "pin_post":
            mappedType = "forum_pin"
        case "feature_post":
            mappedType = "forum_feature"
        default:
            mappedType = "forum_\(forumNotification.notificationType)"
        }
        self.type = mappedType
        
        // 生成标题和内容
        let userName = forumNotification.fromUser?.name ?? "用户"
        switch forumNotification.notificationType {
        case "reply_post":
            self.title = "新回复"
            self.content = "\(userName) 回复了您的帖子"
        case "reply_reply":
            self.title = "新回复"
            self.content = "\(userName) 回复了您的回复"
        case "like_post":
            self.title = "新点赞"
            self.content = "\(userName) 点赞了您的帖子"
        case "like_reply":
            self.title = "新点赞"
            self.content = "\(userName) 点赞了您的回复"
        case "pin_post":
            self.title = "帖子已置顶"
            self.content = "您的帖子已被管理员置顶"
        case "feature_post":
            self.title = "帖子已加精"
            self.content = "您的帖子已被管理员加精"
        default:
            self.title = "论坛通知"
            self.content = "您收到了一条论坛通知"
        }
        
        // 对于回复类型的通知，relatedId应该是postId（用于跳转到帖子详情）
        // 对于点赞类型的通知，relatedId应该是targetId（帖子或回复的ID）
        if forumNotification.notificationType.hasPrefix("reply") {
            self.relatedId = forumNotification.postId ?? forumNotification.targetId
        } else {
            self.relatedId = forumNotification.targetId
        }
        
        self.postId = forumNotification.postId
        self.isRead = forumNotification.isRead
        self.createdAt = forumNotification.createdAt
        self.fromUser = forumNotification.fromUser
    }
}

