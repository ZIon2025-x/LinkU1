import Foundation

/// 后端标准错误响应格式
/// 对应后端 error_handlers.py 中的 create_error_response 格式
nonisolated struct APIErrorResponse: Decodable {
    let error: Bool
    let message: String
    let errorCode: String
    let statusCode: Int
    let details: [String: AnyCodable]?
    
    enum CodingKeys: String, CodingKey {
        case error
        case message
        case errorCode = "error_code"
        case statusCode = "status_code"
        case details
    }
}

/// 用于解析和编码任意类型的 Codable 封装
/// 支持 Encodable 和 Decodable，用于处理动态 JSON 结构
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "无法解码 AnyCodable"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        if let intVal = value as? Int {
            try container.encode(intVal)
        } else if let doubleVal = value as? Double {
            try container.encode(doubleVal)
        } else if let strVal = value as? String {
            try container.encode(strVal)
        } else if let boolVal = value as? Bool {
            try container.encode(boolVal)
        } else if let arrayVal = value as? [Any] {
            let codableArray = arrayVal.map { AnyCodable($0) }
            try container.encode(codableArray)
        } else if let dictVal = value as? [String: Any] {
            let codableDict = dictVal.mapValues { AnyCodable($0) }
            try container.encode(codableDict)
        } else {
            // 简单处理，忽略复杂嵌套
            try container.encode(String(describing: value))
        }
    }
}

extension APIError {
    /// 从后端错误响应创建 APIError（保留 message 与 errorCode，errorCode 供客户端国际化）
    static func from(errorResponse: APIErrorResponse) -> APIError {
        switch errorResponse.statusCode {
        case 401:
            return .unauthorized
        default:
            return .serverError(errorResponse.statusCode, errorResponse.message, errorCode: errorResponse.errorCode)
        }
    }
    
    /// 从 HTTP 响应数据解析错误
    /// 返回 (APIError, 错误消息)
    /// 支持两种格式：
    /// 1. FastAPI HTTPException: {"detail": "错误消息"}
    /// 2. 标准错误响应: {"error": true, "message": "...", "error_code": "...", "status_code": 409}
    nonisolated static func parse(from data: Data) -> (error: APIError, message: String)? {
        // 在非隔离上下文中解码，避免 Swift 6 兼容性问题
        let decoder = JSONDecoder()
        
        // 首先尝试解析标准错误响应格式
        if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
            return (from(errorResponse: errorResponse), errorResponse.message)
        }
        
        // 如果标准格式解析失败，尝试解析 FastAPI HTTPException 格式 {"detail": "..."}
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let detail = json["detail"] as? String {
            // FastAPI HTTPException 格式，需要从 HTTP 状态码推断错误类型
            // 这里返回一个通用的 serverError，状态码需要从外部传入
            // 但为了保持接口一致性，我们返回一个包含消息的 serverError
            // 注意：这里无法获取状态码，所以返回 httpError(0)，调用方需要根据实际状态码处理
            return (.serverError(0, detail), detail)
        }
        
        return nil
    }
    
    // 注意：userFriendlyMessage 已在 ErrorHandler.swift 中定义，这里不再重复定义
}

