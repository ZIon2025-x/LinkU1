import Foundation
import Combine
import os.signpost

/// 企业级性能监控系统
/// 监控网络请求、视图加载、内存使用等关键性能指标

public final class PerformanceMonitor: ObservableObject {
    public static let shared = PerformanceMonitor()
    
    @Published public var metrics: [PerformanceMetric] = []
    
    private var metricStore: [String: PerformanceMetric] = [:]
    private let lock = NSLock()
    private let maxMetricsCount = 1000
    
    private init() {
        startMemoryMonitoring()
    }
    
    // MARK: - 网络性能监控
    
    /// 记录网络请求性能
    public func recordNetworkRequest(
        endpoint: String,
        method: String,
        duration: TimeInterval,
        statusCode: Int? = nil,
        error: Error? = nil
    ) {
        let metric = PerformanceMetric(
            type: .networkRequest,
            identifier: "\(method) \(endpoint)",
            duration: duration,
            metadata: [
                "endpoint": endpoint,
                "method": method,
                "statusCode": statusCode?.description ?? "N/A",
                "error": error?.localizedDescription ?? "none"
            ]
        )
        
        recordMetric(metric)
        
        // 慢请求警告
        if duration > 3.0 {
            Logger.warning("慢请求检测: \(endpoint) 耗时 \(String(format: "%.2f", duration))秒", category: .network)
        }
    }
    
    // MARK: - 视图性能监控
    
    /// 记录视图加载性能
    public func recordViewLoad(
        viewName: String,
        duration: TimeInterval
    ) {
        let metric = PerformanceMetric(
            type: .viewLoad,
            identifier: viewName,
            duration: duration,
            metadata: ["viewName": viewName]
        )
        
        recordMetric(metric)
        
        // 慢加载警告
        if duration > 1.0 {
            Logger.warning("视图加载缓慢: \(viewName) 耗时 \(String(format: "%.2f", duration))秒", category: .ui)
        }
    }
    
    // MARK: - 内存监控
    
    private func startMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.recordMemoryUsage()
        }
    }
    
    private func recordMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let usedMemory = Double(memoryInfo.resident_size) / 1024.0 / 1024.0 // MB
            
            let metric = PerformanceMetric(
                type: .memoryUsage,
                identifier: "memory",
                duration: 0,
                metadata: ["usedMemoryMB": String(format: "%.2f", usedMemory)]
            )
            
            recordMetric(metric)
            
            // 内存警告
            if usedMemory > 200.0 { // 200MB
                Logger.warning("内存使用较高: \(String(format: "%.2f", usedMemory))MB", category: .general)
            }
        }
    }
    
    // MARK: - 指标记录
    
    private func recordMetric(_ metric: PerformanceMetric) {
        lock.lock()
        defer { lock.unlock() }
        
        metricStore[metric.identifier] = metric
        metrics.append(metric)
        
        // 限制存储数量
        if metrics.count > maxMetricsCount {
            metrics.removeFirst(metrics.count - maxMetricsCount)
        }
    }
    
    // MARK: - 性能报告
    
    /// 生成性能报告
    public func generateReport() -> PerformanceReport {
        lock.lock()
        defer { lock.unlock() }
        
        let networkMetrics = metrics.filter { $0.type == .networkRequest }
        let viewMetrics = metrics.filter { $0.type == .viewLoad }
        
        let avgNetworkTime = networkMetrics.isEmpty ? 0 : networkMetrics.map { $0.duration }.reduce(0, +) / Double(networkMetrics.count)
        let avgViewLoadTime = viewMetrics.isEmpty ? 0 : viewMetrics.map { $0.duration }.reduce(0, +) / Double(viewMetrics.count)
        
        return PerformanceReport(
            totalMetrics: metrics.count,
            averageNetworkRequestTime: avgNetworkTime,
            averageViewLoadTime: avgViewLoadTime,
            slowRequests: networkMetrics.filter { $0.duration > 2.0 },
            slowViews: viewMetrics.filter { $0.duration > 1.0 }
        )
    }
    
    /// 清除所有指标
    public func clearMetrics() {
        lock.lock()
        defer { lock.unlock() }
        metrics.removeAll()
        metricStore.removeAll()
    }
}

// MARK: - 性能指标模型

public struct PerformanceMetric: Identifiable, Codable {
    public let id: UUID
    public let type: MetricType
    public let identifier: String
    public let duration: TimeInterval
    public let timestamp: Date
    public let metadata: [String: String]
    
    public init(
        type: MetricType,
        identifier: String,
        duration: TimeInterval,
        metadata: [String: String] = [:]
    ) {
        self.id = UUID()
        self.type = type
        self.identifier = identifier
        self.duration = duration
        self.timestamp = Date()
        self.metadata = metadata
    }
}

public enum MetricType: String, Codable {
    case networkRequest
    case viewLoad
    case memoryUsage
    case databaseQuery
    case imageLoad
}

// MARK: - 性能报告

public struct PerformanceReport {
    public let totalMetrics: Int
    public let averageNetworkRequestTime: TimeInterval
    public let averageViewLoadTime: TimeInterval
    public let slowRequests: [PerformanceMetric]
    public let slowViews: [PerformanceMetric]
    
    public var summary: String {
        return """
        性能报告:
        - 总指标数: \(totalMetrics)
        - 平均网络请求时间: \(String(format: "%.2f", averageNetworkRequestTime))秒
        - 平均视图加载时间: \(String(format: "%.2f", averageViewLoadTime))秒
        - 慢请求数: \(slowRequests.count)
        - 慢视图数: \(slowViews.count)
        """
    }
}

