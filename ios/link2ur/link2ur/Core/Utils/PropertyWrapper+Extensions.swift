import Foundation
import Combine

/// 属性包装器扩展集合

/// 用户默认值属性包装器
@propertyWrapper
public struct UserDefault<T> {
    private let key: String
    private let defaultValue: T
    private let userDefaults: UserDefaults
    
    public init(
        key: String,
        defaultValue: T,
        userDefaults: UserDefaults = .standard
    ) {
        self.key = key
        self.defaultValue = defaultValue
        self.userDefaults = userDefaults
    }
    
    public var wrappedValue: T {
        get {
            return userDefaults.object(forKey: key) as? T ?? defaultValue
        }
        set {
            userDefaults.set(newValue, forKey: key)
        }
    }
}

