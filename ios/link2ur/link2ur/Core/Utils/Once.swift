import Foundation

/// 一次性执行器 - 企业级单次执行保证
public class Once {
    private var executed = false
    private let lock = NSLock()
    
    /// 执行一次操作
    public func execute(_ operation: () -> Void) {
        lock.lock()
        defer { lock.unlock() }
        
        guard !executed else { return }
        executed = true
        operation()
    }
    
    /// 异步执行一次操作
    public func executeAsync(_ operation: () async -> Void) async {
        // 使用同步队列来避免在异步上下文中直接使用 NSLock
        let shouldExecute = await withCheckedContinuation { continuation in
            DispatchQueue.global().async {
                self.lock.lock()
                let shouldExecute = !self.executed
                if shouldExecute {
                    self.executed = true
                }
                self.lock.unlock()
                continuation.resume(returning: shouldExecute)
            }
        }
        
        if shouldExecute {
            await operation()
        }
    }
    
    /// 重置执行状态
    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        executed = false
    }
}

