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
    
    override private init() {
        super.init()
        self.session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
    }
    
    func connect(token: String, userId: String) {
        // 如果已经连接到同一个用户，不需要重新连接
        if isConnected && currentUserId == userId {
            return
        }
        
        // 如果连接到不同用户，先断开旧连接
        if isConnected {
            disconnect()
        }
        
        currentUserId = userId
        // 保存userId到UserDefaults以便重连时使用
        UserDefaults.standard.set(userId, forKey: "current_user_id")
        
        let urlString = "\(Constants.API.wsURL)/ws/chat/\(userId)?token=\(token)"
        guard let url = URL(string: urlString) else { return }
        
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        receiveMessage()
    }
    
    func disconnect() {
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
                print("WebSocket receive error: \(error)")
                self.isConnected = false
                self.reconnect()
            }
        }
    }
    
    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        
        do {
            let message = try JSONDecoder().decode(Message.self, from: data)
            DispatchQueue.main.async {
                self.messageSubject.send(message)
            }
        } catch {
            print("WebSocket message decoding error: \(error)")
        }
    }
    
    func send(_ message: String) {
        let message = URLSessionWebSocketTask.Message.string(message)
        webSocketTask?.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }
    
    private func reconnect() {
        guard !isConnected && reconnectAttempts < maxReconnectAttempts else { return }
        
        reconnectAttempts += 1
        let delay = Double(reconnectAttempts) * 2.0
        
        DispatchQueue.global().asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self = self else { return }
            // 从AppState获取userId，从Keychain获取token
            if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey),
               let userId = AppState.shared.currentUser?.id {
                self.connect(token: token, userId: String(userId))
            } else if let userId = self.currentUserId,
                      let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                // 如果AppState还没有用户信息，使用存储的userId
                self.connect(token: token, userId: userId)
            }
        }
    }
    
    // MARK: - URLSessionWebSocketDelegate
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        print("WebSocket connected")
        isConnected = true
        reconnectAttempts = 0
    }
    
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        print("WebSocket disconnected")
        isConnected = false
        reconnect()
    }
}

