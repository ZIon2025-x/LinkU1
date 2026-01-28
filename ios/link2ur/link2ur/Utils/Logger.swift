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
    case iap = "IAP"
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
        
        // 使用 print 输出到 Xcode 控制台（os_log 也会输出，会导致重复）
        // 只使用 print，避免日志重复
        print(logMessage)
        
        // 注意：os_log 虽然功能更强大（支持筛选、性能更好），但在 Xcode 控制台会和 print 同时显示
        // 如果需要使用 os_log（例如在 Console.app 中查看），可以取消下面的注释，但会导致控制台日志重复
        // switch level {
        // case .debug:
        //     os_log("%{public}@", log: log, type: .debug, logMessage)
        // case .info:
        //     os_log("%{public}@", log: log, type: .info, logMessage)
        // case .warning:
        //     os_log("%{public}@", log: log, type: .default, logMessage)
        // case .error:
        //     os_log("%{public}@", log: log, type: .error, logMessage)
        // case .success:
        //     os_log("%{public}@", log: log, type: .info, logMessage)
        // }
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
