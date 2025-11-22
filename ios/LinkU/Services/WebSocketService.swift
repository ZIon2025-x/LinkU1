//
//  WebSocketService.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import Foundation
import Combine

class WebSocketService: NSObject, URLSessionWebSocketDelegate {
    static let shared = WebSocketService()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    
    @Published var isConnected = false
    @Published var receivedMessage: Message?
    
    // 消息处理器闭包数组
    private var messageHandlers: [(Any) -> Void] = []
    
    // 订阅消息
    func subscribe(_ handler: @escaping (Any) -> Void) -> (() -> Void) {
        messageHandlers.append(handler)
        return { [weak self] in
            self?.messageHandlers.removeAll { $0 as AnyObject === handler as AnyObject }
        }
    }
    
    func connect(userId: String) {
        // 使用Cookie认证，无需在URL中传递token
        guard let url = URL(string: "wss://api.link2ur.com/ws/chat/\(userId)") else {
            print("WebSocket: 无效的URL")
            return
        }
        
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self?.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self?.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self?.receiveMessage() // 继续接收
            case .failure(let error):
                print("WebSocket接收错误: \(error)")
                self?.reconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else {
            return
        }
        
        // 尝试解析为Message
        if let message = try? JSONDecoder().decode(Message.self, from: data) {
            DispatchQueue.main.async {
                self.receivedMessage = message
                // 通知所有订阅者
                self.messageHandlers.forEach { handler in
                    handler(message)
                }
            }
            return
        }
        
        // 尝试解析为通用JSON
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // 处理心跳消息
            if let type = json["type"] as? String {
                if type == "ping" {
                    // 响应pong
                    send(JSONSerialization.jsonObject(with: ["type": "pong"]) ?? "")
                    return
                }
                if type == "pong" || type == "heartbeat" {
                    return
                }
            }
            
            // 通知所有订阅者
            DispatchQueue.main.async {
                self.messageHandlers.forEach { handler in
                    handler(json)
                }
            }
        }
    }
    
    func send(_ message: String) {
        guard let webSocketTask = webSocketTask,
              webSocketTask.state == .running else {
            print("WebSocket: 连接未建立，无法发送消息")
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask.send(wsMessage) { error in
            if let error = error {
                print("WebSocket发送错误: \(error)")
            }
        }
    }
    
    func sendJSON(_ json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let jsonString = String(data: data, encoding: .utf8) else {
            print("WebSocket: JSON序列化失败")
            return
        }
        send(jsonString)
    }
    
    private func reconnect() {
        guard reconnectAttempts < maxReconnectAttempts else {
            print("WebSocket: 已达到最大重连次数")
            return
        }
        
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2.0 // 递增延迟：2秒、4秒、6秒...
        
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            // 需要从AuthViewModel获取userId，这里先使用占位符
            // 实际使用时应该从AuthViewModel传递userId
            if let userId = UserDefaults.standard.string(forKey: "currentUserId") {
                self?.connect(userId: userId)
            }
        }
    }
    
    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        DispatchQueue.main.async {
            self.isConnected = true
            self.reconnectAttempts = 0
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        DispatchQueue.main.async {
            self.isConnected = false
        }
        reconnect()
    }
}

