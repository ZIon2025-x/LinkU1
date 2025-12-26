import Foundation

/// API 请求辅助工具类
/// 提供统一的请求构建方法，减少代码重复
struct APIRequestHelper {
    /// 将 Encodable 对象转换为 Dictionary
    /// 用于将 Swift 结构体转换为 JSON 请求体
    static func encodeToDictionary<T: Encodable>(_ object: T) -> [String: Any]? {
        guard let data = try? JSONEncoder().encode(object),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            Logger.error("无法将 \(type(of: object)) 编码为 Dictionary", category: .api)
            return nil
        }
        return dict
    }
    
    /// 构建带查询参数的 URL
    /// 使用 URLComponents 确保 URL 编码正确
    static func buildURL(baseURL: String, endpoint: String, queryParams: [String: String?]? = nil) -> URL? {
        // 验证 baseURL 是否有效
        guard URL(string: baseURL) != nil else {
            Logger.error("无效的 baseURL: \(baseURL)", category: .api)
            return nil
        }
        
        let fullPath = baseURL + endpoint
        guard var components = URLComponents(string: fullPath) else {
            Logger.error("无法创建 URLComponents: \(fullPath)", category: .api)
            return nil
        }
        
        if let params = queryParams, !params.isEmpty {
            components.queryItems = params.compactMap { key, value in
                guard let value = value, !value.isEmpty else { return nil }
                return URLQueryItem(name: key, value: value)
            }
        }
        
        guard let url = components.url else {
            Logger.error("无法从 URLComponents 创建 URL", category: .api)
            return nil
        }
        
        return url
    }
    
    /// 构建查询参数字符串（用于向后兼容）
    /// 注意：推荐使用 buildURL 方法，这个方法仅用于特殊情况
    static func buildQueryString(_ params: [String: String?]) -> String {
        let items = params.compactMap { key, value -> String? in
            guard let value = value, !value.isEmpty else { return nil }
            // 对键和值都进行 URL 编码
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
            return "\(encodedKey)=\(encodedValue)"
        }
        return items.joined(separator: "&")
    }
    
    /// 构建查询参数字符串（从基本类型）
    static func buildQueryString(_ params: [String: Any]) -> String {
        let items = params.compactMap { key, value -> String? in
            let stringValue: String
            if let str = value as? String {
                stringValue = str
            } else if let int = value as? Int {
                stringValue = "\(int)"
            } else if let double = value as? Double {
                stringValue = "\(double)"
            } else if let bool = value as? Bool {
                stringValue = bool ? "true" : "false"
            } else {
                return nil
            }
            
            guard !stringValue.isEmpty else { return nil }
            let encodedKey = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? key
            let encodedValue = stringValue.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? stringValue
            return "\(encodedKey)=\(encodedValue)"
        }
        return items.joined(separator: "&")
    }
}

