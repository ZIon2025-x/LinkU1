import Foundation

/// 网络日志记录器 - 企业级网络日志
public class NetworkLogger {
    public static let shared = NetworkLogger()
    
    private var logs: [NetworkLog] = []
    private let maxLogs = 100
    private var isEnabled = true
    
    private init() {}
    
    /// 启用/禁用日志
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// 记录请求
    public func logRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) {
        guard isEnabled else { return }
        
        let log = NetworkLog(
            id: UUID().uuidString,
            timestamp: Date(),
            method: method,
            url: url,
            headers: headers,
            requestBody: body,
            responseBody: nil,
            statusCode: nil,
            duration: nil,
            error: nil
        )
        
        logs.append(log)
        trimLogs()
        
        Logger.debug("网络请求: \(method) \(url)", category: .network)
    }
    
    /// 记录响应
    public func logResponse(
        for requestId: String? = nil,
        url: String,
        statusCode: Int? = nil,
        headers: [String: String]? = nil,
        body: Data? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil
    ) {
        guard isEnabled else { return }
        
        // 查找对应的请求日志
        if let requestId = requestId,
           let index = logs.firstIndex(where: { $0.id == requestId }) {
            logs[index].statusCode = statusCode
            logs[index].responseBody = body
            logs[index].duration = duration
            logs[index].error = error?.localizedDescription
        } else {
            // 创建新的响应日志
            let log = NetworkLog(
                id: UUID().uuidString,
                timestamp: Date(),
                method: nil,
                url: url,
                headers: headers,
                requestBody: nil,
                responseBody: body,
                statusCode: statusCode,
                duration: duration,
                error: error?.localizedDescription
            )
            logs.append(log)
        }
        
        trimLogs()
        
        if let error = error {
            Logger.error("网络错误: \(url) - \(error.localizedDescription)", category: .network)
        } else {
            Logger.debug("网络响应: \(url) - \(statusCode ?? 0)", category: .network)
        }
    }
    
    /// 获取日志
    public func getLogs(limit: Int = 50) -> [NetworkLog] {
        return Array(logs.suffix(limit))
    }
    
    /// 清除日志
    public func clearLogs() {
        logs.removeAll()
    }
    
    /// 导出日志
    public func exportLogs() -> [[String: Any]] {
        return logs.map { log in
            var dict: [String: Any] = [
                "id": log.id,
                "timestamp": log.timestamp.timeIntervalSince1970,
                "url": log.url
            ]
            if let method = log.method {
                dict["method"] = method
            }
            if let statusCode = log.statusCode {
                dict["statusCode"] = statusCode
            }
            if let duration = log.duration {
                dict["duration"] = duration
            }
            if let error = log.error {
                dict["error"] = error
            }
            return dict
        }
    }
    
    private func trimLogs() {
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
    }
}

/// 网络日志模型
public struct NetworkLog {
    public let id: String
    public let timestamp: Date
    public var method: String?
    public let url: String
    public var headers: [String: String]?
    public var requestBody: Data?
    public var responseBody: Data?
    public var statusCode: Int?
    public var duration: TimeInterval?
    public var error: String?
}

