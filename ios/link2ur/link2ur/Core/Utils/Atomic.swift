import Foundation

/// 原子值包装器 - 企业级线程安全值
@propertyWrapper
public struct Atomic<T> {
    private var value: T
    private let lock = NSLock()
    
    public init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: T {
        get {
            lock.lock()
            defer { lock.unlock() }
            return value
        }
        set {
            lock.lock()
            defer { lock.unlock() }
            value = newValue
        }
    }
    
    /// 原子更新
    public mutating func update(_ transform: (inout T) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        transform(&value)
    }
    
    /// 原子读取并更新
    public mutating func readAndUpdate(_ transform: (inout T) -> Void) -> T {
        lock.lock()
        defer { lock.unlock() }
        transform(&value)
        return value
    }
}

/// 使用示例：
/// ```swift
/// class Counter {
///     @Atomic var count: Int = 0
///     
///     func increment() {
///         $count.update { $0 += 1 }
///     }
/// }
/// ```

