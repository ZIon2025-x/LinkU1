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
                print("✅ WebSocket 已连接到用户 \(userId)，跳过重复连接")
                return
            }
            
            // 如果正在连接中，等待完成
            if self.isConnecting {
                print("⏳ WebSocket 正在连接中，跳过重复连接")
                return
            }
            
            // 如果连接到不同用户，先断开旧连接
            if self.isConnected || self.webSocketTask != nil {
                print("🔄 断开旧连接")
                self.forceDisconnect()
                // 等待一小段时间确保旧连接完全关闭
                Thread.sleep(forTimeInterval: 0.5)
            }
            
            self.isConnecting = true
            self.currentUserId = userId
            // 保存userId到UserDefaults以便重连时使用
            UserDefaults.standard.set(userId, forKey: "current_user_id")
            
            let urlString = "\(Constants.API.wsURL)/ws/chat/\(userId)?token=\(token)"
            guard let url = URL(string: urlString) else {
                print("❌ WebSocket URL 无效: \(urlString)")
                self.isConnecting = false
                return
            }
            
            print("🔌 正在连接 WebSocket: \(urlString)")
            
            DispatchQueue.main.async {
                self.webSocketTask = self.session?.webSocketTask(with: url)
                self.webSocketTask?.resume()
                self.receiveMessage()
            }
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
            print("🧹 WebSocket 已断开并清除用户信息")
        } else {
            // ⚠️ 保留 currentUserId 和 UserDefaults 中的 userId，以便重连时使用
            print("🔌 WebSocket 已断开（保留用户信息以便重连）")
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
                // 检查是否是正常的断开连接
                if let nsError = error as NSError? {
                    // Code 57 = Socket is not connected (正常断开)
                    // Code 60 = Operation timed out
                    if nsError.code == 57 {
                        print("🔌 WebSocket 已断开连接（正常）")
                    } else {
                        print("⚠️ WebSocket receive error: \(error.localizedDescription) (code: \(nsError.code))")
                    }
                } else {
                    print("⚠️ WebSocket receive error: \(error)")
                }
                self.isConnected = false
                // 只有在非正常断开时才尝试重连
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
            
            // 处理通知创建事件（参考 frontend）
            if type == "notification_created" {
                print("🔔 WebSocket 收到通知创建事件")
                // 通知 AppState 刷新未读通知数量
                DispatchQueue.main.async { [weak self] in
                    self?.notificationSubject.send()
                }
                return
            }
            
            // 处理 pong 或 heartbeat 消息
            if type == "pong" || type == "heartbeat" {
                return
            }
        }
        
        // 在后台线程解码，然后切换到主线程发送
        DispatchQueue.main.async { [weak self] in
            do {
                // 在主线程解码以避免 main actor 隔离问题
                let decoder = JSONDecoder()
                let message = try decoder.decode(Message.self, from: data)
                // 只处理有 content 的消息（过滤掉系统消息或其他类型的消息）
                if message.content != nil {
                    self?.messageSubject.send(message)
                } else {
                    print("⚠️ WebSocket 收到无 content 的消息，已忽略: \(text.prefix(100))")
                }
            } catch {
                print("❌ WebSocket message decoding error: \(error)")
                print("📥 原始消息内容: \(text.prefix(500))")
            }
        }
    }
    
    private func sendPong() {
        let pongMessage = "{\"type\":\"pong\"}"
        send(pongMessage)
    }
    
    func send(_ message: String) {
        guard let webSocketTask = webSocketTask, isConnected else {
            print("⚠️ WebSocket 未连接，无法发送消息")
            return
        }
        
        let wsMessage = URLSessionWebSocketTask.Message.string(message)
        webSocketTask.send(wsMessage) { error in
            if let error = error {
                if let nsError = error as NSError?, nsError.code == 57 {
                    // Socket is not connected - 正常断开，不需要打印错误
                    print("🔌 WebSocket 发送失败：连接已断开")
                } else {
                    print("⚠️ WebSocket send error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private var reconnectWorkItem: DispatchWorkItem?
    
    private func reconnect() {
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
            // 如果已经在重连中或已连接，取消重连
            if self.isConnecting || self.isConnected {
                print("⏳ WebSocket 正在连接或已连接，跳过重连")
                return
            }
            
            // 如果已经在重连中，取消之前的重连任务
            reconnectWorkItem?.cancel()
            
            guard self.reconnectAttempts < self.maxReconnectAttempts else {
                print("❌ WebSocket 重连次数已达上限（\(self.maxReconnectAttempts)次），停止重连")
                return
            }
            
            self.reconnectAttempts += 1
            let delay = Double(self.reconnectAttempts) * 2.0
            
            print("🔄 WebSocket 尝试重连（第 \(self.reconnectAttempts)/\(self.maxReconnectAttempts) 次，延迟 \(delay) 秒）")
            
            let workItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                
                // 再次检查连接状态
                guard !self.isConnected && !self.isConnecting else {
                    print("⏳ WebSocket 已在连接中，取消重连")
                    return
                }
                
                // 确保旧连接已完全关闭（但不清除 userId）
                if self.webSocketTask != nil {
                    print("🧹 清理旧的 WebSocket 连接")
                    // 只清理连接，不清除 userId
                    self.reconnectWorkItem?.cancel()
                    self.reconnectWorkItem = nil
                    self.webSocketTask?.cancel(with: .goingAway, reason: nil)
                    self.webSocketTask = nil
                    self.isConnected = false
                    self.isConnecting = false
                    Thread.sleep(forTimeInterval: 0.5)
                }
                
                // 从存储的userId和Keychain获取token
                // 优先使用 currentUserId，如果为空则从 UserDefaults 获取
                let userId = self.currentUserId ?? UserDefaults.standard.string(forKey: "current_user_id")
                
                guard let finalUserId = userId, !finalUserId.isEmpty else {
                    print("❌ WebSocket 重连失败：无法获取用户ID")
                    // 如果无法获取用户信息，停止重连
                    self.reconnectAttempts = self.maxReconnectAttempts
                    return
                }
                
                guard let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty else {
                    print("❌ WebSocket 重连失败：无法获取token")
                    // 如果无法获取token，停止重连
                    self.reconnectAttempts = self.maxReconnectAttempts
                    return
                }
                
                print("✅ WebSocket 重连：找到用户ID和token，开始连接")
                self.connect(token: token, userId: finalUserId)
            }
            
            self.reconnectWorkItem = workItem
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        connectionQueue.async { [weak self] in
            self?.isConnected = true
            self?.isConnecting = false
            self?.reconnectAttempts = 0
        }
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        let closeCodeValue = closeCode.rawValue
        print("WebSocket disconnected, closeCode: \(closeCodeValue)")
        
        connectionQueue.async { [weak self] in
            guard let self = self else { return }
            
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
                print("🔌 WebSocket 正常关闭，不重连")
                self.reconnectAttempts = 0
            default:
                // 处理 4001 错误代码（心跳超时）
                if closeCodeValue == 4001 {
                    print("⚠️ WebSocket 关闭代码 4001（心跳超时），尝试重连")
                    // 心跳超时，直接重连（不需要等待token刷新）
                    self.reconnect()
                }
                // 处理 1008 错误代码（认证失败）
                else if closeCodeValue == 1008 {
                    print("⚠️ WebSocket 关闭代码 1008（认证失败）")
                    // 检查token是否存在
                    if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty {
                        print("⚠️ Token 存在，但认证失败，可能是token已过期。延迟重连（等待token刷新）")
                        // 延迟重连，给token刷新机制时间
                        DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                            // 再次检查token是否仍然存在
                            if let newToken = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !newToken.isEmpty {
                                self.reconnect()
                            } else {
                                print("❌ Token 已清除，停止 WebSocket 重连")
                                self.reconnectAttempts = self.maxReconnectAttempts
                            }
                        }
                    } else {
                        print("❌ Token 不存在，停止 WebSocket 重连")
                        // Token不存在，停止重连
                        self.reconnectAttempts = self.maxReconnectAttempts
                    }
                } else {
                    print("⚠️ WebSocket 异常关闭（代码: \(closeCodeValue)），尝试重连")
                    self.reconnect()
                }
            }
        }
    }
}

