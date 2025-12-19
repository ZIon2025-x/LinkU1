import Foundation

/// 信号量包装器 - 企业级并发控制
public class Semaphore {
    private let semaphore: DispatchSemaphore
    
    public init(value: Int = 0) {
        self.semaphore = DispatchSemaphore(value: value)
    }
    
    /// 等待信号
    public func wait(timeout: DispatchTime = .distantFuture) -> DispatchTimeoutResult {
        return semaphore.wait(timeout: timeout)
    }
    
    /// 发送信号
    public func signal() {
        semaphore.signal()
    }
    
    /// 执行带信号量控制的操作
    public func execute<T>(_ operation: () throws -> T) rethrows -> T {
        wait()
        defer { signal() }
        return try operation()
    }
    
    /// 异步执行带信号量控制的操作
    public func executeAsync<T>(_ operation: () async throws -> T) async rethrows -> T {
        wait()
        defer { signal() }
        return try await operation()
    }
}

