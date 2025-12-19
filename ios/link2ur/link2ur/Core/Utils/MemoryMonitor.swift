import Foundation
import Combine

/// 内存监控 - 企业级内存管理
public class MemoryMonitor {
    public static let shared = MemoryMonitor()
    
    @Published public var currentMemoryUsage: Int64 = 0
    @Published public var peakMemoryUsage: Int64 = 0
    @Published public var warningThreshold: Int64 = 200 * 1024 * 1024 // 200MB
    
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 5.0
    
    private init() {
        startMonitoring()
    }
    
    /// 开始监控
    public func startMonitoring() {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
        
        updateMemoryUsage()
    }
    
    /// 停止监控
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// 更新内存使用情况
    private func updateMemoryUsage() {
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
            let usedMemory = Int64(memoryInfo.resident_size)
            currentMemoryUsage = usedMemory
            
            if usedMemory > peakMemoryUsage {
                peakMemoryUsage = usedMemory
            }
            
            // 内存警告
            if usedMemory > warningThreshold {
                Logger.warning("内存使用较高: \(formatBytes(usedMemory))", category: .general)
            }
        }
    }
    
    /// 格式化字节数
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 获取内存使用信息
    public var memoryInfo: [String: String] {
        return [
            "current": formatBytes(currentMemoryUsage),
            "peak": formatBytes(peakMemoryUsage),
            "threshold": formatBytes(warningThreshold)
        ]
    }
    
    deinit {
        stopMonitoring()
    }
}

