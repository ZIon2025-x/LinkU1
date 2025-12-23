import Foundation
import Combine

class CustomerServiceViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var messages: [CustomerServiceMessage] = []
    @Published var chat: CustomerServiceChat?
    @Published var service: CustomerServiceInfo?
    @Published var chats: [CustomerServiceChat] = [] // 对话历史列表
    @Published var isLoading = false
    @Published var isConnecting = false
    @Published var isSending = false
    @Published var isLoadingChats = false
    @Published var errorMessage: String?
    @Published var queueStatus: CustomerServiceQueueStatus?
    @Published var showRatingSheet = false // 显示评分界面
    @Published var hasRated = false // 是否已评分
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var messagePollingTimer: Timer?
    private var queuePollingTimer: Timer?
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        stopPolling()
    }
    
    /// 连接客服（分配或获取会话）
    func connectToService(completion: @escaping (Bool) -> Void) {
        isConnecting = true
        errorMessage = nil
        
        // 检查是否已登录
        guard let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !sessionId.isEmpty else {
            self.isConnecting = false
            self.errorMessage = "请先登录后再使用客服功能"
            completion(false)
            return
        }
        
        let startTime = Date()
        let endpoint = "/api/customer-service/assign"
        
        Logger.debug("开始连接客服...", category: .api)
        Logger.debug("当前 Session ID: \(sessionId.prefix(20))...", category: .auth)
        
        apiService.assignCustomerService()
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isConnecting = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "连接客服")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        error: error
                    )
                    // 处理不同类型的错误
                    if case APIError.unauthorized = error {
                        self?.errorMessage = "登录已过期，请重新登录"
                        Logger.error("连接客服失败: 登录已过期", category: .auth)
                    } else if case APIError.httpError(401) = error {
                        // 401 错误：Session 刷新后仍然失败，可能是后端验证问题
                        // 不立即清除 Session，因为可能是临时问题
                        self?.errorMessage = "认证失败，请稍后重试或重新登录"
                        Logger.error("连接客服失败: 401 未授权（Session 刷新后仍失败）", category: .auth)
                        // 注意：不在这里清除 Session，让用户决定是否重新登录
                        // 如果用户需要重新登录，可以在登录页面处理
                    } else {
                        if let apiError = error as? APIError {
                            self?.errorMessage = apiError.userFriendlyMessage
                        } else {
                            self?.errorMessage = error.localizedDescription
                        }
                        Logger.error("连接客服失败: \(error.localizedDescription)", category: .api)
                    }
                    completion(false)
                }
            }, receiveValue: { [weak self] response in
                let duration = Date().timeIntervalSince(startTime)
                Logger.success("收到响应", category: .api)
                // 记录性能指标
                self?.performanceMonitor.recordNetworkRequest(
                    endpoint: endpoint,
                    method: "POST",
                    duration: duration,
                    statusCode: 200
                )
                
                if let error = response.error {
                    // 没有可用客服，已加入排队
                    Logger.warning("没有可用客服: \(error)", category: .api)
                    self?.queueStatus = response.queueStatus
                    self?.errorMessage = response.message ?? "暂无在线客服"
                    if let queueStatus = response.queueStatus {
                        Logger.info("排队状态: 位置 \(queueStatus.position ?? 0), 等待时间 \(queueStatus.estimatedWaitTime ?? 0)秒", category: .api)
                        // 开始排队轮询
                        self?.startQueuePolling()
                    }
                    completion(false)
                } else if let chat = response.chat, let service = response.service {
                    // 成功分配客服
                    Logger.success("成功分配客服: \(service.name) (ID: \(service.id))", category: .api)
                    Logger.debug("会话ID: \(chat.chatId)", category: .api)
                    self?.chat = chat
                    self?.service = service
                    // 加载消息
                    self?.loadMessages(chatId: chat.chatId)
                    // 开始消息轮询
                    self?.startMessagePolling()
                    completion(true)
                } else {
                    Logger.error("响应格式错误: chat=\(response.chat != nil), service=\(response.service != nil)", category: .api)
                    self?.errorMessage = "未知错误"
                    completion(false)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 加载消息
    func loadMessages(chatId: String? = nil) {
        guard let chatId = chatId ?? chat?.chatId else {
            errorMessage = "没有活动的客服会话"
            return
        }
        
        let startTime = Date()
        let endpoint = "/api/customer-service/messages/\(chatId)"
        
        isLoading = true
        errorMessage = nil
        
        apiService.getCustomerServiceMessages(chatId: chatId)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载客服消息")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    self?.errorMessage = error.userFriendlyMessage
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] messages in
                self?.messages = messages.sorted { msg1, msg2 in
                    // 使用 Date 对象进行时间比较
                    let date1 = self?.parseDate(msg1.createdAt) ?? Date.distantPast
                    let date2 = self?.parseDate(msg2.createdAt) ?? Date.distantPast
                    return date1 < date2
                }
            })
            .store(in: &cancellables)
    }
    
    /// 发送消息
    func sendMessage(content: String, completion: @escaping (Bool) -> Void) {
        guard !isSending else { return }
        
        guard let chatId = chat?.chatId else {
            errorMessage = "没有活动的客服会话"
            completion(false)
            return
        }
        
        guard chat?.isEnded != 1 else {
            errorMessage = "对话已结束"
            completion(false)
            return
        }
        
        let startTime = Date()
        let endpoint = "/api/customer-service/messages"
        
        isSending = true
        apiService.sendCustomerServiceMessage(chatId: chatId, content: content)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isSending = false
                if case .failure(let error) = result {
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        error: error
                    )
                    completion(false)
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "POST",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] message in
                self?.isSending = false
                self?.messages.append(message)
                self?.messages.sort { msg1, msg2 in
                    // 使用 Date 对象进行时间比较
                    let date1 = self?.parseDate(msg1.createdAt) ?? Date.distantPast
                    let date2 = self?.parseDate(msg2.createdAt) ?? Date.distantPast
                    return date1 < date2
                }
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 结束对话
    func endChat(completion: @escaping (Bool) -> Void) {
        guard let chatId = chat?.chatId else {
            completion(false)
            return
        }
        
        apiService.endCustomerServiceChat(chatId: chatId)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { [weak self] _ in
                // 检查是否已评分，如果未评分则显示评分界面
                if self?.hasRated == false {
                    self?.showRatingSheet = true
                }
                self?.chat = nil
                self?.service = nil
                self?.messages = []
                self?.stopPolling()
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 对客服进行评分
    func rateService(rating: Int, comment: String? = nil, completion: @escaping (Bool) -> Void) {
        guard let chatId = chat?.chatId else {
            completion(false)
            return
        }
        
        apiService.rateCustomerService(chatId: chatId, rating: rating, comment: comment)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { _ in
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 获取排队状态
    func getQueueStatus() {
        apiService.getCustomerServiceQueueStatus()
            .sink(receiveCompletion: { [weak self] result in
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "获取排队状态")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] status in
                self?.queueStatus = status
            })
            .store(in: &cancellables)
    }
    
    /// 加载对话历史列表
    func loadChats() {
        // 检查 Session ID 是否存在
        guard KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) != nil else {
            // Session ID 不存在，不加载历史
            return
        }
        
        isLoadingChats = true
        errorMessage = nil
        
        apiService.getCustomerServiceChats()
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingChats = false
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "加载对话历史")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] chats in
                // 按创建时间倒序排序（最新的在前）
                self?.chats = chats.sorted { chat1, chat2 in
                    let date1 = self?.parseDate(chat1.createdAt) ?? Date.distantPast
                    let date2 = self?.parseDate(chat2.createdAt) ?? Date.distantPast
                    return date1 > date2
                }
            })
            .store(in: &cancellables)
    }
    
    /// 选择历史对话
    func selectChat(_ chat: CustomerServiceChat) {
        // 停止当前轮询
        stopPolling()
        
        // 加载选中的对话
        self.chat = chat
        // 如果对话未结束，尝试获取客服信息
        if chat.isEnded == 0 {
            // 重新连接以获取客服信息
            connectToService { [weak self] success in
                if success {
                    // 连接成功，消息已加载，开始轮询
                    self?.startMessagePolling()
                } else {
                    // 连接失败，可能是对话已结束，直接加载消息
                    self?.loadMessages(chatId: chat.chatId)
                }
            }
        } else {
            // 对话已结束，直接加载消息
            loadMessages(chatId: chat.chatId)
        }
    }
    
    /// 开始消息轮询（每5秒检查一次新消息）
    func startMessagePolling() {
        stopPolling() // 先停止现有的轮询
        
        guard chat?.chatId != nil else { return }
        
        messagePollingTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, let chatId = self.chat?.chatId else { return }
            // 静默加载消息（不显示加载状态）
            self.apiService.getCustomerServiceMessages(chatId: chatId)
                .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] newMessages in
                    // 检查是否有新消息
                    let currentMessageIds = Set(self?.messages.map { $0.id } ?? [])
                    let newMessageIds = Set(newMessages.map { $0.id })
                    
                    if newMessageIds != currentMessageIds {
                        // 有新消息，更新列表
                        self?.messages = newMessages.sorted { msg1, msg2 in
                            let date1 = self?.parseDate(msg1.createdAt) ?? Date.distantPast
                            let date2 = self?.parseDate(msg2.createdAt) ?? Date.distantPast
                            return date1 < date2
                        }
                    }
                })
                .store(in: &self.cancellables)
        }
    }
    
    /// 开始排队状态轮询（当在排队时）
    func startQueuePolling() {
        stopPolling() // 先停止现有的轮询
        
        queuePollingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.getQueueStatus()
            // 如果排队状态变为已分配，尝试重新连接
            if self?.queueStatus?.status == "assigned" {
                self?.connectToService { _ in }
            }
        }
    }
    
    /// 停止所有轮询
    func stopPolling() {
        messagePollingTimer?.invalidate()
        messagePollingTimer = nil
        queuePollingTimer?.invalidate()
        queuePollingTimer = nil
    }
    
    /// 解析日期字符串为 Date 对象
    private func parseDate(_ dateString: String?) -> Date? {
        guard let dateString = dateString else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 尝试不带毫秒的格式
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: dateString) {
            return date
        }
        
        // 尝试其他常见格式
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        if let date = dateFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
}

