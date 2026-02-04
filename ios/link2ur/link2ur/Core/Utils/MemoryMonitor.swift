import Foundation
import Combine
import UIKit

// MARK: - 内存压力级别

/// 内存压力级别
public enum MemoryPressureLevel: Int, Comparable {
    case normal = 0      // 正常
    case warning = 1     // 警告（50-70%）
    case critical = 2    // 危险（70-85%）
    case emergency = 3   // 紧急（>85%）
    
    public static func < (lhs: MemoryPressureLevel, rhs: MemoryPressureLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var description: String {
        switch self {
        case .normal: return "正常"
        case .warning: return "警告"
        case .critical: return "危险"
        case .emergency: return "紧急"
        }
    }
    
    public var emoji: String {
        switch self {
        case .normal: return "✅"
        case .warning: return "⚠️"
        case .critical: return "🔶"
        case .emergency: return "🔴"
        }
    }
}

// MARK: - 内存快照

/// 内存快照（用于对比和泄漏检测）
public struct MemorySnapshot: Identifiable {
    public let id = UUID()
    public let timestamp: Date
    public let usedMemory: Int64
    public let freeMemory: Int64
    public let totalMemory: Int64
    public let pressureLevel: MemoryPressureLevel
    public let context: String?
    
    public var usagePercentage: Double {
        guard totalMemory > 0 else { return 0 }
        return Double(usedMemory) / Double(totalMemory) * 100
    }
    
    public func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    public var summary: String {
        return "\(pressureLevel.emoji) 内存: \(formatBytes(usedMemory)) / \(formatBytes(totalMemory)) (\(String(format: "%.1f", usagePercentage))%)"
    }
}

// MARK: - 内存监控器

/// 内存监控 - 企业级内存管理
public final class MemoryMonitor: ObservableObject {
    public static let shared = MemoryMonitor()
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentMemoryUsage: Int64 = 0
    @Published public private(set) var peakMemoryUsage: Int64 = 0
    @Published public private(set) var pressureLevel: MemoryPressureLevel = .normal
    @Published public private(set) var lastSnapshot: MemorySnapshot?
    
    /// 警告阈值（默认 150MB）
    @Published public var warningThreshold: Int64 = 150 * 1024 * 1024
    
    /// 危险阈值（默认 250MB）
    @Published public var criticalThreshold: Int64 = 250 * 1024 * 1024
    
    /// 紧急阈值（默认 350MB）
    @Published public var emergencyThreshold: Int64 = 350 * 1024 * 1024
    
    // MARK: - Private Properties
    
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 5.0
    private var memoryHistory: [MemorySnapshot] = []
    private let maxHistoryCount = 100
    private var cancellables = Set<AnyCancellable>()
    private var lastCleanupTime: Date?
    private let cleanupCooldown: TimeInterval = 30.0 // 清理冷却时间
    
    /// 是否启用自动清理
    public var autoCleanupEnabled: Bool = true
    
    /// 是否启用监控
    public var isEnabled: Bool = true
    
    // MARK: - Initialization
    
    private init() {
        setupSystemMemoryWarningObserver()
        startMonitoring()
        
        // 根据设备总内存调整阈值
        adjustThresholdsForDevice()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控
    public func startMonitoring() {
        guard isEnabled else { return }
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        updateMemoryUsage()
        Logger.debug("内存监控已启动，更新间隔: \(updateInterval)s", category: .performance)
    }
    
    /// 停止监控
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// 手动触发内存清理
    public func triggerCleanup(force: Bool = false) {
        performCleanup(level: force ? .emergency : pressureLevel, forced: force)
    }
    
    /// 创建内存快照
    public func takeSnapshot(context: String? = nil) -> MemorySnapshot {
        let snapshot = createSnapshot(context: context)
        memoryHistory.append(snapshot)
        
        // 限制历史记录数量
        if memoryHistory.count > maxHistoryCount {
            memoryHistory.removeFirst(memoryHistory.count - maxHistoryCount)
        }
        
        return snapshot
    }
    
    /// 获取内存历史
    public func getMemoryHistory() -> [MemorySnapshot] {
        return memoryHistory
    }
    
    /// 检测内存泄漏（对比两个快照）
    public func detectLeak(baseline: MemorySnapshot, current: MemorySnapshot, threshold: Int64 = 10 * 1024 * 1024) -> Bool {
        let increase = current.usedMemory - baseline.usedMemory
        return increase > threshold
    }
    
    /// 获取设备总内存
    public var deviceTotalMemory: Int64 {
        return Int64(ProcessInfo.processInfo.physicalMemory)
    }
    
    /// 获取内存使用信息
    public var memoryInfo: [String: String] {
        return [
            "current": formatBytes(currentMemoryUsage),
            "peak": formatBytes(peakMemoryUsage),
            "total": formatBytes(deviceTotalMemory),
            "pressure": pressureLevel.description,
            "warning_threshold": formatBytes(warningThreshold),
            "critical_threshold": formatBytes(criticalThreshold)
        ]
    }
    
    /// 记录内存使用到崩溃报告
    public func recordToCrashReporter() {
        CrashReporter.shared.setCustomValue(currentMemoryUsage, forKey: "memory_usage")
        CrashReporter.shared.setCustomValue(peakMemoryUsage, forKey: "memory_peak")
        CrashReporter.shared.setCustomValue(pressureLevel.description, forKey: "memory_pressure")
    }
    
    // MARK: - Private Methods
    
    private func setupSystemMemoryWarningObserver() {
        NotificationCenter.default.publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleSystemMemoryWarning()
            }
            .store(in: &cancellables)
    }
    
    private func handleSystemMemoryWarning() {
        Logger.warning("收到系统内存警告", category: .performance)
        
        // 立即更新内存状态
        updateMemoryUsage()
        
        // 强制清理
        performCleanup(level: .emergency, forced: true)
        
        // 记录到崩溃报告
        recordToCrashReporter()
        CrashReporter.shared.log("⚠️ System Memory Warning - Usage: \(formatBytes(currentMemoryUsage))")
    }
    
    private func adjustThresholdsForDevice() {
        let totalMemory = deviceTotalMemory
        
        // 根据设备总内存动态调整阈值
        // 低端设备（<2GB）使用更低的阈值
        if totalMemory < 2 * 1024 * 1024 * 1024 {
            warningThreshold = 100 * 1024 * 1024   // 100MB
            criticalThreshold = 180 * 1024 * 1024  // 180MB
            emergencyThreshold = 250 * 1024 * 1024 // 250MB
        } else if totalMemory < 4 * 1024 * 1024 * 1024 {
            // 中端设备（2-4GB）
            warningThreshold = 150 * 1024 * 1024   // 150MB
            criticalThreshold = 250 * 1024 * 1024  // 250MB
            emergencyThreshold = 350 * 1024 * 1024 // 350MB
        } else {
            // 高端设备（>4GB）
            warningThreshold = 200 * 1024 * 1024   // 200MB
            criticalThreshold = 350 * 1024 * 1024  // 350MB
            emergencyThreshold = 500 * 1024 * 1024 // 500MB
        }
        
        Logger.debug("内存阈值已调整 - 警告: \(formatBytes(warningThreshold)), 危险: \(formatBytes(criticalThreshold)), 紧急: \(formatBytes(emergencyThreshold))", category: .performance)
    }
    
    private func updateMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        guard kerr == KERN_SUCCESS else { return }
        
        let usedMemory = Int64(memoryInfo.resident_size)
        currentMemoryUsage = usedMemory
        
        // 更新峰值
        if usedMemory > peakMemoryUsage {
            peakMemoryUsage = usedMemory
        }
        
        // 计算压力级别
        let newPressureLevel = calculatePressureLevel(usedMemory)
        let levelChanged = newPressureLevel != pressureLevel
        pressureLevel = newPressureLevel
        
        // 更新快照
        lastSnapshot = createSnapshot()
        
        // 如果压力级别变化，记录日志
        if levelChanged {
            Logger.info("内存压力级别变化: \(pressureLevel.emoji) \(pressureLevel.description) - \(formatBytes(usedMemory))", category: .performance)
            
            // 发送通知
            NotificationCenter.default.post(
                name: .memoryPressureLevelChanged,
                object: nil,
                userInfo: ["level": pressureLevel, "usage": usedMemory]
            )
        }
        
        // 自动清理
        if autoCleanupEnabled && pressureLevel >= .warning {
            performCleanupIfNeeded()
        }
    }
    
    private func calculatePressureLevel(_ usedMemory: Int64) -> MemoryPressureLevel {
        if usedMemory >= emergencyThreshold {
            return .emergency
        } else if usedMemory >= criticalThreshold {
            return .critical
        } else if usedMemory >= warningThreshold {
            return .warning
        } else {
            return .normal
        }
    }
    
    private func performCleanupIfNeeded() {
        // 检查冷却时间
        if let lastCleanup = lastCleanupTime,
           Date().timeIntervalSince(lastCleanup) < cleanupCooldown {
            return
        }
        
        performCleanup(level: pressureLevel, forced: false)
    }
    
    private func performCleanup(level: MemoryPressureLevel, forced: Bool) {
        lastCleanupTime = Date()
        
        Logger.info("执行内存清理 - 级别: \(level.description), 强制: \(forced)", category: .performance)
        
        let beforeMemory = currentMemoryUsage
        
        switch level {
        case .normal:
            // 正常情况不清理
            break
            
        case .warning:
            // 轻度清理
            ImageCache.shared.clearExpiredCache(maxAge: 24 * 3600) // 清理24小时前的图片缓存
            
        case .critical:
            // 中度清理
            ImageCache.shared.clearExpiredCache(maxAge: 1 * 3600) // 清理1小时前的图片缓存
            URLCache.shared.removeAllCachedResponses() // 清理 URL 缓存
            
        case .emergency:
            // 紧急清理
            ImageCache.shared.clearCache() // 清理所有图片缓存
            URLCache.shared.removeAllCachedResponses()
            CacheManager.shared.clearExpiredCache()
            
            // 通知其他组件清理
            NotificationCenter.default.post(name: .memoryCleanupRequired, object: nil, userInfo: ["level": level])
        }
        
        // 延迟检查清理效果
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            let freedMemory = beforeMemory - self.currentMemoryUsage
            if freedMemory > 0 {
                Logger.info("内存清理完成，释放: \(self.formatBytes(freedMemory))", category: .performance)
            }
        }
    }
    
    private func createSnapshot(context: String? = nil) -> MemorySnapshot {
        let totalMemory = deviceTotalMemory
        let usedMemory = currentMemoryUsage
        let freeMemory = totalMemory - usedMemory
        
        return MemorySnapshot(
            timestamp: Date(),
            usedMemory: usedMemory,
            freeMemory: freeMemory,
            totalMemory: totalMemory,
            pressureLevel: pressureLevel,
            context: context
        )
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - ANR 检测器

/// ANR（Application Not Responding）检测器
public final class ANRDetector {
    public static let shared = ANRDetector()
    
    private var watchdogThread: Thread?
    private var lastMainThreadResponseTime: Date = Date()
    private var isRunning: Bool = false
    
    /// 检测间隔（秒）
    public var watchdogInterval: TimeInterval = 2.0
    
    /// ANR 阈值（秒）- 主线程无响应超过此时间则认为发生 ANR
    public var threshold: TimeInterval = 5.0
    
    /// 是否启用
    public var isEnabled: Bool = true
    
    private init() {}
    
    /// 开始检测
    public func start() {
        guard isEnabled, !isRunning else { return }
        
        isRunning = true
        lastMainThreadResponseTime = Date()
        
        // 创建 watchdog 线程
        watchdogThread = Thread { [weak self] in
            self?.watchdogLoop()
        }
        watchdogThread?.name = "ANRDetector.Watchdog"
        watchdogThread?.qualityOfService = .userInitiated
        watchdogThread?.start()
        
        // 定期在主线程更新响应时间
        startMainThreadPing()
        
        Logger.debug("ANR 检测器已启动，阈值: \(threshold)s", category: .performance)
    }
    
    /// 停止检测
    public func stop() {
        isRunning = false
        watchdogThread?.cancel()
        watchdogThread = nil
    }
    
    private func watchdogLoop() {
        while isRunning && !Thread.current.isCancelled {
            Thread.sleep(forTimeInterval: watchdogInterval)
            
            let timeSinceLastResponse = Date().timeIntervalSince(lastMainThreadResponseTime)
            
            if timeSinceLastResponse > threshold {
                reportANR(duration: timeSinceLastResponse)
            }
        }
    }
    
    private func startMainThreadPing() {
        guard isRunning else { return }
        
        DispatchQueue.main.async { [weak self] in
            self?.lastMainThreadResponseTime = Date()
            
            // 递归调度下一次 ping
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.startMainThreadPing()
            }
        }
    }
    
    private func reportANR(duration: TimeInterval) {
        Logger.critical("检测到 ANR！主线程无响应 \(String(format: "%.2f", duration)) 秒", category: .performance)
        
        // 获取主线程调用栈
        let callStack = Thread.callStackSymbols
        
        // 记录到崩溃报告
        CrashReporter.shared.recordNonFatalError(
            NSError(domain: "ANRDetector", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "ANR detected - Main thread blocked for \(String(format: "%.2f", duration))s",
                "duration": duration,
                "call_stack": callStack.joined(separator: "\n")
            ]),
            severity: .high,
            additionalInfo: [
                "anr_duration": "\(duration)",
                "memory_usage": "\(MemoryMonitor.shared.currentMemoryUsage)"
            ]
        )
        
        // 发送通知
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .anrDetected,
                object: nil,
                userInfo: ["duration": duration, "callStack": callStack]
            )
        }
    }
}

// MARK: - 通知扩展

extension Notification.Name {
    /// 内存压力级别变化
    static let memoryPressureLevelChanged = Notification.Name("memoryPressureLevelChanged")
    /// 需要内存清理
    static let memoryCleanupRequired = Notification.Name("memoryCleanupRequired")
    /// 检测到 ANR
    static let anrDetected = Notification.Name("anrDetected")
}

