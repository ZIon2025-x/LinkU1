import Foundation

/// 应用版本管理 - 企业级版本控制
public struct AppVersion {
    
    /// 当前版本
    public static var current: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// 构建版本
    public static var build: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// 完整版本（版本号 + 构建号）
    public static var full: String {
        return "\(current) (\(build))"
    }
    
    /// 比较版本号
    public static func compare(_ version1: String, _ version2: String) -> ComparisonResult {
        let v1Components = version1.components(separatedBy: ".").compactMap { Int($0) }
        let v2Components = version2.components(separatedBy: ".").compactMap { Int($0) }
        
        let maxCount = max(v1Components.count, v2Components.count)
        
        for i in 0..<maxCount {
            let v1 = i < v1Components.count ? v1Components[i] : 0
            let v2 = i < v2Components.count ? v2Components[i] : 0
            
            if v1 < v2 {
                return .orderedAscending
            } else if v1 > v2 {
                return .orderedDescending
            }
        }
        
        return .orderedSame
    }
    
    /// 检查是否需要更新
    public static func needsUpdate(latestVersion: String) -> Bool {
        return compare(current, latestVersion) == .orderedAscending
    }
    
    /// 版本信息摘要
    public static var info: [String: String] {
        return [
            "version": current,
            "build": build,
            "full": full,
            "bundleIdentifier": Bundle.main.bundleIdentifier ?? "Unknown"
        ]
    }
}

