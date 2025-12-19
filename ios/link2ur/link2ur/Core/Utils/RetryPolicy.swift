import Foundation

/// 重试策略 - 企业级重试管理
public struct RetryPolicy {
    public let maxAttempts: Int
    public let initialDelay: TimeInterval
    public let maxDelay: TimeInterval
    public let multiplier: Double
    public let strategy: RetryStrategy
    
    public enum RetryStrategy {
        case fixed          // 固定延迟
        case exponential    // 指数退避
        case linear         // 线性增长
    }
    
    public init(
        maxAttempts: Int = 3,
        initialDelay: TimeInterval = 1.0,
        maxDelay: TimeInterval = 30.0,
        multiplier: Double = 2.0,
        strategy: RetryStrategy = .exponential
    ) {
        self.maxAttempts = maxAttempts
        self.initialDelay = initialDelay
        self.maxDelay = maxDelay
        self.multiplier = multiplier
        self.strategy = strategy
    }
    
    /// 计算重试延迟
    public func delay(for attempt: Int) -> TimeInterval {
        let calculatedDelay: TimeInterval
        
        switch strategy {
        case .fixed:
            calculatedDelay = initialDelay
            
        case .exponential:
            calculatedDelay = initialDelay * pow(multiplier, Double(attempt - 1))
            
        case .linear:
            calculatedDelay = initialDelay * Double(attempt)
        }
        
        return min(calculatedDelay, maxDelay)
    }
    
    /// 是否应该重试
    public func shouldRetry(attempt: Int, error: Error) -> Bool {
        guard attempt < maxAttempts else { return false }
        
        // 根据错误类型决定是否重试
        if let apiError = error as? APIError {
            switch apiError {
            case .requestFailed:
                return true
            case .httpError(let code) where code >= 500:
                return true
            case .unauthorized, .invalidURL, .invalidResponse:
                return false
            default:
                return false
            }
        }
        
        return true
    }
}

/// 默认重试策略
extension RetryPolicy {
    public static let `default` = RetryPolicy()
    public static let fast = RetryPolicy(maxAttempts: 2, initialDelay: 0.5)
    public static let slow = RetryPolicy(maxAttempts: 5, initialDelay: 2.0, maxDelay: 60.0)
}

