import Foundation

/// Result 扩展 - 企业级结果处理
extension Result {
    
    /// 获取成功值（如果存在）
    public var value: Success? {
        if case .success(let value) = self {
            return value
        }
        return nil
    }
    
    /// 获取错误（如果存在）
    public var error: Failure? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
    
    /// 是否成功
    public var isSuccess: Bool {
        if case .success = self {
            return true
        }
        return false
    }
    
    /// 是否失败
    public var isFailure: Bool {
        return !isSuccess
    }
    
    /// 映射成功值
    public func map<NewSuccess>(_ transform: (Success) -> NewSuccess) -> Result<NewSuccess, Failure> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// 映射错误
    public func mapError<NewFailure>(_ transform: (Failure) -> NewFailure) -> Result<Success, NewFailure> {
        switch self {
        case .success(let value):
            return .success(value)
        case .failure(let error):
            return .failure(transform(error))
        }
    }
    
    /// 扁平化嵌套 Result
    public func flatMap<NewSuccess>(_ transform: (Success) -> Result<NewSuccess, Failure>) -> Result<NewSuccess, Failure> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    /// 获取值或默认值
    public func getOrElse(_ defaultValue: Success) -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return defaultValue
        }
    }
    
    /// 获取值或执行闭包
    public func getOrElse(_ defaultValue: () -> Success) -> Success {
        switch self {
        case .success(let value):
            return value
        case .failure:
            return defaultValue()
        }
    }
}

