import Foundation
import UIKit

// MARK: - Firebase Crashlytics 协议（用于依赖注入，便于测试和切换实现）
/// 崩溃报告服务协议
public protocol CrashReportingService {
    /// 记录非致命错误
    func recordError(_ error: Error, additionalInfo: [String: Any]?)
    /// 记录自定义日志
    func log(_ message: String)
    /// 设置用户标识
    func setUserID(_ userID: String?)
    /// 设置自定义键值对
    func setCustomValue(_ value: Any?, forKey key: String)
    /// 强制发送报告
    func sendUnsentReports()
}

/// 默认的本地崩溃报告服务（当 Firebase 未集成时使用）
public final class LocalCrashReportingService: CrashReportingService {
    public func recordError(_ error: Error, additionalInfo: [String: Any]?) {
        // 本地记录到日志
        Logger.error("Non-fatal error: \(error.localizedDescription)", category: .general, additionalData: additionalInfo?.mapValues { "\($0)" })
    }
    
    public func log(_ message: String) {
        Logger.info(message, category: .general)
    }
    
    public func setUserID(_ userID: String?) {
        // 本地存储
    }
    
    public func setCustomValue(_ value: Any?, forKey key: String) {
        // 本地存储
    }
    
    public func sendUnsentReports() {
        // 本地实现无需发送
    }
}

// MARK: - 崩溃报告器 - 企业级崩溃管理

/// 崩溃严重程度
public enum CrashSeverity: String, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
}

/// 崩溃报告器 - 企业级崩溃管理
public final class CrashReporter {
    public static let shared = CrashReporter()
    
    // MARK: - Properties
    
    private var crashLogs: [CrashLog] = []
    private let maxLogs = 50
    private let logFile: URL
    private let queue = DispatchQueue(label: "com.link2ur.crashreporter", qos: .utility)
    
    /// 崩溃报告服务（可注入 Firebase Crashlytics）
    public var crashReportingService: CrashReportingService = LocalCrashReportingService()
    
    /// 是否启用（Release 模式下默认启用）
    public var isEnabled: Bool = true
    
    /// 当前用户 ID（用于崩溃关联）
    private var currentUserID: String?
    
    /// 自定义属性（崩溃时一起上报）
    private var customAttributes: [String: Any] = [:]
    
    // MARK: - Initialization
    
    private init() {
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        logFile = docsDir.appendingPathComponent("crash_logs.json")
        loadCrashLogs()
        setupCrashHandlers()
        setupMemoryWarningObserver()
        
        // 检查并上报之前的崩溃
        checkAndReportPreviousCrash()
    }
    
    // MARK: - Setup
    
    /// 设置崩溃处理器
    private func setupCrashHandlers() {
        // 设置未捕获异常处理器
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.handleException(exception)
        }
        
        // 设置信号处理器（捕获更多类型的崩溃）
        setupSignalHandlers()
    }
    
    /// 设置信号处理器
    /// 注意：信号处理器内只能调用 async-signal-safe 函数。queue.sync、文件 I/O、Logger 等均不安全，
    /// 会在 SIGSEGV 等场景下导致死锁或二次崩溃。因此 handler 仅恢复默认并重新抛出信号。
    private func setupSignalHandlers() {
        let signals: [Int32] = [SIGABRT, SIGILL, SIGSEGV, SIGFPE, SIGBUS, SIGPIPE, SIGTRAP]
        for sig in signals {
            signal(sig) { s in
                Foundation.signal(s, SIG_DFL)
                raise(s)
            }
        }
    }
    
    /// 设置内存警告监听
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.recordMemoryWarning()
        }
    }
    
    // MARK: - Public Methods
    
    /// 配置 Firebase Crashlytics（在 AppDelegate 中调用）
    /// 
    /// 集成 Firebase Crashlytics 步骤：
    /// 1. 在 Xcode 中添加 Firebase SDK (Swift Package Manager)
    /// 2. 下载 GoogleService-Info.plist 并添加到项目
    /// 3. 在 AppDelegate 中初始化：
    /// ```swift
    /// import FirebaseCore
    /// import FirebaseCrashlytics
    /// 
    /// func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    ///     FirebaseApp.configure()
    ///     CrashReporter.shared.configureWithFirebase()
    /// }
    /// ```
    public func configureWithFirebase() {
        // 当集成 Firebase 后，取消以下注释：
        /*
        #if canImport(FirebaseCrashlytics)
        crashReportingService = FirebaseCrashlyticsService()
        Logger.info("Firebase Crashlytics 已配置", category: .general)
        #endif
        */
        
        Logger.info("CrashReporter 已初始化（本地模式）", category: .general)
    }
    
    /// 设置用户标识（用于崩溃关联）
    public func setUserID(_ userID: String?) {
        currentUserID = userID
        crashReportingService.setUserID(userID)
    }
    
    /// 设置自定义属性
    public func setCustomValue(_ value: Any?, forKey key: String) {
        if let value = value {
            customAttributes[key] = value
        } else {
            customAttributes.removeValue(forKey: key)
        }
        crashReportingService.setCustomValue(value, forKey: key)
    }
    
    /// 记录非致命错误
    public func recordNonFatalError(
        _ error: Error,
        severity: CrashSeverity = .medium,
        additionalInfo: [String: Any]? = nil
    ) {
        guard isEnabled else { return }
        
        var info = additionalInfo ?? [:]
        info["severity"] = severity.rawValue
        info["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        // 添加最近的日志
        info["recent_logs"] = Logger.getRecentLogs(maxCount: 20).joined(separator: "\n")
        
        crashReportingService.recordError(error, additionalInfo: info)
        
        Logger.warning("记录非致命错误: \(error.localizedDescription)", category: .general)
    }
    
    /// 记录自定义日志（会随崩溃报告一起上传）
    public func log(_ message: String) {
        crashReportingService.log(message)
    }
    
    /// 记录崩溃
    public func recordCrash(
        exception: NSException? = nil,
        reason: String,
        severity: CrashSeverity = .critical,
        userInfo: [String: Any]? = nil
    ) {
        guard isEnabled else { return }
        
        let log = CrashLog(
            timestamp: Date(),
            reason: reason,
            severity: severity,
            exceptionName: exception?.name.rawValue,
            callStack: exception?.callStackSymbols ?? Thread.callStackSymbols,
            userInfo: userInfo,
            deviceInfo: DeviceInfo.deviceInfoSummary,
            appVersion: AppVersion.full,
            userID: currentUserID,
            customAttributes: customAttributes,
            recentLogs: Logger.getRecentLogs(maxCount: 50)
        )
        
        queue.sync {
            crashLogs.append(log)
            saveCrashLogsSync()
            
            // 限制日志数量
            if crashLogs.count > maxLogs {
                crashLogs.removeFirst(crashLogs.count - maxLogs)
            }
        }
        
        // 通知远程服务
        if let exception = exception {
            let error = NSError(
                domain: "CrashReporter",
                code: -1,
                userInfo: [
                    NSLocalizedDescriptionKey: reason,
                    "exception_name": exception.name.rawValue,
                    "severity": severity.rawValue
                ]
            )
            crashReportingService.recordError(error, additionalInfo: userInfo)
        }
    }
    
    /// 获取崩溃日志
    public func getCrashLogs() -> [CrashLog] {
        return queue.sync { crashLogs }
    }
    
    /// 清除崩溃日志
    public func clearCrashLogs() {
        queue.async { [weak self] in
            self?.crashLogs.removeAll()
            self?.saveCrashLogsSync()
        }
    }
    
    /// 检查是否有未上报的崩溃
    public func hasUnreportedCrashes() -> Bool {
        return !crashLogs.isEmpty
    }
    
    /// 发送未发送的报告
    public func sendUnsentReports() {
        crashReportingService.sendUnsentReports()
    }
    
    // MARK: - Private Methods
    
    /// 处理未捕获异常
    private func handleException(_ exception: NSException) {
        recordCrash(
            exception: exception,
            reason: exception.reason ?? "Unknown exception",
            severity: .critical
        )
        
        // 给一点时间让数据写入
        Thread.sleep(forTimeInterval: 0.5)
    }
    
    /// 获取信号名称（供 recordCrash 等非信号上下文使用）
    private func signalName(for signal: Int32) -> String {
        switch signal {
        case SIGABRT: return "SIGABRT"
        case SIGILL: return "SIGILL"
        case SIGSEGV: return "SIGSEGV"
        case SIGFPE: return "SIGFPE"
        case SIGBUS: return "SIGBUS"
        case SIGPIPE: return "SIGPIPE"
        case SIGTRAP: return "SIGTRAP"
        default: return "UNKNOWN(\(signal))"
        }
    }
    
    /// 记录内存警告
    private func recordMemoryWarning() {
        log("⚠️ Memory Warning Received")
        setCustomValue(Date().timeIntervalSince1970, forKey: "last_memory_warning")
        
        Logger.warning("收到内存警告", category: .performance)
    }
    
    /// 检查并上报之前的崩溃
    private func checkAndReportPreviousCrash() {
        // 检查是否有之前保存的崩溃日志需要上报
        if !crashLogs.isEmpty {
            Logger.info("发现 \(crashLogs.count) 个未上报的崩溃日志", category: .general)
            sendUnsentReports()
        }
    }
    
    /// 保存崩溃日志（同步版本，用于崩溃时）
    private func saveCrashLogsSync() {
        guard let data = try? JSONEncoder().encode(crashLogs) else { return }
        try? data.write(to: logFile, options: .atomic)
    }
    
    /// 加载崩溃日志
    private func loadCrashLogs() {
        guard let data = try? Data(contentsOf: logFile),
              let logs = try? JSONDecoder().decode([CrashLog].self, from: data) else {
            return
        }
        crashLogs = logs
    }
}

// MARK: - 崩溃日志模型

public struct CrashLog: Codable, Identifiable {
    public let id: UUID
    public let timestamp: Date
    public let reason: String
    public let severity: CrashSeverity
    public let exceptionName: String?
    public let callStack: [String]
    public let userInfo: [String: Any]?
    public let deviceInfo: [String: String]
    public let appVersion: String
    public let userID: String?
    public let customAttributes: [String: Any]?
    public let recentLogs: [String]?
    
    enum CodingKeys: String, CodingKey {
        case id, timestamp, reason, severity, exceptionName, callStack
        case userInfo, deviceInfo, appVersion, userID, customAttributes, recentLogs
    }
    
    public init(
        timestamp: Date,
        reason: String,
        severity: CrashSeverity = .critical,
        exceptionName: String?,
        callStack: [String],
        userInfo: [String: Any]?,
        deviceInfo: [String: String],
        appVersion: String,
        userID: String? = nil,
        customAttributes: [String: Any]? = nil,
        recentLogs: [String]? = nil
    ) {
        self.id = UUID()
        self.timestamp = timestamp
        self.reason = reason
        self.severity = severity
        self.exceptionName = exceptionName
        self.callStack = callStack
        self.userInfo = userInfo
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
        self.userID = userID
        self.customAttributes = customAttributes
        self.recentLogs = recentLogs
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        reason = try container.decode(String.self, forKey: .reason)
        severity = try container.decodeIfPresent(CrashSeverity.self, forKey: .severity) ?? .critical
        exceptionName = try container.decodeIfPresent(String.self, forKey: .exceptionName)
        callStack = try container.decode([String].self, forKey: .callStack)
        deviceInfo = try container.decode([String: String].self, forKey: .deviceInfo)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        userID = try container.decodeIfPresent(String.self, forKey: .userID)
        recentLogs = try container.decodeIfPresent([String].self, forKey: .recentLogs)
        
        // 解码 userInfo
        if let userInfoData = try? container.decode(Data.self, forKey: .userInfo),
           let decoded = try? JSONSerialization.jsonObject(with: userInfoData) as? [String: Any] {
            self.userInfo = decoded
        } else {
            self.userInfo = nil
        }
        
        // 解码 customAttributes
        if let attrData = try? container.decode(Data.self, forKey: .customAttributes),
           let decoded = try? JSONSerialization.jsonObject(with: attrData) as? [String: Any] {
            self.customAttributes = decoded
        } else {
            self.customAttributes = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(reason, forKey: .reason)
        try container.encode(severity, forKey: .severity)
        try container.encodeIfPresent(exceptionName, forKey: .exceptionName)
        try container.encode(callStack, forKey: .callStack)
        try container.encode(deviceInfo, forKey: .deviceInfo)
        try container.encode(appVersion, forKey: .appVersion)
        try container.encodeIfPresent(userID, forKey: .userID)
        try container.encodeIfPresent(recentLogs, forKey: .recentLogs)
        
        // 编码 userInfo
        if let userInfo = userInfo,
           let data = try? JSONSerialization.data(withJSONObject: userInfo) {
            try container.encode(data, forKey: .userInfo)
        }
        
        // 编码 customAttributes
        if let attrs = customAttributes,
           let data = try? JSONSerialization.data(withJSONObject: attrs) {
            try container.encode(data, forKey: .customAttributes)
        }
    }
}

// MARK: - Firebase Crashlytics 服务实现（集成 Firebase 后取消注释）

/*
#if canImport(FirebaseCrashlytics)
import FirebaseCrashlytics

public final class FirebaseCrashlyticsService: CrashReportingService {
    public func recordError(_ error: Error, additionalInfo: [String: Any]?) {
        var userInfo = additionalInfo ?? [:]
        userInfo[NSLocalizedDescriptionKey] = error.localizedDescription
        
        let nsError = NSError(
            domain: (error as NSError).domain,
            code: (error as NSError).code,
            userInfo: userInfo as [String: Any]
        )
        
        Crashlytics.crashlytics().record(error: nsError)
    }
    
    public func log(_ message: String) {
        Crashlytics.crashlytics().log(message)
    }
    
    public func setUserID(_ userID: String?) {
        Crashlytics.crashlytics().setUserID(userID ?? "")
    }
    
    public func setCustomValue(_ value: Any?, forKey key: String) {
        Crashlytics.crashlytics().setCustomValue(value, forKey: key)
    }
    
    public func sendUnsentReports() {
        Crashlytics.crashlytics().sendUnsentReports()
    }
}
#endif
*/

