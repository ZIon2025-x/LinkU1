import Foundation
import Combine
import SwiftUI

/// 企业级错误处理系统
/// 提供统一的错误处理、恢复策略和用户友好的错误展示

// MARK: - 错误类型扩展

extension APIError {
    /// 错误恢复策略
    var recoveryStrategy: ErrorRecoveryStrategy {
        switch self {
        case .unauthorized:
            return .reauthenticate
        case .httpError(let code) where code >= 500:
            return .retry(maxAttempts: 3, delay: 2.0)
        case .requestFailed:
            return .retry(maxAttempts: 2, delay: 1.0)
        case .decodingError:
            return .showError
        case .invalidResponse:
            return .retry(maxAttempts: 1, delay: 0.5)
        default:
            return .showError
        }
    }
    
    /// 用户友好的错误消息
    var userFriendlyMessage: String {
        switch self {
        case .invalidURL:
            return "请求地址无效，请稍后重试"
        case .requestFailed(let error):
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                return "网络连接失败，请检查网络设置"
            } else if (error as NSError).code == NSURLErrorTimedOut {
                return "请求超时，请稍后重试"
            }
            return "网络请求失败，请稍后重试"
        case .invalidResponse:
            return "服务器响应异常，请稍后重试"
        case .httpError(let code):
            switch code {
            case 400:
                return "请求参数错误"
            case 401:
                return "登录已过期，请重新登录"
            case 403:
                return "没有权限执行此操作"
            case 404:
                return "请求的资源不存在"
            case 429:
                return "请求过于频繁，请稍后重试"
            case 500...599:
                return "服务器错误，请稍后重试"
            default:
                return "请求失败 (错误代码: \(code))"
            }
        case .decodingError:
            return "数据解析失败，请稍后重试"
        case .unauthorized:
            return "登录已过期，请重新登录"
        case .unknown:
            return "发生未知错误，请稍后重试"
        }
    }
}

// MARK: - 错误恢复策略

enum ErrorRecoveryStrategy {
    case retry(maxAttempts: Int, delay: TimeInterval)
    case reauthenticate
    case showError
    case ignore
}

// MARK: - 错误处理器

public final class ErrorHandler: ObservableObject {
    public static let shared = ErrorHandler()
    
    @Published public var currentError: AppError?
    @Published public var isShowingError: Bool = false
    
    private var errorQueue: [AppError] = []
    private let maxQueueSize = 10
    
    private init() {}
    
    // MARK: - 错误处理
    
    /// 处理错误
    public func handle(_ error: Error, context: String? = nil) {
        let appError = AppError(
            error: error,
            context: context,
            timestamp: Date()
        )
        
        Logger.error("错误处理: \(appError.description)", category: .general)
        
        // 添加到队列
        addToQueue(appError)
        
        // 根据错误类型决定恢复策略
        let strategy = getRecoveryStrategy(for: error)
        
        switch strategy {
        case .retry(_, _):
            // 重试逻辑由调用方处理
            currentError = appError
            isShowingError = true
            
        case .reauthenticate:
            // 触发重新认证
            NotificationCenter.default.post(name: .userShouldReauthenticate, object: nil)
            currentError = appError
            isShowingError = true
            
        case .showError:
            currentError = appError
            isShowingError = true
            
        case .ignore:
            // 静默忽略
            break
        }
    }
    
    /// 清除当前错误
    public func clearError() {
        currentError = nil
        isShowingError = false
    }
    
    /// 获取错误历史
    public func getErrorHistory(limit: Int = 10) -> [AppError] {
        return Array(errorQueue.prefix(limit))
    }
    
    // MARK: - 私有方法
    
    private func addToQueue(_ error: AppError) {
        errorQueue.insert(error, at: 0)
        if errorQueue.count > maxQueueSize {
            errorQueue.removeLast()
        }
    }
    
    private func getRecoveryStrategy(for error: Error) -> ErrorRecoveryStrategy {
        if let apiError = error as? APIError {
            return apiError.recoveryStrategy
        }
        return .showError
    }
}

// MARK: - 应用错误模型

public struct AppError: Identifiable, Equatable {
    public let id = UUID()
    public let error: Error
    public let context: String?
    public let timestamp: Date
    
    public var description: String {
        var desc = "错误: \(error.localizedDescription)"
        if let context = context {
            desc += " (上下文: \(context))"
        }
        return desc
    }
    
    public var userMessage: String {
        if let apiError = error as? APIError {
            return apiError.userFriendlyMessage
        }
        return error.localizedDescription
    }
    
    public static func == (lhs: AppError, rhs: AppError) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    static let userShouldReauthenticate = Notification.Name("userShouldReauthenticate")
}

// MARK: - 错误重试机制

public struct RetryableRequest<T> {
    let request: () -> AnyPublisher<T, Error>
    let maxAttempts: Int
    let delay: TimeInterval
    
    public init(
        request: @escaping () -> AnyPublisher<T, Error>,
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0
    ) {
        self.request = request
        self.maxAttempts = maxAttempts
        self.delay = delay
    }
    
    public func execute() -> AnyPublisher<T, Error> {
        return request()
            .catch { error -> AnyPublisher<T, Error> in
                if maxAttempts > 1 {
                    return Just(())
                        .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
                        .flatMap { _ in
                            RetryableRequest(
                                request: self.request,
                                maxAttempts: self.maxAttempts - 1,
                                delay: self.delay
                            ).execute()
                        }
                        .eraseToAnyPublisher()
                } else {
                    return Fail(error: error).eraseToAnyPublisher()
                }
            }
            .eraseToAnyPublisher()
    }
}

