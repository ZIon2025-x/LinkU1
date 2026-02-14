import Foundation
import Combine

// MARK: - Banner API Extension

extension APIService {
    /// 获取首页广告横幅列表（带缓存，1小时有效）
    func getBanners() -> AnyPublisher<BannerListResponse, APIError> {
        return requestWithCache(
            BannerListResponse.self,
            APIEndpoints.Common.banners,
            cachePolicy: .cacheFirst
        )
    }
}

// MARK: - FAQ 库 API Extension

extension APIService {
    /// 获取 FAQ 列表（按语言：zh / en）（带缓存，24小时有效）
    func getFaq(lang: String = "en") -> AnyPublisher<FaqListResponse, APIError> {
        let endpoint = APIEndpoints.Common.faq(lang: lang)
        return requestWithCache(
            FaqListResponse.self,
            endpoint,
            queryParams: ["lang": lang],
            cachePolicy: .cacheFirst
        )
    }
}

// MARK: - 法律文档库 API Extension

extension APIService {
    /// 获取法律文档（隐私/用户协议/Cookie），type: privacy | terms | cookie，lang: zh | en（带缓存，24小时有效）
    func getLegalDocument(type: String, lang: String = "en") -> AnyPublisher<LegalDocumentOut, APIError> {
        let endpoint = APIEndpoints.Common.legal(type: type, lang: lang)
        return requestWithCache(
            LegalDocumentOut.self,
            endpoint,
            queryParams: ["type": type, "lang": lang],
            cachePolicy: .cacheFirst
        )
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
    let images: [String]?
    
    enum CodingKeys: String, CodingKey {
        case title, content, images
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
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(LoginResponse.self, APIEndpoints.Auth.login, method: "POST", body: bodyDict)
    }
    
    /// 邮箱验证码登录
    func loginWithCode(email: String, code: String, captchaToken: String? = nil) -> AnyPublisher<LoginResponse, APIError> {
        var body: [String: Any] = [
            "email": email,
            "verification_code": code
        ]
        if let captchaToken = captchaToken {
            body["captcha_token"] = captchaToken
        }
        return request(LoginResponse.self, APIEndpoints.Auth.loginWithCode, method: "POST", body: body)
    }
    
    /// 手机验证码登录
    func loginWithPhone(phone: String, code: String, captchaToken: String? = nil) -> AnyPublisher<LoginResponse, APIError> {
        let body = PhoneLoginRequest(phone: phone, verificationCode: code, captchaToken: captchaToken)
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(LoginResponse.self, APIEndpoints.Auth.loginWithPhoneCode, method: "POST", body: bodyDict)
    }
    
    /// 发送邮箱验证码
    func sendEmailCode(email: String, captchaToken: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = ["email": email]
        if let captchaToken = captchaToken {
            body["captcha_token"] = captchaToken
        }
        return request(EmptyResponse.self, APIEndpoints.Auth.sendVerificationCode, method: "POST", body: body)
    }
    
    /// 发送手机验证码
    func sendPhoneCode(phone: String, captchaToken: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = ["phone": phone]
        if let captchaToken = captchaToken {
            body["captcha_token"] = captchaToken
        }
        return request(EmptyResponse.self, APIEndpoints.Auth.sendPhoneVerificationCode, method: "POST", body: body)
    }
    
    /// 获取CAPTCHA site key
    func getCaptchaSiteKey() -> AnyPublisher<CaptchaConfigResponse, APIError> {
        return request(CaptchaConfigResponse.self, APIEndpoints.Auth.captchaSiteKey)
    }
    
    /// 登出
    func logout() -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Auth.logout, method: "POST")
    }
    
    /// 删除账户
    func deleteAccount() -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Users.deleteAccount, method: "DELETE")
    }
    
    // MARK: - User Profile (用户资料)
    
    /// 获取当前用户信息
    /// 获取当前用户信息（带缓存，10分钟有效）
    func getUserProfile() -> AnyPublisher<User, APIError> {
        return requestWithCache(
            User.self,
            APIEndpoints.Users.profileMe,
            cachePolicy: .networkFirst  // 优先网络，失败时用缓存
        )
    }
    
    /// 获取指定用户信息（简化版，只返回 User）（带缓存）
    func getUserProfile(userId: String) -> AnyPublisher<User, APIError> {
        return requestWithCache(
            User.self,
            APIEndpoints.Users.profile(userId),
            queryParams: ["user_id": userId],
            cachePolicy: .cacheFirst
        )
    }
    
    /// 获取指定用户完整资料（包含统计、任务、评价等）（带缓存）
    func getUserProfileDetail(userId: String) -> AnyPublisher<UserProfileResponse, APIError> {
        return requestWithCache(
            UserProfileResponse.self,
            APIEndpoints.Users.profile(userId),
            queryParams: ["user_id": userId, "detail": "true"],
            cachePolicy: .cacheFirst
        )
    }
    
    /// 更新用户资料
    func updateProfile(name: String? = nil, avatar: String? = nil, residenceCity: String? = nil) -> AnyPublisher<User, APIError> {
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let avatar = avatar { body["avatar"] = avatar }
        if let residenceCity = residenceCity { body["residence_city"] = residenceCity }
        return request(User.self, APIEndpoints.Users.profileMe, method: "PATCH", body: body)
    }
    
    /// 更新头像
    func updateAvatar(avatar: String) -> AnyPublisher<User, APIError> {
        let body: [String: Any] = ["avatar": avatar]
        return request(User.self, APIEndpoints.Users.updateAvatar, method: "PATCH", body: body)
    }
    
    // MARK: - Tasks (任务)
    
    /// 获取任务列表（带重试和缓存：先读缓存再请求网络）
    func getTasks(page: Int = 1, pageSize: Int = 20, type: String? = nil, location: String? = nil, keyword: String? = nil, sortBy: String? = nil, userLatitude: Double? = nil, userLongitude: Double? = nil) -> AnyPublisher<TaskListResponse, APIError> {
        var queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        if let type = type, type != "all" {
            queryParams["task_type"] = type
        }
        if let location = location, location != "all" {
            queryParams["location"] = location
        }
        if let keyword = keyword {
            queryParams["keyword"] = keyword
        }
        if let sortBy = sortBy {
            queryParams["sort_by"] = sortBy
        }
        if let lat = userLatitude, let lon = userLongitude {
            queryParams["user_latitude"] = "\(lat)"
            queryParams["user_longitude"] = "\(lon)"
        }
        
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Tasks.list)?\(queryString)"
        
        // 只缓存第一页且无搜索关键词的请求
        let shouldCache = page == 1 && (keyword == nil || keyword?.isEmpty == true)
        
        // 构建查询参数字典用于缓存键
        let cacheQueryParams = queryParams.compactMapValues { $0 }
        
        // 网络请求 Publisher（带重试）
        let networkPublisher = requestWithRetry(
            TaskListResponse.self,
            endpoint,
            retryConfiguration: .default
        )
        .handleEvents(receiveOutput: { response in
            // 成功时缓存结果
            if shouldCache {
                APICache.shared.set(response, for: APIEndpoints.Tasks.list, queryParams: cacheQueryParams)
            }
        })
        .eraseToAnyPublisher()
        
        // 如果应该使用缓存，先尝试读缓存
        if shouldCache {
            // 尝试从缓存读取
            if let cached: TaskListResponse = APICache.shared.get(TaskListResponse.self, for: APIEndpoints.Tasks.list, queryParams: cacheQueryParams) {
                Logger.debug("任务列表: 从缓存返回数据，同时后台刷新", category: .cache)
                // 先发缓存数据，再发网络数据（cacheFirst 策略）
                let cachedPublisher = Just(cached)
                    .setFailureType(to: APIError.self)
                    .eraseToAnyPublisher()
                
                // 合并：先缓存，后网络（忽略网络错误，因为已有缓存）
                return cachedPublisher
                    .merge(with: networkPublisher.catch { _ in Empty<TaskListResponse, APIError>() })
                    .eraseToAnyPublisher()
            }
        }
        
        // 无缓存或不应缓存，直接网络请求
        return networkPublisher
            .catch { error -> AnyPublisher<TaskListResponse, APIError> in
                // 网络失败时，尝试从缓存获取（兜底）
                if shouldCache, let cached: TaskListResponse = APICache.shared.get(TaskListResponse.self, for: APIEndpoints.Tasks.list, queryParams: cacheQueryParams) {
                    Logger.info("任务列表网络请求失败，使用缓存兜底", category: .cache)
                    return Just(cached).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// 获取我的任务
    /// 获取我的任务（带重试）
    func getMyTasks() -> AnyPublisher<[Task], APIError> {
        return requestWithRetry(
            [Task].self,
            APIEndpoints.Users.myTasks,
            retryConfiguration: .default
        )
    }
    
    /// 获取任务详情
    /// 获取任务详情（带重试和缓存）
    func getTaskDetail(taskId: Int) -> AnyPublisher<Task, APIError> {
        let endpoint = APIEndpoints.Tasks.detail(taskId)
        
        return requestWithRetry(
            Task.self,
            endpoint,
            retryConfiguration: .fast
        )
        .handleEvents(receiveOutput: { task in
            // 缓存任务详情（3分钟有效）
            APICache.shared.set(task, for: endpoint, ttl: 180)
        })
        .catch { error -> AnyPublisher<Task, APIError> in
            // 网络失败时尝试从缓存获取
            if let cached: Task = APICache.shared.get(Task.self, for: endpoint) {
                Logger.info("任务详情网络请求失败，使用缓存: \(taskId)", category: .cache)
                return Just(cached).setFailureType(to: APIError.self).eraseToAnyPublisher()
            }
            return Fail(error: error).eraseToAnyPublisher()
        }
        .eraseToAnyPublisher()
    }
    
    /// 创建任务（支持离线：离线时加入队列，网络恢复后自动同步）
    func createTask(_ task: TaskCreateRequest) -> AnyPublisher<Task, APIError> {
        guard let bodyDict = APIRequestHelper.encodeToDictionary(task) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        // 检查网络状态，离线时加入离线队列
        if !Reachability.shared.isConnected {
            Logger.info("当前离线，任务创建已加入离线队列", category: .network)
            
            // 将请求加入离线队列
            if let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) {
                let operation = OfflineOperation(
                    type: .create,
                    endpoint: APIEndpoints.Tasks.list,
                    method: "POST",
                    body: bodyData,
                    resourceType: "task"
                )
                OfflineManager.shared.addOperation(operation)
            }
            
            // 返回离线错误，让 UI 知道已离线处理
            return Fail(error: APIError.requestFailed(NSError(domain: "OfflineMode", code: -1009, userInfo: [NSLocalizedDescriptionKey: "已离线，任务将在网络恢复后创建"])))
                .eraseToAnyPublisher()
        }
        
        return requestWithRetry(
            Task.self,
            APIEndpoints.Tasks.list,
            method: "POST",
            body: bodyDict,
            retryConfiguration: .default,
            enqueueOnFailure: true
        )
    }
    
    /// 申请任务（支持离线：离线时加入队列）
    func applyForTask(taskId: Int, message: String? = nil, negotiatedPrice: Double? = nil, currency: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = [:]
        if let message = message, !message.isEmpty { body["message"] = message }
        if let negotiatedPrice = negotiatedPrice { body["negotiated_price"] = negotiatedPrice }
        if let currency = currency { body["currency"] = currency }
        
        // 检查网络状态，离线时加入离线队列
        if !Reachability.shared.isConnected {
            Logger.info("当前离线，任务申请已加入离线队列: taskId=\(taskId)", category: .network)
            
            if let bodyData = try? JSONSerialization.data(withJSONObject: body) {
                let operation = OfflineOperation(
                    type: .create,
                    endpoint: APIEndpoints.Tasks.apply(taskId),
                    method: "POST",
                    body: body.isEmpty ? nil : bodyData,
                    resourceType: "task_application",
                    resourceId: String(taskId)
                )
                OfflineManager.shared.addOperation(operation)
            }
            
            return Fail(error: APIError.requestFailed(NSError(domain: "OfflineMode", code: -1009, userInfo: [NSLocalizedDescriptionKey: "已离线，申请将在网络恢复后提交"])))
                .eraseToAnyPublisher()
        }
        
        return requestWithRetry(
            EmptyResponse.self,
            APIEndpoints.Tasks.apply(taskId),
            method: "POST",
            body: body.isEmpty ? nil : body,
            retryConfiguration: .fast,
            enqueueOnFailure: true
        )
    }
    
    // 注意：acceptApplication 方法已移至 APIService+Chat.swift，这里不再重复定义
    
    /// 完成任务 (执行者)
    func completeTask(taskId: Int, evidenceImages: [String]? = nil, evidenceText: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = [:]
        if let evidenceImages = evidenceImages, !evidenceImages.isEmpty {
            body["evidence_images"] = evidenceImages
        }
        if let evidenceText = evidenceText, !evidenceText.trimmingCharacters(in: .whitespaces).isEmpty {
            body["evidence_text"] = evidenceText.trimmingCharacters(in: .whitespaces)
        }
        return request(EmptyResponse.self, APIEndpoints.Tasks.taskComplete(taskId), method: "POST", body: body.isEmpty ? nil : body)
    }
    
    /// 确认任务完成 (发布者)
    func confirmTaskCompletion(taskId: Int, evidenceFiles: [String]? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any]? = nil
        if let evidenceFiles = evidenceFiles, !evidenceFiles.isEmpty {
            body = ["evidence_files": evidenceFiles]
        }
        return request(EmptyResponse.self, APIEndpoints.Tasks.confirmCompletion(taskId), method: "POST", body: body)
    }
    
    /// 创建退款申请
    func createRefundRequest(
        taskId: Int,
        reasonType: String,
        reason: String,
        refundType: String,
        evidenceFiles: [String]? = nil,
        refundAmount: Double? = nil,
        refundPercentage: Double? = nil
    ) -> AnyPublisher<RefundRequest, APIError> {
        let body = RefundRequestCreate(
            reasonType: reasonType,
            reason: reason,
            refundType: refundType,
            evidenceFiles: evidenceFiles,
            refundAmount: refundAmount,
            refundPercentage: refundPercentage
        )
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(RefundRequest.self, APIEndpoints.Tasks.refundRequest(taskId), method: "POST", body: bodyDict)
    }
    
    /// 查询退款申请状态
    func getRefundStatus(taskId: Int) -> AnyPublisher<RefundRequest?, APIError> {
        // 使用 OptionalResponse 包装器来处理可选响应
        struct OptionalRefundRequestResponse: Codable {
            let value: RefundRequest?
        }
        
        return request(RefundRequest.self, APIEndpoints.Tasks.refundStatus(taskId))
            .map { Optional.some($0) }
            .catch { error -> AnyPublisher<RefundRequest?, APIError> in
                // 如果返回404，说明没有退款申请，返回nil
                if case .httpError(let code) = error, code == 404 {
                    return Just(nil).setFailureType(to: APIError.self).eraseToAnyPublisher()
                }
                return Fail(error: error).eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    /// 获取退款申请历史记录
    func getRefundHistory(taskId: Int) -> AnyPublisher<[RefundRequest], APIError> {
        return request([RefundRequest].self, APIEndpoints.Tasks.refundHistory(taskId))
    }
    
    /// 撤销退款申请
    func cancelRefundRequest(taskId: Int, refundId: Int) -> AnyPublisher<RefundRequest, APIError> {
        return request(RefundRequest.self, APIEndpoints.Tasks.cancelRefundRequest(taskId, refundId), method: "POST")
    }
    
    /// 提交退款申请反驳
    func submitRefundRebuttal(
        taskId: Int,
        refundId: Int,
        rebuttalText: String,
        evidenceFiles: [String]? = nil
    ) -> AnyPublisher<RefundRequest, APIError> {
        let body = RefundRequestRebuttal(
            rebuttalText: rebuttalText,
            evidenceFiles: evidenceFiles
        )
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(RefundRequest.self, APIEndpoints.Tasks.submitRefundRebuttal(taskId, refundId), method: "POST", body: bodyDict)
    }
    
    /// 获取任务争议时间线
    func getTaskDisputeTimeline(taskId: Int) -> AnyPublisher<DisputeTimelineResponse, APIError> {
        return request(DisputeTimelineResponse.self, APIEndpoints.Tasks.disputeTimeline(taskId))
    }
    
    /// 取消任务
    func cancelTask(taskId: Int, reason: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any]? = nil
        if let reason = reason {
            body = ["reason": reason]
        }
        return request(EmptyResponse.self, APIEndpoints.Tasks.cancel(taskId), method: "POST", body: body)
    }
    
    /// 删除任务
    func deleteTask(taskId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Tasks.delete(taskId), method: "DELETE")
    }
    
    /// 记录任务交互（用于推荐系统）
    func recordTaskInteraction(taskId: Int, interactionType: String, durationSeconds: Int? = nil, deviceType: String? = nil, isRecommended: Bool = false, metadata: [String: Any]? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = ["interaction_type": interactionType]
        if let durationSeconds = durationSeconds {
            body["duration_seconds"] = durationSeconds
        }
        if let deviceType = deviceType {
            body["device_type"] = deviceType
        }
        
        // 构建完整的 metadata
        var fullMetadata: [String: Any] = metadata ?? [:]
        fullMetadata["is_recommended"] = isRecommended
        
        // 添加设备信息
        let deviceInfo: [String: Any] = [
            "type": deviceType ?? "mobile",
            "os": "iOS",
            "os_version": DeviceInfo.systemVersion,
            "app_version": DeviceInfo.appVersion,
            "screen_width": Int(DeviceInfo.screenWidth),
            "screen_height": Int(DeviceInfo.screenHeight),
            "device_model": DeviceInfo.model
        ]
        fullMetadata["device_info"] = deviceInfo
        
        body["metadata"] = fullMetadata
        
        return request(EmptyResponse.self, APIEndpoints.Tasks.interaction(taskId), method: "POST", body: body)
    }
    
    // MARK: - Flea Market (跳蚤市场)
    
    /// 获取商品列表
    /// 获取跳蚤市场商品列表（带重试）
    func getFleaMarketItems(page: Int = 1, pageSize: Int = 20, category: String? = nil) -> AnyPublisher<FleaMarketItemListResponse, APIError> {
        var queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        if let category = category {
            queryParams["category"] = category
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.FleaMarket.items)?\(queryString)"
        
        return requestWithRetry(
            FleaMarketItemListResponse.self,
            endpoint,
            retryConfiguration: .default
        )
    }
    
    /// 获取商品详情（带缓存，3分钟有效）
    func getFleaMarketItemDetail(itemId: String) -> AnyPublisher<FleaMarketItemResponse, APIError> {
        let endpoint = APIEndpoints.FleaMarket.itemDetail(itemId)
        return requestWithCache(
            FleaMarketItemResponse.self,
            endpoint,
            queryParams: ["item_id": itemId],
            cachePolicy: .cacheFirst
        )
    }
    
    /// 发布商品
    func createFleaMarketItem(_ item: FleaMarketItemCreateRequest) -> AnyPublisher<CreateFleaMarketItemResponse, APIError> {
        guard let bodyDict = APIRequestHelper.encodeToDictionary(item) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(CreateFleaMarketItemResponse.self, APIEndpoints.FleaMarket.items, method: "POST", body: bodyDict)
    }
    
    /// 购买商品 (直接购买)
    func purchaseItem(itemId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.FleaMarket.directPurchase(itemId), method: "POST")
    }
    
    /// 更新商品
    func updateFleaMarketItem(itemId: String, item: [String: Any]) -> AnyPublisher<FleaMarketItem, APIError> {
        return request(FleaMarketItem.self, APIEndpoints.FleaMarket.itemDetail(itemId), method: "PUT", body: item)
    }
    
    /// 刷新商品（重置自动删除计时器）
    func refreshFleaMarketItem(itemId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.FleaMarket.refresh(itemId), method: "POST")
    }
    
    /// 获取我的购买记录
    func getMyPurchases(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<MyPurchasesListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.FleaMarket.myPurchases)?\(queryString)"
        
        return request(MyPurchasesListResponse.self, endpoint)
    }
    
    // MARK: - Forum (论坛)
    
    /// 获取论坛板块列表（用户可见的）（带缓存，1小时有效）
    func getForumCategories(includeAll: Bool = false, viewAs: String? = nil, includeLatestPost: Bool = true) -> AnyPublisher<ForumCategoryListResponse, APIError> {
        var queryParams: [String: String?] = [
            "include_all": "\(includeAll)",
            "include_latest_post": "\(includeLatestPost)"
        ]
        if let viewAs = viewAs {
            queryParams["view_as"] = viewAs
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Forum.categories)?\(queryString)"
        
        return requestWithCache(
            ForumCategoryListResponse.self,
            endpoint,
            queryParams: queryParams.compactMapValues { $0 },
            cachePolicy: .cacheFirst
        )
    }
    
    /// 获取帖子列表（带重试）
    func getForumPosts(page: Int = 1, pageSize: Int = 20, categoryId: Int? = nil, sort: String = "latest", keyword: String? = nil) -> AnyPublisher<ForumPostListResponse, APIError> {
        var queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)",
            "sort": sort
        ]
        if let categoryId = categoryId {
            queryParams["category_id"] = "\(categoryId)"
        }
        if let keyword = keyword, !keyword.isEmpty {
            queryParams["q"] = keyword
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Forum.posts)?\(queryString)"
        
        Logger.debug("论坛帖子 API 请求: \(endpoint)", category: .api)
        return requestWithRetry(
            ForumPostListResponse.self,
            endpoint,
            retryConfiguration: .default
        )
    }
}

// MARK: - Discovery Feed API

extension APIService {
    /// 获取发现 Feed（首页「发现更多」瀑布流）
    func getDiscoveryFeed(page: Int = 1, limit: Int = 20) -> AnyPublisher<DiscoveryFeedResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "limit": "\(limit)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Discovery.feed)?\(queryString)"
        return requestWithRetry(
            DiscoveryFeedResponse.self,
            endpoint,
            retryConfiguration: .default
        )
    }
}

// MARK: - Forum Post Detail (continued)

extension APIService {
    /// 获取帖子详情（带缓存，3分钟有效）
    func getForumPostDetail(postId: Int) -> AnyPublisher<ForumPostOut, APIError> {
        let endpoint = APIEndpoints.Forum.postDetail(postId)
        return requestWithCache(
            ForumPostOut.self,
            endpoint,
            queryParams: ["post_id": "\(postId)"],
            cachePolicy: .cacheFirst
        )
    }
    
    /// 发布帖子（带重试，失败时加入离线队列）
    /// 发布帖子（支持离线：离线时加入队列）
    func createForumPost(_ post: ForumPostCreateRequest) -> AnyPublisher<ForumPostOut, APIError> {
        guard let bodyDict = APIRequestHelper.encodeToDictionary(post) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        // 检查网络状态，离线时加入离线队列
        if !Reachability.shared.isConnected {
            Logger.info("当前离线，帖子发布已加入离线队列", category: .network)
            
            if let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) {
                let operation = OfflineOperation(
                    type: .create,
                    endpoint: APIEndpoints.Forum.posts,
                    method: "POST",
                    body: bodyData,
                    resourceType: "forum_post"
                )
                OfflineManager.shared.addOperation(operation)
            }
            
            return Fail(error: APIError.requestFailed(NSError(domain: "OfflineMode", code: -1009, userInfo: [NSLocalizedDescriptionKey: "已离线，帖子将在网络恢复后发布"])))
                .eraseToAnyPublisher()
        }
        
        return requestWithRetry(
            ForumPostOut.self,
            APIEndpoints.Forum.posts,
            method: "POST",
            body: bodyDict,
            retryConfiguration: .default,
            enqueueOnFailure: true
        )
    }
    
    /// 获取帖子回复（带重试）
    func getForumReplies(postId: Int, page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ForumReplyListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Forum.replies(postId))?\(queryString)"
        
        return requestWithRetry(
            ForumReplyListResponse.self,
            endpoint,
            retryConfiguration: .default
        )
    }
    
    /// 回复帖子（带重试，失败时加入离线队列）
    /// 回复帖子（支持离线：离线时加入队列）
    func replyToPost(postId: Int, content: String, parentReplyId: Int? = nil) -> AnyPublisher<ForumReplyOut, APIError> {
        let body = ForumReplyCreateRequest(content: content, parentReplyId: parentReplyId)
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        // 检查网络状态，离线时加入离线队列
        if !Reachability.shared.isConnected {
            Logger.info("当前离线，回复已加入离线队列: postId=\(postId)", category: .network)
            
            if let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) {
                let operation = OfflineOperation(
                    type: .create,
                    endpoint: APIEndpoints.Forum.replies(postId),
                    method: "POST",
                    body: bodyData,
                    resourceType: "forum_reply",
                    resourceId: String(postId)
                )
                OfflineManager.shared.addOperation(operation)
            }
            
            return Fail(error: APIError.requestFailed(NSError(domain: "OfflineMode", code: -1009, userInfo: [NSLocalizedDescriptionKey: "已离线，回复将在网络恢复后发送"])))
                .eraseToAnyPublisher()
        }
        
        return requestWithRetry(
            ForumReplyOut.self,
            APIEndpoints.Forum.replies(postId),
            method: "POST",
            body: bodyDict,
            retryConfiguration: .fast,
            enqueueOnFailure: true
        )
    }
    
    // MARK: - 板块申请管理（用户端）
    
    /// 获取我的板块申请列表（普通用户）
    func getMyCategoryRequests() -> AnyPublisher<[ForumCategoryRequestDetail], APIError> {
        return requestWithRetry(
            [ForumCategoryRequestDetail].self,
            APIEndpoints.Forum.myCategoryRequests,
            retryConfiguration: .default
        )
    }
    
    /// 点赞/取消点赞（带重试）
    func toggleForumLike(targetType: String, targetId: Int) -> AnyPublisher<ForumLikeResponse, APIError> {
        let body: [String: Any] = ["target_type": targetType, "target_id": targetId]
        return requestWithRetry(
            ForumLikeResponse.self,
            APIEndpoints.Forum.likes,
            method: "POST",
            body: body,
            retryConfiguration: .fast
        )
    }
    
    /// 收藏/取消收藏帖子
    func toggleForumFavorite(postId: Int) -> AnyPublisher<ForumFavoriteResponse, APIError> {
        let body: [String: Any] = ["post_id": postId]
        return request(ForumFavoriteResponse.self, APIEndpoints.Forum.favorites, method: "POST", body: body)
    }
    
    /// 收藏/取消收藏板块
    func toggleCategoryFavorite(categoryId: Int) -> AnyPublisher<ForumCategoryFavoriteResponse, APIError> {
        return request(ForumCategoryFavoriteResponse.self, APIEndpoints.Forum.categoryFavorite(categoryId), method: "POST")
    }
    
    /// 获取板块收藏状态
    func getCategoryFavoriteStatus(categoryId: Int) -> AnyPublisher<ForumCategoryFavoriteResponse, APIError> {
        return request(ForumCategoryFavoriteResponse.self, APIEndpoints.Forum.categoryFavoriteStatus(categoryId))
    }
    
    /// 批量获取板块收藏状态
    func getCategoryFavoritesBatch(categoryIds: [Int]) -> AnyPublisher<ForumCategoryFavoriteBatchResponse, APIError> {
        return requestWithArrayBody(ForumCategoryFavoriteBatchResponse.self, APIEndpoints.Forum.categoryFavoritesBatch, method: "POST", body: categoryIds)
    }
    
    /// 获取我收藏的板块列表
    func getMyCategoryFavorites(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ForumCategoryListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Forum.myCategoryFavorites)?\(queryString)"
        return request(ForumCategoryListResponse.self, endpoint)
    }
    
    /// 增加帖子浏览量
    func incrementPostViewCount(postId: Int) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Forum.incrementView(postId), method: "POST")
    }
    
    // MARK: - Task Expert (任务达人)
    
    /// 获取任务达人列表
    func getTaskExperts() -> AnyPublisher<[TaskExpertOut], APIError> {
        return request([TaskExpertOut].self, APIEndpoints.TaskExperts.list)
    }
    
    /// 获取达人详情
    func getTaskExpertDetail(expertId: String) -> AnyPublisher<TaskExpertOut, APIError> {
        return request(TaskExpertOut.self, APIEndpoints.TaskExperts.detail(expertId))
    }
    
    /// 获取达人服务列表
    func getTaskExpertServices(expertId: String) -> AnyPublisher<[TaskExpertServiceOut], APIError> {
        return request([TaskExpertServiceOut].self, APIEndpoints.TaskExperts.services(expertId))
    }
    
    /// 申请达人服务
    func applyForService(serviceId: Int, requestData: ServiceApplyRequest) -> AnyPublisher<ServiceApplication, APIError> {
        guard let bodyDict = APIRequestHelper.encodeToDictionary(requestData) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(ServiceApplication.self, APIEndpoints.TaskExperts.applyForService(serviceId), method: "POST", body: bodyDict)
    }
    
    // MARK: - Notifications & Messages (通知与消息)
    
    /// 获取通知列表
    /// 获取通知列表（带重试）
    func getNotifications(limit: Int = 20) -> AnyPublisher<[NotificationOut], APIError> {
        let queryParams: [String: String?] = ["limit": "\(limit)"]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Users.notifications)?\(queryString)"
        return requestWithRetry(
            [NotificationOut].self,
            endpoint,
            retryConfiguration: .default
        )
    }
    
    /// 获取未读通知列表
    func getUnreadNotifications() -> AnyPublisher<[NotificationOut], APIError> {
        return request([NotificationOut].self, APIEndpoints.Users.unreadNotifications)
    }
    
    /// 获取未读通知数量
    func getUnreadNotificationCount() -> AnyPublisher<[String: Int], APIError> {
        return request([String: Int].self, APIEndpoints.Users.unreadNotificationCount)
    }
    
    /// 获取所有未读通知和最近N条已读通知
    func getNotificationsWithRecentRead(recentReadLimit: Int = 10) -> AnyPublisher<[NotificationOut], APIError> {
        return request([NotificationOut].self, APIEndpoints.Users.notificationsWithRecentRead(limit: recentReadLimit))
    }
    
    /// 标记通知为已读（后端返回 NotificationOut）
    /// 注意：发送空 body 以确保后端正确解析 POST 请求
    func markNotificationRead(notificationId: Int) -> AnyPublisher<SystemNotification, APIError> {
        return request(SystemNotification.self, APIEndpoints.Users.markNotificationRead(notificationId), method: "POST", body: [:])
    }
    
    /// 标记所有通知已读
    func markAllNotificationsRead() -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Users.markAllNotificationsRead, method: "POST", body: [:])
    }
    
    /// 获取论坛通知列表
    func getForumNotifications(page: Int = 1, pageSize: Int = 20, isRead: Bool? = nil) -> AnyPublisher<ForumNotificationListResponse, APIError> {
        var queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        if let isRead = isRead {
            queryParams["is_read"] = "\(isRead)"
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Forum.notifications)?\(queryString)"
        return request(ForumNotificationListResponse.self, endpoint)
    }
    
    /// 标记论坛通知为已读
    func markForumNotificationRead(notificationId: Int) -> AnyPublisher<ForumNotification, APIError> {
        return request(ForumNotification.self, APIEndpoints.Forum.markNotificationRead(notificationId), method: "PUT")
    }
    
    /// 标记所有论坛通知为已读
    func markAllForumNotificationsRead() -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Forum.markAllNotificationsRead, method: "PUT")
    }
    
    /// 发送私信
    /// ⚠️ 注意：此接口已废弃，后端返回410错误
    /// 联系人聊天功能已移除，请使用任务聊天接口或客服对话接口
    /// 发送私信（带重试，失败时加入离线队列）
    /// 发送私信（支持离线：离线时加入队列，网络恢复后自动发送）
    func sendMessage(receiverId: String, content: String) -> AnyPublisher<MessageOut, APIError> {
        let body = MessageSendRequest(receiverId: receiverId, content: content)
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        
        // 检查网络状态，离线时加入离线队列
        if !Reachability.shared.isConnected {
            Logger.info("当前离线，私信已加入离线队列: receiverId=\(receiverId)", category: .network)
            
            if let bodyData = try? JSONSerialization.data(withJSONObject: bodyDict) {
                let operation = OfflineOperation(
                    type: .create,
                    endpoint: APIEndpoints.Users.messagesSend,
                    method: "POST",
                    body: bodyData,
                    resourceType: "message",
                    resourceId: receiverId
                )
                OfflineManager.shared.addOperation(operation)
            }
            
            return Fail(error: APIError.requestFailed(NSError(domain: "OfflineMode", code: -1009, userInfo: [NSLocalizedDescriptionKey: "已离线，消息将在网络恢复后发送"])))
                .eraseToAnyPublisher()
        }
        
        return requestWithRetry(
            MessageOut.self,
            APIEndpoints.Users.messagesSend,
            method: "POST",
            body: bodyDict,
            retryConfiguration: .fast,
            enqueueOnFailure: true
        )
    }
    
    // MARK: - Customer Service (客服对话)
    
    /// 分配或获取客服会话
    /// 如果用户已有未结束的对话，返回现有对话；否则尝试分配在线客服
    func assignCustomerService() -> AnyPublisher<CustomerServiceAssignResponse, APIError> {
        return request(CustomerServiceAssignResponse.self, APIEndpoints.Users.customerServiceAssign, method: "POST", body: [:])
    }
    
    /// 获取用户的客服会话列表
    func getCustomerServiceChats() -> AnyPublisher<[CustomerServiceChat], APIError> {
        return request([CustomerServiceChat].self, APIEndpoints.Users.customerServiceChats)
    }
    
    /// 获取客服会话消息
    func getCustomerServiceMessages(chatId: String) -> AnyPublisher<[CustomerServiceMessage], APIError> {
        return request([CustomerServiceMessage].self, APIEndpoints.Users.customerServiceMessages(chatId))
    }
    
    /// 发送客服消息
    func sendCustomerServiceMessage(chatId: String, content: String) -> AnyPublisher<CustomerServiceMessage, APIError> {
        let body: [String: Any] = ["content": content]
        return request(CustomerServiceMessage.self, APIEndpoints.Users.customerServiceMessages(chatId), method: "POST", body: body)
    }
    
    /// 结束客服对话
    func endCustomerServiceChat(chatId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Users.customerServiceEndChat(chatId), method: "POST", body: [:])
    }
    
    /// 对客服进行评分
    func rateCustomerService(chatId: String, rating: Int, comment: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = ["rating": rating]
        if let comment = comment {
            body["comment"] = comment
        }
        return request(EmptyResponse.self, APIEndpoints.Users.customerServiceRate(chatId), method: "POST", body: body)
    }
    
    /// 获取客服排队状态
    func getCustomerServiceQueueStatus() -> AnyPublisher<CustomerServiceQueueStatus, APIError> {
        return request(CustomerServiceQueueStatus.self, APIEndpoints.Users.customerServiceQueueStatus)
    }
    
    /// 获取历史消息
    func getMessageHistory(userId: String, limit: Int = 10, sessionId: Int? = nil, offset: Int = 0) -> AnyPublisher<[MessageOut], APIError> {
        var queryParams: [String: String?] = [
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]
        if let sessionId = sessionId {
            queryParams["session_id"] = "\(sessionId)"
        }
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Users.messageHistory(userId))?\(queryString)"
        return request([MessageOut].self, endpoint)
    }
    
    /// 获取未读消息
    func getUnreadMessages() -> AnyPublisher<[MessageOut], APIError> {
        return request([MessageOut].self, APIEndpoints.Users.messagesUnread)
    }
    
    /// 获取未读消息数量（普通聊天消息）
    func getUnreadMessageCount() -> AnyPublisher<[String: Int], APIError> {
        return request([String: Int].self, APIEndpoints.Users.messagesUnreadCount)
    }
    
    /// 获取任务聊天消息的未读数量
    func getTaskChatUnreadCount() -> AnyPublisher<[String: Int], APIError> {
        return request([String: Int].self, APIEndpoints.TaskMessages.unreadCount)
    }
    
    /// 获取联系人列表
    func getContacts() -> AnyPublisher<[Contact], APIError> {
        // 添加时间戳避免缓存
        let timestamp = Int(Date().timeIntervalSince1970)
        let queryParams: [String: String?] = ["t": "\(timestamp)"]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Users.contacts)?\(queryString)"
        return request([Contact].self, endpoint)
    }
    
    /// 标记聊天消息为已读
    func markChatRead(contactId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.Users.markChatRead(contactId), method: "POST")
    }
    
    // MARK: - Leaderboard (排行榜)
    
    /// 获取自定义排行榜列表
    func getCustomLeaderboards(page: Int = 1, limit: Int = 20) -> AnyPublisher<CustomLeaderboardListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "limit": "\(limit)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Leaderboard.list)?\(queryString)"
        return request(CustomLeaderboardListResponse.self, endpoint)
    }
    
    /// 获取排行榜详情（包含条目）
    func getLeaderboardItems(leaderboardId: Int, page: Int = 1, limit: Int = 20) -> AnyPublisher<LeaderboardItemListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "limit": "\(limit)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Leaderboard.items(leaderboardId))?\(queryString)"
        return request(LeaderboardItemListResponse.self, endpoint)
    }
    
    /// 投票
    func voteLeaderboardItem(itemId: Int, voteType: String) -> AnyPublisher<LeaderboardItemOut, APIError> {
        let body: [String: Any] = ["item_id": itemId, "vote_type": voteType]
        return request(LeaderboardItemOut.self, APIEndpoints.Leaderboard.vote, method: "POST", body: body)
    }
    
    /// 收藏/取消收藏排行榜
    func toggleLeaderboardFavorite(leaderboardId: Int) -> AnyPublisher<CustomLeaderboardFavoriteResponse, APIError> {
        return request(CustomLeaderboardFavoriteResponse.self, APIEndpoints.Leaderboard.favorite(leaderboardId), method: "POST")
    }
    
    /// 获取排行榜收藏状态
    func getLeaderboardFavoriteStatus(leaderboardId: Int) -> AnyPublisher<CustomLeaderboardFavoriteResponse, APIError> {
        return request(CustomLeaderboardFavoriteResponse.self, APIEndpoints.Leaderboard.favoriteStatus(leaderboardId))
    }
    
    /// 批量获取排行榜收藏状态
    func getLeaderboardFavoritesBatch(leaderboardIds: [Int]) -> AnyPublisher<CustomLeaderboardFavoriteBatchResponse, APIError> {
        return requestWithArrayBody(CustomLeaderboardFavoriteBatchResponse.self, APIEndpoints.Leaderboard.favoritesBatch, method: "POST", body: leaderboardIds)
    }
    
    /// 获取我收藏的排行榜列表
    func getMyLeaderboardFavorites(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<CustomLeaderboardListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Leaderboard.myFavorites)?\(queryString)"
        return request(CustomLeaderboardListResponse.self, endpoint)
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
        return request(EmptyResponse.self, APIEndpoints.Users.sendEmailUpdateCode, method: "POST", body: body)
    }
    
    /// 发送修改手机验证码
    func sendPhoneUpdateCode(newPhone: String) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ["new_phone": newPhone]
        return request(EmptyResponse.self, APIEndpoints.Users.sendPhoneUpdateCode, method: "POST", body: body)
    }
    
    // MARK: - User Preferences (用户偏好)
    
    /// 获取用户任务偏好
    func getUserPreferences() -> AnyPublisher<UserPreferences, APIError> {
        return request(UserPreferences.self, APIEndpoints.UserPreferences.get)
    }
    
    /// 更新用户任务偏好
    func updateUserPreferences(preferences: UserPreferences) -> AnyPublisher<EmptyResponse, APIError> {
        let body: [String: Any] = [
            "task_types": preferences.taskTypes,
            "locations": preferences.locations,
            "task_levels": preferences.taskLevels,
            "keywords": preferences.keywords,
            "min_deadline_days": preferences.minDeadlineDays
        ]
        return request(EmptyResponse.self, APIEndpoints.UserPreferences.update, method: "PUT", body: body)
    }
    
    // MARK: - Tasks Extensions (任务扩展)
    
    /// 拒绝任务 (发布者拒绝申请或执行者拒绝)
    func rejectTask(taskId: Int) -> AnyPublisher<Task, APIError> {
        return request(Task.self, APIEndpoints.Tasks.reject(taskId), method: "POST")
    }
    
    // 注意：deleteTask 方法已在上面定义（第286行），这里不再重复定义
    
    /// 评价任务
    func reviewTask(taskId: Int, rating: Double, comment: String?, isAnonymous: Bool = false) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ReviewCreateRequest(rating: rating, comment: comment, isAnonymous: isAnonymous)
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(EmptyResponse.self, APIEndpoints.Tasks.review(taskId), method: "POST", body: bodyDict)
    }
    
    /// 获取任务评价
    func getTaskReviews(taskId: Int) -> AnyPublisher<[Review], APIError> {
        return request([Review].self, APIEndpoints.Tasks.reviews(taskId))
    }
    
    // MARK: - Flea Market Extensions (跳蚤市场扩展)
    
    /// 收藏/取消收藏商品
    func favoriteItem(itemId: String) -> AnyPublisher<EmptyResponse, APIError> {
        return request(EmptyResponse.self, APIEndpoints.FleaMarket.favorite(itemId), method: "POST")
    }
    
    /// 获取我的收藏列表（包含完整商品信息）
    func getMyFavorites(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<FleaMarketItemListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.FleaMarket.favorites)?\(queryString)"
        return request(FleaMarketItemListResponse.self, endpoint)
    }
    
    /// 申请购买/议价
    func requestPurchase(itemId: String, proposedPrice: Double, message: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body = PurchaseRequestCreate(proposedPrice: proposedPrice, message: message)
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(EmptyResponse.self, APIEndpoints.FleaMarket.purchaseRequest(itemId), method: "POST", body: bodyDict)
    }
    
    // MARK: - Forum Extensions (论坛扩展)
    
    /// 收藏帖子（已废弃，请使用 toggleForumFavorite）
    func favoritePost(postId: Int) -> AnyPublisher<ForumLikeResponse, APIError> { // 复用 LikeResponse 结构
        let body = ["post_id": postId]
        return request(ForumLikeResponse.self, APIEndpoints.Forum.favorites, method: "POST", body: body)
    }
    
    /// 获取我的帖子
    func getMyPosts(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ForumPostListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Forum.myPosts)?\(queryString)"
        return request(ForumPostListResponse.self, endpoint)
    }
    
    /// 获取我的回复
    func getMyReplies(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ForumReplyListResponse, APIError> {
        let queryParams: [String: String?] = [
            "page": "\(page)",
            "page_size": "\(pageSize)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Forum.myReplies)?\(queryString)"
        return request(ForumReplyListResponse.self, endpoint)
    }
    
    // MARK: - Task Expert Extensions (达人扩展)
    
    /// 申请成为达人
    func applyToBeExpert(message: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body = ExpertApplyRequest(applicationMessage: message)
        guard let bodyDict = APIRequestHelper.encodeToDictionary(body) else {
            return Fail(error: APIError.unknown).eraseToAnyPublisher()
        }
        return request(EmptyResponse.self, APIEndpoints.TaskExperts.apply, method: "POST", body: bodyDict)
    }
    
    /// 获取我的服务申请记录 (作为普通用户申请达人服务的记录)
    func getMyServiceApplications(page: Int = 1, pageSize: Int = 20) -> AnyPublisher<ServiceApplicationListResponse, APIError> {
        let limit = pageSize
        let offset = (page - 1) * pageSize
        let queryParams: [String: String?] = [
            "limit": "\(limit)",
            "offset": "\(offset)"
        ]
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Users.myServiceApplications)?\(queryString)"
        return request(ServiceApplicationListResponse.self, endpoint)
    }
    
    // MARK: - Message Extensions (消息扩展)
    
    /// 标记单条消息已读
    func markMessageRead(messageId: Int) -> AnyPublisher<MessageOut, APIError> {
        return request(MessageOut.self, APIEndpoints.Users.markMessageRead(messageId), method: "POST")
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
        return request(EmptyResponse.self, APIEndpoints.Reports.forumPost, method: "POST", body: body)
    }
    
    /// 举报排行榜
    func reportLeaderboard(leaderboardId: Int, reason: String, description: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body: [String: Any] = [
            "reason": reason,
            "description": description ?? ""
        ]
        return request(EmptyResponse.self, APIEndpoints.Leaderboard.report(leaderboardId), method: "POST", body: body)
    }
    
    /// 举报排行榜条目
    func reportLeaderboardItem(itemId: Int, reason: String, description: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body: [String: Any] = [
            "reason": reason,
            "description": description ?? ""
        ]
        return request(EmptyResponse.self, APIEndpoints.Leaderboard.reportItem(itemId), method: "POST", body: body)
    }
    
    /// 举报跳蚤市场商品
    func reportFleaMarketItem(itemId: String, reason: String, description: String?) -> AnyPublisher<EmptyResponse, APIError> {
        let body: [String: Any] = [
            "reason": reason,
            "description": description ?? ""
        ]
        return request(EmptyResponse.self, APIEndpoints.FleaMarket.report(itemId), method: "POST", body: body)
    }
    
    // MARK: - Recommendations (推荐)
    
    /// 获取推荐任务列表（增强：支持GPS位置）
    func getTaskRecommendations(limit: Int = 20, algorithm: String = "hybrid", taskType: String? = nil, location: String? = nil, keyword: String? = nil, latitude: Double? = nil, longitude: Double? = nil) -> AnyPublisher<TaskRecommendationResponse, APIError> {
        var queryParams: [String: String?] = [
            "limit": "\(limit)",
            "algorithm": algorithm
        ]
        if let taskType = taskType, taskType != "all" {
            queryParams["task_type"] = taskType
        }
        if let location = location, location != "all" {
            queryParams["location"] = location
        }
        if let keyword = keyword, !keyword.isEmpty {
            queryParams["keyword"] = keyword
        }
        // 增强：如果提供了GPS位置，添加到查询参数
        if let lat = latitude, let lon = longitude {
            queryParams["latitude"] = "\(lat)"
            queryParams["longitude"] = "\(lon)"
        }
        
        let queryString = APIRequestHelper.buildQueryString(queryParams)
        let endpoint = "\(APIEndpoints.Recommendations.list)?\(queryString)"
        
        return request(TaskRecommendationResponse.self, endpoint)
    }
    
    /// 提交推荐反馈
    func submitRecommendationFeedback(taskId: Int, feedbackType: String, recommendationId: String? = nil) -> AnyPublisher<EmptyResponse, APIError> {
        var body: [String: Any] = ["feedback_type": feedbackType]
        if let recommendationId = recommendationId {
            body["recommendation_id"] = recommendationId
        }
        return request(EmptyResponse.self, APIEndpoints.Recommendations.feedback(taskId), method: "POST", body: body)
    }
}

// MARK: - VIP (VIP会员)

// VIP订阅状态响应模型
struct VIPSubscriptionStatus: Codable {
    let subscriptionId: Int?
    let productId: String?
    let status: String?
    let purchaseDate: String?
    let expiresDate: String?
    let isExpired: Bool?
    let autoRenewStatus: Bool?
    let isTrialPeriod: Bool?
    let isInIntroOfferPeriod: Bool?
    
    enum CodingKeys: String, CodingKey {
        case subscriptionId = "subscription_id"
        case productId = "product_id"
        case status
        case purchaseDate = "purchase_date"
        case expiresDate = "expires_date"
        case isExpired = "is_expired"
        case autoRenewStatus = "auto_renew_status"
        case isTrialPeriod = "is_trial_period"
        case isInIntroOfferPeriod = "is_in_intro_offer_period"
    }
}

struct VIPStatusResponse: Codable {
    let userLevel: String
    let isVIP: Bool
    let subscription: VIPSubscriptionStatus?
    
    enum CodingKeys: String, CodingKey {
        case userLevel = "user_level"
        case isVIP = "is_vip"
        case subscription
    }
}

extension APIService {
    /// 激活VIP会员（通过IAP购买）
    func activateVIP(productID: String, transactionID: String, transactionJWS: String) async throws {
        let body: [String: Any] = [
            "product_id": productID,
            "transaction_id": transactionID,
            "transaction_jws": transactionJWS
        ]
        
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = request(EmptyResponse.self, APIEndpoints.Users.activateVIP, method: "POST", body: body)
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { _ in
                        continuation.resume()
                        cancellable?.cancel()
                    }
                )
        }
    }
    
    /// 获取VIP订阅状态
    func getVIPStatus() async throws -> VIPStatusResponse {
        return try await withCheckedThrowingContinuation { continuation in
            var cancellable: AnyCancellable?
            cancellable = request(VIPStatusResponse.self, APIEndpoints.Users.vipStatus, method: "GET")
                .sink(
                    receiveCompletion: { completion in
                        if case .failure(let error) = completion {
                            continuation.resume(throwing: error)
                        }
                        cancellable?.cancel()
                    },
                    receiveValue: { response in
                        continuation.resume(returning: response)
                        cancellable?.cancel()
                    }
                )
        }
    }
}

