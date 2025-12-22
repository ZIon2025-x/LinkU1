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
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadTaskChats() {
        let startTime = Date()
        let endpoint = "/api/messages/tasks"
        
        // 防止重复请求
        guard !isRequesting else {
            Logger.warning("任务聊天列表请求已在进行中，跳过重复请求", category: .api)
            return
        }
        
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
                    if case let apiError as APIError = error {
                        self?.errorMessage = apiError.userFriendlyMessage
                    } else {
                        self?.errorMessage = error.localizedDescription
                    }
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
                
                // 按照最新消息时间排序（最新的在前）
                let sortedChats = filteredChats.sorted { chat1, chat2 in
                    let time1 = self?.parseDate(from: chat1.lastMessageTime ?? chat1.lastMessage?.createdAt) ?? Date.distantPast
                    let time2 = self?.parseDate(from: chat2.lastMessageTime ?? chat2.lastMessage?.createdAt) ?? Date.distantPast
                    return time1 > time2 // 降序排列，最新的在前
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
                    self?.errorMessage = error.localizedDescription
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
                
                let sortedChats = filteredChats.sorted { chat1, chat2 in
                    let time1 = self.parseDate(from: chat1.lastMessageTime ?? chat1.lastMessage?.createdAt) ?? Date.distantPast
                    let time2 = self.parseDate(from: chat2.lastMessageTime ?? chat2.lastMessage?.createdAt) ?? Date.distantPast
                    return time1 > time2
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
}

