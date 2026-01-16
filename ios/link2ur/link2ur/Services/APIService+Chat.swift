import Foundation
import Combine

// MARK: - 任务聊天请求/响应模型

// MARK: - 任务聊天请求/响应模型
// 注意：TaskChatItem、TaskChatListResponse 和 LastMessage 定义已移至 Models/Notification.swift，这里保留 TaskMessagesResponse（包含 task 字段的完整版本）

struct TaskMessagesResponse: Decodable {
    let messages: [TaskMessage]
    let task: TaskChatDetail
    let nextCursor: String?
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case messages, task
        case nextCursor = "next_cursor"
        case hasMore = "has_more"
    }
}

struct TaskMessage: Decodable, Identifiable {
    let id: Int
    let senderId: String? // 系统消息可能为 null
    let senderName: String?
    let senderAvatar: String?
    let content: String
    let messageType: String
    let taskId: Int
    let createdAt: String?
    let isRead: Bool
    let attachments: [MessageAttachment]
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderId = "sender_id"
        case senderName = "sender_name"
        case senderAvatar = "sender_avatar"
        case content
        case messageType = "message_type"
        case taskId = "task_id"
        case createdAt = "created_at"
        case isRead = "is_read"
        case attachments
    }
}

// MessageAttachment 定义在 Message.swift 中

struct TaskChatDetail: Decodable {
    let id: Int
    let title: String
    let status: String
    let posterId: String? // 可能为 null（例如专家创建的任务）
    let takerId: String?
    let baseReward: Double?
    let agreedReward: Double?
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case id, title, status
        case posterId = "poster_id"
        case takerId = "taker_id"
        case baseReward = "base_reward"
        case agreedReward = "agreed_reward"
        case currency
    }
}

struct SendTaskMessageRequest: Encodable {
    let content: String
    let meta: [String: AnyCodable]? // 使用 APIErrorResponse.swift 中定义的 AnyCodable
    let attachments: [AttachmentRequest]?
}

struct AttachmentRequest: Encodable {
    let attachmentType: String
    let url: String?
    let blobId: String?
    
    enum CodingKeys: String, CodingKey {
        case attachmentType = "attachment_type"
        case url
        case blobId = "blob_id"
    }
}

struct MarkReadRequest: Encodable {
    let uptoMessageId: Int?
    let messageIds: [Int]?
    
    enum CodingKeys: String, CodingKey {
        case uptoMessageId = "upto_message_id"
        case messageIds = "message_ids"
    }
}

// MARK: - 任务申请相关模型

struct TaskApplicationListResponse: Decodable {
    let applications: [TaskApplication]
    let total: Int
    
    // 支持多种格式：包装对象 {applications: [...], total: ...} 或直接数组 [...]
    init(from decoder: Decoder) throws {
        // 先尝试作为包装对象解析
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            applications = try container.decodeIfPresent([TaskApplication].self, forKey: .applications) ?? []
            total = try container.decodeIfPresent(Int.self, forKey: .total) ?? applications.count
        } else {
            // 尝试直接数组格式
            let container = try decoder.singleValueContainer()
            applications = (try? container.decode([TaskApplication].self)) ?? []
            total = applications.count
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case applications
        case total
    }
}

struct TaskApplication: Decodable, Identifiable {
    let id: Int
    let applicantId: String
    let applicantName: String?
    let applicantAvatar: String?
    let message: String?
    let negotiatedPrice: Double?
    let currency: String
    let status: String
    let createdAt: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case applicantId = "applicant_id"
        case applicantName = "applicant_name"
        case applicantAvatar = "applicant_avatar"
        case message
        case negotiatedPrice = "negotiated_price"
        case currency, status
        case createdAt = "created_at"
    }
}

struct NegotiateRequest: Encodable {
    let negotiatedPrice: Double
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case negotiatedPrice = "negotiated_price"
        case message
    }
}

struct RespondNegotiationRequest: Encodable {
    let action: String // "accept" or "reject"
    let token: String
}

struct SendApplicationMessageRequest: Encodable {
    let message: String
    let negotiatedPrice: Double?
    
    enum CodingKeys: String, CodingKey {
        case message
        case negotiatedPrice = "negotiated_price"
    }
}

struct ReplyApplicationMessageRequest: Encodable {
    let message: String
    let notificationId: Int
    
    enum CodingKeys: String, CodingKey {
        case message
        case notificationId = "notification_id"
    }
}

struct TokenResponse: Decodable {
    let tokenAccept: String?
    let tokenReject: String?
    let taskId: Int?
    let applicationId: Int?
    
    enum CodingKeys: String, CodingKey {
        case tokenAccept = "token_accept"
        case tokenReject = "token_reject"
        case taskId = "task_id"
        case applicationId = "application_id"
    }
}

struct AcceptApplicationResponse: Decodable {
    let message: String
    let applicationId: Int?
    let taskId: Int?
    let paymentIntentId: String?
    let clientSecret: String?
    let customerId: String?
    let ephemeralKeySecret: String?
    let amount: Int?
    let amountDisplay: String?
    let currency: String?
    let isPaid: Bool?
    
    enum CodingKeys: String, CodingKey {
        case message
        case applicationId = "application_id"
        case taskId = "task_id"
        case paymentIntentId = "payment_intent_id"
        case clientSecret = "client_secret"
        case customerId = "customer_id"
        case ephemeralKeySecret = "ephemeral_key_secret"
        case amount
        case amountDisplay = "amount_display"
        case currency
        case isPaid = "is_paid"
    }
}


// MARK: - APIService Chat & Applications Extension

extension APIService {
    
    // MARK: - Task Chat List & Messages
    
    /// 获取任务聊天列表
    func getTaskChatList(limit: Int = 20, offset: Int = 0) -> AnyPublisher<TaskChatListResponse, APIError> {
        let queryParams: [String: String?] = [
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.TaskMessages.list)?\(queryString)"
        return request(TaskChatListResponse.self, endpoint)
    }
    
    /// 获取任务聊天详情（消息列表）
    func getTaskMessages(taskId: Int, limit: Int = 20, cursor: String? = nil) -> AnyPublisher<TaskMessagesResponse, APIError> {
        var queryParams: [String: String?] = [
            "limit": "\(limit)"
        ]
        if let cursor = cursor {
            queryParams["cursor"] = cursor
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.TaskMessages.taskMessages(taskId))?\(queryString)"
        
        return request(TaskMessagesResponse.self, endpoint)
    }
    
    /// 发送任务消息
    func sendTaskMessage(taskId: Int, content: String, meta: [String: Any]? = nil, attachments: [AttachmentRequest]? = nil) -> AnyPublisher<TaskMessage, APIError> {
        // 构建 meta 字典 (由于 Encodable 限制，这里简单处理，实际项目建议完善 AnyCodable)
        var metaCodable: [String: AnyCodable]? = nil
        if let meta = meta {
            metaCodable = [:]
            for (key, value) in meta {
                metaCodable?[key] = AnyCodable(value)
            }
        }
        
        let body = SendTaskMessageRequest(content: content, meta: metaCodable, attachments: attachments)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(TaskMessage.self, APIEndpoints.TaskMessages.send(taskId), method: "POST", body: bodyDict)
    }
    
    /// 标记消息已读
    func markMessagesRead(taskId: Int, uptoMessageId: Int? = nil, messageIds: [Int]? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        let body = MarkReadRequest(uptoMessageId: uptoMessageId, messageIds: messageIds)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.TaskMessages.read(taskId), method: "POST", body: bodyDict)
    }
    
    // MARK: - Task Applications & Negotiation
    
    /// 获取任务申请列表
    func getTaskApplications(taskId: Int, status: String? = nil, limit: Int = 20, offset: Int = 0) -> AnyPublisher<TaskApplicationListResponse, APIError> {
        var queryParams: [String: String?] = [
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]
        if let status = status {
            queryParams["status"] = status
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Tasks.applications(taskId))?\(queryString)"
        return request(TaskApplicationListResponse.self, endpoint)
    }
    
    /// 接受申请
    func acceptApplication(taskId: Int, applicationId: Int) -> AnyPublisher<AcceptApplicationResponse, APIError> {
        return request(AcceptApplicationResponse.self, APIEndpoints.Tasks.acceptApplication(taskId, applicationId), method: "POST")
    }
    
    /// 拒绝申请
    func rejectApplication(taskId: Int, applicationId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Tasks.rejectApplication(taskId, applicationId), method: "POST")
    }
    
    /// 撤回申请
    func withdrawApplication(taskId: Int, applicationId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Tasks.withdrawApplication(taskId, applicationId), method: "POST")
    }
    
    /// 发起再次议价 (发布者)
    func negotiateApplication(taskId: Int, applicationId: Int, price: Double, message: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body = NegotiateRequest(negotiatedPrice: price, message: message)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Tasks.negotiateApplication(taskId, applicationId), method: "POST", body: bodyDict)
    }
    
    /// 获取议价Token (通过通知ID)
    func getNegotiationTokens(notificationId: Int) -> AnyPublisher<TokenResponse, APIError> {
        return request(TokenResponse.self, APIEndpoints.Notifications.negotiationTokens(notificationId))
    }
    
    /// 处理再次议价 (同意/拒绝)
    func respondNegotiation(taskId: Int, applicationId: Int, action: String, token: String) -> AnyPublisher<EmptyResponse, APIError> {
        let body = RespondNegotiationRequest(action: action, token: token)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Tasks.respondNegotiation(taskId, applicationId), method: "POST", body: bodyDict)
    }
    
    /// 发送申请留言
    func sendApplicationMessage(taskId: Int, applicationId: Int, message: String, price: Double? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        let body = SendApplicationMessageRequest(message: message, negotiatedPrice: price)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Tasks.sendApplicationMessage(taskId, applicationId), method: "POST", body: bodyDict)
    }
    
    /// 回复申请留言
    func replyApplicationMessage(taskId: Int, applicationId: Int, message: String, notificationId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ReplyApplicationMessageRequest(message: message, notificationId: notificationId)
        
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        return request(EmptyResponse.self, APIEndpoints.Tasks.replyApplicationMessage(taskId, applicationId), method: "POST", body: bodyDict)
    }
}

