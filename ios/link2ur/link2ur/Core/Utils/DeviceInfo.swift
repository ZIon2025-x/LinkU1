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
    
    // MARK: - iPad 型号检测
    
    /// iPad 型号枚举
    public enum iPadModelType {
        case mini          // iPad Mini (8.3英寸)
        case air           // iPad Air (10.9英寸)
        case pro11         // iPad Pro 11英寸
        case pro12_9       // iPad Pro 12.9英寸
        case standard      // 标准iPad (10.2英寸等)
        case unknown       // 未知型号
    }
    
    /// 检测 iPad 型号
    public static var iPadModel: iPadModelType {
        guard isPad else { return .unknown }
        
        let modelCode = self.model
        let screenWidth = self.screenWidth
        let screenHeight = self.screenHeight
        let minDimension = min(screenWidth, screenHeight)
        let maxDimension = max(screenWidth, screenHeight)
        
        // 根据屏幕尺寸和型号代码判断
        // iPad Mini (8.3英寸): 744 x 1133 点
        if minDimension <= 744 && maxDimension <= 1133 {
            return .mini
        }
        // iPad Pro 12.9英寸: 1024 x 1366 点
        else if minDimension >= 1024 && maxDimension >= 1366 {
            return .pro12_9
        }
        // iPad Pro 11英寸: 834 x 1194 点
        else if minDimension >= 834 && maxDimension >= 1194 && minDimension < 1024 {
            return .pro11
        }
        // iPad Air (10.9英寸): 820 x 1180 点
        else if minDimension >= 820 && maxDimension >= 1180 && minDimension < 834 {
            return .air
        }
        // 标准iPad (10.2英寸等): 810 x 1080 点
        else if minDimension >= 810 && maxDimension >= 1080 {
            return .standard
        }
        // 根据型号代码进一步判断
        else if modelCode.contains("iPad13") || modelCode.contains("iPad14") {
            // iPad Air 4/5 (iPad13,x) 或 iPad Air 5 (iPad14,x)
            return .air
        }
        else if modelCode.contains("iPad11") || modelCode.contains("iPad12") {
            // iPad Pro 11英寸
            return .pro11
        }
        else if modelCode.contains("iPad8") || modelCode.contains("iPad13") {
            // iPad Pro 12.9英寸
            return .pro12_9
        }
        else if modelCode.contains("iPad14") || modelCode.contains("iPad15") {
            // iPad Mini 6/7
            return .mini
        }
        
        return .standard
    }
    
    /// 是否为 iPad Mini
    public static var isIPadMini: Bool {
        return iPadModel == .mini
    }
    
    /// 是否为 iPad Pro
    public static var isIPadPro: Bool {
        return iPadModel == .pro11 || iPadModel == .pro12_9
    }
    
    /// 是否为 iPad Pro 12.9英寸
    public static var isIPadPro12_9: Bool {
        return iPadModel == .pro12_9
    }
    
    /// 是否为 iPad Pro 11英寸
    public static var isIPadPro11: Bool {
        return iPadModel == .pro11
    }
    
    /// 是否为 iPad Air
    public static var isIPadAir: Bool {
        return iPadModel == .air
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
        _ = KeychainHelper.shared.save(
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

