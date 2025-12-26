import Foundation
import Combine

/// 依赖注入容器 - 企业级架构核心
/// 提供类型安全的依赖注入，支持单例和工厂模式
public final class DependencyContainer {
    public static let shared = DependencyContainer()
    
    private var services: [String: Any] = [:]
    private var factories: [String: () -> Any] = [:]
    private let lock = NSLock()
    
    private init() {
        registerDefaultServices()
    }
    
    // MARK: - 注册服务
    
    /// 注册单例服务
    public func register<T>(_ type: T.Type, instance: T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        services[key] = instance
    }
    
    /// 注册工厂方法
    public func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        factories[key] = factory
    }
    
    // MARK: - 解析服务
    
    /// 解析服务（单例或工厂）
    public func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        
        // 先尝试单例
        if let instance = services[key] as? T {
            return instance
        }
        
        // 再尝试工厂
        if let factory = factories[key] as? () -> T {
            let instance = factory()
            // 缓存单例
            services[key] = instance
            return instance
        }
        
        fatalError("Service \(key) not registered")
    }
    
    /// 可选解析（不会崩溃）
    public func resolveOptional<T>(_ type: T.Type) -> T? {
        let key = String(describing: type)
        lock.lock()
        defer { lock.unlock() }
        
        if let instance = services[key] as? T {
            return instance
        }
        
        if let factory = factories[key] as? () -> T {
            let instance = factory()
            services[key] = instance
            return instance
        }
        
        return nil
    }
    
    // MARK: - 默认服务注册
    
    private func registerDefaultServices() {
        // API 服务
        register(APIServiceProtocol.self) { APIService.shared }
        
        // WebSocket 服务
        register(WebSocketServiceProtocol.self) { WebSocketService.shared }
        
        // 缓存管理器
        register(CacheManagerProtocol.self) { CacheManager.shared }
        
        // 位置服务
        register((any LocationServiceProtocol).self) { LocationService.shared as any LocationServiceProtocol }
        
        // Keychain 助手
        register(KeychainHelperProtocol.self) { KeychainHelper.shared }
    }
    
    // MARK: - 清理
    
    /// 清除所有注册的服务（主要用于测试）
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        services.removeAll()
        factories.removeAll()
        registerDefaultServices()
    }
}

// MARK: - 协议定义

/// API 服务协议
public protocol APIServiceProtocol {
    func request<T: Decodable>(_ type: T.Type, _ endpoint: String, method: String, body: [String: Any]?, headers: [String: String]?) -> AnyPublisher<T, APIError>
}

extension APIService: APIServiceProtocol {}

/// WebSocket 服务协议
public protocol WebSocketServiceProtocol {
    func connect(token: String, userId: String)
    func disconnect()
    var notificationSubject: PassthroughSubject<Void, Never> { get }
    var messageSubject: PassthroughSubject<Message, Never> { get }
}

extension WebSocketService: WebSocketServiceProtocol {}

/// 缓存管理器协议
public protocol CacheManagerProtocol {
    func save<T: Codable>(_ object: T, forKey key: String)
    func load<T: Codable>(_ type: T.Type, forKey key: String) -> T?
    func remove(forKey key: String)
    func clearAll()
}

extension CacheManager: CacheManagerProtocol {}

/// 位置服务协议
public protocol LocationServiceProtocol: ObservableObject {
    var currentLocation: LocationInfo? { get }
    var currentCityName: String? { get }
    func requestLocationAuthorization()
    func startUpdatingLocation()
    func stopUpdatingLocation()
}

extension LocationService: LocationServiceProtocol {}

/// Keychain 助手协议
public protocol KeychainHelperProtocol {
    func save(_ data: Data, service: String, account: String) -> Bool
    func read(service: String, account: String) -> String?
    func delete(service: String, account: String) -> Bool
}

extension KeychainHelper: KeychainHelperProtocol {}

