import Foundation
import Combine

// MARK: - 网络重试配置

/// 网络重试配置（Sendable，可在任意并发上下文使用）
public struct NetworkRetryConfiguration: Sendable {
    /// 最大重试次数
    public let maxAttempts: Int
    /// 基础延迟时间（秒）
    public let baseDelay: TimeInterval
    /// 最大延迟时间（秒）
    public let maxDelay: TimeInterval
    /// 退避乘数
    public let backoffMultiplier: Double
    /// 是否添加随机抖动（避免重试风暴）
    public let useJitter: Bool
    /// 可重试的 HTTP 状态码
    public let retryableStatusCodes: Set<Int>
    /// 可重试的 NSURLError 错误码
    public let retryableErrorCodes: Set<Int>
    
    /// 默认配置（nonisolated 计算属性，避免 main actor 隔离警告）
    public static nonisolated var `default`: NetworkRetryConfiguration {
        NetworkRetryConfiguration(
            maxAttempts: 3,
            baseDelay: 1.0,
            maxDelay: 30.0,
            backoffMultiplier: 2.0,
            useJitter: true,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504],
            retryableErrorCodes: [
                NSURLErrorTimedOut,                    // -1001
                NSURLErrorCannotFindHost,              // -1003
                NSURLErrorCannotConnectToHost,         // -1004
                NSURLErrorNetworkConnectionLost,       // -1005
                NSURLErrorDNSLookupFailed,             // -1006
                NSURLErrorNotConnectedToInternet,      // -1009
                NSURLErrorSecureConnectionFailed,      // -1200
                NSURLErrorServerCertificateHasBadDate, // -1201
            ]
        )
    }
    
    /// 快速重试配置（适用于关键操作）
    public static nonisolated var fast: NetworkRetryConfiguration {
        NetworkRetryConfiguration(
            maxAttempts: 2,
            baseDelay: 0.5,
            maxDelay: 5.0,
            backoffMultiplier: 2.0,
            useJitter: true,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504],
            retryableErrorCodes: [
                NSURLErrorTimedOut,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorNotConnectedToInternet,
            ]
        )
    }
    
    /// 持久重试配置（适用于后台同步等）
    public static nonisolated var persistent: NetworkRetryConfiguration {
        NetworkRetryConfiguration(
            maxAttempts: 5,
            baseDelay: 2.0,
            maxDelay: 60.0,
            backoffMultiplier: 2.0,
            useJitter: true,
            retryableStatusCodes: [408, 429, 500, 502, 503, 504],
            retryableErrorCodes: [
                NSURLErrorTimedOut,
                NSURLErrorCannotFindHost,
                NSURLErrorCannotConnectToHost,
                NSURLErrorNetworkConnectionLost,
                NSURLErrorDNSLookupFailed,
                NSURLErrorNotConnectedToInternet,
                NSURLErrorSecureConnectionFailed,
            ]
        )
    }
    
    /// 无重试配置
    public static nonisolated var none: NetworkRetryConfiguration {
        NetworkRetryConfiguration(
            maxAttempts: 1,
            baseDelay: 0,
            maxDelay: 0,
            backoffMultiplier: 1.0,
            useJitter: false,
            retryableStatusCodes: [],
            retryableErrorCodes: []
        )
    }
    
    /// 可从任意并发上下文调用的初始化器
    public nonisolated init(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        maxDelay: TimeInterval,
        backoffMultiplier: Double,
        useJitter: Bool,
        retryableStatusCodes: Set<Int>,
        retryableErrorCodes: Set<Int>
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelay = baseDelay
        self.maxDelay = maxDelay
        self.backoffMultiplier = backoffMultiplier
        self.useJitter = useJitter
        self.retryableStatusCodes = retryableStatusCodes
        self.retryableErrorCodes = retryableErrorCodes
    }
    
    /// 计算第 n 次重试的延迟时间
    public func delay(forAttempt attempt: Int) -> TimeInterval {
        let exponentialDelay = baseDelay * pow(backoffMultiplier, Double(attempt - 1))
        var delay = min(exponentialDelay, maxDelay)
        
        // 添加随机抖动（±25%）
        if useJitter {
            let jitter = delay * 0.25 * (Double.random(in: -1...1))
            delay += jitter
        }
        
        return max(0, delay)
    }
    
    /// 检查错误是否可重试
    public func shouldRetry(error: Error, statusCode: Int? = nil) -> Bool {
        // 检查 HTTP 状态码
        if let statusCode = statusCode, retryableStatusCodes.contains(statusCode) {
            return true
        }
        
        // 检查 NSError 错误码
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && retryableErrorCodes.contains(nsError.code) {
            return true
        }
        
        // 检查 APIError
        if let apiError = error as? APIError {
            switch apiError {
            case .httpError(let code):
                return retryableStatusCodes.contains(code)
            case .serverError(let code, _):
                return retryableStatusCodes.contains(code)
            case .requestFailed(let underlyingError):
                let nsError = underlyingError as NSError
                return nsError.domain == NSURLErrorDomain && retryableErrorCodes.contains(nsError.code)
            default:
                return false
            }
        }
        
        return false
    }
}

// MARK: - 重试状态

/// 重试状态（用于监控和日志）
public struct RetryState {
    public let attempt: Int
    public let maxAttempts: Int
    public let delay: TimeInterval
    public let error: Error?
    
    public var isLastAttempt: Bool {
        return attempt >= maxAttempts
    }
    
    public var progress: Double {
        return Double(attempt) / Double(maxAttempts)
    }
}

/// 重试状态回调
public typealias RetryStateCallback = (RetryState) -> Void

// MARK: - 重试管理器

/// 重试管理器 - 企业级重试策略
public final class RetryManager {
    public static let shared = RetryManager()
    
    /// 当前活跃的重试操作数
    @Published public private(set) var activeRetryCount: Int = 0
    
    private let queue = DispatchQueue(label: "com.link2ur.retrymanager", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    private init() {}
    
    // MARK: - Async/Await API
    
    /// 异步延迟（兼容 Swift 5 和 iOS 16.0）
    private func sleep(seconds: TimeInterval) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                continuation.resume()
            }
        }
    }
    
    /// 执行带重试的异步操作
    public func execute<T>(
        _ operation: @escaping () async throws -> T,
        configuration: NetworkRetryConfiguration = .default,
        onRetry: RetryStateCallback? = nil
    ) async throws -> T {
        var lastError: Error?
        
        incrementActiveCount()
        defer { decrementActiveCount() }
        
        for attempt in 1...configuration.maxAttempts {
            do {
                let result = try await operation()
                
                // 如果有重试，记录成功
                if attempt > 1 {
                    Logger.info("操作在第 \(attempt) 次尝试后成功", category: .network)
                }
                
                return result
            } catch {
                lastError = error
                
                let state = RetryState(
                    attempt: attempt,
                    maxAttempts: configuration.maxAttempts,
                    delay: configuration.delay(forAttempt: attempt),
                    error: error
                )
                
                // 检查是否应该重试
                if !configuration.shouldRetry(error: error) {
                    Logger.debug("错误不可重试: \(error.localizedDescription)", category: .network)
                    throw error
                }
                
                // 如果是最后一次尝试，直接抛出错误
                if attempt >= configuration.maxAttempts {
                    Logger.warning("达到最大重试次数 (\(configuration.maxAttempts))，放弃重试", category: .network)
                    throw error
                }
                
                // 通知重试状态
                onRetry?(state)
                
                let delay = configuration.delay(forAttempt: attempt)
                Logger.debug("重试操作 (尝试 \(attempt)/\(configuration.maxAttempts))，延迟 \(String(format: "%.2f", delay))s", category: .network)
                
                // 等待后重试
                await sleep(seconds: delay)
            }
        }
        
        throw lastError ?? RetryError.maxAttemptsReached
    }
    
    /// 执行带网络重试的异步操作（便捷方法）
    public func executeNetworkRequest<T>(
        _ operation: @escaping () async throws -> T,
        retryConfiguration: NetworkRetryConfiguration = .default
    ) async throws -> T {
        return try await execute(operation, configuration: retryConfiguration) { state in
            Logger.debug("网络请求重试 (尝试 \(state.attempt)/\(state.maxAttempts))", category: .network)
        }
    }
    
    // MARK: - Combine API
    
    /// 为 Publisher 添加重试逻辑
    public func withRetry<T, E: Error>(
        _ publisher: AnyPublisher<T, E>,
        configuration: NetworkRetryConfiguration = .default,
        onRetry: RetryStateCallback? = nil
    ) -> AnyPublisher<T, E> {
        var currentAttempt = 0
        
        return publisher
            .catch { [weak self] error -> AnyPublisher<T, E> in
                currentAttempt += 1
                
                let state = RetryState(
                    attempt: currentAttempt,
                    maxAttempts: configuration.maxAttempts,
                    delay: configuration.delay(forAttempt: currentAttempt),
                    error: error
                )
                
                // 检查是否应该重试（E: Error 即 any Error）
                guard configuration.shouldRetry(error: error as Error),
                      currentAttempt < configuration.maxAttempts else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
                
                // 通知重试状态
                onRetry?(state)
                
                let delay = configuration.delay(forAttempt: currentAttempt)
                Logger.debug("Combine 重试 (尝试 \(currentAttempt)/\(configuration.maxAttempts))，延迟 \(String(format: "%.2f", delay))s", category: .network)
                
                // 延迟后重试
                return Just(())
                    .delay(for: .seconds(delay), scheduler: DispatchQueue.global())
                    .flatMap { _ -> AnyPublisher<T, E> in
                        return self?.withRetry(publisher, configuration: configuration, onRetry: onRetry)
                            ?? Fail(error: error).eraseToAnyPublisher()
                    }
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Sync API
    
    /// 执行带重试的同步操作
    /// 警告：会阻塞当前线程，请勿在主线程调用
    public func executeSync<T>(
        _ operation: @escaping () throws -> T,
        configuration: NetworkRetryConfiguration = .default,
        onRetry: RetryStateCallback? = nil
    ) throws -> T {
        // 运行时检查：禁止在主线程调用此方法，否则会阻塞 UI
        assert(!Thread.isMainThread, "executeSync 不应在主线程调用，会导致 UI 卡顿。请使用异步版本 execute() 或在后台线程调用。")
        
        var lastError: Error?
        
        for attempt in 1...configuration.maxAttempts {
            do {
                return try operation()
            } catch {
                lastError = error
                
                let state = RetryState(
                    attempt: attempt,
                    maxAttempts: configuration.maxAttempts,
                    delay: configuration.delay(forAttempt: attempt),
                    error: error
                )
                
                // 检查是否应该重试
                if !configuration.shouldRetry(error: error) {
                    throw error
                }
                
                // 如果是最后一次尝试，直接抛出错误
                if attempt >= configuration.maxAttempts {
                    throw error
                }
                
                // 通知重试状态
                onRetry?(state)
                
                let delay = configuration.delay(forAttempt: attempt)
                Logger.debug("同步重试 (尝试 \(attempt)/\(configuration.maxAttempts))，延迟 \(String(format: "%.2f", delay))s", category: .network)
                
                // 等待后重试
                Thread.sleep(forTimeInterval: delay)
            }
        }
        
        throw lastError ?? RetryError.maxAttemptsReached
    }
    
    // MARK: - Private Methods
    
    private func incrementActiveCount() {
        queue.async { [weak self] in
            self?.activeRetryCount += 1
        }
    }
    
    private func decrementActiveCount() {
        queue.async { [weak self] in
            guard let self = self else { return }
            self.activeRetryCount = max(0, self.activeRetryCount - 1)
        }
    }
}

// MARK: - 重试错误

public enum RetryError: LocalizedError {
    case maxAttemptsReached
    case cancelled
    case invalidConfiguration
    
    public var errorDescription: String? {
        switch self {
        case .maxAttemptsReached:
            return "达到最大重试次数"
        case .cancelled:
            return "重试操作已取消"
        case .invalidConfiguration:
            return "无效的重试配置"
        }
    }
}

// MARK: - Publisher 扩展

extension Publisher {
    /// 添加指数退避重试
    public func retryWithBackoff(
        configuration: NetworkRetryConfiguration = .default
    ) -> AnyPublisher<Output, Failure> {
        return RetryManager.shared.withRetry(
            self.eraseToAnyPublisher(),
            configuration: configuration
        )
    }
}

