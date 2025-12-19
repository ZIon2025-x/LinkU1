import Foundation

/// 重试管理器 - 企业级重试策略
public class RetryManager {
    public static let shared = RetryManager()
    
    private init() {}
    
    /// 异步延迟（兼容 Swift 5 和 iOS 16.0）
    private func sleep(seconds: TimeInterval) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                continuation.resume()
            }
        }
    }
    
    /// 执行带重试的操作
    public func execute<T>(
        _ operation: @escaping () async throws -> T,
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        shouldRetry: ((Error) -> Bool)? = nil
    ) async throws -> T {
        var lastError: Error?
        var currentDelay = delay
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // 检查是否应该重试
                if let shouldRetry = shouldRetry, !shouldRetry(error) {
                    throw error
                }
                
                // 如果是最后一次尝试，直接抛出错误
                if attempt == maxAttempts {
                    throw error
                }
                
                // 等待后重试
                await sleep(seconds: currentDelay)
                currentDelay *= backoffMultiplier
                
                Logger.debug("重试操作 (尝试 \(attempt)/\(maxAttempts))", category: .general)
            }
        }
        
        throw lastError ?? RetryError.maxAttemptsReached
    }
    
    /// 执行带重试的同步操作
    public func executeSync<T>(
        _ operation: @escaping () throws -> T,
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        backoffMultiplier: Double = 2.0,
        shouldRetry: ((Error) -> Bool)? = nil
    ) throws -> T {
        var lastError: Error?
        var currentDelay = delay
        
        for attempt in 1...maxAttempts {
            do {
                return try operation()
            } catch {
                lastError = error
                
                // 检查是否应该重试
                if let shouldRetry = shouldRetry, !shouldRetry(error) {
                    throw error
                }
                
                // 如果是最后一次尝试，直接抛出错误
                if attempt == maxAttempts {
                    throw error
                }
                
                // 等待后重试
                Thread.sleep(forTimeInterval: currentDelay)
                currentDelay *= backoffMultiplier
                
                Logger.debug("重试操作 (尝试 \(attempt)/\(maxAttempts))", category: .general)
            }
        }
        
        throw lastError ?? RetryError.maxAttemptsReached
    }
}

/// 重试错误
enum RetryError: LocalizedError {
    case maxAttemptsReached
    
    var errorDescription: String? {
        switch self {
        case .maxAttemptsReached:
            return "达到最大重试次数"
        }
    }
}

