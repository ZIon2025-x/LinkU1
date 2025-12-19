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
    
    // 发布接收到的消息
    let messageSubject = PassthroughSubject<Message, Never>()
    
    // 发布接收到的通知事件
    let notificationSubject = PassthroughSubject<Void, Never>()
    
    override private init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect(token: String, userId: String) {
        // 如果已经连接到同一个用户，不需要重新连接
        if isConnected && currentUserId == userId {
            print("✅ WebSocket 已连接到用户 \(userId)，跳过重复连接")
            return
        }
        
        // 如果连接到不同用户，先断开旧连接
        if isConnected {
            print("🔄 切换到新用户，断开旧连接")
            disconnect()
        }
        
        currentUserId = userId
        // 保存userId到UserDefaults以便重连时使用
        UserDefaults.standard.set(userId, forKey: "current_user_id")
        
        let urlString = "\(Constants.API.wsURL)/ws/chat/\(userId)?token=\(token)"
        guard let url = URL(string: urlString) else {
            print("❌ WebSocket URL 无效: \(urlString)")
            return
        }
        
        print("🔌 正在连接 WebSocket: \(urlString)")
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    func disconnect() {
        // 取消正在进行的重连
        reconnectWorkItem?.cancel()
        reconnectWorkItem = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        currentUserId = nil
        reconnectAttempts = 0
        // 清除存储的userId
        UserDefaults.standard.removeObject(forKey: "current_user_id")
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
        // 如果已经在重连中，取消之前的重连任务
        reconnectWorkItem?.cancel()
        
        guard !isConnected && reconnectAttempts < maxReconnectAttempts else {
            if reconnectAttempts >= maxReconnectAttempts {
                print("❌ WebSocket 重连次数已达上限（\(maxReconnectAttempts)次），停止重连")
            }
            return
        }
        
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2.0
        
        print("🔄 WebSocket 尝试重连（第 \(reconnectAttempts)/\(maxReconnectAttempts) 次，延迟 \(delay) 秒）")
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self, !self.isConnected else { return }
            
            // 从存储的userId和Keychain获取token
            if let userId = self.currentUserId,
               let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                self.connect(token: token, userId: userId)
            } else if let storedUserId = UserDefaults.standard.string(forKey: "current_user_id"),
                      let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                // 使用存储的userId
                self.connect(token: token, userId: storedUserId)
            } else {
                print("❌ WebSocket 重连失败：无法获取用户ID或token")
                // 如果无法获取用户信息，停止重连
                self.reconnectAttempts = self.maxReconnectAttempts
            }
        }
        
        reconnectWorkItem = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: workItem)
    }
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        isConnected = true
        reconnectAttempts = 0
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected, closeCode: \(closeCode.rawValue)")
        isConnected = false
        
        // 根据关闭代码决定是否重连
        // .goingAway (1001) = 正常关闭，不需要重连
        // .normalClosure (1000) = 正常关闭，不需要重连
        // 其他代码 = 异常关闭，需要重连
        switch closeCode {
        case .goingAway, .normalClosure:
            print("🔌 WebSocket 正常关闭，不重连")
            reconnectAttempts = 0
        default:
            print("⚠️ WebSocket 异常关闭，尝试重连")
            reconnect()
        }
    }
}

