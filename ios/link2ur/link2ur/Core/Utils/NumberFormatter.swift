import Foundation

/// 数字格式化工具 - 企业级数字显示
public struct NumberFormatterHelper {
    
    /// 格式化货币
    public static func currency(
        _ amount: Double,
        currencyCode: String = "GBP",
        locale: Locale = .current
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }
    
    /// 格式化百分比
    public static func percentage(
        _ value: Double,
        decimalPlaces: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)%"
    }
    
    /// 格式化数字（带千位分隔符）
    public static func number(
        _ value: Double,
        decimalPlaces: Int = 2
    ) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
    
    /// 格式化文件大小
    public static func fileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    /// 格式化距离（米/公里）
    public static func distance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f米", meters)
        } else {
            return String(format: "%.2f公里", meters / 1000)
        }
    }
    
    /// 格式化大数字（如 1.2K, 1.5M）
    public static func abbreviated(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        
        if value >= 1_000_000_000 {
            return "\(formatter.string(from: NSNumber(value: value / 1_000_000_000)) ?? "")B"
        } else if value >= 1_000_000 {
            return "\(formatter.string(from: NSNumber(value: value / 1_000_000)) ?? "")M"
        } else if value >= 1_000 {
            return "\(formatter.string(from: NSNumber(value: value / 1_000)) ?? "")K"
        } else {
            return formatter.string(from: NSNumber(value: value)) ?? "\(Int(value))"
        }
    }
}

