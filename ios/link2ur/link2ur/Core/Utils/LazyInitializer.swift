import Foundation

/// 延迟初始化器 - 企业级延迟加载
@propertyWrapper
public struct LazyInitializer<T> {
    private var value: T?
    private let initializer: () -> T
    
    public init(wrappedValue initializer: @escaping @autoclosure () -> T) {
        self.initializer = initializer
    }
    
    public var wrappedValue: T {
        mutating get {
            if value == nil {
                value = initializer()
            }
            return value!
        }
        set {
            value = newValue
        }
    }
}

/// 使用示例：
/// ```swift
/// class ViewModel {
///     @LazyInitializer var service = APIService()
/// }
/// ```

