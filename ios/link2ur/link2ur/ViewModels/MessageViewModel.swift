import Foundation
import Combine

class MessageViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var conversations: [Contact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    func loadConversations() {
        isLoading = true
        apiService.getContacts()
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载会话列表")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] contacts in
                self?.conversations = contacts
            })
            .store(in: &cancellables)
    }
    
    func markAsRead(contactId: String) {
        apiService.markChatRead(contactId: contactId)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                // 更新本地未读数
                if self.conversations.contains(where: { $0.id == contactId }) {
                    // 这里可以更新未读数，但Contact是struct，需要重新创建
                }
            })
            .store(in: &cancellables)
    }
}

// EmptyResponse 已在 APIService.swift 中定义

// 扩展ChatViewModel以支持WebSocket
extension ChatViewModel {
    func connectWebSocket(currentUserId: String) {
        guard let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) else {
            return
        }
        
        WebSocketService.shared.connect(token: token, userId: currentUserId)
        
        // 监听WebSocket消息
        let capturedUserId = currentUserId  // 捕获到局部变量，确保在闭包中可用
        WebSocketService.shared.messageSubject
            .sink { [weak self] message in
                // 只处理当前对话的消息
                if message.senderId == self?.partnerId || message.receiverId == self?.partnerId {
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if !self.messages.contains(where: { $0.id == message.id }) {
                            self.messages.append(message)
                            // 自动排序（处理可选的 createdAt）
                            self.messages.sort { msg1, msg2 in
                                let time1 = msg1.createdAt ?? ""
                                let time2 = msg2.createdAt ?? ""
                                return time1 < time2
                            }
                            
                            // 如果视图可见且消息不是来自当前用户，自动标记为已读
                            if self.isViewVisible, let senderId = message.senderId, senderId != capturedUserId {
                                // 延迟一小段时间，确保消息已添加到列表
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    self.markAsRead()
                                }
                            }
                            // 不再在此处发本地推送：服务端已对私信发 APNs，同一条消息会重复（APNs + 本地）
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func disconnectWebSocket() {
        // 注意：如果多个聊天窗口，不应该断开，只在应用退出时断开
        // WebSocketService.shared.disconnect()
    }
}

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var errorMessage: String?
    @Published var partner: Contact?
    @Published var hasMoreMessages = true
    @Published var isInitialLoadComplete = false
    @Published var isViewVisible = false // 视图是否可见，用于自动标记已读
    
    // 分页参数
    private let pageSize = 20
    private var currentOffset = 0
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private let cacheManager = CacheManager.shared
    private var cancellables = Set<AnyCancellable>()
    let partnerId: String
    
    // 缓存键
    private var cacheKey: String { "chat_messages_\(partnerId)" }
    
    init(partnerId: String, partner: Contact? = nil, apiService: APIService? = nil) {
        self.partnerId = partnerId
        self.partner = partner
        self.apiService = apiService ?? APIService.shared
        
        // 先快速检查内存缓存（同步，很快）
        if let cachedMessages: [Message] = cacheManager.load([Message].self, forKey: cacheKey) {
            if !cachedMessages.isEmpty {
                self.messages = cachedMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                Logger.debug("✅ 从内存缓存加载了 \(cachedMessages.count) 条消息", category: .cache)
                return // 内存缓存命中，直接返回
            }
        }
        
        // 内存缓存未命中，异步加载磁盘缓存（如果存在）
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            // 磁盘缓存加载已经在 getDiskCache 中优化，不会阻塞太久
            if let cachedMessages: [Message] = self.cacheManager.load([Message].self, forKey: self.cacheKey) {
                if !cachedMessages.isEmpty {
                    let sortedMessages = cachedMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                    DispatchQueue.main.async {
                        self.messages = sortedMessages
                        Logger.debug("✅ 从磁盘缓存加载了 \(cachedMessages.count) 条消息", category: .cache)
                    }
                }
            }
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - 缓存管理
    
    private func loadFromCache() {
        // 先快速检查内存缓存（同步，很快）
        if let cachedMessages: [Message] = cacheManager.load([Message].self, forKey: cacheKey) {
            if !cachedMessages.isEmpty {
                self.messages = cachedMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                Logger.debug("✅ 从缓存加载了 \(cachedMessages.count) 条消息", category: .cache)
                return
            }
        }
    }
    
    private func saveToCache() {
        // 只缓存最新的100条消息
        let messagesToCache = Array(messages.suffix(100))
        if !messagesToCache.isEmpty {
            cacheManager.save(messagesToCache, forKey: cacheKey)
            Logger.debug("✅ 已缓存 \(messagesToCache.count) 条消息", category: .cache)
        }
    }
    
    // MARK: - 加载消息
    
    /// 加载最新消息（首次进入或刷新）
    func loadMessages() {
        isLoading = true
        currentOffset = 0
        
        apiService.getMessageHistory(userId: partnerId, limit: pageSize, offset: 0)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                self?.isInitialLoadComplete = true
                if case .failure(let error) = result {
                    ErrorHandler.shared.handle(error, context: "加载消息历史")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] newMessages in
                guard let self = self else { return }
                
                // 按时间排序
                let sortedMessages = newMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                
                // 如果返回的消息数小于 pageSize，说明没有更多了
                self.hasMoreMessages = newMessages.count >= self.pageSize
                self.currentOffset = newMessages.count
                
                // 合并新消息和缓存的消息
                var allMessages = self.messages
                for msg in sortedMessages {
                    if !allMessages.contains(where: { $0.id == msg.id }) {
                        allMessages.append(msg)
                    }
                }
                
                self.messages = allMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                
                // 保存到缓存
                self.saveToCache()
            })
            .store(in: &cancellables)
    }
    
    /// 加载更多历史消息（向上滚动时调用）
    func loadMoreMessages() {
        guard !isLoadingMore && hasMoreMessages else { return }
        
        isLoadingMore = true
        
        apiService.getMessageHistory(userId: partnerId, limit: pageSize, offset: currentOffset)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingMore = false
                if case .failure(let error) = result {
                    Logger.error("加载更多消息失败: \(error)", category: .api)
                }
            }, receiveValue: { [weak self] olderMessages in
                guard let self = self else { return }
                
                // 如果返回的消息数小于 pageSize，说明没有更多了
                self.hasMoreMessages = olderMessages.count >= self.pageSize
                self.currentOffset += olderMessages.count
                
                // 将旧消息插入到列表前面
                var allMessages = self.messages
                for msg in olderMessages {
                    if !allMessages.contains(where: { $0.id == msg.id }) {
                        allMessages.append(msg)
                    }
                }
                
                self.messages = allMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                
                // 保存到缓存
                self.saveToCache()
            })
            .store(in: &cancellables)
    }
    
    @Published var isSending = false
    
    func sendMessage(content: String, completion: @escaping (Bool) -> Void) {
        guard !isSending else { return }
        
        isSending = true
        apiService.sendMessage(receiverId: partnerId, content: content)
            .sink(receiveCompletion: { [weak self] result in
                self?.isSending = false
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { [weak self] message in
                guard let self = self else { return }
                self.isSending = false
                
                // 添加新消息
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                    self.messages.sort { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                }
                
                // 保存到缓存
                self.saveToCache()
                
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func markAsRead() {
        // 标记整个对话为已读
        apiService.markChatRead(contactId: partnerId)
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}

// 任务聊天专用的 ViewModel
class TaskChatDetailViewModel: ObservableObject {
    private let performanceMonitor = PerformanceMonitor.shared
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var hasMoreMessages = true
    @Published var isInitialLoadComplete = false
    @Published var isViewVisible = false // 视图是否可见，用于自动标记已读
    
    // 分页参数
    private let pageSize = 20
    private var currentCursor: String?
    
    private let apiService = APIService.shared
    private let cacheManager = CacheManager.shared
    var cancellables = Set<AnyCancellable>() // 改为公开，以便在 View 中使用
    private let taskId: Int
    private let taskChat: TaskChatItem?
    private var partnerId: String? // 对方用户ID（poster 或 taker）
    
    // 缓存键
    private var cacheKey: String { "task_chat_messages_\(taskId)" }
    
    init(taskId: Int, taskChat: TaskChatItem? = nil) {
        self.taskId = taskId
        self.taskChat = taskChat
        // 先快速检查内存缓存（同步，很快）
        if let cachedMessages: [Message] = cacheManager.load([Message].self, forKey: cacheKey) {
            if !cachedMessages.isEmpty {
                self.messages = cachedMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                Logger.debug("✅ 从内存缓存加载了 \(cachedMessages.count) 条任务聊天消息", category: .cache)
                return // 内存缓存命中，直接返回
            }
        }
        
        // 内存缓存未命中，异步加载磁盘缓存（如果存在）
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            if let cachedMessages: [Message] = self.cacheManager.load([Message].self, forKey: self.cacheKey) {
                if !cachedMessages.isEmpty {
                    let sortedMessages = cachedMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                    DispatchQueue.main.async {
                        self.messages = sortedMessages
                        Logger.debug("✅ 从磁盘缓存加载了 \(cachedMessages.count) 条任务聊天消息", category: .cache)
                    }
                }
            }
        }
    }
    
    deinit {
        cancellables.removeAll()
    }
    
    // MARK: - 缓存管理
    
    private func loadFromCache() {
        // 先快速检查内存缓存（同步，很快）
        if let cachedMessages: [Message] = cacheManager.load([Message].self, forKey: cacheKey) {
            if !cachedMessages.isEmpty {
                self.messages = cachedMessages.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
                Logger.debug("✅ 从缓存加载了 \(cachedMessages.count) 条任务聊天消息", category: .cache)
                return
            }
        }
    }
    
    private var cacheSaveWorkItem: DispatchWorkItem?
    
    func saveToCache() {
        // 取消之前的保存任务（防抖：避免频繁写入）
        cacheSaveWorkItem?.cancel()
        
        // 只缓存最新的100条消息
        let messagesToCache = Array(messages.suffix(100))
        guard !messagesToCache.isEmpty else { return }
        
        // 创建保存任务（延迟 0.5 秒，批量保存）
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.cacheManager.save(messagesToCache, forKey: self.cacheKey)
            Logger.debug("✅ 已缓存 \(messagesToCache.count) 条任务聊天消息", category: .cache)
        }
        
        cacheSaveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    // 注意：taskChat 会在 loadMessages 方法中使用，这里先保存
    
    /// 将 TaskMessage 数组转换为 Message 数组（用于展示）
    private func convertTaskMessagesToMessages(_ taskMessages: [TaskMessage]) -> [Message] {
        let converted = taskMessages.compactMap { taskMsg -> Message? in
            var messageDict: [String: Any] = [:]
            messageDict["id"] = taskMsg.id
            messageDict["content"] = taskMsg.content
            messageDict["message_type"] = taskMsg.messageType
            messageDict["is_read"] = taskMsg.isRead
            messageDict["sender_id"] = taskMsg.senderId ?? NSNull()
            messageDict["sender_name"] = taskMsg.senderName ?? NSNull()
            messageDict["sender_avatar"] = taskMsg.senderAvatar ?? NSNull()
            messageDict["created_at"] = taskMsg.createdAt ?? NSNull()
            if !taskMsg.attachments.isEmpty {
                let attachmentsData = try? JSONEncoder().encode(taskMsg.attachments)
                if let attachmentsData = attachmentsData,
                   let attachmentsArray = try? JSONSerialization.jsonObject(with: attachmentsData) as? [[String: Any]] {
                    messageDict["attachments"] = attachmentsArray
                }
            } else {
                messageDict["attachments"] = []
            }
            guard let jsonData = try? JSONSerialization.data(withJSONObject: messageDict, options: []),
                  let message = try? JSONDecoder().decode(Message.self, from: jsonData) else { return nil }
            return message
        }
        return converted.sorted { ($0.createdAt ?? "") < ($1.createdAt ?? "") }
    }
    
    /// 首次加载或下拉刷新：拉取最新一页消息（后端返回 DESC，转为时间正序展示）
    func loadMessages(currentUserId: String?) {
        let startTime = Date()
        
        isLoading = true
        errorMessage = nil
        currentCursor = nil
        
        Logger.debug("开始加载任务聊天消息，任务ID: \(taskId)", category: .api)
        
        if let taskChat = taskChat, let currentUserId = currentUserId {
            if taskChat.posterId == currentUserId {
                partnerId = taskChat.takerId
            } else if taskChat.takerId == currentUserId {
                partnerId = taskChat.posterId
            }
        }
        
        apiService.getTaskMessages(taskId: taskId, limit: pageSize, cursor: nil)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: "/api/messages/task/\(self?.taskId ?? 0)",
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    Logger.error("任务聊天消息加载失败: \(error)", category: .api)
                } else {
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: "/api/messages/task/\(self?.taskId ?? 0)",
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                let converted = self.convertTaskMessagesToMessages(response.messages)
                self.messages = converted
                self.currentCursor = response.nextCursor
                self.hasMoreMessages = response.hasMore
                self.isInitialLoadComplete = true
                self.saveToCache()
                
                Logger.success("任务聊天消息加载成功，共\(self.messages.count)条，hasMore: \(response.hasMore)", category: .api)
                
                if let lastMessage = self.messages.last, let messageId = lastMessage.messageId {
                    self.markAsRead(uptoMessageId: messageId)
                }
            })
            .store(in: &cancellables)
    }
    
    /// 往上滑加载更早的历史消息（使用 cursor 分页）
    func loadMoreMessages(currentUserId: String?) {
        guard hasMoreMessages, !isLoadingMore else { return }
        guard let cursor = currentCursor, !cursor.isEmpty else { return }
        
        isLoadingMore = true
        Logger.debug("加载更早的任务聊天消息，cursor: \(cursor.prefix(30))...", category: .api)
        
        apiService.getTaskMessages(taskId: taskId, limit: pageSize, cursor: cursor)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoadingMore = false
                if case .failure(let error) = result {
                    Logger.error("加载更早消息失败: \(error)", category: .api)
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                let olderBatch = self.convertTaskMessagesToMessages(response.messages)
                if !olderBatch.isEmpty {
                    self.messages = olderBatch + self.messages
                    self.saveToCache()
                }
                self.currentCursor = response.nextCursor
                self.hasMoreMessages = response.hasMore
                self.isLoadingMore = false
                Logger.debug("加载更早消息成功，本页 \(olderBatch.count) 条，总 \(self.messages.count) 条，hasMore: \(response.hasMore)", category: .api)
            })
            .store(in: &cancellables)
    }
    
    private func loadTaskDetailAndGetPartnerId(currentUserId: String?) {
        let startTime = Date()
        let endpoint = "/api/tasks/\(taskId)"
        
        // 从任务详情获取对方用户ID
        Logger.debug("请求任务详情，任务ID: \(taskId)", category: .api)
        apiService.request(Task.self, endpoint, method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                let duration = Date().timeIntervalSince(startTime)
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                    // 记录性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        error: error
                    )
                    Logger.error("获取任务详情失败: \(error)", category: .api)
                } else {
                    // 记录成功请求的性能指标
                    self?.performanceMonitor.recordNetworkRequest(
                        endpoint: endpoint,
                        method: "GET",
                        duration: duration,
                        statusCode: 200
                    )
                }
            }, receiveValue: { [weak self] task in
                guard let self = self, let currentUserId = currentUserId else { return }
                
                Logger.debug("任务详情 - posterId: \(task.posterId ?? "nil"), takerId: \(task.takerId ?? "nil")", category: .api)
                
                // 从任务详情中确定对方用户ID
                if task.posterId == currentUserId {
                    self.partnerId = task.takerId
                    Logger.debug("从任务详情确定：当前用户是发布者，对方用户ID: \(self.partnerId ?? "nil")", category: .api)
                } else if task.takerId == currentUserId {
                    self.partnerId = task.posterId
                    Logger.debug("从任务详情确定：当前用户是接取者，对方用户ID: \(self.partnerId ?? "nil")", category: .api)
                } else {
                    Logger.warning("当前用户既不是发布者也不是接取者", category: .api)
                }
                
                // 如果找到了对方用户ID，重新加载消息
                if let partnerId = self.partnerId, !partnerId.isEmpty {
                    Logger.debug("📤 从任务详情获取到对方用户ID: \(partnerId)，重新加载消息", category: .api)
                    self.loadMessages(currentUserId: currentUserId)
                } else {
                    self.errorMessage = "无法确定对方用户ID"
                    Logger.warning("❌ 无法从任务详情确定对方用户ID", category: .api)
                }
            })
            .store(in: &cancellables)
    }
    
    func sendMessage(content: String, completion: @escaping (Bool) -> Void) {
        guard !isSending else { return }
        
        // 使用任务聊天专用发送端点
        let body: [String: Any] = [
            "task_id": taskId,
            "content": content
        ]
        
        isSending = true
        Logger.debug("📤 发送任务聊天消息，任务ID: \(taskId)", category: .api)
        apiService.request(Message.self, "/api/messages/task/\(taskId)/send", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                self?.isSending = false
                if case .failure(let error) = result {
                    Logger.error("❌ 发送任务聊天消息失败: \(error)", category: .api)
                    completion(false)
                }
            }, receiveValue: { [weak self] message in
                guard let self = self else { return }
                self.isSending = false
                
                // 优化：使用二分插入保持有序，避免每次都完整排序
                let messageTime = message.createdAt ?? ""
                if let insertIndex = self.messages.firstIndex(where: { ($0.createdAt ?? "") > messageTime }) {
                    self.messages.insert(message, at: insertIndex)
                } else {
                    self.messages.append(message)
                }
                
                // 保存到缓存（内部已实现防抖）
                self.saveToCache()
                
                Logger.debug("✅ 任务聊天消息发送成功", category: .api)
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 发送带附件的消息
    func sendMessageWithAttachment(content: String, attachmentType: String, attachmentUrl: String, completion: @escaping (Bool) -> Void) {
        guard !isSending else { return }
        
        // 构建附件数据（original_filename 取 URL 路径最后一段，不含 query）
        let filename = (URL(string: attachmentUrl)?.lastPathComponent).flatMap { $0.isEmpty ? nil : $0 } ?? "image.jpg"
        let attachment: [String: Any] = [
            "attachment_type": attachmentType,
            "url": attachmentUrl,
            "meta": ["original_filename": filename]
        ]
        
        // 使用任务聊天专用发送端点（body 不含 task_id，已体现在 path 中）
        let body: [String: Any] = [
            "content": content,
            "attachments": [attachment]
        ]
        
        isSending = true
        Logger.debug("📤 发送带附件的任务聊天消息，任务ID: \(taskId), 附件类型: \(attachmentType), url: \(attachmentUrl.prefix(80))...", category: .api)
        apiService.request(Message.self, "/api/messages/task/\(taskId)/send", method: "POST", body: body)
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { [weak self] result in
                self?.isSending = false
                if case .failure(let error) = result {
                    Logger.error("❌ 发送带附件消息失败: \(error)", category: .api)
                    self?.errorMessage = error.userFriendlyMessage
                    completion(false)
                }
            }, receiveValue: { [weak self] message in
                guard let self = self else { return }
                self.isSending = false
                
                // 调试：确认服务端返回了 attachments，便于排查图片不显示
                Logger.debug("✅ 带附件消息发送成功，attachments: \(message.attachments?.count ?? 0), firstImageUrl: \(message.firstImageUrl ?? "nil")", category: .api)
                
                // 优化：使用二分插入保持有序，避免每次都完整排序
                let messageTime = message.createdAt ?? ""
                if let insertIndex = self.messages.firstIndex(where: { ($0.createdAt ?? "") > messageTime }) {
                    self.messages.insert(message, at: insertIndex)
                } else {
                    self.messages.append(message)
                }
                
                // 保存到缓存（内部已实现防抖）
                self.saveToCache()
                
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    private var markAsReadWorkItem: DispatchWorkItem?
    
    func markAsRead(uptoMessageId: Int? = nil) {
        // 取消之前的标记已读任务（防抖：避免频繁请求）
        markAsReadWorkItem?.cancel()
        
        // 使用任务聊天专用标记已读端点
        // 如果提供了 uptoMessageId，使用它；否则使用最新消息的ID
        let messageId = uptoMessageId ?? messages.last?.messageId
        
        // 根据后端要求，如果没有 messageId，不发送 body（空字典可能导致422错误）
        var body: [String: Any]? = nil
        if let messageId = messageId {
            body = ["upto_message_id": messageId]
            Logger.debug("📤 标记任务聊天已读，任务ID: \(taskId), 消息ID: \(messageId)", category: .api)
        } else {
            Logger.debug("📤 标记任务聊天已读，任务ID: \(taskId)（无消息ID，不发送body）", category: .api)
        }
        
        // 创建标记已读任务（延迟 0.2 秒，防抖）
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            // 如果有 body 才发送，否则使用空 body
            self.apiService.request(EmptyResponse.self, "/api/messages/task/\(self.taskId)/read", method: "POST", body: body ?? [:])
                .sink(receiveCompletion: { result in
                    if case .failure(let error) = result {
                        Logger.warning("⚠️ 标记任务聊天已读失败: \(error)", category: .api)
                    }
                }, receiveValue: { _ in
                    Logger.debug("✅ 任务聊天已标记为已读", category: .api)
                })
                .store(in: &self.cancellables)
        }
        
        markAsReadWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
}

