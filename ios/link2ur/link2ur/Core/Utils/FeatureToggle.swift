import Foundation
import Combine

/// 特性开关 - 企业级功能开关管理
public class FeatureToggle: ObservableObject {
    public static let shared = FeatureToggle()
    
    @Published public var toggles: [String: Bool] = [:]
    
    private let userDefaults = UserDefaults.standard
    private let toggleKey = "feature_toggles"
    
    private init() {
        loadToggles()
    }
    
    /// 加载开关状态
    private func loadToggles() {
        if let saved = userDefaults.dictionary(forKey: toggleKey) as? [String: Bool] {
            toggles = saved
        } else {
            // 默认值
            toggles = [
                "analytics": true,
                "crash_reporting": true,
                "performance_monitoring": true,
                "remote_config": false,
                "ab_testing": false
            ]
        }
    }
    
    /// 检查特性是否启用
    public func isEnabled(_ feature: String) -> Bool {
        return toggles[feature] ?? false
    }
    
    /// 启用特性
    public func enable(_ feature: String) {
        toggles[feature] = true
        saveToggles()
    }
    
    /// 禁用特性
    public func disable(_ feature: String) {
        toggles[feature] = false
        saveToggles()
    }
    
    /// 切换特性状态
    public func toggle(_ feature: String) {
        toggles[feature] = !isEnabled(feature)
        saveToggles()
    }
    
    /// 保存开关状态
    private func saveToggles() {
        userDefaults.set(toggles, forKey: toggleKey)
    }
    
    /// 批量更新
    public func update(_ newToggles: [String: Bool]) {
        toggles.merge(newToggles) { _, new in new }
        saveToggles()
    }
}

/// 特性开关键
public enum FeatureKey: String {
    case analytics = "analytics"
    case crashReporting = "crash_reporting"
    case performanceMonitoring = "performance_monitoring"
    case remoteConfig = "remote_config"
    case abTesting = "ab_testing"
    
    public var isEnabled: Bool {
        return FeatureToggle.shared.isEnabled(self.rawValue)
    }
}

