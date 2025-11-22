//
//  MessageViewModel.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI
import Combine

class MessageViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [Message] = []
    @Published var currentConversationId: Int?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var unreadCount = 0
    
    private var cancellables = Set<AnyCancellable>()
    private let apiService = APIService.shared
    private var wsSubscription: (() -> Void)?
    
    init() {
        setupWebSocket()
    }
    
    func loadConversations() {
        isLoading = true
        errorMessage = nil
        
        apiService.getConversations()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.conversations = response.conversations
                }
            )
            .store(in: &cancellables)
    }
    
    func loadMessages(conversationId: Int) {
        isLoading = true
        currentConversationId = conversationId
        
        apiService.getMessages(conversationId: conversationId)
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.errorMessage = error.localizedDescription
                    }
                },
                receiveValue: { [weak self] response in
                    self?.messages = response.messages
                }
            )
            .store(in: &cancellables)
    }
    
    func sendMessage(content: String, receiverId: Int, taskId: Int? = nil) {
        // 优先通过WebSocket发送
        if WebSocketService.shared.isConnected {
            let message: [String: Any] = [
                "type": "message",
                "content": content,
                "receiver_id": receiverId,
                "task_id": taskId as Any
            ]
            WebSocketService.shared.sendJSON(message)
            
            // 立即添加到消息列表（乐观更新）
            let tempMessage = Message(
                id: Int(Date().timeIntervalSince1970),
                content: content,
                senderId: UserDefaults.standard.integer(forKey: "currentUserId"),
                receiverId: receiverId,
                taskId: taskId,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                isRead: false
            )
            messages.append(tempMessage)
        } else {
            // WebSocket未连接，使用HTTP API
            apiService.sendMessage(content: content, receiverId: receiverId, taskId: taskId)
                .receive(on: DispatchQueue.main)
                .sink(
                    receiveCompletion: { [weak self] completion in
                        if case .failure(let error) = completion {
                            self?.errorMessage = error.localizedDescription
                        }
                    },
                    receiveValue: { [weak self] message in
                        self?.messages.append(message)
                    }
                )
                .store(in: &cancellables)
        }
    }
    
    private func setupWebSocket() {
        // 订阅WebSocket消息
        wsSubscription = WebSocketService.shared.subscribe { [weak self] message in
            if let msg = message as? Message {
                self?.handleNewMessage(msg)
            } else if let json = message as? [String: Any],
                      let type = json["type"] as? String,
                      type == "message_sent" {
                // 收到新消息通知，刷新消息列表
                if let conversationId = self?.currentConversationId {
                    self?.loadMessages(conversationId: conversationId)
                }
                self?.refreshUnreadCount()
            }
        }
    }
    
    private func handleNewMessage(_ message: Message) {
        // 如果是当前对话的消息，添加到消息列表
        if let conversationId = currentConversationId,
           message.taskId == conversationId {
            DispatchQueue.main.async {
                self.messages.append(message)
            }
        }
        refreshUnreadCount()
    }
    
    func refreshUnreadCount() {
        apiService.getUnreadCount()
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { _ in },
                receiveValue: { [weak self] response in
                    self?.unreadCount = response.count
                }
            )
            .store(in: &cancellables)
    }
    
    deinit {
        wsSubscription?()
    }
}

struct Conversation: Identifiable, Codable {
    let id: Int
    let otherUser: User
    let lastMessage: Message?
    let unreadCount: Int
    let updatedAt: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case otherUser = "other_user"
        case lastMessage = "last_message"
        case unreadCount = "unread_count"
        case updatedAt = "updated_at"
    }
}

