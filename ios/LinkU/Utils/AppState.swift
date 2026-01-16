import Foundation
import Combine

public class AppState: ObservableObject {
    @Published public var isAuthenticated: Bool = false
    @Published public var currentUser: User?
    
    private let apiService = APIService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public init() {
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
                if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                    WebSocketService.shared.connect(token: token, userId: String(user.id))
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
    
    public func checkLoginStatus() {
        if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey), !token.isEmpty {
            // 验证Token有效性并加载用户信息
            apiService.request(User.self, "/api/users/profile/me", method: "GET")
                .sink(receiveCompletion: { [weak self] result in
                    if case .failure(let error) = result {
                        // ⚠️ 修复：区分网络错误和认证错误
                        // 只有真正的认证失败（401且刷新失败）才应该登出
                        // 网络错误、超时等不应该导致登出，保持登录状态
                        if case APIError.unauthorized = error {
                            // 401 未授权：可能是 token 过期，尝试刷新
                            print("登录状态检查：401 未授权，可能是 token 过期")
                            // 注意：APIService 会自动尝试刷新 token
                            // 如果刷新失败，APIService 会处理登出逻辑
                            // 这里不立即登出，等待刷新结果
                        } else if case APIError.httpError(401) = error {
                            // HTTP 401 错误：认证失败
                            print("登录状态检查：HTTP 401 错误，认证失败")
                            // 不立即登出，等待 token 刷新机制处理
                        } else {
                            // 网络错误、超时等：不登出，保持登录状态
                            print("登录状态检查失败（网络错误），保持登录状态: \(error.localizedDescription)")
                            // 保持 isAuthenticated 状态，不调用 logout()
                            // 用户仍然可以尝试使用应用，如果 token 有效，后续请求会成功
                        }
                    }
                }, receiveValue: { [weak self] user in
                    self?.currentUser = user
                    self?.isAuthenticated = true
                    
                    // 建立WebSocket连接
                    if let token = KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) {
                        WebSocketService.shared.connect(token: token, userId: String(user.id))
                    }
                })
                .store(in: &cancellables)
        } else {
            isAuthenticated = false
        }
    }
    
    public func logout() {
        // 断开WebSocket连接
        WebSocketService.shared.disconnect()
        
        KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey)
        KeychainHelper.shared.delete(service: Constants.Keychain.service, account: Constants.Keychain.refreshTokenKey)
        isAuthenticated = false
        currentUser = nil
    }
}

