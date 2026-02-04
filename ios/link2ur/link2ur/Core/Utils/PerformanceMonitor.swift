import Foundation
import UIKit
import Combine
import QuartzCore

// MARK: - FPS 监控器

/// FPS 监控级别
public enum FPSLevel: String {
    case excellent = "excellent"  // >= 55 FPS
    case good = "good"            // 45-54 FPS
    case fair = "fair"            // 30-44 FPS
    case poor = "poor"            // < 30 FPS
    
    public var description: String {
        switch self {
        case .excellent: return "优秀"
        case .good: return "良好"
        case .fair: return "一般"
        case .poor: return "较差"
        }
    }
    
    public var emoji: String {
        switch self {
        case .excellent: return "🟢"
        case .good: return "🟡"
        case .fair: return "🟠"
        case .poor: return "🔴"
        }
    }
    
    public static func from(fps: Double) -> FPSLevel {
        switch fps {
        case 55...: return .excellent
        case 45..<55: return .good
        case 30..<45: return .fair
        default: return .poor
        }
    }
}

/// FPS 监控器
public final class FPSMonitor: ObservableObject {
    public static let shared = FPSMonitor()
    
    // MARK: - Published Properties
    
    @Published public private(set) var currentFPS: Double = 60.0
    @Published public private(set) var averageFPS: Double = 60.0
    @Published public private(set) var fpsLevel: FPSLevel = .excellent
    @Published public private(set) var isMonitoring: Bool = false
    
    // MARK: - Private Properties
    
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var frameCount: Int = 0
    private var fpsHistory: [Double] = []
    private let maxHistoryCount = 60 // 保留最近60个采样
    private var lowFPSCount: Int = 0
    private let lowFPSThreshold: Double = 30.0
    private let lowFPSWarningCount = 10 // 连续10次低FPS才报警
    
    /// 是否启用（仅在 DEBUG 模式下默认启用）
    public var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    deinit {
        stop()
    }
    
    // MARK: - Public Methods
    
    /// 开始监控
    public func start() {
        guard isEnabled, !isMonitoring else { return }
        
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkTick))
        displayLink?.add(to: .main, forMode: .common)
        
        isMonitoring = true
        lastTimestamp = 0
        frameCount = 0
        
        Logger.debug("FPS 监控已启动", category: .performance)
    }
    
    /// 停止监控
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        isMonitoring = false
        
        Logger.debug("FPS 监控已停止", category: .performance)
    }
    
    /// 获取 FPS 报告
    public func getReport() -> [String: Any] {
        return [
            "current_fps": currentFPS,
            "average_fps": averageFPS,
            "level": fpsLevel.rawValue,
            "is_monitoring": isMonitoring,
            "history_count": fpsHistory.count
        ]
    }
    
    /// 记录滚动性能
    public func recordScrollPerformance(viewName: String, fps: Double) {
        if fps < lowFPSThreshold {
            Logger.warning("\(viewName) 滚动性能较差: \(String(format: "%.1f", fps)) FPS", category: .performance)
            
            // 记录到崩溃报告
            CrashReporter.shared.setCustomValue(fps, forKey: "scroll_fps_\(viewName)")
        }
    }
    
    // MARK: - Private Methods
    
    @objc private func displayLinkTick(_ link: CADisplayLink) {
        guard lastTimestamp > 0 else {
            lastTimestamp = link.timestamp
            return
        }
        
        frameCount += 1
        let elapsed = link.timestamp - lastTimestamp
        
        // 每秒计算一次 FPS
        if elapsed >= 1.0 {
            let fps = Double(frameCount) / elapsed
            currentFPS = fps
            fpsLevel = FPSLevel.from(fps: fps)
            
            // 更新历史记录
            fpsHistory.append(fps)
            if fpsHistory.count > maxHistoryCount {
                fpsHistory.removeFirst()
            }
            
            // 计算平均 FPS
            averageFPS = fpsHistory.reduce(0, +) / Double(fpsHistory.count)
            
            // 检测持续低 FPS
            if fps < lowFPSThreshold {
                lowFPSCount += 1
                if lowFPSCount >= lowFPSWarningCount {
                    reportLowFPS(fps)
                    lowFPSCount = 0
                }
            } else {
                lowFPSCount = 0
            }
            
            // 重置计数器
            frameCount = 0
            lastTimestamp = link.timestamp
        }
    }
    
    private func reportLowFPS(_ fps: Double) {
        Logger.warning("检测到持续低 FPS: \(String(format: "%.1f", fps))", category: .performance)
        
        // 记录到崩溃报告
        CrashReporter.shared.recordNonFatalError(
            NSError(domain: "FPSMonitor", code: -1, userInfo: [
                NSLocalizedDescriptionKey: "Sustained low FPS detected: \(fps)"
            ]),
            severity: .medium,
            additionalInfo: [
                "fps": "\(fps)",
                "average_fps": "\(averageFPS)",
                "memory_usage": "\(MemoryMonitor.shared.currentMemoryUsage)"
            ]
        )
    }
}

// MARK: - 网络请求性能监控

/// 网络请求性能记录
public struct NetworkRequestMetric: Identifiable {
    public let id = UUID()
    public let endpoint: String
    public let method: String
    public let startTime: Date
    public let duration: TimeInterval
    public let statusCode: Int?
    public let error: Error?
    public let requestSize: Int?
    public let responseSize: Int?
    
    public var isSuccess: Bool {
        if let code = statusCode {
            return (200..<300).contains(code)
        }
        return error == nil
    }
    
    public var isSlow: Bool {
        return duration > 3.0 // 超过3秒认为是慢请求
    }
}

/// 性能监控器 - 企业级性能监控
public final class PerformanceMonitor: ObservableObject {
    public static let shared = PerformanceMonitor()
    
    // MARK: - Published Properties
    
    @Published public private(set) var networkMetrics: [NetworkRequestMetric] = []
    @Published public private(set) var averageNetworkDuration: TimeInterval = 0
    @Published public private(set) var slowRequestCount: Int = 0
    @Published public private(set) var failedRequestCount: Int = 0
    
    // MARK: - Private Properties
    
    private let maxMetricsCount = 100
    private var cancellables = Set<AnyCancellable>()
    
    /// 是否启用
    public var isEnabled: Bool = true
    
    /// 是否已启动监控
    @Published public private(set) var isMonitoring: Bool = false
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 启动性能监控
    /// 在 DEBUG 模式下启动 FPS 监控和 ANR 检测
    public func startMonitoring() {
        guard !isMonitoring else { return }
        
        #if DEBUG
        // 启动 FPS 监控
        FPSMonitor.shared.start()
        // 启动 ANR 检测
        ANRDetector.shared.start()
        #endif
        
        isMonitoring = true
        Logger.info("性能监控已启动", category: .performance)
    }
    
    /// 停止性能监控
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        #if DEBUG
        FPSMonitor.shared.stop()
        ANRDetector.shared.stop()
        #endif
        
        isMonitoring = false
        Logger.info("性能监控已停止", category: .performance)
    }
    
    // MARK: - Network Performance
    
    /// 记录网络请求性能
    public func recordNetworkRequest(
        endpoint: String,
        method: String,
        duration: TimeInterval,
        statusCode: Int? = nil,
        error: Error? = nil,
        requestSize: Int? = nil,
        responseSize: Int? = nil
    ) {
        guard isEnabled else { return }
        
        let metric = NetworkRequestMetric(
            endpoint: endpoint,
            method: method,
            startTime: Date().addingTimeInterval(-duration),
            duration: duration,
            statusCode: statusCode,
            error: error,
            requestSize: requestSize,
            responseSize: responseSize
        )
        
        DispatchQueue.main.async { [weak self] in
            self?.addMetric(metric)
        }
        
        // 慢请求警告
        if metric.isSlow {
            Logger.warning("慢请求: \(method) \(endpoint) - \(String(format: "%.2f", duration))s", category: .performance)
        }
    }
    
    private func addMetric(_ metric: NetworkRequestMetric) {
        networkMetrics.insert(metric, at: 0)
        
        if networkMetrics.count > maxMetricsCount {
            networkMetrics = Array(networkMetrics.prefix(maxMetricsCount))
        }
        
        // 更新统计数据
        updateStatistics()
    }
    
    private func updateStatistics() {
        guard !networkMetrics.isEmpty else { return }
        
        let totalDuration = networkMetrics.reduce(0) { $0 + $1.duration }
        averageNetworkDuration = totalDuration / Double(networkMetrics.count)
        
        slowRequestCount = networkMetrics.filter { $0.isSlow }.count
        failedRequestCount = networkMetrics.filter { !$0.isSuccess }.count
    }
    
    // MARK: - 操作计时
    
    private var operationTimers: [String: Date] = [:]
    
    /// 开始计时操作
    public func startOperation(_ name: String) {
        operationTimers[name] = Date()
    }
    
    /// 结束计时操作并记录
    public func endOperation(_ name: String, additionalData: [String: String]? = nil) {
        guard let startTime = operationTimers[name] else { return }
        
        let duration = Date().timeIntervalSince(startTime)
        operationTimers.removeValue(forKey: name)
        
        Logger.performance(operation: name, duration: duration, additionalData: additionalData)
    }
    
    /// 测量代码块执行时间
    @discardableResult
    public func measure<T>(_ name: String, block: () throws -> T) rethrows -> T {
        let startTime = Date()
        let result = try block()
        let duration = Date().timeIntervalSince(startTime)
        
        Logger.performance(operation: name, duration: duration)
        
        return result
    }
    
    /// 异步测量代码块执行时间
    @discardableResult
    public func measureAsync<T>(_ name: String, block: () async throws -> T) async rethrows -> T {
        let startTime = Date()
        let result = try await block()
        let duration = Date().timeIntervalSince(startTime)
        
        Logger.performance(operation: name, duration: duration)
        
        return result
    }
    
    // MARK: - 报告生成
    
    /// 获取性能报告
    public func getReport() -> [String: Any] {
        return [
            "network": [
                "total_requests": networkMetrics.count,
                "average_duration": averageNetworkDuration,
                "slow_requests": slowRequestCount,
                "failed_requests": failedRequestCount
            ],
            "memory": MemoryMonitor.shared.memoryInfo,
            "fps": FPSMonitor.shared.getReport(),
            "launch": LaunchPerformanceMonitor.shared.lastReport?.totalDuration ?? 0
        ]
    }
    
    /// 清除所有指标
    public func clearMetrics() {
        networkMetrics.removeAll()
        slowRequestCount = 0
        failedRequestCount = 0
        averageNetworkDuration = 0
    }
}

// MARK: - 列表预加载管理器

/// 列表预加载管理器
public final class ListPrefetchManager<Item: Identifiable> {
    private var items: [Item] = []
    private var prefetchedIndices: Set<Int> = []
    private let prefetchDistance: Int
    private let onPrefetch: ([Item]) -> Void
    
    /// 初始化预加载管理器
    /// - Parameters:
    ///   - prefetchDistance: 预加载距离（当前可见项前后多少项）
    ///   - onPrefetch: 预加载回调
    public init(prefetchDistance: Int = 3, onPrefetch: @escaping ([Item]) -> Void) {
        self.prefetchDistance = prefetchDistance
        self.onPrefetch = onPrefetch
    }
    
    /// 更新数据源
    public func updateItems(_ items: [Item]) {
        self.items = items
        self.prefetchedIndices.removeAll()
    }
    
    /// 当项变为可见时调用
    public func onAppear(at index: Int) {
        let startIndex = max(0, index - prefetchDistance)
        let endIndex = min(items.count - 1, index + prefetchDistance)
        
        var itemsToPrefetch: [Item] = []
        
        for i in startIndex...endIndex {
            if !prefetchedIndices.contains(i) {
                prefetchedIndices.insert(i)
                itemsToPrefetch.append(items[i])
            }
        }
        
        if !itemsToPrefetch.isEmpty {
            onPrefetch(itemsToPrefetch)
        }
    }
    
    /// 当项变为不可见时调用
    public func onDisappear(at index: Int) {
        // 可选：清理不再需要的预加载数据
    }
    
    /// 重置预加载状态
    public func reset() {
        prefetchedIndices.removeAll()
    }
}

// MARK: - View 性能修饰符

import SwiftUI

extension View {
    /// 添加性能监控（仅 DEBUG 模式）
    public func performanceMonitored(_ name: String) -> some View {
        #if DEBUG
        return self.onAppear {
            PerformanceMonitor.shared.startOperation("view_appear_\(name)")
        }.onDisappear {
            PerformanceMonitor.shared.endOperation("view_appear_\(name)")
        }
        #else
        return self
        #endif
    }
    
    /// 列表项出现时的动画（带入场延迟）
    public func listItemAppear(index: Int, totalItems: Int, baseDelay: Double = 0.05) -> some View {
        let delay = min(Double(index) * baseDelay, 0.3) // 最大延迟0.3秒
        
        return self
            .opacity(1)
            .animation(.easeOut(duration: 0.3).delay(delay), value: index)
    }
}
