import Foundation

/// Bundle 扩展 - 企业级应用信息获取
extension Bundle {
    
    /// 应用名称
    public var appName: String {
        return infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "Unknown"
    }
    
    /// 应用版本
    public var appVersion: String {
        return infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// 构建版本
    public var buildNumber: String {
        return infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// 应用标识符
    public var appBundleIdentifier: String {
        return self.bundleIdentifier ?? "Unknown"
    }
    
    /// 应用图标名称
    public var appIconName: String? {
        if let icons = infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primaryIcon = icons["CFBundlePrimaryIcon"] as? [String: Any],
           let iconFiles = primaryIcon["CFBundleIconFiles"] as? [String],
           let lastIcon = iconFiles.last {
            return lastIcon
        }
        return nil
    }
    
    /// 是否启用后台模式
    public var hasBackgroundModes: Bool {
        return infoDictionary?["UIBackgroundModes"] != nil
    }
    
    /// 支持的方向
    public var supportedOrientations: [String] {
        return infoDictionary?["UISupportedInterfaceOrientations"] as? [String] ?? []
    }
    
    /// 最低支持版本
    public var minimumOSVersion: String? {
        return infoDictionary?["MinimumOSVersion"] as? String
    }
}

