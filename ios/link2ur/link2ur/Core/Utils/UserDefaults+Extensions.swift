import Foundation

/// UserDefaults 扩展 - 企业级配置存储
extension UserDefaults {
    
    
    /// 应用组 UserDefaults（用于扩展）
    public static func appGroup(_ groupIdentifier: String) -> UserDefaults? {
        return UserDefaults(suiteName: groupIdentifier)
    }
    
    // MARK: - 类型安全存储
    
    /// 安全存储 Codable 对象
    public func setCodable<T: Codable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            set(data, forKey: key)
        }
    }
    
    /// 安全读取 Codable 对象
    public func codable<T: Codable>(_ type: T.Type, forKey key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    
    // MARK: - 便捷方法
    
    /// 存储日期
    public func setDate(_ date: Date?, forKey key: String) {
        if let date = date {
            set(date.timeIntervalSince1970, forKey: key)
        } else {
            removeObject(forKey: key)
        }
    }
    
    /// 读取日期
    public func date(forKey key: String) -> Date? {
        let timeInterval = double(forKey: key)
        guard timeInterval > 0 else { return nil }
        return Date(timeIntervalSince1970: timeInterval)
    }
    
    /// 存储 URL
    public func setURL(_ url: URL?, forKey key: String) {
        set(url, forKey: key)
    }
    
    /// 读取 URL
    public func urlValue(forKey key: String) -> URL? {
        return Foundation.UserDefaults.standard.url(forKey: key)
    }
    
    // MARK: - 批量操作
    
    /// 批量设置值
    public func setValues(_ dictionary: [String: Any]) {
        dictionary.forEach { key, value in
            set(value, forKey: key)
        }
    }
    
    /// 批量读取值
    public func values(forKeys keys: [String]) -> [String: Any] {
        var result: [String: Any] = [:]
        keys.forEach { key in
            if let value = object(forKey: key) {
                result[key] = value
            }
        }
        return result
    }
    
    // MARK: - 清理
    
    /// 清除所有数据（危险操作）
    public func clearAll() {
        dictionaryRepresentation().keys.forEach { key in
            removeObject(forKey: key)
        }
    }
    
    /// 清除指定前缀的键
    public func clear(prefix: String) {
        dictionaryRepresentation().keys
            .filter { $0.hasPrefix(prefix) }
            .forEach { removeObject(forKey: $0) }
    }
}

