import Foundation
import os.log

// MARK: - 企业级日志系统

/// 日志级别 - 支持分级过滤
public enum LogLevel: Int, Comparable, CaseIterable {
    case verbose = 0  // 最详细的日志，通常只在开发时使用
    case debug = 1    // 调试信息
    case info = 2     // 一般信息
    case warning = 3  // 警告信息
    case error = 4    // 错误信息
    case critical = 5 // 严重错误，可能导致崩溃
    
    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var emoji: String {
        switch self {
        case .verbose: return "📝"
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🔥"
        }
    }
    
    var label: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }
    
    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error, .critical: return .error
        }
    }
}

/// 日志分类
public enum LogCategory: String, CaseIterable {
    case api = "API"
    case ui = "UI"
    case network = "Network"
    case cache = "Cache"
    case websocket = "WebSocket"
    case auth = "Auth"
    case iap = "IAP"
    case payment = "Payment"
    case performance = "Performance"
    case lifecycle = "Lifecycle"
    case database = "Database"
    case security = "Security"
    case general = "General"
}

/// 日志条目模型
public struct LogEntry: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let level: Int // LogLevel.rawValue
    public let category: String
    public let message: String
    public let file: String
    public let function: String
    public let line: Int
    public let threadName: String
    public let additionalData: [String: String]?
    
    public init(
        level: LogLevel,
        category: LogCategory,
        message: String,
        file: String,
        function: String,
        line: Int,
        additionalData: [String: String]? = nil
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.level = level.rawValue
        self.category = category.rawValue
        self.message = message
        self.file = (file as NSString).lastPathComponent
        self.function = function
        self.line = line
        self.threadName = Thread.current.isMainThread ? "main" : (Thread.current.name ?? "background")
        self.additionalData = additionalData
    }
    
    public var levelEnum: LogLevel {
        return LogLevel(rawValue: level) ?? .info
    }
    
    public var formattedMessage: String {
        let timestamp = DateFormatter.logFormatter.string(from: self.timestamp)
        return "[\(timestamp)] [\(category)] \(levelEnum.emoji) \(levelEnum.label) \(file):\(line) \(function) [\(threadName)] - \(message)"
    }
}

/// 日志存储管理器 - 负责日志持久化
public final class LogStorage {
    public static let shared = LogStorage()
    
    private let fileManager = FileManager.default
    private let logDirectory: URL
    private let maxLogFiles = 7 // 保留最近7天的日志
    private let maxFileSize: Int64 = 5 * 1024 * 1024 // 5MB per file
    private let queue = DispatchQueue(label: "com.link2ur.logstorage", qos: .utility)
    
    private var currentLogFile: URL?
    private var currentFileHandle: FileHandle?
    private var currentFileSize: Int64 = 0
    
    private init() {
        // 创建日志目录
        let cacheDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        logDirectory = cacheDir.appendingPathComponent("Logs", isDirectory: true)
        
        try? fileManager.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        // 清理旧日志
        cleanupOldLogs()
        
        // 初始化当前日志文件
        initializeCurrentLogFile()
    }
    
    deinit {
        try? currentFileHandle?.close()
    }
    
    /// 写入日志条目
    public func write(_ entry: LogEntry) {
        queue.async { [weak self] in
            self?.writeSync(entry)
        }
    }
    
    private func writeSync(_ entry: LogEntry) {
        // 检查是否需要轮转日志文件
        if shouldRotateFile() {
            rotateLogFile()
        }
        
        guard let handle = currentFileHandle else { return }
        
        let logLine = entry.formattedMessage + "\n"
        if let data = logLine.data(using: .utf8) {
            do {
                try handle.write(contentsOf: data)
                currentFileSize += Int64(data.count)
            } catch {
                // 静默处理写入错误
            }
        }
    }
    
    /// 获取最近的日志条目（用于崩溃上报）
    public func getRecentLogs(maxCount: Int = 100) -> [String] {
        var logs: [String] = []
        
        queue.sync {
            // 先同步当前文件
            try? currentFileHandle?.synchronize()
            
            // 读取当前日志文件
            if let currentFile = currentLogFile,
               let content = try? String(contentsOf: currentFile, encoding: .utf8) {
                let lines = content.components(separatedBy: .newlines)
                logs = Array(lines.suffix(maxCount))
            }
        }
        
        return logs.filter { !$0.isEmpty }
    }
    
    /// 获取所有日志文件路径
    public func getAllLogFiles() -> [URL] {
        let files = (try? fileManager.contentsOfDirectory(at: logDirectory, includingPropertiesForKeys: [.creationDateKey])) ?? []
        return files.filter { $0.pathExtension == "log" }.sorted { url1, url2 in
            let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
            return date1 > date2
        }
    }
    
    /// 清除所有日志
    public func clearAllLogs() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? self.currentFileHandle?.close()
            self.currentFileHandle = nil
            
            for file in self.getAllLogFiles() {
                try? self.fileManager.removeItem(at: file)
            }
            
            self.initializeCurrentLogFile()
        }
    }
    
    /// 导出日志（用于用户反馈）
    public func exportLogs() -> URL? {
        let exportFile = logDirectory.appendingPathComponent("exported_logs_\(Date().timeIntervalSince1970).txt")
        
        var allContent = ""
        for file in getAllLogFiles().reversed() {
            if let content = try? String(contentsOf: file, encoding: .utf8) {
                allContent += "\n--- \(file.lastPathComponent) ---\n"
                allContent += content
            }
        }
        
        do {
            try allContent.write(to: exportFile, atomically: true, encoding: .utf8)
            return exportFile
        } catch {
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func initializeCurrentLogFile() {
        let dateString = DateFormatter.logFileDateFormatter.string(from: Date())
        currentLogFile = logDirectory.appendingPathComponent("app_\(dateString).log")
        
        if let file = currentLogFile {
            if !fileManager.fileExists(atPath: file.path) {
                fileManager.createFile(atPath: file.path, contents: nil)
            }
            
            currentFileHandle = try? FileHandle(forWritingTo: file)
            _ = try? currentFileHandle?.seekToEnd()
            currentFileSize = (try? fileManager.attributesOfItem(atPath: file.path)[.size] as? Int64) ?? 0
        }
    }
    
    private func shouldRotateFile() -> Bool {
        // 检查文件大小或日期变更
        let currentDate = DateFormatter.logFileDateFormatter.string(from: Date())
        let fileDate = currentLogFile?.lastPathComponent.replacingOccurrences(of: "app_", with: "").replacingOccurrences(of: ".log", with: "") ?? ""
        
        return currentFileSize >= maxFileSize || currentDate != fileDate
    }
    
    private func rotateLogFile() {
        try? currentFileHandle?.close()
        initializeCurrentLogFile()
    }
    
    private func cleanupOldLogs() {
        let files = getAllLogFiles()
        if files.count > maxLogFiles {
            for file in files.dropFirst(maxLogFiles) {
                try? fileManager.removeItem(at: file)
            }
        }
    }
}

/// 企业级日志管理器
public final class Logger {
    public static let shared = Logger()
    
    /// 最小日志级别（低于此级别的日志不会记录）
    public var minimumLevel: LogLevel = {
        #if DEBUG
        return .verbose
        #else
        return .info
        #endif
    }()
    
    /// 是否启用控制台输出
    public var consoleOutputEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    /// 是否启用文件持久化
    public var persistenceEnabled: Bool = true
    
    /// 是否启用 os_log
    public var osLogEnabled: Bool = false
    
    private let subsystem = Bundle.main.bundleIdentifier ?? "com.link2ur.app"
    private let storage = LogStorage.shared
    
    private init() {}
    
    // MARK: - 日志方法
    
    /// 记录日志
    public func log(
        _ message: String,
        level: LogLevel = .info,
        category: LogCategory = .general,
        additionalData: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        guard level >= minimumLevel else { return }
        
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            additionalData: additionalData
        )
        
        // 控制台输出
        if consoleOutputEnabled {
            print(entry.formattedMessage)
        }
        
        // os_log 输出
        if osLogEnabled {
            let log = OSLog(subsystem: subsystem, category: category.rawValue)
            os_log("%{public}@", log: log, type: level.osLogType, entry.formattedMessage)
        }
        
        // 持久化存储
        if persistenceEnabled {
            storage.write(entry)
        }
        
        // Critical 级别额外处理
        if level == .critical {
            handleCriticalLog(entry)
        }
    }
    
    /// 处理严重错误日志
    private func handleCriticalLog(_ entry: LogEntry) {
        // 可以在这里添加额外的处理，如立即同步文件、发送告警等
        // 当集成 Firebase Crashlytics 后，这里可以记录非致命错误
    }
    
    // MARK: - 便捷方法（静态）
    
    public static func verbose(_ message: String, category: LogCategory = .general, additionalData: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .verbose, category: category, additionalData: additionalData, file: file, function: function, line: line)
    }
    
    public static func debug(_ message: String, category: LogCategory = .general, additionalData: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .debug, category: category, additionalData: additionalData, file: file, function: function, line: line)
    }
    
    public static func info(_ message: String, category: LogCategory = .general, additionalData: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .info, category: category, additionalData: additionalData, file: file, function: function, line: line)
    }
    
    public static func warning(_ message: String, category: LogCategory = .general, additionalData: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .warning, category: category, additionalData: additionalData, file: file, function: function, line: line)
    }
    
    public static func error(_ message: String, category: LogCategory = .general, additionalData: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .error, category: category, additionalData: additionalData, file: file, function: function, line: line)
    }
    
    public static func critical(_ message: String, category: LogCategory = .general, additionalData: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log(message, level: .critical, category: category, additionalData: additionalData, file: file, function: function, line: line)
    }
    
    /// 成功日志（语义化便捷方法）
    public static func success(_ message: String, category: LogCategory = .general, file: String = #file, function: String = #function, line: Int = #line) {
        shared.log("✅ \(message)", level: .info, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - 审计日志
    
    /// 记录关键操作审计日志
    public static func audit(
        action: String,
        userId: String? = nil,
        details: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var data = details ?? [:]
        data["audit_action"] = action
        if let userId = userId {
            data["user_id"] = userId
        }
        
        shared.log("🔐 AUDIT: \(action)", level: .info, category: .security, additionalData: data, file: file, function: function, line: line)
    }
    
    // MARK: - 性能日志
    
    /// 记录性能指标
    public static func performance(
        operation: String,
        duration: TimeInterval,
        additionalData: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var data = additionalData ?? [:]
        data["operation"] = operation
        data["duration_ms"] = String(format: "%.2f", duration * 1000)
        
        let level: LogLevel = duration > 3.0 ? .warning : .debug
        shared.log("⏱️ \(operation): \(String(format: "%.2f", duration * 1000))ms", level: level, category: .performance, additionalData: data, file: file, function: function, line: line)
    }
    
    // MARK: - 日志导出
    
    /// 获取最近的日志（用于崩溃上报）
    public static func getRecentLogs(maxCount: Int = 100) -> [String] {
        return LogStorage.shared.getRecentLogs(maxCount: maxCount)
    }
    
    /// 导出日志文件
    public static func exportLogs() -> URL? {
        return LogStorage.shared.exportLogs()
    }
    
    /// 清除所有日志
    public static func clearAllLogs() {
        LogStorage.shared.clearAllLogs()
    }
}

// MARK: - DateFormatter 扩展
extension DateFormatter {
    static let logFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    static let logFileDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
