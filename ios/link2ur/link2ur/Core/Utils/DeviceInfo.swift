import Foundation
import UIKit

/// 设备信息工具 - 企业级设备信息获取
public struct DeviceInfo {
    
    // MARK: - 设备基本信息
    
    /// 设备型号
    public static var model: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let modelCode = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        }
        return modelCode ?? "Unknown"
    }
    
    /// 设备名称（用户设置）
    public static var name: String {
        return UIDevice.current.name
    }
    
    /// 系统版本
    public static var systemVersion: String {
        return UIDevice.current.systemVersion
    }
    
    /// iOS 版本号
    public static var iOSVersion: (major: Int, minor: Int, patch: Int)? {
        let version = UIDevice.current.systemVersion
        let components = version.components(separatedBy: ".")
        guard components.count >= 2,
              let major = Int(components[0]),
              let minor = Int(components[1]) else {
            return nil
        }
        let patch = components.count > 2 ? Int(components[2]) ?? 0 : 0
        return (major, minor, patch)
    }
    
    // MARK: - 应用信息
    
    /// 应用版本
    public static var appVersion: String {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    
    /// 构建版本
    public static var buildNumber: String {
        return Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    }
    
    /// 应用标识符
    public static var bundleIdentifier: String {
        return Bundle.main.bundleIdentifier ?? "Unknown"
    }
    
    /// 应用名称
    public static var appName: String {
        return Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "Unknown"
    }
    
    // MARK: - 屏幕信息
    
    /// 屏幕尺寸
    public static var screenSize: CGSize {
        return UIScreen.main.bounds.size
    }
    
    /// 屏幕宽度
    public static var screenWidth: CGFloat {
        return UIScreen.main.bounds.width
    }
    
    /// 屏幕高度
    public static var screenHeight: CGFloat {
        return UIScreen.main.bounds.height
    }
    
    /// 屏幕比例
    public static var screenScale: CGFloat {
        return UIScreen.main.scale
    }
    
    /// 是否为 iPad
    public static var isPad: Bool {
        return UIDevice.current.userInterfaceIdiom == .pad
    }
    
    /// 是否为 iPhone
    public static var isPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    // MARK: - 设备标识
    
    /// 设备唯一标识符（使用 Keychain 存储）
    public static var deviceIdentifier: String {
        let key = "device_identifier"
        if let identifier = KeychainHelper.shared.read(
            service: Constants.Keychain.service,
            account: key
        ) {
            return identifier
        }
        
        // 生成新的标识符
        let identifier = UUID().uuidString
        KeychainHelper.shared.save(
            identifier.data(using: .utf8) ?? Data(),
            service: Constants.Keychain.service,
            account: key
        )
        return identifier
    }
    
    // MARK: - 设备信息摘要
    
    /// 获取完整的设备信息摘要
    public static var deviceInfoSummary: [String: String] {
        return [
            "model": model,
            "name": name,
            "systemVersion": systemVersion,
            "appVersion": appVersion,
            "buildNumber": buildNumber,
            "bundleIdentifier": bundleIdentifier,
            "screenSize": "\(Int(screenWidth))x\(Int(screenHeight))",
            "screenScale": "\(screenScale)x",
            "deviceType": isPad ? "iPad" : "iPhone",
            "deviceIdentifier": deviceIdentifier
        ]
    }
    
    /// 获取设备信息 JSON 字符串
    public static var deviceInfoJSON: String? {
        guard let data = try? JSONSerialization.data(
            withJSONObject: deviceInfoSummary,
            options: .prettyPrinted
        ) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

