import Foundation

/// 弱引用包装器 - 企业级内存管理
@propertyWrapper
public struct WeakRef<T: AnyObject> {
    private weak var value: T?
    
    public init(wrappedValue: T?) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: T? {
        get { value }
        set { value = newValue }
    }
}

/// 使用示例：
/// ```swift
/// class ViewModel {
///     @WeakRef var delegate: SomeDelegate?
/// }
/// ```

