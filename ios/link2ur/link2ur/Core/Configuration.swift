import Foundation

/// 企业级配置管理
/// 支持多环境配置、特性开关、远程配置等

public struct AppConfiguration {
    public static let shared = AppConfiguration()
    
    // MARK: - 环境配置
    
    public enum Environment {
        case development
        case staging
        case production
        
        var apiBaseURL: String {
            switch self {
            case .development:
                return "https://dev-api.link2ur.com"
            case .staging:
                return "https://staging-api.link2ur.com"
            case .production:
                return "https://api.link2ur.com"
            }
        }
        
        var websocketURL: String {
            switch self {
            case .development:
                return "wss://dev-api.link2ur.com"
            case .staging:
                return "wss://staging-api.link2ur.com"
            case .production:
                return "wss://api.link2ur.com"
            }
        }
    }
    
    public let environment: Environment
    
    // MARK: - 特性开关
    
    public struct FeatureFlags {
        public let enableAnalytics: Bool
        public let enableCrashReporting: Bool
        public let enablePerformanceMonitoring: Bool
        public let enableRemoteConfig: Bool
        public let enableABTesting: Bool
        
        public init(
            enableAnalytics: Bool = true,
            enableCrashReporting: Bool = true,
            enablePerformanceMonitoring: Bool = true,
            enableRemoteConfig: Bool = false,
            enableABTesting: Bool = false
        ) {
            self.enableAnalytics = enableAnalytics
            self.enableCrashReporting = enableCrashReporting
            self.enablePerformanceMonitoring = enablePerformanceMonitoring
            self.enableRemoteConfig = enableRemoteConfig
            self.enableABTesting = enableABTesting
        }
    }
    
    public let featureFlags: FeatureFlags
    
    // MARK: - 网络配置
    
    public struct NetworkConfig {
        public let timeoutInterval: TimeInterval
        public let maxRetries: Int
        public let retryDelay: TimeInterval
        public let enableRequestDeduplication: Bool
        
        public init(
            timeoutInterval: TimeInterval = 30,
            maxRetries: Int = 3,
            retryDelay: TimeInterval = 1.0,
            enableRequestDeduplication: Bool = true
        ) {
            self.timeoutInterval = timeoutInterval
            self.maxRetries = maxRetries
            self.retryDelay = retryDelay
            self.enableRequestDeduplication = enableRequestDeduplication
        }
    }
    
    public let networkConfig: NetworkConfig
    
    // MARK: - 缓存配置
    
    public struct CacheConfig {
        public let memoryCapacity: Int
        public let diskCapacity: Int
        public let cacheExpiration: TimeInterval
        
        public init(
            memoryCapacity: Int = 50 * 1024 * 1024, // 50MB
            diskCapacity: Int = 200 * 1024 * 1024, // 200MB
            cacheExpiration: TimeInterval = 3600 // 1 hour
        ) {
            self.memoryCapacity = memoryCapacity
            self.diskCapacity = diskCapacity
            self.cacheExpiration = cacheExpiration
        }
    }
    
    public let cacheConfig: CacheConfig
    
    // MARK: - 初始化
    
    private init() {
        // 从环境变量或 Info.plist 读取环境
        #if DEBUG
        self.environment = .development
        #else
        // 生产环境可以从配置读取
        if let envString = Bundle.main.infoDictionary?["APP_ENVIRONMENT"] as? String {
            switch envString.lowercased() {
            case "staging":
                self.environment = .staging
            case "production":
                self.environment = .production
            default:
                self.environment = .development
            }
        } else {
            self.environment = .production
        }
        #endif
        
        // 初始化特性开关
        self.featureFlags = FeatureFlags(
            enableAnalytics: true,
            enableCrashReporting: true,
            enablePerformanceMonitoring: true,
            enableRemoteConfig: false,
            enableABTesting: false
        )
        
        // 初始化网络配置
        self.networkConfig = NetworkConfig()
        
        // 初始化缓存配置
        self.cacheConfig = CacheConfig()
    }
    
    // MARK: - 远程配置（可选）
    
    public func loadRemoteConfig(completion: @escaping (Bool) -> Void) {
        guard featureFlags.enableRemoteConfig else {
            completion(false)
            return
        }
        
        // 从服务器加载远程配置
        // 实现远程配置加载逻辑
        completion(false)
    }
}

