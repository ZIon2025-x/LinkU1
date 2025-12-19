import Foundation

/// 节流器 - 企业级节流控制
public class Throttler {
    private let interval: TimeInterval
    private var lastExecutionTime: Date?
    private let lock = NSLock()
    
    public init(interval: TimeInterval) {
        self.interval = interval
    }
    
    /// 执行节流操作
    public func execute(_ operation: @escaping () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        let now = Date()
        if let lastTime = lastExecutionTime {
            let elapsed = now.timeIntervalSince(lastTime)
            if elapsed < interval {
                return // 跳过执行
            }
        }
        
        lastExecutionTime = now
        operation()
    }
    
    /// 异步执行节流操作
    public func executeAsync(_ operation: @escaping () async -> Void) async {
        let shouldExecute = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            // 使用同步块来保护共享状态
            lock.lock()
            defer { lock.unlock() }
            
            let now = Date()
            let shouldExec: Bool
            if let lastTime = lastExecutionTime {
                let elapsed = now.timeIntervalSince(lastTime)
                shouldExec = elapsed >= interval
            } else {
                shouldExec = true
            }
            
            if shouldExec {
                lastExecutionTime = now
            }
            continuation.resume(returning: shouldExec)
        }
        
        if shouldExecute {
            await operation()
        }
    }
    
    /// 重置节流器
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        lastExecutionTime = nil
    }
}

