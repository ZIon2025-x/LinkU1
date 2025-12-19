import Foundation
import Combine

/// 属性观察器 - 企业级属性变化监听
@propertyWrapper
public struct PropertyObserver<T> {
    private var value: T
    private let subject = PassthroughSubject<T, Never>()
    
    public init(wrappedValue: T) {
        self.value = wrappedValue
    }
    
    public var wrappedValue: T {
        get { value }
        set {
            value = newValue
            subject.send(newValue)
        }
    }
    
    /// 获取变化发布者
    public var projectedValue: AnyPublisher<T, Never> {
        return subject.eraseToAnyPublisher()
    }
}

/// 使用示例：
/// ```swift
/// class ViewModel {
///     @PropertyObserver var count: Int = 0
///     
///     init() {
///         $count.sink { newValue in
///             print("Count changed to: \(newValue)")
///         }
///     }
/// }
/// ```

