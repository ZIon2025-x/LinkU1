import Foundation

/// Dictionary 扩展 - 企业级字典操作工具
extension Dictionary {
    
    // MARK: - 安全访问
    
    /// 安全获取值（带默认值）
    public func safeValue(forKey key: Key, defaultValue: Value) -> Value {
        return self[key] ?? defaultValue
    }
    
    /// 安全获取可选值
    public func safeValue(forKey key: Key) -> Value? {
        return self[key]
    }
    
    // MARK: - 合并
    
    /// 合并另一个字典
    public mutating func merge(_ other: [Key: Value]) {
        for (key, value) in other {
            self[key] = value
        }
    }
    
    /// 合并另一个字典（返回新字典）
    public func merging(_ other: [Key: Value]) -> [Key: Value] {
        var result = self
        result.merge(other)
        return result
    }
    
    // MARK: - 过滤
    
    /// 过滤字典
    public func filter(_ isIncluded: (Key, Value) -> Bool) -> [Key: Value] {
        return Dictionary(uniqueKeysWithValues: self.filter(isIncluded))
    }
    
    /// 移除 nil 值
    public func compactMapValues<T>(_ transform: (Value) -> T?) -> [Key: T] {
        var result: [Key: T] = [:]
        for (key, value) in self {
            if let transformed = transform(value) {
                result[key] = transformed
            }
        }
        return result
    }
    
    // MARK: - 转换
    
    /// 转换为查询字符串
    public func toQueryString() -> String {
        return map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
    }
    
    /// 转换为 JSON 字符串
    public func toJSONString(prettyPrinted: Bool = false) -> String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: self,
            options: prettyPrinted ? .prettyPrinted : []
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

/// Dictionary 扩展 - Codable 值
extension Dictionary where Key: Encodable, Value: Codable {
    
    /// 编码为 JSON 数据
    public func toJSONData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
}

/// Dictionary 扩展 - String 键
extension Dictionary where Key == String {
    
    /// 安全获取字符串值
    public func string(forKey key: String) -> String? {
        return self[key] as? String
    }
    
    /// 安全获取整数值
    public func int(forKey key: String) -> Int? {
        if let value = self[key] as? Int {
            return value
        }
        if let string = self[key] as? String {
            return Int(string)
        }
        return nil
    }
    
    /// 安全获取双精度值
    public func double(forKey key: String) -> Double? {
        if let value = self[key] as? Double {
            return value
        }
        if let string = self[key] as? String {
            return Double(string)
        }
        return nil
    }
    
    /// 安全获取布尔值
    public func bool(forKey key: String) -> Bool? {
        if let value = self[key] as? Bool {
            return value
        }
        if let string = self[key] as? String {
            return string.safeBool
        }
        return nil
    }
}

