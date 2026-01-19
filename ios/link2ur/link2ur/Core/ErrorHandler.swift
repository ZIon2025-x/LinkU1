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
        case .serverError(let code, _) where code >= 500:
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
            return LocalizationKey.errorInvalidURL.localized
        case .requestFailed(let error):
            if (error as NSError).code == NSURLErrorNotConnectedToInternet {
                return LocalizationKey.errorNetworkConnectionFailed.localized
            } else if (error as NSError).code == NSURLErrorTimedOut {
                return LocalizationKey.errorRequestTimeout.localized
            }
            return LocalizationKey.errorNetworkRequestFailed.localized
        case .invalidResponse:
            return LocalizationKey.errorInvalidResponse.localized
        case .httpError(let code):
            switch code {
            case 400:
                return LocalizationKey.errorBadRequest.localized
            case 401:
                return LocalizationKey.errorUnauthorized.localized
            case 403:
                return LocalizationKey.errorForbidden.localized
            case 404:
                return LocalizationKey.errorNotFound.localized
            case 429:
                return LocalizationKey.errorTooManyRequests.localized
            case 500...599:
                return LocalizationKey.errorServerError.localized
            default:
                return String(format: LocalizationKey.errorRequestFailed.localized, code)
            }
        case .serverError(let code, let message):
            switch code {
            case 400:
                return "\(LocalizationKey.errorBadRequest.localized): \(message)"
            case 401:
                return LocalizationKey.errorUnauthorized.localized
            case 403:
                return LocalizationKey.errorForbidden.localized
            case 404:
                return LocalizationKey.errorNotFound.localized
            case 413:
                return "文件过大: \(message)"
            case 429:
                return LocalizationKey.errorTooManyRequests.localized
            case 500...599:
                return "\(LocalizationKey.errorServerError.localized): \(message)"
            default:
                return "\(String(format: LocalizationKey.errorRequestFailed.localized, code)): \(message)"
            }
        case .decodingError:
            return LocalizationKey.errorDecodingError.localized
        case .unauthorized:
            return LocalizationKey.errorUnauthorized.localized
        case .unknown:
            return LocalizationKey.errorUnknown.localized
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

