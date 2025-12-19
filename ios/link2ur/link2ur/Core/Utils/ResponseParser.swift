import Foundation

/// 响应解析器 - 企业级响应处理
public struct ResponseParser {
    
    /// 解析 JSON 响应
    public static func parseJSON<T: Decodable>(
        _ type: T.Type,
        from data: Data,
        decoder: JSONDecoder? = nil
    ) throws -> T {
        let jsonDecoder = decoder ?? {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return decoder
        }()
        
        return try jsonDecoder.decode(type, from: data)
    }
    
    /// 解析 JSON 字典
    public static func parseDictionary(from data: Data) throws -> [String: Any] {
        guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw ResponseParserError.invalidFormat
        }
        return dictionary
    }
    
    /// 解析 JSON 数组
    public static func parseArray(from data: Data) throws -> [[String: Any]] {
        guard let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw ResponseParserError.invalidFormat
        }
        return array
    }
    
    /// 验证响应状态码
    public static func validateStatusCode(_ statusCode: Int, validRange: Range<Int> = 200..<300) throws {
        guard validRange.contains(statusCode) else {
            throw ResponseParserError.invalidStatusCode(statusCode)
        }
    }
    
    /// 提取错误信息
    public static func extractError(from data: Data) -> String? {
        if let dictionary = try? parseDictionary(from: data) {
            return dictionary["error"] as? String
                ?? dictionary["message"] as? String
                ?? dictionary["detail"] as? String
        }
        return nil
    }
}

/// 响应解析器错误
enum ResponseParserError: LocalizedError {
    case invalidFormat
    case invalidStatusCode(Int)
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "响应格式无效"
        case .invalidStatusCode(let code):
            return "无效的状态码: \(code)"
        case .decodingFailed:
            return "响应解码失败"
        }
    }
}

