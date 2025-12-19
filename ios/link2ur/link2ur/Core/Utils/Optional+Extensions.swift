import Foundation

/// Optional 扩展 - 企业级可选值工具
extension Optional {
    
    /// 如果为 nil，返回默认值
    public func or(_ defaultValue: Wrapped) -> Wrapped {
        return self ?? defaultValue
    }
    
    /// 如果为 nil，执行闭包
    public func or(_ defaultValue: () -> Wrapped) -> Wrapped {
        return self ?? defaultValue()
    }
    
    /// 如果为 nil，抛出错误
    public func orThrow(_ error: Error) throws -> Wrapped {
        guard let value = self else {
            throw error
        }
        return value
    }
    
    /// 如果为 nil，抛出默认错误
    public func orThrow(_ message: String) throws -> Wrapped {
        guard let value = self else {
            throw NSError(domain: "OptionalError", code: -1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return value
    }
}

/// Optional 扩展 - Equatable
extension Optional where Wrapped: Equatable {
    
    /// 安全比较（nil 视为不相等）
    public func isEqual(to other: Wrapped?) -> Bool {
        switch (self, other) {
        case (.none, .none):
            return true
        case (.some(let a), .some(let b)):
            return a == b
        default:
            return false
        }
    }
}

/// Optional 扩展 - Collection
extension Optional where Wrapped: Collection {
    
    /// 如果为 nil 或空，返回 true
    public var isEmptyOrNil: Bool {
        return self?.isEmpty ?? true
    }
    
    /// 如果不为 nil 且不为空，返回 true
    public var isNotEmpty: Bool {
        return !isEmptyOrNil
    }
}

/// Optional 扩展 - String
extension Optional where Wrapped == String {
    
    /// 如果为 nil 或空，返回 true
    public var isEmptyOrNil: Bool {
        return self?.isEmpty ?? true
    }
    
    /// 如果为 nil 或空，返回默认值
    public func orEmpty() -> String {
        return self ?? ""
    }
}

