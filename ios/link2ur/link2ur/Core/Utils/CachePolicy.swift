import Foundation

/// 缓存策略 - 企业级缓存管理
public enum CachePolicy {
    case networkOnly          // 只使用网络
    case cacheOnly            // 只使用缓存
    case cacheFirst           // 优先缓存
    case networkFirst         // 优先网络
    case cacheThenNetwork     // 先缓存后网络
    
    /// 是否应该使用缓存
    public var shouldUseCache: Bool {
        switch self {
        case .networkOnly:
            return false
        case .cacheOnly, .cacheFirst, .networkFirst, .cacheThenNetwork:
            return true
        }
    }
    
    /// 是否应该使用网络
    public var shouldUseNetwork: Bool {
        switch self {
        case .cacheOnly:
            return false
        case .networkOnly, .cacheFirst, .networkFirst, .cacheThenNetwork:
            return true
        }
    }
}

/// 缓存配置
public struct CacheConfig {
    public let maxAge: TimeInterval
    public let maxSize: Int64
    public let policy: CachePolicy
    
    public init(
        maxAge: TimeInterval = 3600, // 1小时
        maxSize: Int64 = 100 * 1024 * 1024, // 100MB
        policy: CachePolicy = .networkFirst
    ) {
        self.maxAge = maxAge
        self.maxSize = maxSize
        self.policy = policy
    }
}

/// 缓存项
public struct CacheItem<T> {
    public let value: T
    public let timestamp: Date
    public let size: Int64
    
    public var isExpired: Bool {
        return Date().timeIntervalSince(timestamp) > 3600 // 默认1小时
    }
    
    public init(value: T, timestamp: Date = Date(), size: Int64 = 0) {
        self.value = value
        self.timestamp = timestamp
        self.size = size
    }
}

