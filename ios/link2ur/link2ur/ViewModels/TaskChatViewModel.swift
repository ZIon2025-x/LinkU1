import Foundation
import Combine

class TaskChatViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var taskChats: [TaskChatItem] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private var isRequesting = false // 防止重复请求
    
    /// 节流：2.5 秒内不重复请求（onAppear/Tab 切换时生效，下拉刷新不节流）
    private var lastLoadTime: Date?
    private let loadThrottleInterval: TimeInterval = 2.5
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    /// - Parameter forceRefresh: 为 true 时跳过节流（下拉刷新、重试时使用）
    func loadTaskChats(forceRefresh: Bool = false) {
        let startTime = Date()
        let endpoint = "/api/messages/tasks"
        
        // 节流：非强制刷新时，2.5 秒内跳过
        if !forceRefresh {
            if let last = lastLoadTime, Date().timeIntervalSince(last) < loadThrottleInterval {
                Logger.debug("任务聊天列表节流跳过（距上次 \(String(format: "%.1f", Date().timeIntervalSince(last))) 秒）", category: .api)
                return
            }
        }
        
        // 防止重复请求
        guard !isRequesting else {
            Logger.warning("任务聊天列表请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
        lastLoadTime = Date()
        
        isRequesting = true
        isLoading = true
        errorMessage = nil
        
        // 使用与Web端一致的API端点：/api/messages/tasks
        // 后端返回格式：{ tasks: [...] }
        apiService.request(TaskChatListResponse.self, "\(endpoint)?limit=50&offset=0", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                self?.isRequesting = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载任务聊天列表")
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    Logger.error("TaskChatListResponse 解码失败: \(error)", category: .api)
                    Logger.debug("尝试使用备用解析方法...", category: .api)
                    // 如果包装对象失败，尝试使用备用方法
                    self?.loadTaskChatsWithFallback()
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
            }, receiveValue: { [weak self] response in
                // 过滤掉已取消的任务
                let filteredChats = response.taskChats.filter { taskChat in
                    // 检查 status 或 taskStatus 字段，排除 "cancelled" 状态
                    if let status = taskChat.status, status.lowercased() == "cancelled" {
                        return false
                    }
                    if let taskStatus = taskChat.taskStatus, taskStatus.lowercased() == "cancelled" {
                        return false
                    }
                    return true
                }
                
                // 排序逻辑：优先显示新任务和活跃任务
                // 1. 有未读消息的任务优先（按未读数降序）
                // 2. 然后优先显示处于活跃状态的任务（in_progress, pending_confirmation, pending_payment）
                // 3. 然后按最后消息时间排序（最新的在前）
                // 4. 如果都没有消息，按任务ID降序（新任务的ID更大）
                let sortedChats = filteredChats.sorted { chat1, chat2 in
                    let unreadCount1 = chat1.unreadCount ?? 0
                    let unreadCount2 = chat2.unreadCount ?? 0
                    
                    // 优先显示有未读消息的任务
                    if unreadCount1 > 0 && unreadCount2 == 0 {
                        return true
                    }
                    if unreadCount1 == 0 && unreadCount2 > 0 {
                        return false
                    }
                    
                    // 如果都有未读消息，按未读数降序
                    if unreadCount1 > 0 && unreadCount2 > 0 {
                        if unreadCount1 != unreadCount2 {
                            return unreadCount1 > unreadCount2
                        }
                    }
                    
                    // 判断任务是否处于活跃状态（需要用户关注的状态）
                    let isActive1 = self?.isActiveStatus(chat1.status ?? chat1.taskStatus) ?? false
                    let isActive2 = self?.isActiveStatus(chat2.status ?? chat2.taskStatus) ?? false
                    
                    // 优先显示活跃状态的任务
                    if isActive1 && !isActive2 {
                        return true
                    }
                    if !isActive1 && isActive2 {
                        return false
                    }
                    
                    // 然后按最后消息时间排序
                    let time1 = self?.parseDate(from: chat1.lastMessageTime ?? chat1.lastMessage?.createdAt) ?? Date.distantPast
                    let time2 = self?.parseDate(from: chat2.lastMessageTime ?? chat2.lastMessage?.createdAt) ?? Date.distantPast
                    
                    // 如果都有消息时间，按时间降序
                    if time1 != Date.distantPast && time2 != Date.distantPast {
                        return time1 > time2
                    }
                    
                    // 如果只有一个有消息时间，有消息的排在前面
                    if time1 != Date.distantPast && time2 == Date.distantPast {
                        return true
                    }
                    if time1 == Date.distantPast && time2 != Date.distantPast {
                        return false
                    }
                    
                    // 如果都没有消息，按任务ID降序（新任务的ID更大）
                    return chat1.id > chat2.id
                }
                
                self?.taskChats = sortedChats
                self?.isRequesting = false
                if response.taskChats.count != filteredChats.count {
                    Logger.success("任务聊天列表加载成功，共\(sortedChats.count)条（已过滤\(response.taskChats.count - filteredChats.count)条已取消任务）", category: .api)
                }
            })
            .store(in: &cancellables)
    }
    
    private func loadTaskChatsWithFallback() {
        // 使用 APIService 的底层方法，手动处理响应
        guard let url = URL(string: "\(Constants.API.baseURL)/api/messages/tasks?limit=50&offset=0") else {
            self.errorMessage = "无效的 URL"
            self.isRequesting = false
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 添加 Session ID
        if let sessionId = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !sessionId.isEmpty {
            request.setValue(sessionId, forHTTPHeaderField: "X-Session-ID")
        }
        
        (Foundation.URLSession.shared as URLSession).dataTaskPublisher(for: request)
            .map { $0.data }
            .tryMap { data -> [TaskChatItem] in
                // 先解析为字典
                guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tasksArray = dict["tasks"] as? [[String: Any]] else {
                    throw APIError.decodingError(NSError(domain: "TaskChatViewModel", code: -1, userInfo: [NSLocalizedDescriptionKey: "无法解析响应数据"]))
                }
                
                // 解析每个任务项
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                
                var taskChats: [TaskChatItem] = []
                for taskDict in tasksArray {
                    if let jsonData = try? JSONSerialization.data(withJSONObject: taskDict),
                       let taskChat = try? decoder.decode(TaskChatItem.self, from: jsonData) {
                        taskChats.append(taskChat)
                    }
                }
                
                return taskChats
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isRequesting = false
                if case .failure(let error) = result {
                    // 备用方法用 URLSession.dataTaskPublisher，Failure 为 Error；仅当为 APIError 时使用 userFriendlyMessage
                    self?.errorMessage = (error as? APIError)?.userFriendlyMessage ?? error.localizedDescription
                    Logger.error("备用解析方法也失败: \(error)", category: .api)
                }
            }, receiveValue: { [weak self] taskChats in
                guard let self = self else { return }
                
                // 过滤和排序
                let filteredChats = taskChats.filter { taskChat in
                    if let status = taskChat.status, status.lowercased() == "cancelled" {
                        return false
                    }
                    if let taskStatus = taskChat.taskStatus, taskStatus.lowercased() == "cancelled" {
                        return false
                    }
                    return true
                }
                
                // 排序逻辑：优先显示新任务和活跃任务
                // 1. 有未读消息的任务优先（按未读数降序）
                // 2. 然后优先显示处于活跃状态的任务（in_progress, pending_confirmation, pending_payment）
                // 3. 然后按最后消息时间排序（最新的在前）
                // 4. 如果都没有消息，按任务ID降序（新任务的ID更大）
                let sortedChats = filteredChats.sorted { chat1, chat2 in
                    let unreadCount1 = chat1.unreadCount ?? 0
                    let unreadCount2 = chat2.unreadCount ?? 0
                    
                    // 优先显示有未读消息的任务
                    if unreadCount1 > 0 && unreadCount2 == 0 {
                        return true
                    }
                    if unreadCount1 == 0 && unreadCount2 > 0 {
                        return false
                    }
                    
                    // 如果都有未读消息，按未读数降序
                    if unreadCount1 > 0 && unreadCount2 > 0 {
                        if unreadCount1 != unreadCount2 {
                            return unreadCount1 > unreadCount2
                        }
                    }
                    
                    // 判断任务是否处于活跃状态（需要用户关注的状态）
                    let isActive1 = self.isActiveStatus(chat1.status ?? chat1.taskStatus)
                    let isActive2 = self.isActiveStatus(chat2.status ?? chat2.taskStatus)
                    
                    // 优先显示活跃状态的任务
                    if isActive1 && !isActive2 {
                        return true
                    }
                    if !isActive1 && isActive2 {
                        return false
                    }
                    
                    // 然后按最后消息时间排序
                    let time1 = self.parseDate(from: chat1.lastMessageTime ?? chat1.lastMessage?.createdAt) ?? Date.distantPast
                    let time2 = self.parseDate(from: chat2.lastMessageTime ?? chat2.lastMessage?.createdAt) ?? Date.distantPast
                    
                    // 如果都有消息时间，按时间降序
                    if time1 != Date.distantPast && time2 != Date.distantPast {
                        return time1 > time2
                    }
                    
                    // 如果只有一个有消息时间，有消息的排在前面
                    if time1 != Date.distantPast && time2 == Date.distantPast {
                        return true
                    }
                    if time1 == Date.distantPast && time2 != Date.distantPast {
                        return false
                    }
                    
                    // 如果都没有消息，按任务ID降序（新任务的ID更大）
                    return chat1.id > chat2.id
                }
                
                self.taskChats = sortedChats
                self.isRequesting = false
                Logger.success("任务聊天列表加载成功（备用方法），共\(sortedChats.count)条", category: .api)
            })
            .store(in: &cancellables)
    }
    
    /// 解析日期字符串为 Date 对象
    private func parseDate(from dateString: String?) -> Date? {
        guard let dateString = dateString, !dateString.isEmpty else {
            return nil
        }
        
        // 使用 DateFormatterHelper 解析日期
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // 尝试不带小数秒的格式
        let standardIsoFormatter = ISO8601DateFormatter()
        standardIsoFormatter.formatOptions = [.withInternetDateTime]
        standardIsoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        
        if let date = standardIsoFormatter.date(from: dateString) {
            return date
        }
        
        return nil
    }
    
    /// 判断任务是否处于活跃状态（需要用户关注的状态）
    /// 活跃状态包括：in_progress（进行中）、pending_confirmation（待确认）、pending_payment（待支付）
    private func isActiveStatus(_ status: String?) -> Bool {
        guard let status = status else { return false }
        let lowercasedStatus = status.lowercased()
        return lowercasedStatus == "in_progress" ||
               lowercasedStatus == "pending_confirmation" ||
               lowercasedStatus == "pending_payment"
    }
}

