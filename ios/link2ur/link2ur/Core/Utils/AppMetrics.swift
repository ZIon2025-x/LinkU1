import Foundation
import Combine

/// 应用指标收集器 - 企业级指标管理
public class AppMetrics: ObservableObject {
    public static let shared = AppMetrics()
    
    @Published public var metrics: [Metric] = []
    
    private var metricStore: [String: Metric] = [:]
    private let lock = NSLock()
    private let maxMetrics = 1000
    
    private init() {}
    
    /// 记录指标
    public func record(
        name: String,
        value: Double,
        tags: [String: String]? = nil
    ) {
        let metric = Metric(
            name: name,
            value: value,
            tags: tags,
            timestamp: Date()
        )
        
        lock.lock()
        metricStore[name] = metric
        metrics.append(metric)
        
        if metrics.count > maxMetrics {
            metrics.removeFirst(metrics.count - maxMetrics)
        }
        lock.unlock()
    }
    
    /// 增加计数
    public func increment(_ name: String, by amount: Double = 1.0) {
        lock.lock()
        let currentValue = metricStore[name]?.value ?? 0
        record(name: name, value: currentValue + amount)
        lock.unlock()
    }
    
    /// 获取指标值
    public func getValue(for name: String) -> Double? {
        lock.lock()
        defer { lock.unlock() }
        return metricStore[name]?.value
    }
    
    /// 获取指标摘要
    public func getSummary() -> [String: Double] {
        lock.lock()
        defer { lock.unlock() }
        return metricStore.mapValues { $0.value }
    }
    
    /// 清除所有指标
    public func clear() {
        lock.lock()
        defer { lock.unlock() }
        metrics.removeAll()
        metricStore.removeAll()
    }
}

/// 指标模型
public struct Metric: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let value: Double
    public let tags: [String: String]?
    public let timestamp: Date
    
    public init(id: UUID = UUID(), name: String, value: Double, tags: [String: String]?, timestamp: Date) {
        self.id = id
        self.name = name
        self.value = value
        self.tags = tags
        self.timestamp = timestamp
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case value
        case tags
        case timestamp
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decode(String.self, forKey: .name)
        value = try container.decode(Double.self, forKey: .value)
        tags = try container.decodeIfPresent([String: String].self, forKey: .tags)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
    }
}

