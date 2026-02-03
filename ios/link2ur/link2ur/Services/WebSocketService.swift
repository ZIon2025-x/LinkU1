import Foundation
import Combine

class WebSocketService: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    static let shared = WebSocketService()
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var reconnectAttempts = 0
    private let maxReconnectAttempts = 5
    @Published var isConnected = false
    private var currentUserId: String?
    private var isConnecting = false // 防止并发连接
    private let connectionQueue = DispatchQueue(label: "com.link2ur.websocket.connection")
    private var heartbeatTimer: Timer?
    
    // 发布接收到的消息
    let messageSubject = PassthroughSubject<Message, Never>()
    
    // 发布接收到的通知事件
    let notificationSubject = PassthroughSubject<Void, Never>()
    
    override private init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect(token: String, userId: String) {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 如果已经连接到同一个用户，不需要重新连接
            if self.isConnected && self.currentUserId == userId {
                return
            }
            
            if self.webSocketTask != nil && self.currentUserId == userId {
                return
            }
            
            if self.isConnecting {
                return
            }
            
            if self.isConnected || self.webSocketTask != nil {
                self.forceDisconnect()
                // 使用异步延迟替代 Thread.sleep，避免阻塞 connectionQueue
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    self?.connectionQueue.async {
                        self?.performConnect(token: token, userId: userId)
                    }
                }
                return
            }
            
            self.performConnect(token: token, userId: userId)
        }
    }
    
    /// 在 connectionQueue 上执行实际连接（供 connect 与延迟后调用）
    private func performConnect(token: String, userId: String) {
        guard !isConnecting else { return }
        isConnecting = true
        currentUserId = userId
        UserDefaults.standard.set(userId, forKey: "current_user_id")
        
        let urlString = "\(Constants.API.wsURL)/ws/chat/\(userId)?token=\(token)"
        guard let url = URL(string: urlString) else {
            isConnecting = false
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.webSocketTask = self.session?.webSocketTask(with: url)
            self.webSocketTask?.resume()
            self.receiveMessage()
        }
    }
    
    func disconnect() {
        connectionQueue.async { [weak self] in
            self?.forceDisconnect(clearUserInfo: false)
        }
    }
    
    /// 完全断开连接并清除用户信息（用于登出等场景）
    func disconnectAndClear() {
        connectionQueue.async { [weak self] in
            self?.forceDisconnect(clearUserInfo: true)
        }
    }
    
    private func forceDisconnect(clearUserInfo: Bool = false) {
        // 取消正在进行的重连
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        
        stopHeartbeat()
        
        // 取消 WebSocket 任务
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        isConnected = false
        isConnecting = false
        reconnectAttempts = 0
        
        // 根据参数决定是否清除用户信息
        if clearUserInfo {
            currentUserId = nil
            UserDefaults.standard.removeObject(forKey: "current_user_id")
        }
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                self.receiveMessage() // 继续监听
                
            case .failure(let error):
                self.webSocketTask = nil
                self.isConnected = false
                if let nsError = error as NSError?, nsError.code != 57 {
                    self.reconnect()
                }
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        // 先检查是否是ping消息
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String {
            
            if type == "ping" {
                // 响应pong消息以保持连接
                sendPong()
                return
            }
            
            if type == "notification_created" {
                DispatchQueue.main.async { [weak self] in
                    self?.notificationSubject.send()
                }
                return
            }
            
            // 处理 pong 或 heartbeat 消息
            if type == "pong" || type == "heartbeat" {
                return
            }
            
            // 处理任务消息（格式：{ "type": "task_message", "message": {...} }）
            if type == "task_message", let messageDict = json["message"] as? [String: Any] {
                guard let messageData = try? JSONSerialization.data(withJSONObject: messageDict) else { return }
                // 在主线程解码，避免 Swift 6 下 Message 的 main actor-isolated Decodable 在非隔离上下文使用的警告
                DispatchQueue.main.async { [weak self] in
                    do {
                        let decoder = JSONDecoder()
                        let message = try decoder.decode(Message.self, from: messageData)
                        guard message.content != nil else { return }
                        self?.messageSubject.send(message)
                    } catch { }
                }
                return
            }
        }
        
        // 在主线程解码并发送（Message 的 Decodable 为 main actor-isolated，需在主线程解码以避免 Swift 6 警告）
        DispatchQueue.main.async { [weak self] in
            do {
                let decoder = JSONDecoder()
                let message = try decoder.decode(Message.self, from: data)
                guard message.content != nil else { return }
                self?.messageSubject.send(message)
            } catch { }
        }
    }
    
    private func sendPong() {
        // 直接用 task 发送，不依赖 isConnected 标志（避免 didOpen 未回调时无法响应 ping）
        guard let webSocketTask = webSocketTask else { return }
        let pongMessage = URLSessionWebSocketTask.Message.string("{\"type\":\"pong\"}")
        webSocketTask.send(pongMessage) { _ in }
    }
    
    private func startHeartbeat() {
        stopHeartbeat()
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 将心跳间隔从 25 秒增加到 30 秒，减少心跳频率，降低超时风险
            // 同时避免过于频繁的心跳占用资源
            self.heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
                self?.sendPong()
            }
        }
    }
    
    private func stopHeartbeat() {
        DispatchQueue.main.async { [weak self] in
            self?.heartbeatTimer?.invalidate()
            self?.heartbeatTimer = nil
        }
    }
    
    func send(_ message: String) {
        guard let webSocketTask = webSocketTask, isConnected else { return }
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask.send(wsMessage) { _ in }
    }
    
    private var reconnectWorkItem: DispatchWorkItem?
    
    private func reconnect() {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.isConnecting || self.isConnected {
                return
            }
            
            reconnectWorkItem?.cancel()
            
            guard self.reconnectAttempts < self.maxReconnectAttempts else {
                return
            }
            
            self.reconnectAttempts += 1
            let delay = Double(self.reconnectAttempts) * 2.0
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                guard !self.isConnected && !self.isConnecting else {
                    return
                }
                
                if self.webSocketTask != nil {
                    self.reconnectWorkItem?.cancel()
                    self.reconnectWorkItem = nil
                    self.webSocketTask?.cancel(with: .goingAway, reason: nil)
                    self.webSocketTask = nil
                    self.isConnected = false
                    self.isConnecting = false
                    // 使用异步延迟替代 Thread.sleep，避免阻塞
                    DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.connectionQueue.async {
                            guard let self = self else { return }
                            let userId = self.currentUserId ?? UserDefaults.standard.string(forKey: "current_user_id")
                            guard let finalUserId = userId, !finalUserId.isEmpty else {
                                self.reconnectAttempts = self.maxReconnectAttempts
                                return
                            }
                            guard let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty else {
                                self.reconnectAttempts = self.maxReconnectAttempts
                                return
                            }
                            self.connect(token: token, userId: finalUserId)
                        }
                    }
                    return
                }
                
                let userId = self.currentUserId ?? UserDefaults.standard.string(forKey: "current_user_id")
                guard let finalUserId = userId, !finalUserId.isEmpty else {
                    self.reconnectAttempts = self.maxReconnectAttempts
                    return
                }
                guard let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty else {
                    self.reconnectAttempts = self.maxReconnectAttempts
                    return
                }
                self.connect(token: token, userId: finalUserId)
            }
            
            self.reconnectWorkItem = workItem
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        connectionQueue.async { [weak self] in
            self?.isConnected = true
            self?.isConnecting = false
            self?.reconnectAttempts = 0
        }
        startHeartbeat()
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let closeCodeValue = closeCode.rawValue
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 立即清空 task，避免任何后续 send/receive 对已关闭连接写入（消除 nw_flow_add_write_request / Socket is not connected）
            self.webSocketTask?.cancel(with: .goingAway, reason: nil)
            self.webSocketTask = nil
            self.isConnected = false
            self.isConnecting = false
            
            // 根据关闭代码决定是否重连
            // .goingAway (1001) = 正常关闭，不需要重连
            // .normalClosure (1000) = 正常关闭，不需要重连
            // 4001 = 心跳超时（后端定义），需要重连
            // 1008 = 认证失败（协议错误），需要检查token有效性
            // 其他代码 = 异常关闭，需要重连
            switch closeCode {
            case .goingAway, .normalClosure:
                self.reconnectAttempts = 0
            default:
                if closeCodeValue == 4001 {
                    self.reconnect()
                } else if closeCodeValue == 1008 {
                    if KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) != nil {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                            if KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) != nil {
                                self.reconnect()
                            } else {
                                self.reconnectAttempts = self.maxReconnectAttempts
                            }
                        }
                    } else {
                        self.reconnectAttempts = self.maxReconnectAttempts
                    }
                } else {
                    self.reconnect()
                }
            }
        }
    }
}

