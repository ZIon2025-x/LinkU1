import Foundation
import Combine

/// 键值观察器 - 企业级 KVO 工具
public class KeyValueObserver: NSObject {
    private var observations: [NSKeyValueObservation] = []
    
    public override init() {
        super.init()
    }
    
    /// 观察对象属性
    public func observe<Object: NSObject, Value>(
        _ object: Object,
        keyPath: KeyPath<Object, Value>,
        options: NSKeyValueObservingOptions = [.new],
        changeHandler: @escaping (Value) -> Void
    ) {
        let observation = object.observe(keyPath, options: options) { _, change in
            if let newValue = change.newValue {
                changeHandler(newValue)
            }
        }
        observations.append(observation)
    }
    
    /// 停止所有观察
    public func stopObserving() {
        observations.removeAll()
    }
    
    deinit {
        stopObserving()
    }
}

/// Combine KVO 发布者
extension NSObject {
    /// 创建 KVO 发布者
    public func publisher<Value>(
        for keyPath: ReferenceWritableKeyPath<NSObject, Value>,
        options: NSKeyValueObservingOptions = [.new]
    ) -> NSKeyValueObservingPublisher<NSObject, Value> {
        return NSKeyValueObservingPublisher(object: self, keyPath: keyPath, options: options)
    }
}

/// KVO 发布者
public struct NSKeyValueObservingPublisher<Object: NSObject, Value>: Publisher {
    public typealias Output = Value
    public typealias Failure = Never
    
    private let object: Object
    private let keyPath: KeyPath<Object, Value>
    private let options: NSKeyValueObservingOptions
    
    public init(object: Object, keyPath: KeyPath<Object, Value>, options: NSKeyValueObservingOptions) {
        self.object = object
        self.keyPath = keyPath
        self.options = options
    }
    
    public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        let subscription = KVOSubscription(
            object: object,
            keyPath: keyPath,
            options: options,
            subscriber: subscriber
        )
        subscriber.receive(subscription: subscription)
    }
}

/// KVO 订阅
private class KVOSubscription<Object: NSObject, Value, Subscriber: Combine.Subscriber>: Subscription
where Subscriber.Input == Value, Subscriber.Failure == Never {
    private var observation: NSKeyValueObservation?
    private let object: Object
    private let keyPath: KeyPath<Object, Value>
    private let options: NSKeyValueObservingOptions
    private var subscriber: Subscriber?
    
    init(object: Object, keyPath: KeyPath<Object, Value>, options: NSKeyValueObservingOptions, subscriber: Subscriber) {
        self.object = object
        self.keyPath = keyPath
        self.options = options
        self.subscriber = subscriber
        
        observation = object.observe(keyPath, options: options) { [weak self] _, change in
            guard let self = self,
                  let newValue = change.newValue,
                  let subscriber = self.subscriber else {
                return
            }
            _ = subscriber.receive(newValue)
        }
    }
    
    func request(_ demand: Subscribers.Demand) {}
    
    func cancel() {
        observation?.invalidate()
        observation = nil
        subscriber = nil
    }
}

