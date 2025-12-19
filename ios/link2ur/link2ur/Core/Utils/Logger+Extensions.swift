import Foundation

/// Logger 扩展 - 增强日志功能
extension Logger {
    
    /// 记录网络请求
    public static func logRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil
    ) {
        var message = "\(method) \(url)"
        if let headers = headers, !headers.isEmpty {
            message += "\nHeaders: \(headers)"
        }
        debug(message, category: .network)
    }
    
    /// 记录网络响应
    public static func logResponse(
        url: String,
        statusCode: Int,
        duration: TimeInterval? = nil
    ) {
        var message = "\(url) - \(statusCode)"
        if let duration = duration {
            message += " (耗时: \(String(format: "%.2f", duration))秒)"
        }
        if (200...299).contains(statusCode) {
            success(message, category: .network)
        } else {
            error(message, category: .network)
        }
    }
    
    /// 记录性能指标
    public static func logPerformance(
        operation: String,
        duration: TimeInterval
    ) {
        let message = "\(operation): \(String(format: "%.2f", duration))秒"
        if duration > 1.0 {
            warning(message, category: .general)
        } else {
            debug(message, category: .general)
        }
    }
    
    /// 记录用户操作
    public static func logUserAction(
        action: String,
        parameters: [String: Any]? = nil
    ) {
        var message = "用户操作: \(action)"
        if let parameters = parameters {
            message += " - \(parameters)"
        }
        info(message, category: .general)
    }
    
    /// 记录数据变更
    public static func logDataChange(
        type: String,
        action: String,
        count: Int? = nil
    ) {
        var message = "数据变更: \(type) - \(action)"
        if let count = count {
            message += " (数量: \(count))"
        }
        info(message, category: .general)
    }
}

