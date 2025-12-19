import Foundation

/// 分析工具 - 企业级事件追踪
public class Analytics {
    public static let shared = Analytics()
    
    private var events: [AnalyticsEvent] = []
    private let maxEvents = 1000
    private var isEnabled = true
    
    private init() {}
    
    /// 启用/禁用分析
    public func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
    }
    
    /// 记录事件
    public func logEvent(
        _ name: String,
        parameters: [String: Any]? = nil
    ) {
        guard isEnabled else { return }
        
        let event = AnalyticsEvent(
            name: name,
            parameters: parameters,
            timestamp: Date()
        )
        
        events.append(event)
        
        // 限制事件数量
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
        
        Logger.debug("分析事件: \(name)", category: .general)
    }
    
    /// 记录屏幕浏览
    public func logScreenView(_ screenName: String, parameters: [String: Any]? = nil) {
        var params = parameters ?? [:]
        params["screen_name"] = screenName
        logEvent("screen_view", parameters: params)
    }
    
    /// 记录用户操作
    public func logUserAction(_ action: String, parameters: [String: Any]? = nil) {
        var params = parameters ?? [:]
        params["action"] = action
        logEvent("user_action", parameters: params)
    }
    
    /// 记录错误
    public func logError(_ error: Error, context: String? = nil) {
        var params: [String: Any] = [
            "error_description": error.localizedDescription
        ]
        if let context = context {
            params["context"] = context
        }
        logEvent("error", parameters: params)
    }
    
    /// 获取事件历史
    public func getEvents(limit: Int = 100) -> [AnalyticsEvent] {
        return Array(events.suffix(limit))
    }
    
    /// 清除所有事件
    public func clearEvents() {
        events.removeAll()
    }
    
    /// 导出事件（用于上报）
    public func exportEvents() -> [[String: Any]] {
        return events.map { event in
            var dict: [String: Any] = [
                "name": event.name,
                "timestamp": event.timestamp.timeIntervalSince1970
            ]
            if let parameters = event.parameters {
                dict["parameters"] = parameters
            }
            return dict
        }
    }
}

/// 分析事件模型
public struct AnalyticsEvent {
    public let name: String
    public let parameters: [String: Any]?
    public let timestamp: Date
}

