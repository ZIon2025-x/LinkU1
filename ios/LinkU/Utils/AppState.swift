import Foundation
import Combine

class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        checkLoginStatus()
        setupNotifications()
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: .userDidLogin)
            .compactMap { $0.object as? User }
            .sink { [weak self] user in
                self?.currentUser = user
                self?.isAuthenticated = true
                
                // 登录成功后，建立WebSocket连接
                if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey),
                   let userId = user.id {
                    WebSocketService.shared.connect(token: token, userId: String(userId))
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .userDidLogout)
            .sink { [weak self] _ in
                // 登出时断开WebSocket连接
                WebSocketService.shared.disconnect()
                self?.logout()
            }
            .store(in: &cancellables)
    }
    
    func checkLoginStatus() {
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty {
            // 验证Token有效性并加载用户信息
            apiService.request(User.self, "/api/users/profile/me", method: "GET")
                .sink(receiveCompletion: { [weak self] completion in
                    if case .failure = completion {
                        // Token无效，清除并登出
                        self?.logout()
                    }
                }, receiveValue: { [weak self] user in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    
                    // 建立WebSocket连接
                    if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey),
                       let userId = user.id {
                        WebSocketService.shared.connect(token: token, userId: String(userId))
                    }
                })
                .store(in: &cancellables)
        } else {
            isAuthenticated = false
        }
    }
    
    func logout() {
        // 断开WebSocket连接
        WebSocketService.shared.disconnect()
        
        KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
        KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
        isAuthenticated = false
        currentUser = nil
    }
}

