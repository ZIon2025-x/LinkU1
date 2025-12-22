import Foundation
import Combine

// MARK: - Banner API Extension

extension APIService {
    /// 获取首页广告横幅列表
    func getBanners() -> AnyPublisher<BannerListResponse, APIError> {
        return request(BannerListResponse.self, "/api/banners")
    }
}

// MARK: - 类型别名（用于兼容性）
typealias MessageOut = Message
typealias NotificationOut = SystemNotification
typealias ForumPostOut = ForumPost
typealias ForumReplyOut = ForumReply
typealias FleaMarketItemResponse = FleaMarketItem
typealias MyPurchasesListResponse = FleaMarketItemListResponse
typealias TaskExpertOut = TaskExpert
typealias TaskExpertServiceOut = TaskExpertService
typealias LeaderboardItemOut = LeaderboardItem

// MARK: - API 请求模型定义
// 为了保持代码整洁，将请求 Body 的结构体定义在这里

// 登录请求
struct LoginRequest: Encodable {
    let email: String
    let password: String
}

// 验证码登录请求
struct CodeLoginRequest: Encodable {
    let email: String
    let verificationCode: String
    
    enum CodingKeys: String, CodingKey {
        case email
        case verificationCode = "verification_code"
    }
}

// 手机验证码登录请求
struct PhoneLoginRequest: Encodable {
    let phone: String
    let verificationCode: String
    let captchaToken: String?  // CAPTCHA验证token（可选）
    
    enum CodingKeys: String, CodingKey {
        case phone
        case verificationCode = "verification_code"
        case captchaToken = "captcha_token"
    }
}

// CAPTCHA 响应模型
struct CaptchaConfigResponse: Codable {
    let siteKey: String?
    let enabled: Bool
    let type: String?  // "recaptcha" 或 "hcaptcha"
    
    enum CodingKeys: String, CodingKey {
        case siteKey = "site_key"
        case enabled
        case type
    }
}

// 发送验证码请求
struct SendCodeRequest: Encodable {
    let email: String?
    let phone: String?
}

// 任务创建请求
struct TaskCreateRequest: Encodable {
    let title: String
    let description: String
    let reward: Double
    let currency: String
    let location: String
    let taskType: String
    let deadline: String?
    let isFlexible: Int
    let isPublic: Int
    let images: [String]?
    let maxParticipants: Int?
    let minParticipants: Int?
    
    enum CodingKeys: String, CodingKey {
        case title, description, reward, currency, location
        case taskType = "task_type"
        case deadline
        case isFlexible = "is_flexible"
        case isPublic = "is_public"
        case images
        case maxParticipants = "max_participants"
        case minParticipants = "min_participants"
    }
}

// 跳蚤市场商品创建请求
struct FleaMarketItemCreateRequest: Encodable {
    let title: String
    let description: String
    let price: Double
    let location: String?
    let category: String?
    let contact: String?
    let images: [String]?
}

// 论坛帖子创建请求
struct ForumPostCreateRequest: Encodable {
    let title: String
    let content: String
    let categoryId: Int
    
    enum CodingKeys: String, CodingKey {
        case title, content
        case categoryId = "category_id"
    }
}

// 论坛回复创建请求
struct ForumReplyCreateRequest: Encodable {
    let content: String
    let parentReplyId: Int?
    
    enum CodingKeys: String, CodingKey {
        case content
        case parentReplyId = "parent_reply_id"
    }
}

// 达人服务申请请求
struct ServiceApplyRequest: Encodable {
    let idempotencyKey: String
    let timeSlotId: Int?
    let preferredDeadline: String?
    let isFlexibleTime: Bool?
    let applicationMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case idempotencyKey = "idempotency_key"
        case timeSlotId = "time_slot_id"
        case preferredDeadline = "preferred_deadline"
        case isFlexibleTime = "is_flexible_time"
        case applicationMessage = "application_message"
    }
}

// 消息发送请求
struct MessageSendRequest: Encodable {
    let receiverId: String
    let content: String
    
    enum CodingKeys: String, CodingKey {
        case receiverId = "receiver_id"
        case content
    }
}

// MARK: - APIService Endpoints Extension

extension APIService {
    
    // MARK: - Authentication (认证)
    
    /// 邮箱密码登录
    func login(email: String, password: String) -> AnyPublisher<LoginResponse, APIError> {
        let body = LoginRequest(email: email, password: password)
        // 将 Encodable 转换为 Dictionary
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(LoginResponse.self, "/api/secure-auth/login", method: "POST", body: bodyDict)
    }
    
    /// 邮箱验证码登录
    func loginWithCode(email: String, code: String) -> AnyPublisher<LoginResponse, APIError> {
        let body = CodeLoginRequest(email: email, verificationCode: code)
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(LoginResponse.self, "/api/secure-auth/login-with-code", method: "POST", body: bodyDict)
    }
    
    /// 手机验证码登录
    func loginWithPhone(phone: String, code: String, captchaToken: String? = nil) -> AnyPublisher<LoginResponse, APIError> {
        let body = PhoneLoginRequest(phone: phone, verificationCode: code, captchaToken: captchaToken)
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(LoginResponse.self, "/api/secure-auth/login-with-phone-code", method: "POST", body: bodyDict)
    }
    
    /// 发送邮箱验证码
    func sendEmailCode(email: String) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ["email": email]
        return request(EmptyResponse.self, "/api/secure-auth/send-verification-code", method: "POST", body: body)
    }
    
    /// 发送手机验证码
    func sendPhoneCode(phone: String, captchaToken: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = ["phone": phone]
        if let captchaToken = captchaToken {
            body["captcha_token"] = captchaToken
        }
        return request(EmptyResponse.self, "/api/secure-auth/send-phone-verification-code", method: "POST", body: body)
    }
    
    /// 获取CAPTCHA site key
    func getCaptchaSiteKey() -> AnyPublisher<CaptchaConfigResponse, APIError> {
        return request(CaptchaConfigResponse.self, "/api/secure-auth/captcha-site-key")
    }
    
    /// 登出
    func logout() -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/secure-auth/logout", method: "POST")
    }
    
    // MARK: - User Profile (用户资料)
    
    /// 获取当前用户信息
    func getUserProfile() -> AnyPublisher<User, APIError> {
        return request(User.self, "/api/users/profile/me")
    }
    
    /// 获取指定用户信息（简化版，只返回 User）
    func getUserProfile(userId: String) -> AnyPublisher<User, APIError> {
        return request(User.self, "/api/users/profile/\(userId)")
    }
    
    /// 获取指定用户完整资料（包含统计、任务、评价等）
    func getUserProfileDetail(userId: String) -> AnyPublisher<UserProfileResponse, APIError> {
        return request(UserProfileResponse.self, "/api/users/profile/\(userId)")
    }
    
    /// 更新用户资料
    func updateProfile(name: String? = nil, avatar: String? = nil, residenceCity: String? = nil) -> AnyPublisher<User, APIError> {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let avatar = avatar { body["avatar"] = avatar }
        if let residenceCity = residenceCity { body["residence_city"] = residenceCity }
        // 根据 web 前端：/api/users/profile/avatar 和 /api/users/profile/timezone
        return request(User.self, "/api/users/profile/me", method: "PATCH", body: body)
    }
    
    /// 更新头像
    func updateAvatar(avatar: String) -> AnyPublisher<User, APIError> {
        let body: [String: Any] = ["avatar": avatar]
        return request(User.self, "/api/users/profile/avatar", method: "PATCH", body: body)
    }
    
    // MARK: - Tasks (任务)
    
    /// 获取任务列表
    func getTasks(page: Int = 1, pageSize: Int = 20, type: String? = nil, location: String? = nil, keyword: String? = nil, sortBy: String? = nil, userLatitude: Double? = nil, userLongitude: Double? = nil) -> AnyPublisher<TaskListResponse, APIError> {
        var endpoint = "/api/tasks?page=\(page)&page_size=\(pageSize)"
        if let type = type, type != "all" { endpoint += "&task_type=\(type)" }
        if let location = location, location != "all" { endpoint += "&location=\(location)" }
        if let keyword = keyword { endpoint += "&keyword=\(keyword)" }
        if let sortBy = sortBy { endpoint += "&sort_by=\(sortBy)" }
        // 添加用户位置参数（用于"附近"功能的距离排序）
        if let lat = userLatitude, let lon = userLongitude {
            endpoint += "&user_latitude=\(lat)&user_longitude=\(lon)"
        }
        // URL 编码处理
        endpoint = endpoint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? endpoint
        
        return request(TaskListResponse.self, endpoint)
    }
    
    /// 获取我的任务
    func getMyTasks() -> AnyPublisher<[Task], APIError> {
        return request([Task].self, "/api/users/my-tasks")
    }
    
    /// 获取任务详情
    func getTaskDetail(taskId: Int) -> AnyPublisher<Task, APIError> {
        return request(Task.self, "/api/tasks/\(taskId)")
    }
    
    /// 创建任务
    func createTask(_ task: TaskCreateRequest) -> AnyPublisher<Task, APIError> {
        guard let bodyData = try? JSONEncoder().encode(task),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(Task.self, "/api/tasks", method: "POST", body: bodyDict)
    }
    
    /// 申请任务（支持议价）
    func applyForTask(taskId: Int, message: String? = nil, negotiatedPrice: Double? = nil, currency: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = [:]
        if let message = message, !message.isEmpty { body["message"] = message }
        if let negotiatedPrice = negotiatedPrice { body["negotiated_price"] = negotiatedPrice }
        if let currency = currency { body["currency"] = currency }
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/apply", method: "POST", body: body.isEmpty ? nil : body)
    }
    
    // 注意：acceptApplication 方法已移至 APIService+Chat.swift，这里不再重复定义
    
    /// 完成任务 (执行者)
    func completeTask(taskId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        // 后端路由在 routers.py 中定义为 /tasks/{task_id}/complete，注册在 /api/users 前缀下
        return request(EmptyResponse.self, "/api/users/tasks/\(taskId)/complete", method: "POST")
    }
    
    /// 确认任务完成 (发布者)
    func confirmTaskCompletion(taskId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/confirm_completion", method: "POST")
    }
    
    /// 取消任务
    func cancelTask(taskId: Int, reason: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any]? = nil
        if let reason = reason {
            body = ["reason": reason]
        }
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/cancel", method: "POST", body: body)
    }
    
    /// 删除任务
    func deleteTask(taskId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/delete", method: "DELETE")
    }
    
    // MARK: - Flea Market (跳蚤市场)
    
    /// 获取商品列表
    func getFleaMarketItems(page: Int = 1, pageSize: Int = 20, category: String? = nil) -> AnyPublisher<FleaMarketItemListResponse, APIError> {
        var endpoint = "/api/flea-market/items?page=\(page)&page_size=\(pageSize)"
        if let category = category { endpoint += "&category=\(category)" }
        endpoint = endpoint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? endpoint
        
        return request(FleaMarketItemListResponse.self, endpoint)
    }
    
    /// 获取商品详情
    func getFleaMarketItemDetail(itemId: String) -> AnyPublisher<FleaMarketItemResponse, APIError> {
        return request(FleaMarketItemResponse.self, "/api/flea-market/items/\(itemId)")
    }
    
    /// 发布商品
    func createFleaMarketItem(_ item: FleaMarketItemCreateRequest) -> AnyPublisher<CreateFleaMarketItemResponse, APIError> {
        guard let bodyData = try? JSONEncoder().encode(item),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(CreateFleaMarketItemResponse.self, "/api/flea-market/items", method: "POST", body: bodyDict)
    }
    
    /// 购买商品 (直接购买)
    func purchaseItem(itemId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/flea-market/items/\(itemId)/direct-purchase", method: "POST")
    }
    
    /// 获取我的购买记录
    func getMyPurchases(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<MyPurchasesListResponse, APIError> {
        return request(MyPurchasesListResponse.self, "/api/flea-market/my-purchases?page=\(page)&page_size=\(pageSize)")
    }
    
    // MARK: - Forum (论坛)
    
    /// 获取论坛板块列表（用户可见的）
    func getForumCategories(includeAll: Bool = false, viewAs: String? = nil, includeLatestPost: Bool = true) -> AnyPublisher<ForumCategoryListResponse, APIError> {
        var endpoint = "/api/forum/forums/visible?include_all=\(includeAll)&include_latest_post=\(includeLatestPost)"
        if let viewAs = viewAs {
            endpoint += "&view_as=\(viewAs)"
        }
        return request(ForumCategoryListResponse.self, endpoint)
    }
    
    /// 获取帖子列表
    func getForumPosts(page: Int = 1, pageSize: Int = 20, categoryId: Int? = nil, sort: String = "latest", keyword: String? = nil) -> AnyPublisher<ForumPostListResponse, APIError> {
        var endpoint = "/api/forum/posts?page=\(page)&page_size=\(pageSize)&sort=\(sort)"
        if let categoryId = categoryId { endpoint += "&category_id=\(categoryId)" }
        if let keyword = keyword { endpoint += "&q=\(keyword)" }
        endpoint = endpoint.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? endpoint
        return request(ForumPostListResponse.self, endpoint)
    }
    
    /// 获取帖子详情
    func getForumPostDetail(postId: Int) -> AnyPublisher<ForumPostOut, APIError> {
        return request(ForumPostOut.self, "/api/forum/posts/\(postId)")
    }
    
    /// 发布帖子
    func createForumPost(_ post: ForumPostCreateRequest) -> AnyPublisher<ForumPostOut, APIError> {
        guard let bodyData = try? JSONEncoder().encode(post),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(ForumPostOut.self, "/api/forum/posts", method: "POST", body: bodyDict)
    }
    
    /// 获取帖子回复
    func getForumReplies(postId: Int, page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ForumReplyListResponse, APIError> {
        return request(ForumReplyListResponse.self, "/api/forum/posts/\(postId)/replies?page=\(page)&page_size=\(pageSize)")
    }
    
    /// 回复帖子
    func replyToPost(postId: Int, content: String, parentReplyId: Int? = nil) -> AnyPublisher<ForumReplyOut, APIError> {
        let body = ForumReplyCreateRequest(content: content, parentReplyId: parentReplyId)
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(ForumReplyOut.self, "/api/forum/posts/\(postId)/replies", method: "POST", body: bodyDict)
    }
    
    /// 点赞/取消点赞
    func toggleForumLike(targetType: String, targetId: Int) -> AnyPublisher<ForumLikeResponse, APIError> {
        let body: [String: Any] = ["target_type": targetType, "target_id": targetId]
        return request(ForumLikeResponse.self, "/api/forum/likes", method: "POST", body: body)
    }
    
    /// 收藏/取消收藏帖子
    func toggleForumFavorite(postId: Int) -> AnyPublisher<ForumFavoriteResponse, APIError> {
        let body: [String: Any] = ["post_id": postId]
        return request(ForumFavoriteResponse.self, "/api/forum/favorites", method: "POST", body: body)
    }
    
    /// 增加帖子浏览量
    func incrementPostViewCount(postId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/forum/posts/\(postId)/view", method: "POST")
    }
    
    // MARK: - Task Expert (任务达人)
    
    /// 获取任务达人列表
    func getTaskExperts() -> AnyPublisher<[TaskExpertOut], APIError> {
        return request([TaskExpertOut].self, "/api/task-experts")
    }
    
    /// 获取达人详情
    func getTaskExpertDetail(expertId: String) -> AnyPublisher<TaskExpertOut, APIError> {
        return request(TaskExpertOut.self, "/api/task-experts/\(expertId)")
    }
    
    /// 获取达人服务列表
    func getTaskExpertServices(expertId: String) -> AnyPublisher<[TaskExpertServiceOut], APIError> {
        // 根据 routers.py: @task_expert_router.get("/{expert_id}/services")
        return request([TaskExpertServiceOut].self, "/api/task-experts/\(expertId)/services")
    }
    
    /// 申请达人服务
    func applyForService(serviceId: Int, requestData: ServiceApplyRequest) -> AnyPublisher<ServiceApplication, APIError> {
        guard let bodyData = try? JSONEncoder().encode(requestData),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(ServiceApplication.self, "/api/task-experts/services/\(serviceId)/apply", method: "POST", body: bodyDict)
    }
    
    // MARK: - Notifications & Messages (通知与消息)
    
    /// 获取通知列表
    func getNotifications(limit: Int = 20) -> AnyPublisher<[NotificationOut], APIError> {
        return request([NotificationOut].self, "/api/users/notifications?limit=\(limit)")
    }
    
    /// 获取未读通知列表
    func getUnreadNotifications() -> AnyPublisher<[NotificationOut], APIError> {
        return request([NotificationOut].self, "/api/users/notifications/unread")
    }
    
    /// 获取未读通知数量
    func getUnreadNotificationCount() -> AnyPublisher<[String: Int], APIError> {
        return request([String: Int].self, "/api/users/notifications/unread/count")
    }
    
    /// 标记通知为已读（后端返回 NotificationOut）
    /// 注意：发送空 body 以确保后端正确解析 POST 请求
    func markNotificationRead(notificationId: Int) -> AnyPublisher<SystemNotification, APIError> {
        return request(SystemNotification.self, "/api/users/notifications/\(notificationId)/read", method: "POST", body: [:])
    }
    
    /// 标记所有通知已读
    func markAllNotificationsRead() -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/users/notifications/read-all", method: "POST", body: [:])
    }
    
    /// 获取论坛通知列表
    func getForumNotifications(page: Int = 1, pageSize: Int = 20, isRead: Bool? = nil) -> AnyPublisher<ForumNotificationListResponse, APIError> {
        var queryParams = ["page=\(page)", "page_size=\(pageSize)"]
        if let isRead = isRead {
            queryParams.append("is_read=\(isRead)")
        }
        let endpoint = "/api/forum/notifications?\(queryParams.joined(separator: "&"))"
        return request(ForumNotificationListResponse.self, endpoint, method: "GET")
    }
    
    /// 标记论坛通知为已读
    func markForumNotificationRead(notificationId: Int) -> AnyPublisher<ForumNotification, APIError> {
        return request(ForumNotification.self, "/api/forum/notifications/\(notificationId)/read", method: "PUT")
    }
    
    /// 标记所有论坛通知为已读
    func markAllForumNotificationsRead() -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/forum/notifications/read-all", method: "PUT")
    }
    
    /// 发送私信
    /// ⚠️ 注意：此接口已废弃，后端返回410错误
    /// 联系人聊天功能已移除，请使用任务聊天接口或客服对话接口
    func sendMessage(receiverId: String, content: String) -> AnyPublisher<MessageOut, APIError> {
        let body = MessageSendRequest(receiverId: receiverId, content: content)
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(MessageOut.self, "/api/users/messages/send", method: "POST", body: bodyDict)
    }
    
    // MARK: - Customer Service (客服对话)
    
    /// 分配或获取客服会话
    /// 如果用户已有未结束的对话，返回现有对话；否则尝试分配在线客服
    func assignCustomerService() -> AnyPublisher<CustomerServiceAssignResponse, APIError> {
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(CustomerServiceAssignResponse.self, "/api/users/user/customer-service/assign", method: "POST", body: [:])
    }
    
    /// 获取用户的客服会话列表
    func getCustomerServiceChats() -> AnyPublisher<[CustomerServiceChat], APIError> {
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request([CustomerServiceChat].self, "/api/users/user/customer-service/chats")
    }
    
    /// 获取客服会话消息
    func getCustomerServiceMessages(chatId: String) -> AnyPublisher<[CustomerServiceMessage], APIError> {
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request([CustomerServiceMessage].self, "/api/users/user/customer-service/chats/\(chatId)/messages")
    }
    
    /// 发送客服消息
    func sendCustomerServiceMessage(chatId: String, content: String) -> AnyPublisher<CustomerServiceMessage, APIError> {
        let body: [String: Any] = ["content": content]
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(CustomerServiceMessage.self, "/api/users/user/customer-service/chats/\(chatId)/messages", method: "POST", body: body)
    }
    
    /// 结束客服对话
    func endCustomerServiceChat(chatId: String) -> AnyPublisher<EmptyResponse, APIError> {
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(EmptyResponse.self, "/api/users/user/customer-service/chats/\(chatId)/end", method: "POST", body: [:])
    }
    
    /// 对客服进行评分
    func rateCustomerService(chatId: String, rating: Int, comment: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = ["rating": rating]
        if let comment = comment {
            body["comment"] = comment
        }
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(EmptyResponse.self, "/api/users/user/customer-service/chats/\(chatId)/rate", method: "POST", body: body)
    }
    
    /// 获取客服排队状态
    func getCustomerServiceQueueStatus() -> AnyPublisher<CustomerServiceQueueStatus, APIError> {
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(CustomerServiceQueueStatus.self, "/api/users/user/customer-service/queue-status")
    }
    
    /// 获取历史消息
    func getMessageHistory(userId: String, limit: Int = 10, sessionId: Int? = nil, offset: Int = 0) -> AnyPublisher<[MessageOut], APIError> {
        var endpoint = "/api/users/messages/history/\(userId)?limit=\(limit)&offset=\(offset)"
        if let sessionId = sessionId {
            endpoint += "&session_id=\(sessionId)"
        }
        return request([MessageOut].self, endpoint)
    }
    
    /// 获取未读消息
    func getUnreadMessages() -> AnyPublisher<[MessageOut], APIError> {
        return request([MessageOut].self, "/api/users/messages/unread")
    }
    
    /// 获取未读消息数量
    func getUnreadMessageCount() -> AnyPublisher<[String: Int], APIError> {
        return request([String: Int].self, "/api/users/messages/unread/count")
    }
    
    /// 获取联系人列表
    func getContacts() -> AnyPublisher<[Contact], APIError> {
        // 添加时间戳避免缓存
        let timestamp = Int(Date().timeIntervalSince1970)
        return request([Contact].self, "/api/users/contacts?t=\(timestamp)")
    }
    
    /// 标记聊天消息为已读
    func markChatRead(contactId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/users/messages/mark-chat-read/\(contactId)", method: "POST")
    }
    
    // MARK: - Leaderboard (排行榜)
    
    /// 获取自定义排行榜列表
    func getCustomLeaderboards(page: Int = 1, limit: Int = 20) -> AnyPublisher<CustomLeaderboardListResponse, APIError> {
        return request(CustomLeaderboardListResponse.self, "/api/custom-leaderboards?page=\(page)&limit=\(limit)")
    }
    
    /// 获取排行榜详情（包含条目）
    func getLeaderboardItems(leaderboardId: Int, page: Int = 1, limit: Int = 20) -> AnyPublisher<LeaderboardItemListResponse, APIError> {
        return request(LeaderboardItemListResponse.self, "/api/custom-leaderboards/\(leaderboardId)/items?page=\(page)&limit=\(limit)")
    }
    
    /// 投票
    func voteLeaderboardItem(itemId: Int, voteType: String) -> AnyPublisher<LeaderboardItemOut, APIError> {
        let body: [String: Any] = ["item_id": itemId, "vote_type": voteType]
        return request(LeaderboardItemOut.self, "/api/custom-leaderboards/vote", method: "POST", body: body)
    }
}

import Foundation
import Combine

// MARK: - 补全的请求模型

// 评价请求
struct ReviewCreateRequest: Encodable {
    let rating: Double
    let comment: String?
    let isAnonymous: Bool
    
    enum CodingKeys: String, CodingKey {
        case rating, comment
        case isAnonymous = "is_anonymous"
    }
}

// 申请成为达人请求
struct ExpertApplyRequest: Encodable {
    let applicationMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case applicationMessage = "application_message"
    }
}

// 跳蚤市场议价请求
struct PurchaseRequestCreate: Encodable {
    let proposedPrice: Double
    let message: String?
    
    enum CodingKeys: String, CodingKey {
        case proposedPrice = "proposed_price"
        case message
    }
}

// MARK: - APIService Endpoints Extension Supplement

extension APIService {
    
    // MARK: - User Profile Extensions (用户资料扩展)
    
    /// 发送修改邮箱验证码
    func sendEmailUpdateCode(newEmail: String) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ["new_email": newEmail]
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(EmptyResponse.self, "/api/users/profile/send-email-update-code", method: "POST", body: body)
    }
    
    /// 发送修改手机验证码
    func sendPhoneUpdateCode(newPhone: String) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ["new_phone": newPhone]
        // 后端在 routers.py 中，router 注册在 /api/users 前缀下
        return request(EmptyResponse.self, "/api/users/profile/send-phone-update-code", method: "POST", body: body)
    }
    
    // MARK: - Tasks Extensions (任务扩展)
    
    /// 拒绝任务 (发布者拒绝申请或执行者拒绝)
    func rejectTask(taskId: Int) -> AnyPublisher<Task, APIError> {
        return request(Task.self, "/api/tasks/\(taskId)/reject", method: "POST")
    }
    
    // 注意：deleteTask 方法已在上面定义（第286行），这里不再重复定义
    
    /// 评价任务
    func reviewTask(taskId: Int, rating: Double, comment: String?, isAnonymous: Bool = false) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ReviewCreateRequest(rating: rating, comment: comment, isAnonymous: isAnonymous)
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        // 注意：返回值可能是 Review 对象，这里简化为 EmptyResponse 或根据需要调整
        return request(EmptyResponse.self, "/api/tasks/\(taskId)/review", method: "POST", body: bodyDict)
    }
    
    /// 获取任务评价
    func getTaskReviews(taskId: Int) -> AnyPublisher<[Review], APIError> {
        return request([Review].self, "/api/tasks/\(taskId)/reviews")
    }
    
    // MARK: - Flea Market Extensions (跳蚤市场扩展)
    
    /// 收藏/取消收藏商品
    func favoriteItem(itemId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, "/api/flea-market/items/\(itemId)/favorite", method: "POST")
    }
    
    /// 获取我的收藏列表（包含完整商品信息）
    func getMyFavorites(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<FleaMarketItemListResponse, APIError> {
        // 后端路径：/api/flea-market/favorites/items
        return request(FleaMarketItemListResponse.self, "/api/flea-market/favorites/items?page=\(page)&page_size=\(pageSize)")
    }
    
    /// 申请购买/议价
    func requestPurchase(itemId: String, proposedPrice: Double, message: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body = PurchaseRequestCreate(proposedPrice: proposedPrice, message: message)
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(EmptyResponse.self, "/api/flea-market/items/\(itemId)/purchase-request", method: "POST", body: bodyDict)
    }
    
    // MARK: - Forum Extensions (论坛扩展)
    
    /// 收藏帖子（已废弃，请使用 toggleForumFavorite）
    func favoritePost(postId: Int) -> AnyPublisher<ForumLikeResponse, APIError> { // 复用 LikeResponse 结构
        let body = ["post_id": postId]
        return request(ForumLikeResponse.self, "/api/forum/favorites", method: "POST", body: body)
    }
    
    /// 获取我的帖子
    func getMyPosts(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ForumPostListResponse, APIError> {
        return request(ForumPostListResponse.self, "/api/forum/my/posts?page=\(page)&page_size=\(pageSize)")
    }
    
    /// 获取我的回复
    func getMyReplies(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ForumReplyListResponse, APIError> {
        return request(ForumReplyListResponse.self, "/api/forum/my/replies?page=\(page)&page_size=\(pageSize)")
    }
    
    // MARK: - Task Expert Extensions (达人扩展)
    
    /// 申请成为达人
    func applyToBeExpert(message: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ExpertApplyRequest(applicationMessage: message)
        guard let bodyData = try? JSONEncoder().encode(body),
              let bodyDict = try? JSONSerialization.jsonObject(with: bodyData) as? [String: Any] else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(EmptyResponse.self, "/api/task-experts/apply", method: "POST", body: bodyDict)
    }
    
    /// 获取我的服务申请记录 (作为普通用户申请达人服务的记录)
    func getMyServiceApplications(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ServiceApplicationListResponse, APIError> {
        // 后端使用 limit 和 offset，需要转换 page 和 pageSize
        // 端点：/api/users/me/service-applications (普通用户获取自己申请的达人服务)
        let limit = pageSize
        let offset = (page - 1) * pageSize
        return request(ServiceApplicationListResponse.self, "/api/users/me/service-applications?limit=\(limit)&offset=\(offset)")
    }
    
    // MARK: - Message Extensions (消息扩展)
    
    /// 标记单条消息已读
    func markMessageRead(messageId: Int) -> AnyPublisher<MessageOut, APIError> {
        return request(MessageOut.self, "/api/messages/\(messageId)/read", method: "POST")
    }
    
    // MARK: - Common Extensions (公共扩展)
    
    // 图片上传已在 APIService.swift 基础类中实现 uploadImage
    
    // MARK: - Report Extensions (举报扩展)
    
    /// 举报论坛内容 (帖子或回复)
    func reportForumTarget(targetType: String, targetId: Int, reason: String, description: String?) -> AnyPublisher<EmptyResponse, APIError> {
        // targetType: "post" or "reply"
        let body: [String: Any] = [
            "target_type": targetType,
            "target_id": targetId,
            "reason": reason,
            "description": description ?? ""
        ]
        return request(EmptyResponse.self, "/api/posts/reports", method: "POST", body: body)
    }
    
    /// 举报排行榜
    func reportLeaderboard(leaderboardId: Int, reason: String, description: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body: [String: Any] = [
            "reason": reason,
            "description": description ?? ""
        ]
        return request(EmptyResponse.self, "/api/custom-leaderboards/\(leaderboardId)/report", method: "POST", body: body)
    }
    
    /// 举报排行榜条目
    func reportLeaderboardItem(itemId: Int, reason: String, description: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body: [String: Any] = [
            "reason": reason,
            "description": description ?? ""
        ]
        return request(EmptyResponse.self, "/api/custom-leaderboards/items/\(itemId)/report", method: "POST", body: body)
    }
    
    /// 举报跳蚤市场商品
    func reportFleaMarketItem(itemId: String, reason: String, description: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body: [String: Any] = [
            "reason": reason,
            "description": description ?? ""
        ]
        return request(EmptyResponse.self, "/api/flea-market/items/\(itemId)/report", method: "POST", body: body)
    }
}

