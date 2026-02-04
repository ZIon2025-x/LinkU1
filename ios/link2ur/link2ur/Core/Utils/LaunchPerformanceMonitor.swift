import Foundation
import UIKit
import Combine

// MARK: - 启动阶段定义

/// 启动阶段
public enum LaunchPhase: String, CaseIterable {
    case preMain = "pre_main"           // main() 之前（无法在 Swift 中直接测量）
    case appInit = "app_init"           // App 初始化
    case willFinish = "will_finish"     // willFinishLaunchingWithOptions
    case didFinish = "did_finish"       // didFinishLaunchingWithOptions
    case firstFrame = "first_frame"     // 首帧渲染完成
    case interactive = "interactive"    // 用户可交互
    case dataLoaded = "data_loaded"     // 首屏数据加载完成
    
    public var displayName: String {
        switch self {
        case .preMain: return "Pre-main"
        case .appInit: return "App 初始化"
        case .willFinish: return "即将启动完成"
        case .didFinish: return "启动完成"
        case .firstFrame: return "首帧渲染"
        case .interactive: return "可交互"
        case .dataLoaded: return "数据加载完成"
        }
    }
}

/// 启动阶段时间记录
public struct LaunchPhaseRecord {
    public let phase: LaunchPhase
    public let timestamp: Date
    public let duration: TimeInterval?  // 从上一阶段到当前阶段的时间
    public let totalDuration: TimeInterval  // 从启动开始到当前阶段的时间
    
    public var isNormal: Bool {
        guard let duration = duration else { return true }
        
        // 定义各阶段的正常时间阈值（秒）
        let thresholds: [LaunchPhase: TimeInterval] = [
            .appInit: 0.5,
            .willFinish: 0.3,
            .didFinish: 1.0,
            .firstFrame: 0.5,
            .interactive: 0.5,
            .dataLoaded: 3.0
        ]
        
        return duration < (thresholds[phase] ?? 1.0)
    }
}

/// 启动性能报告
public struct LaunchPerformanceReport {
    public let launchDate: Date
    public let totalDuration: TimeInterval
    public let phases: [LaunchPhaseRecord]
    public let isWarmLaunch: Bool
    public let memoryAtLaunch: UInt64
    public let deviceInfo: [String: String]
    
    /// 启动是否在正常范围内
    public var isNormalLaunch: Bool {
        return totalDuration < 3.0 && phases.allSatisfy { $0.isNormal }
    }
    
    /// 获取最慢的阶段
    public var slowestPhase: LaunchPhaseRecord? {
        return phases.max { ($0.duration ?? 0) < ($1.duration ?? 0) }
    }
    
    /// 生成报告摘要
    public func summary() -> String {
        var lines: [String] = []
        lines.append("=== 启动性能报告 ===")
        lines.append("启动时间: \(DateFormatter.logFormatter.string(from: launchDate))")
        lines.append("总耗时: \(String(format: "%.2f", totalDuration * 1000))ms")
        lines.append("启动类型: \(isWarmLaunch ? "热启动" : "冷启动")")
        lines.append("启动内存: \(memoryAtLaunch / 1024 / 1024)MB")
        lines.append("状态: \(isNormalLaunch ? "✅ 正常" : "⚠️ 较慢")")
        lines.append("")
        lines.append("阶段详情:")
        
        for record in phases {
            let durationStr = record.duration.map { String(format: "%.2f", $0 * 1000) } ?? "N/A"
            let statusIcon = record.isNormal ? "✅" : "⚠️"
            lines.append("  \(statusIcon) \(record.phase.displayName): \(durationStr)ms")
        }
        
        if let slowest = slowestPhase, let duration = slowest.duration {
            lines.append("")
            lines.append("最慢阶段: \(slowest.phase.displayName) (\(String(format: "%.2f", duration * 1000))ms)")
        }
        
        return lines.joined(separator: "\n")
    }
}

// MARK: - 启动性能监控器

/// 启动性能监控器 - 企业级启动监控
public final class LaunchPerformanceMonitor: ObservableObject {
    public static let shared = LaunchPerformanceMonitor()
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentPhase: LaunchPhase = .appInit
    @Published public private(set) var isLaunchComplete: Bool = false
    @Published public private(set) var lastReport: LaunchPerformanceReport?
    
    // MARK: - Private Properties
    
    private let launchStartTime: Date
    private var phaseTimestamps: [LaunchPhase: Date] = [:]
    private var previousLaunchTime: Date?
    private let queue = DispatchQueue(label: "com.link2ur.launchmonitor", qos: .userInitiated)
    private var cancellables = Set<AnyCancellable>()
    
    /// 是否启用监控
    public var isEnabled: Bool = true
    
    /// 慢启动阈值（秒）
    public var slowLaunchThreshold: TimeInterval = 3.0
    
    // MARK: - Initialization
    
    private init() {
        // 记录启动时间（尽可能早）
        launchStartTime = Date()
        phaseTimestamps[.appInit] = launchStartTime
        
        // 检查是否是热启动
        previousLaunchTime = UserDefaults.standard.object(forKey: "lastLaunchTime") as? Date
        
        setupObservers()
        
        Logger.debug("LaunchPerformanceMonitor 初始化，启动时间: \(DateFormatter.logFormatter.string(from: launchStartTime))", category: .performance)
    }
    
    // MARK: - Public Methods
    
    /// 标记阶段完成
    public func markPhase(_ phase: LaunchPhase) {
        guard isEnabled else { return }
        
        queue.async { [weak self] in
            guard let self = self else { return }
            
            let timestamp = Date()
            self.phaseTimestamps[phase] = timestamp
            
            DispatchQueue.main.async {
                self.currentPhase = phase
            }
            
            let totalDuration = timestamp.timeIntervalSince(self.launchStartTime)
            Logger.debug("启动阶段: \(phase.displayName)，累计耗时: \(String(format: "%.2f", totalDuration * 1000))ms", category: .performance)
            
            // 如果是可交互阶段，标记启动完成
            if phase == .interactive || phase == .dataLoaded {
                self.finalizeLaunch()
            }
        }
    }
    
    /// 手动触发启动完成（用于复杂场景）
    public func completeLaunch() {
        markPhase(.interactive)
    }
    
    /// 记录首屏数据加载完成
    public func markDataLoaded() {
        markPhase(.dataLoaded)
    }
    
    /// 获取当前启动耗时
    public func currentLaunchDuration() -> TimeInterval {
        return Date().timeIntervalSince(launchStartTime)
    }
    
    /// 获取指定阶段的耗时
    public func duration(for phase: LaunchPhase) -> TimeInterval? {
        guard let timestamp = phaseTimestamps[phase] else { return nil }
        return timestamp.timeIntervalSince(launchStartTime)
    }
    
    // MARK: - Private Methods
    
    private func setupObservers() {
        // 监听首帧渲染完成
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .first()
            .sink { [weak self] _ in
                self?.markPhase(.firstFrame)
            }
            .store(in: &cancellables)
    }
    
    private func finalizeLaunch() {
        guard !isLaunchComplete else { return }
        
        DispatchQueue.main.async {
            self.isLaunchComplete = true
        }
        
        // 生成报告
        let report = generateReport()
        
        DispatchQueue.main.async {
            self.lastReport = report
        }
        
        // 保存启动时间
        UserDefaults.standard.set(Date(), forKey: "lastLaunchTime")
        
        // 记录到日志
        Logger.info(report.summary(), category: .performance)
        
        // 如果启动过慢，记录警告
        if !report.isNormalLaunch {
            Logger.warning("检测到慢启动: \(String(format: "%.2f", report.totalDuration * 1000))ms", category: .performance)
            
            // 可以在这里上报到崩溃收集服务
            CrashReporter.shared.setCustomValue(report.totalDuration, forKey: "launch_duration")
            
            if let slowest = report.slowestPhase {
                CrashReporter.shared.setCustomValue(slowest.phase.rawValue, forKey: "slowest_launch_phase")
            }
        }
        
        // 保存历史启动数据
        saveHistoricalData(report)
    }
    
    private func generateReport() -> LaunchPerformanceReport {
        let sortedPhases = LaunchPhase.allCases.filter { phaseTimestamps[$0] != nil }
        
        var records: [LaunchPhaseRecord] = []
        var previousTimestamp = launchStartTime
        
        for phase in sortedPhases {
            guard let timestamp = phaseTimestamps[phase] else { continue }
            
            let duration = timestamp.timeIntervalSince(previousTimestamp)
            let totalDuration = timestamp.timeIntervalSince(launchStartTime)
            
            records.append(LaunchPhaseRecord(
                phase: phase,
                timestamp: timestamp,
                duration: duration,
                totalDuration: totalDuration
            ))
            
            previousTimestamp = timestamp
        }
        
        let totalDuration = (phaseTimestamps[.interactive] ?? phaseTimestamps[.dataLoaded] ?? Date()).timeIntervalSince(launchStartTime)
        
        return LaunchPerformanceReport(
            launchDate: launchStartTime,
            totalDuration: totalDuration,
            phases: records,
            isWarmLaunch: isWarmLaunch(),
            memoryAtLaunch: getCurrentMemoryUsage(),
            deviceInfo: DeviceInfo.deviceInfoSummary
        )
    }
    
    private func isWarmLaunch() -> Bool {
        guard let previousLaunch = previousLaunchTime else { return false }
        // 如果距离上次启动不到 5 分钟，认为是热启动
        return Date().timeIntervalSince(previousLaunch) < 300
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    private func saveHistoricalData(_ report: LaunchPerformanceReport) {
        // 保存最近 10 次启动数据
        var history = UserDefaults.standard.array(forKey: "launchHistory") as? [[String: Any]] ?? []
        
        let data: [String: Any] = [
            "date": report.launchDate.timeIntervalSince1970,
            "duration": report.totalDuration,
            "isWarm": report.isWarmLaunch,
            "isNormal": report.isNormalLaunch
        ]
        
        history.insert(data, at: 0)
        if history.count > 10 {
            history = Array(history.prefix(10))
        }
        
        UserDefaults.standard.set(history, forKey: "launchHistory")
    }
    
    /// 获取历史启动数据
    public func getHistoricalData() -> [(date: Date, duration: TimeInterval, isWarm: Bool, isNormal: Bool)] {
        guard let history = UserDefaults.standard.array(forKey: "launchHistory") as? [[String: Any]] else {
            return []
        }
        
        return history.compactMap { data in
            guard let timestamp = data["date"] as? TimeInterval,
                  let duration = data["duration"] as? TimeInterval,
                  let isWarm = data["isWarm"] as? Bool,
                  let isNormal = data["isNormal"] as? Bool else {
                return nil
            }
            
            return (Date(timeIntervalSince1970: timestamp), duration, isWarm, isNormal)
        }
    }
    
    /// 获取平均启动时间
    public func getAverageLaunchDuration() -> TimeInterval? {
        let history = getHistoricalData()
        guard !history.isEmpty else { return nil }
        
        let total = history.reduce(0.0) { $0 + $1.duration }
        return total / Double(history.count)
    }
}

// MARK: - 延迟初始化管理器

/// 延迟初始化管理器 - 用于优化启动性能
public final class DeferredInitializationManager {
    public static let shared = DeferredInitializationManager()
    
    private var deferredTasks: [(priority: Int, task: () -> Void)] = []
    private var hasExecuted: Bool = false
    private let queue = DispatchQueue(label: "com.link2ur.deferredinit", qos: .utility)
    
    private init() {}
    
    /// 注册延迟初始化任务
    /// - Parameters:
    ///   - priority: 优先级（数字越小优先级越高）
    ///   - task: 初始化任务
    public func register(priority: Int = 100, task: @escaping () -> Void) {
        guard !hasExecuted else {
            // 如果已经执行过，直接执行新任务
            queue.async { task() }
            return
        }
        
        deferredTasks.append((priority, task))
    }
    
    /// 执行所有延迟初始化任务
    /// 应该在首帧渲染后调用
    public func executeAll() {
        guard !hasExecuted else { return }
        hasExecuted = true
        
        // 按优先级排序
        let sortedTasks = deferredTasks.sorted { $0.priority < $1.priority }
        
        queue.async {
            let startTime = Date()
            
            for (index, item) in sortedTasks.enumerated() {
                let taskStart = Date()
                item.task()
                let taskDuration = Date().timeIntervalSince(taskStart)
                
                if taskDuration > 0.1 {
                    Logger.debug("延迟初始化任务 \(index + 1) 耗时: \(String(format: "%.2f", taskDuration * 1000))ms", category: .performance)
                }
            }
            
            let totalDuration = Date().timeIntervalSince(startTime)
            Logger.info("延迟初始化完成，共 \(sortedTasks.count) 个任务，总耗时: \(String(format: "%.2f", totalDuration * 1000))ms", category: .performance)
        }
        
        // 清空任务列表
        deferredTasks.removeAll()
    }
}

// MARK: - App Delegate 扩展（用于标记启动阶段）

extension AppDelegate {
    /// 在 didFinishLaunchingWithOptions 开始时调用
    func markLaunchWillFinish() {
        LaunchPerformanceMonitor.shared.markPhase(.willFinish)
    }
    
    /// 在 didFinishLaunchingWithOptions 结束时调用
    func markLaunchDidFinish() {
        LaunchPerformanceMonitor.shared.markPhase(.didFinish)
        
        // 延迟执行非关键初始化
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            DeferredInitializationManager.shared.executeAll()
        }
    }
}
