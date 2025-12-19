import Foundation
import Combine

/// 应用状态管理器 - 企业级状态管理
public class AppStateManager: ObservableObject {
    public static let shared = AppStateManager()
    
    @Published public var isOnline: Bool = true
    @Published public var isAuthenticated: Bool = false
    @Published public var appVersion: String = ""
    @Published public var buildNumber: String = ""
    
    // 使用泛型存储用户对象，避免直接依赖 User 类型
    @Published public var currentUserId: String?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupObservers()
        loadInitialState()
    }
    
    private func setupObservers() {
        // 网络状态
        Reachability.shared.$isConnected
            .assign(to: &$isOnline)
        
        // 应用版本
        appVersion = AppVersion.current
        buildNumber = AppVersion.build
    }
    
    private func loadInitialState() {
        // 加载初始状态
        // TODO: 从存储加载
    }
    
    /// 更新用户状态
    public func updateUser(userId: String?) {
        currentUserId = userId
        isAuthenticated = userId != nil
    }
    
    /// 清除状态
    public func clear() {
        currentUserId = nil
        isAuthenticated = false
    }
}

