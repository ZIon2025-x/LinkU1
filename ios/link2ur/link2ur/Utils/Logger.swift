import Foundation
import os.log

// MARK: - 统一日志系统

/// 日志级别
enum LogLevel: String {
    case debug = "🔍 DEBUG"
    case info = "ℹ️ INFO"
    case warning = "⚠️ WARNING"
    case error = "❌ ERROR"
    case success = "✅ SUCCESS"
}

/// 日志分类
enum LogCategory: String {
    case api = "API"
    case ui = "UI"
    case network = "Network"
    case cache = "Cache"
    case websocket = "WebSocket"
    case auth = "Auth"
    case general = "General"
}

/// 统一日志管理器
struct Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.link2ur.app"
    
    /// 记录日志
    static func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let timestamp = DateFormatter.logFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] [\(category.rawValue)] \(level.rawValue) \(fileName):\(line) \(function) - \(message)"
        
        // 使用 os.log 进行系统级日志记录
        let log = OSLog(subsystem: subsystem, category: category.rawValue)
        
        switch level {
        case .debug:
            os_log("%{public}@", log: log, type: .debug, logMessage)
        case .info:
            os_log("%{public}@", log: log, type: .info, logMessage)
        case .warning:
            os_log("%{public}@", log: log, type: .default, logMessage)
        case .error:
            os_log("%{public}@", log: log, type: .error, logMessage)
        case .success:
            os_log("%{public}@", log: log, type: .info, logMessage)
        }
        
        // 同时输出到控制台（仅 DEBUG 模式）
        print(logMessage)
        #endif
    }
    
    /// 调试日志
    static func debug(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .debug, category: category, file: file, function: function, line: line)
    }
    
    /// 信息日志
    static func info(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// 警告日志
    static func warning(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// 错误日志
    static func error(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// 成功日志
    static func success(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .success, category: category, file: file, function: function, line: line)
    }
}

// MARK: - DateFormatter 扩展
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
}
