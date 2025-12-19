import Foundation

/// 过期值包装器 - 企业级过期值管理
@propertyWrapper
public struct ExpiringValue<T> {
    private var value: T?
    private var expirationDate: Date?
    private let ttl: TimeInterval
    
    public init(wrappedValue: T? = nil, ttl: TimeInterval) {
        self.value = wrappedValue
        self.ttl = ttl
        if wrappedValue != nil {
            self.expirationDate = Date().addingTimeInterval(ttl)
        }
    }
    
    public var wrappedValue: T? {
        mutating get {
            guard let expirationDate = expirationDate,
                  expirationDate > Date() else {
                // 已过期，清除值
                self.value = nil
                self.expirationDate = nil
                return nil
            }
            return value
        }
        set {
            value = newValue
            expirationDate = newValue != nil ? Date().addingTimeInterval(ttl) : nil
        }
    }
    
    /// 检查是否过期
    public var isExpired: Bool {
        guard let expirationDate = expirationDate else {
            return true
        }
        return expirationDate <= Date()
    }
    
    /// 手动刷新过期时间
    public mutating func refresh() {
        if value != nil {
            expirationDate = Date().addingTimeInterval(ttl)
        }
    }
}

/// 使用示例：
/// ```swift
/// class Cache {
///     @ExpiringValue(ttl: 3600) var token: String?
/// }
/// ```

