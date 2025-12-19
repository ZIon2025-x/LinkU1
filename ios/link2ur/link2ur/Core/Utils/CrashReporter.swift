import Foundation

/// 崩溃报告器 - 企业级崩溃管理
public class CrashReporter {
    public static let shared = CrashReporter()
    
    private var crashLogs: [CrashLog] = []
    private let maxLogs = 50
    private let logFile: URL
    
    private init() {
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        logFile = urls[0].appendingPathComponent("crash_logs.json")
        loadCrashLogs()
        setupCrashHandler()
    }
    
    /// 设置崩溃处理器
    private func setupCrashHandler() {
        NSSetUncaughtExceptionHandler { exception in
            CrashReporter.shared.recordCrash(
                exception: exception,
                reason: exception.reason ?? "Unknown"
            )
        }
    }
    
    /// 记录崩溃
    public func recordCrash(
        exception: NSException? = nil,
        reason: String,
        userInfo: [String: Any]? = nil
    ) {
        let log = CrashLog(
            timestamp: Date(),
            reason: reason,
            exceptionName: exception?.name.rawValue,
            callStack: exception?.callStackSymbols ?? Thread.callStackSymbols,
            userInfo: userInfo,
            deviceInfo: DeviceInfo.deviceInfoSummary,
            appVersion: AppVersion.full
        )
        
        crashLogs.append(log)
        saveCrashLogs()
        
        // 限制日志数量
        if crashLogs.count > maxLogs {
            crashLogs.removeFirst(crashLogs.count - maxLogs)
        }
    }
    
    /// 获取崩溃日志
    public func getCrashLogs() -> [CrashLog] {
        return crashLogs
    }
    
    /// 清除崩溃日志
    public func clearCrashLogs() {
        crashLogs.removeAll()
        saveCrashLogs()
    }
    
    /// 保存崩溃日志
    private func saveCrashLogs() {
        guard let data = try? JSONEncoder().encode(crashLogs) else { return }
        try? data.write(to: logFile)
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

/// 崩溃日志模型
public struct CrashLog: Codable {
    public let timestamp: Date
    public let reason: String
    public let exceptionName: String?
    public let callStack: [String]
    public let userInfo: [String: Any]?
    public let deviceInfo: [String: String]
    public let appVersion: String
    
    enum CodingKeys: String, CodingKey {
        case timestamp, reason, exceptionName, callStack, userInfo, deviceInfo, appVersion
    }
    
    public init(
        timestamp: Date,
        reason: String,
        exceptionName: String?,
        callStack: [String],
        userInfo: [String: Any]?,
        deviceInfo: [String: String],
        appVersion: String
    ) {
        self.timestamp = timestamp
        self.reason = reason
        self.exceptionName = exceptionName
        self.callStack = callStack
        self.userInfo = userInfo
        self.deviceInfo = deviceInfo
        self.appVersion = appVersion
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        reason = try container.decode(String.self, forKey: .reason)
        exceptionName = try container.decodeIfPresent(String.self, forKey: .exceptionName)
        callStack = try container.decode([String].self, forKey: .callStack)
        deviceInfo = try container.decode([String: String].self, forKey: .deviceInfo)
        appVersion = try container.decode(String.self, forKey: .appVersion)
        
        if let userInfoData = try? container.decode(Data.self, forKey: .userInfo),
           let userInfo = try? JSONSerialization.jsonObject(with: userInfoData) as? [String: Any] {
            self.userInfo = userInfo
        } else {
            self.userInfo = nil
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(reason, forKey: .reason)
        try container.encodeIfPresent(exceptionName, forKey: .exceptionName)
        try container.encode(callStack, forKey: .callStack)
        try container.encode(deviceInfo, forKey: .deviceInfo)
        try container.encode(appVersion, forKey: .appVersion)
        
        if let userInfo = userInfo,
           let userInfoData = try? JSONSerialization.data(withJSONObject: userInfo) {
            try container.encode(userInfoData, forKey: .userInfo)
        }
    }
}

