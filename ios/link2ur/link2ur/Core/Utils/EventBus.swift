import Foundation
import Combine

/// 事件总线 - 企业级事件系统
public class EventBus {
    public static let shared = EventBus()
    
    private var subjects: [String: PassthroughSubject<Any, Never>] = [:]
    private let lock = NSLock()
    
    private init() {}
    
    /// 发布事件
    public func publish<T>(_ event: T, topic: String = String(describing: T.self)) {
        lock.lock()
        defer { lock.unlock() }
        
        let subject = getOrCreateSubject(for: topic)
        subject.send(event)
    }
    
    /// 订阅事件
    public func subscribe<T>(
        _ type: T.Type,
        topic: String? = nil
    ) -> AnyPublisher<T, Never> {
        let topicName = topic ?? String(describing: type)
        
        lock.lock()
        let subject = getOrCreateSubject(for: topicName)
        lock.unlock()
        
        return subject
            .compactMap { $0 as? T }
            .eraseToAnyPublisher()
    }
    
    /// 获取或创建主题
    private func getOrCreateSubject(for topic: String) -> PassthroughSubject<Any, Never> {
        if let existing = subjects[topic] {
            return existing
        }
        
        let subject = PassthroughSubject<Any, Never>()
        subjects[topic] = subject
        return subject
    }
    
    /// 清除所有订阅
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        subjects.removeAll()
    }
}

/// 事件协议
public protocol AppEvent {
    var timestamp: Date { get }
}

/// 基础事件
public struct BaseEvent: AppEvent {
    public let timestamp = Date()
    public let name: String
    public let data: [String: Any]?
    
    public init(name: String, data: [String: Any]? = nil) {
        self.name = name
        self.data = data
    }
}

