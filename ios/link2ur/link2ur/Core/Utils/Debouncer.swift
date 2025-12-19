import Foundation
import Combine

/// 防抖器 - 企业级防抖工具
public class Debouncer {
    private var workItem: DispatchWorkItem?
    private let queue: DispatchQueue
    private let delay: TimeInterval
    
    public init(delay: TimeInterval, queue: DispatchQueue = .main) {
        self.delay = delay
        self.queue = queue
    }
    
    /// 执行防抖操作
    public func debounce(_ action: @escaping () -> Void) {
        workItem?.cancel()
        workItem = DispatchWorkItem(block: action)
        if let workItem = workItem {
            queue.asyncAfter(deadline: .now() + delay, execute: workItem)
        }
    }
    
    /// 取消防抖
    public func cancel() {
        workItem?.cancel()
        workItem = nil
    }
}

/// Combine 防抖器
public struct DebouncePublisher<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    
    private let upstream: Upstream
    private let interval: TimeInterval
    private let scheduler: DispatchQueue
    
    public init(upstream: Upstream, interval: TimeInterval, scheduler: DispatchQueue = .main) {
        self.upstream = upstream
        self.interval = interval
        self.scheduler = scheduler
    }
    
    public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        upstream
            .debounce(for: .seconds(interval), scheduler: scheduler)
            .receive(subscriber: subscriber)
    }
}

/// Combine 节流器
public struct ThrottlePublisher<Upstream: Publisher>: Publisher {
    public typealias Output = Upstream.Output
    public typealias Failure = Upstream.Failure
    
    private let upstream: Upstream
    private let interval: TimeInterval
    private let scheduler: DispatchQueue
    private let latest: Bool
    
    public init(upstream: Upstream, interval: TimeInterval, scheduler: DispatchQueue = .main, latest: Bool = true) {
        self.upstream = upstream
        self.interval = interval
        self.scheduler = scheduler
        self.latest = latest
    }
    
    public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
        upstream
            .throttle(for: .seconds(interval), scheduler: scheduler, latest: latest)
            .receive(subscriber: subscriber)
    }
}

