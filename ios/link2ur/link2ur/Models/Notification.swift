import Foundation

// 动态键用于解码字典
struct DynamicCodingKeys: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    
    init?(intValue: Int) {
        self.intValue = intValue
        self.stringValue = "\(intValue)"
    }
}

// 系统通知
struct SystemNotification: Codable, Identifiable {
    let id: Int
    let userId: String?  // 后端返回 user_id
    let title: String
    let content: String
    let titleEn: String?  // 英文标题（可选）
    let contentEn: String?  // 英文内容（可选）
    let type: String?
    let isRead: Int?
    let createdAt: String
    let relatedId: Int?  // 后端返回 related_id（可能是字符串或整数）
    let link: String?  // iOS 扩展字段，可能为空
    let taskId: Int?  // 对于 application_message 和 negotiation_offer 类型，存储 task_id
    let variables: [String: AnyCodable]?  // 动态变量（用于格式化翻译键）
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case title, content, type
        case titleEn = "title_en"
        case contentEn = "content_en"
        case isRead = "is_read"
        case createdAt = "created_at"
        case relatedId = "related_id"
        case link  // 可选字段，如果后端不返回则为 nil
        case taskId = "task_id"  // 可选字段，后端可能返回
        case variables  // 动态变量
    }
    
    // 显式成员初始化器（因为添加了自定义解码器，需要手动提供）
    init(
        id: Int,
        userId: String?,
        title: String,
        content: String,
        type: String?,
        isRead: Int?,
        createdAt: String,
        relatedId: Int?,
        link: String?,
        taskId: Int?,
        titleEn: String? = nil,
        contentEn: String? = nil,
        variables: [String: AnyCodable]? = nil
    ) {
        self.id = id
        self.userId = userId
        self.title = title
        self.content = content
        self.type = type
        self.isRead = isRead
        self.createdAt = createdAt
        self.relatedId = relatedId
        self.link = link
        self.taskId = taskId
        self.titleEn = titleEn
        self.contentEn = contentEn
        self.variables = variables
    }
    
    // 自定义解码，处理 related_id 可能是字符串或整数的情况
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        id = try container.decode(Int.self, forKey: .id)
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decode(String.self, forKey: .content)
        titleEn = try container.decodeIfPresent(String.self, forKey: .titleEn)
        contentEn = try container.decodeIfPresent(String.self, forKey: .contentEn)
        type = try container.decodeIfPresent(String.self, forKey: .type)
        isRead = try container.decodeIfPresent(Int.self, forKey: .isRead)
        createdAt = try container.decode(String.self, forKey: .createdAt)
        link = try container.decodeIfPresent(String.self, forKey: .link)
        taskId = try container.decodeIfPresent(Int.self, forKey: .taskId)
        
        // 解码 variables（使用 AnyCodable 处理动态类型）
        variables = try? container.decodeIfPresent([String: AnyCodable].self, forKey: .variables)
        
        // 处理 related_id：可能是字符串或整数
        if let relatedIdInt = try? container.decode(Int.self, forKey: .relatedId) {
            relatedId = relatedIdInt
        } else if let relatedIdString = try? container.decode(String.self, forKey: .relatedId),
                  let relatedIdInt = Int(relatedIdString) {
            relatedId = relatedIdInt
        } else {
            relatedId = nil
        }
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
            taskId: self.taskId,
            titleEn: self.titleEn,
            contentEn: self.contentEn,
            variables: self.variables
        )
    }
}

// 实现 Equatable
extension SystemNotification: Equatable {
    static func == (lhs: SystemNotification, rhs: SystemNotification) -> Bool {
        return lhs.id == rhs.id &&
               lhs.userId == rhs.userId &&
               lhs.title == rhs.title &&
               lhs.content == rhs.content &&
               lhs.titleEn == rhs.titleEn &&
               lhs.contentEn == rhs.contentEn &&
               lhs.type == rhs.type &&
               lhs.isRead == rhs.isRead &&
               lhs.createdAt == rhs.createdAt &&
               lhs.relatedId == rhs.relatedId &&
               lhs.link == rhs.link &&
               lhs.taskId == rhs.taskId &&
               areVariablesEqual(lhs.variables, rhs.variables)
    }
    
    private static func areVariablesEqual(_ lhs: [String: AnyCodable]?, _ rhs: [String: AnyCodable]?) -> Bool {
        guard let lhs = lhs, let rhs = rhs else {
            return lhs == nil && rhs == nil
        }
        guard lhs.count == rhs.count else { return false }
        for (key, lhsValue) in lhs {
            guard let rhsValue = rhs[key] else { return false }
            // 比较 AnyCodable 的值
            if !areValuesEqual(lhsValue.value, rhsValue.value) {
                return false
            }
        }
        return true
    }
    
    private static func areValuesEqual(_ lhs: Any, _ rhs: Any) -> Bool {
        if let lhs = lhs as? String, let rhs = rhs as? String {
            return lhs == rhs
        } else if let lhs = lhs as? Int, let rhs = rhs as? Int {
            return lhs == rhs
        } else if let lhs = lhs as? Double, let rhs = rhs as? Double {
            return lhs == rhs
        } else if let lhs = lhs as? Bool, let rhs = rhs as? Bool {
            return lhs == rhs
        }
        return false
    }
}

// 任务聊天项（用于任务聊天列表）
struct TaskChatItem: Codable, Identifiable, Equatable {
    let id: Int // 任务ID
    let title: String
    let titleEn: String? // 英文标题
    let titleZh: String? // 中文标题
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
        case titleEn = "title_en"
        case titleZh = "title_zh"
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
        titleEn = try container.decodeIfPresent(String.self, forKey: .titleEn)
        titleZh = try container.decodeIfPresent(String.self, forKey: .titleZh)
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
    
    // 根据当前语言获取显示标题
    var displayTitle: String {
        let language = LocalizationHelper.currentLanguage
        if language.hasPrefix("zh") {
            return titleZh?.isEmpty == false ? titleZh! : title
        } else {
            return titleEn?.isEmpty == false ? titleEn! : title
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
        // 使用翻译键获取标题
        self.title = UnifiedNotification.getSystemNotificationTitle(type: systemNotification.type ?? "unknown")
        // 使用翻译键和变量格式化内容，如果失败则回退到原始内容
        let languageCode = LocalizationHelper.currentLanguage
        let fallbackContent = languageCode.lowercased().hasPrefix("zh") 
            ? systemNotification.content 
            : (systemNotification.contentEn ?? systemNotification.content)
        
        // 将 AnyCodable 转换为 [String: Any]
        let variablesDict: [String: Any] = systemNotification.variables?.mapValues { $0.value } ?? [:]
        
        self.content = UnifiedNotification.getSystemNotificationContent(
            type: systemNotification.type ?? "unknown",
            variables: variablesDict,
            fallbackContent: fallbackContent
        )
        self.relatedId = systemNotification.relatedId
        self.postId = nil
        self.isRead = (systemNotification.isRead ?? 0) == 1
        self.createdAt = systemNotification.createdAt
        self.fromUser = nil
    }
    
    // 根据通知类型获取翻译后的标题
    static func getSystemNotificationTitle(type: String) -> String {
        let notificationType = NotificationType(rawValue: type.lowercased()) ?? .unknown
        return notificationType.localizedTitle
    }
    
    // 根据通知类型和变量获取翻译后的内容
    static func getSystemNotificationContent(type: String, variables: [String: Any], fallbackContent: String? = nil) -> String {
        let notificationType = NotificationType(rawValue: type.lowercased()) ?? .unknown
        let template = notificationType.localizedContentTemplate
        
        // 如果变量为空，且提供了后备内容，使用后备内容
        if variables.isEmpty && fallbackContent != nil {
            return fallbackContent!
        }
        
        // 格式化模板，替换变量占位符
        var result = template
        
        // 按变量名长度降序排序，避免短变量名被长变量名的一部分替换
        let sortedVariables = variables.sorted { $0.key.count > $1.key.count }
        
        for (key, value) in sortedVariables {
            let placeholder = "{\(key)}"
            var stringValue = "\(value)"
            
            // 处理特殊格式：如果是数字，可能需要格式化
            if let doubleValue = value as? Double {
                // 检查模板中是否有格式化要求（如 {negotiated_price:.2f}）
                if template.contains("\(key):.2f") {
                    stringValue = String(format: "%.2f", doubleValue)
                } else {
                    stringValue = String(format: "%.0f", doubleValue)
                }
            } else if let intValue = value as? Int {
                stringValue = "\(intValue)"
            }
            
            result = result.replacingOccurrences(of: placeholder, with: stringValue)
            // 也替换带格式的占位符（如 {negotiated_price:.2f}）
            result = result.replacingOccurrences(of: "{\(key):.2f}", with: stringValue)
        }
        
        // 如果格式化后的结果仍然包含占位符（说明变量不完整），且提供了后备内容，使用后备内容
        if result.contains("{") && fallbackContent != nil {
            return fallbackContent!
        }
        
        return result
    }
    
    // 系统通知类型枚举
    enum NotificationType: String {
        case taskApplication = "task_application"
        case applicationAccepted = "application_accepted"
        case applicationRejected = "application_rejected"
        case applicationWithdrawn = "application_withdrawn"
        case taskCompleted = "task_completed"
        case taskConfirmed = "task_confirmed"
        case taskCancelled = "task_cancelled"
        case taskAutoCancelled = "task_auto_cancelled"
        case applicationMessage = "application_message"
        case negotiationOffer = "negotiation_offer"
        case negotiationRejected = "negotiation_rejected"
        case taskApproved = "task_approved"
        case taskRewardPaid = "task_reward_paid"
        case taskApprovedWithPayment = "task_approved_with_payment"
        case announcement = "announcement"
        case customerService = "customer_service"
        case unknown = "unknown"
        
        var localizedTitle: String {
            switch self {
            case .taskApplication:
                return LocalizationKey.notificationTitleTaskApplication.localized
            case .applicationAccepted:
                return LocalizationKey.notificationTitleApplicationAccepted.localized
            case .applicationRejected:
                return LocalizationKey.notificationTitleApplicationRejected.localized
            case .applicationWithdrawn:
                return LocalizationKey.notificationTitleApplicationWithdrawn.localized
            case .taskCompleted:
                return LocalizationKey.notificationTitleTaskCompleted.localized
            case .taskConfirmed:
                return LocalizationKey.notificationTitleTaskConfirmed.localized
            case .taskCancelled:
                return LocalizationKey.notificationTitleTaskCancelled.localized
            case .taskAutoCancelled:
                return LocalizationKey.notificationTitleTaskAutoCancelled.localized
            case .applicationMessage:
                return LocalizationKey.notificationTitleApplicationMessage.localized
            case .negotiationOffer:
                return LocalizationKey.notificationTitleNegotiationOffer.localized
            case .negotiationRejected:
                return LocalizationKey.notificationTitleNegotiationRejected.localized
            case .taskApproved:
                return LocalizationKey.notificationTitleTaskApproved.localized
            case .taskRewardPaid:
                return LocalizationKey.notificationTitleTaskRewardPaid.localized
            case .taskApprovedWithPayment:
                return LocalizationKey.notificationTitleTaskApprovedWithPayment.localized
            case .announcement:
                return LocalizationKey.notificationTitleAnnouncement.localized
            case .customerService:
                return LocalizationKey.notificationTitleCustomerService.localized
            case .unknown:
                return LocalizationKey.notificationTitleUnknown.localized
            }
        }
        
        var localizedContentTemplate: String {
            switch self {
            case .taskApplication:
                return LocalizationKey.notificationContentTaskApplication.localized
            case .applicationAccepted:
                return LocalizationKey.notificationContentApplicationAccepted.localized
            case .applicationRejected:
                return LocalizationKey.notificationContentApplicationRejected.localized
            case .applicationWithdrawn:
                return LocalizationKey.notificationContentApplicationWithdrawn.localized
            case .taskCompleted:
                return LocalizationKey.notificationContentTaskCompleted.localized
            case .taskConfirmed:
                return LocalizationKey.notificationContentTaskConfirmed.localized
            case .taskCancelled:
                return LocalizationKey.notificationContentTaskCancelled.localized
            case .taskAutoCancelled:
                return LocalizationKey.notificationContentTaskAutoCancelled.localized
            case .applicationMessage:
                return LocalizationKey.notificationContentApplicationMessage.localized
            case .negotiationOffer:
                return LocalizationKey.notificationContentNegotiationOffer.localized
            case .negotiationRejected:
                return LocalizationKey.notificationContentNegotiationRejected.localized
            case .taskApproved:
                return LocalizationKey.notificationContentTaskApproved.localized
            case .taskRewardPaid:
                return LocalizationKey.notificationContentTaskRewardPaid.localized
            case .taskApprovedWithPayment:
                return LocalizationKey.notificationContentTaskApprovedWithPayment.localized
            case .announcement:
                return LocalizationKey.notificationContentAnnouncement.localized
            case .customerService:
                return LocalizationKey.notificationContentCustomerService.localized
            case .unknown:
                return LocalizationKey.notificationContentUnknown.localized
            }
        }
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
        
        // 生成标题和内容（国际化）
        let userName = forumNotification.fromUser?.name ?? LocalizationKey.forumSomeone.localized
        
        switch forumNotification.notificationType {
        case "reply_post":
            self.title = LocalizationKey.forumNotificationNewReply.localized
            self.content = String(format: LocalizationKey.forumNotificationReplyPost.localized, userName)
        case "reply_reply":
            self.title = LocalizationKey.forumNotificationNewReply.localized
            self.content = String(format: LocalizationKey.forumNotificationReplyReply.localized, userName)
        case "like_post":
            self.title = LocalizationKey.forumNotificationNewLike.localized
            self.content = String(format: LocalizationKey.forumNotificationLikePost.localized, userName)
        case "like_reply":
            self.title = LocalizationKey.forumNotificationNewLike.localized
            self.content = String(format: LocalizationKey.forumNotificationLikeReply.localized, userName)
        case "pin_post":
            self.title = LocalizationKey.forumNotificationPinPost.localized
            self.content = LocalizationKey.forumNotificationPinPostContent.localized
        case "feature_post":
            self.title = LocalizationKey.forumNotificationFeaturePost.localized
            self.content = LocalizationKey.forumNotificationFeaturePostContent.localized
        default:
            self.title = LocalizationKey.forumNotificationDefault.localized
            self.content = LocalizationKey.forumNotificationDefaultContent.localized
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

