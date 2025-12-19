import Foundation

/// JSON 辅助工具 - 企业级 JSON 处理
public struct JSONHelper {
    
    /// 编码对象为 JSON 数据
    public static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(value)
    }
    
    /// 编码对象为 JSON 字符串
    public static func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let data = try encode(value)
        return String(data: data, encoding: .utf8) ?? ""
    }
    
    /// 解码 JSON 数据为对象
    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    /// 解码 JSON 字符串为对象
    public static func decode<T: Decodable>(_ type: T.Type, from string: String) throws -> T {
        guard let data = string.data(using: .utf8) else {
            throw JSONError.invalidString
        }
        return try decode(type, from: data)
    }
    
    /// 验证 JSON 格式
    public static func isValid(_ jsonString: String) -> Bool {
        guard let data = jsonString.data(using: .utf8) else {
            return false
        }
        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return true
        } catch {
            return false
        }
    }
    
    /// 美化 JSON 字符串
    public static func prettify(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let prettyData = try? JSONSerialization.data(
                withJSONObject: jsonObject,
                options: .prettyPrinted
              ) else {
            return nil
        }
        return String(data: prettyData, encoding: .utf8)
    }
    
    /// 压缩 JSON 字符串（移除空白）
    public static func minify(_ jsonString: String) -> String? {
        guard let data = jsonString.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data),
              let minifiedData = try? JSONSerialization.data(withJSONObject: jsonObject) else {
            return nil
        }
        return String(data: minifiedData, encoding: .utf8)
    }
}

/// JSON 错误
enum JSONError: LocalizedError {
    case invalidString
    case encodingFailed
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidString:
            return "无效的 JSON 字符串"
        case .encodingFailed:
            return "JSON 编码失败"
        case .decodingFailed:
            return "JSON 解码失败"
        }
    }
}

