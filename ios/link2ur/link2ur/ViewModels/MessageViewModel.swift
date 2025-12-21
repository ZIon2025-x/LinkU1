import Foundation
import Combine

class MessageViewModel: ObservableObject {
    @Published var conversations: [Contact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    
    init(apiService: APIService? = nil) {
        self.apiService = apiService ?? APIService.shared
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
    @Published var errorMessage: String?
    @Published var partner: Contact?
    
    // 使用依赖注入获取服务
    private let apiService: APIService
    private var cancellables = Set<AnyCancellable>()
    private let partnerId: String
    
    init(partnerId: String, partner: Contact? = nil, apiService: APIService? = nil) {
        self.partnerId = partnerId
        self.partner = partner
        self.apiService = apiService ?? APIService.shared
    }
    
    func loadMessages() {
        isLoading = true
        apiService.getMessageHistory(userId: partnerId)
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    // 使用 ErrorHandler 统一处理错误
                    ErrorHandler.shared.handle(error, context: "加载消息历史")
                    self?.errorMessage = error.userFriendlyMessage
                }
            }, receiveValue: { [weak self] messages in
                self?.messages = messages.sorted { msg1, msg2 in
                    // 按时间排序（处理可选的 createdAt）
                    let time1 = msg1.createdAt ?? ""
                    let time2 = msg2.createdAt ?? ""
                    return time1 < time2
                }
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
                self?.isSending = false
                self?.messages.append(message)
                self?.messages.sort { msg1, msg2 in
                    let time1 = msg1.createdAt ?? ""
                    let time2 = msg2.createdAt ?? ""
                    return time1 < time2
                }
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
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    var cancellables = Set<AnyCancellable>() // 改为公开，以便在 View 中使用
    private let taskId: Int
    private let taskChat: TaskChatItem?
    private var partnerId: String? // 对方用户ID（poster 或 taker）
    
    init(taskId: Int, taskChat: TaskChatItem? = nil) {
        self.taskId = taskId
        self.taskChat = taskChat
        // 从 taskChat 中确定对方用户ID
        // 注意：taskChat 会在 loadMessages 方法中使用，这里先保存
    }
    
    func loadMessages(currentUserId: String?) {
        isLoading = true
        errorMessage = nil
        
        print("🔍 开始加载任务聊天消息，任务ID: \(taskId), 当前用户ID: \(currentUserId ?? "nil")")
        
        // 确定对方用户ID
        if let taskChat = taskChat, let currentUserId = currentUserId {
            print("📋 任务聊天信息 - posterId: \(taskChat.posterId ?? "nil"), takerId: \(taskChat.takerId ?? "nil")")
            if taskChat.posterId == currentUserId {
                partnerId = taskChat.takerId
                print("✅ 当前用户是发布者，对方用户ID: \(partnerId ?? "nil")")
            } else if taskChat.takerId == currentUserId {
                partnerId = taskChat.posterId
                print("✅ 当前用户是接取者，对方用户ID: \(partnerId ?? "nil")")
            } else {
                print("⚠️ 当前用户既不是发布者也不是接取者")
            }
        }
        
        // 直接使用任务聊天专用端点：/api/messages/task/{taskId}（注意是单数 task）
        // 这个端点返回格式：{ messages: [...], cursor?: string, has_more?: bool }
        print("📤 请求任务聊天消息，任务ID: \(taskId)")
        apiService.request(TaskMessagesResponse.self, "/api/messages/task/\(taskId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                    print("❌ 任务聊天消息加载失败: \(error)")
                }
            }, receiveValue: { [weak self] response in
                guard let self = self else { return }
                
                let allTaskMessages = response.messages
                
                // 将 TaskMessage 转换为 Message 类型（用于 MessageBubble）
                // 由于 Message 使用自定义解码，我们需要手动创建字典然后解码
                let convertedMessages = allTaskMessages.compactMap { taskMsg -> Message? in
                    // 创建字典表示（senderId 可能为 nil，系统消息时）
                    let messageDict: [String: Any] = [
                        "id": taskMsg.id,
                        "sender_id": taskMsg.senderId as Any, // 可能为 nil
                        "content": taskMsg.content,
                        "message_type": taskMsg.messageType,
                        "created_at": taskMsg.createdAt as Any,
                        "is_read": taskMsg.isRead
                    ]
                    
                    // 使用 JSONEncoder/Decoder 转换
                    guard let jsonData = try? JSONSerialization.data(withJSONObject: messageDict),
                          let message = try? JSONDecoder().decode(Message.self, from: jsonData) else {
                        return nil
                    }
                    return message
                }
                
                // 任务聊天消息已经通过任务ID过滤，直接显示所有消息
                self.messages = convertedMessages.sorted { msg1, msg2 in
                    let time1 = msg1.createdAt ?? ""
                    let time2 = msg2.createdAt ?? ""
                    return time1 < time2
                }
                print("✅ 任务聊天消息加载成功，共\(self.messages.count)条")
                
                // 加载成功后，标记最新消息为已读（只在有消息ID时调用）
                if let lastMessage = self.messages.last, let messageId = lastMessage.messageId {
                    self.markAsRead(uptoMessageId: messageId)
                } else if !self.messages.isEmpty {
                    print("⚠️ 最新消息没有ID，跳过标记已读")
                }
            })
            .store(in: &cancellables)
    }
    
    private func loadTaskDetailAndGetPartnerId(currentUserId: String?) {
        // 从任务详情获取对方用户ID
        print("📤 请求任务详情，任务ID: \(taskId)")
        apiService.request(Task.self, "/api/tasks/\(taskId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                    print("❌ 获取任务详情失败: \(error)")
                }
            }, receiveValue: { [weak self] task in
                guard let self = self, let currentUserId = currentUserId else { return }
                
                print("📋 任务详情 - posterId: \(task.posterId ?? "nil"), takerId: \(task.takerId ?? "nil")")
                
                // 从任务详情中确定对方用户ID
                if task.posterId == currentUserId {
                    self.partnerId = task.takerId
                    print("✅ 从任务详情确定：当前用户是发布者，对方用户ID: \(self.partnerId ?? "nil")")
                } else if task.takerId == currentUserId {
                    self.partnerId = task.posterId
                    print("✅ 从任务详情确定：当前用户是接取者，对方用户ID: \(self.partnerId ?? "nil")")
                } else {
                    print("⚠️ 当前用户既不是发布者也不是接取者")
                }
                
                // 如果找到了对方用户ID，重新加载消息
                if let partnerId = self.partnerId, !partnerId.isEmpty {
                    print("📤 从任务详情获取到对方用户ID: \(partnerId)，重新加载消息")
                    self.loadMessages(currentUserId: currentUserId)
                } else {
                    self.errorMessage = "无法确定对方用户ID"
                    print("❌ 无法从任务详情确定对方用户ID")
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
        print("📤 发送任务聊天消息，任务ID: \(taskId)")
        apiService.request(Message.self, "/api/messages/task/\(taskId)/send", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                self?.isSending = false
                if case .failure(let error) = result {
                    print("❌ 发送任务聊天消息失败: \(error)")
                    completion(false)
                }
            }, receiveValue: { [weak self] message in
                self?.isSending = false
                self?.messages.append(message)
                self?.messages.sort { msg1, msg2 in
                    let time1 = msg1.createdAt ?? ""
                    let time2 = msg2.createdAt ?? ""
                    return time1 < time2
                }
                print("✅ 任务聊天消息发送成功")
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    /// 发送带附件的消息
    func sendMessageWithAttachment(content: String, attachmentType: String, attachmentUrl: String, completion: @escaping (Bool) -> Void) {
        guard !isSending else { return }
        
        // 构建附件数据
        let attachment: [String: Any] = [
            "attachment_type": attachmentType,
            "url": attachmentUrl,
            "meta": [
                "original_filename": attachmentUrl.components(separatedBy: "/").last ?? "image.jpg"
            ]
        ]
        
        // 使用任务聊天专用发送端点
        let body: [String: Any] = [
            "task_id": taskId,
            "content": content,
            "attachments": [attachment]
        ]
        
        isSending = true
        print("📤 发送带附件的任务聊天消息，任务ID: \(taskId), 附件类型: \(attachmentType)")
        apiService.request(Message.self, "/api/messages/task/\(taskId)/send", method: "POST", body: body)
            .sink(receiveCompletion: { [weak self] result in
                self?.isSending = false
                if case .failure(let error) = result {
                    print("❌ 发送带附件消息失败: \(error)")
                    completion(false)
                }
            }, receiveValue: { [weak self] message in
                self?.isSending = false
                self?.messages.append(message)
                self?.messages.sort { msg1, msg2 in
                    let time1 = msg1.createdAt ?? ""
                    let time2 = msg2.createdAt ?? ""
                    return time1 < time2
                }
                print("✅ 带附件消息发送成功")
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func markAsRead(uptoMessageId: Int? = nil) {
        // 使用任务聊天专用标记已读端点
        // 如果提供了 uptoMessageId，使用它；否则使用最新消息的ID
        let messageId = uptoMessageId ?? messages.last?.messageId
        
        // 根据后端要求，如果没有 messageId，不发送 body（空字典可能导致422错误）
        var body: [String: Any]? = nil
        if let messageId = messageId {
            body = ["upto_message_id": messageId]
            print("📤 标记任务聊天已读，任务ID: \(taskId), 消息ID: \(messageId)")
        } else {
            print("📤 标记任务聊天已读，任务ID: \(taskId)（无消息ID，不发送body）")
        }
        
        // 如果有 body 才发送，否则使用空 body
        apiService.request(EmptyResponse.self, "/api/messages/task/\(taskId)/read", method: "POST", body: body ?? [:])
            .sink(receiveCompletion: { result in
                if case .failure(let error) = result {
                    print("⚠️ 标记任务聊天已读失败: \(error)")
                }
            }, receiveValue: { _ in
                print("✅ 任务聊天已标记为已读")
            })
            .store(in: &cancellables)
    }
}

