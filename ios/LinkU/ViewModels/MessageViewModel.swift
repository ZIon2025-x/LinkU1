import Foundation
import Combine

class MessageViewModel: ObservableObject {
    @Published var conversations: [Contact] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    func loadConversations() {
        isLoading = true
        apiService.request([Contact].self, "/api/users/conversations", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] contacts in
                self?.conversations = contacts
            })
            .store(in: &cancellables)
    }
    
    func markAsRead(contactId: String) {
        apiService.request(EmptyResponse.self, "/api/users/messages/mark-chat-read/\(contactId)", method: "POST", body: [:])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in
                // 更新本地未读数
                if let index = self.conversations.firstIndex(where: { $0.id == contactId }) {
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
                            // 自动排序
                            self.messages.sort { $0.createdAt < $1.createdAt }
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
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    private let partnerId: String
    
    init(partnerId: String, partner: Contact? = nil) {
        self.partnerId = partnerId
        self.partner = partner
    }
    
    func loadMessages() {
        isLoading = true
        apiService.request([Message].self, "/api/users/messages/conversation/\(partnerId)", method: "GET")
            .sink(receiveCompletion: { [weak self] result in
                self?.isLoading = false
                if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
            }, receiveValue: { [weak self] messages in
                self?.messages = messages.sorted { msg1, msg2 in
                    // 按时间排序
                    return msg1.createdAt < msg2.createdAt
                }
            })
            .store(in: &cancellables)
    }
    
    func sendMessage(content: String, completion: @escaping (Bool) -> Void) {
        let body: [String: Any] = [
            "receiver_id": partnerId,
            "content": content
        ]
        
        apiService.request(Message.self, "/api/users/messages/send", method: "POST", body: body)
            .sink(receiveCompletion: { result in
                if case .failure = result {
                    completion(false)
                }
            }, receiveValue: { [weak self] message in
                self?.messages.append(message)
                completion(true)
            })
            .store(in: &cancellables)
    }
    
    func markAsRead() {
        // 标记整个对话为已读
        apiService.request(EmptyResponse.self, "/api/users/messages/mark-chat-read/\(partnerId)", method: "POST", body: [:])
            .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
            .store(in: &cancellables)
    }
}

