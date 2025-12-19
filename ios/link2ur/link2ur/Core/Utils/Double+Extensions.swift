import Foundation

/// Double 扩展 - 企业级浮点数工具
extension Double {
    
    /// 格式化货币
    public func currency(currencyCode: String = "GBP", locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currencyCode
        formatter.locale = locale
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// 格式化百分比
    public func percentage(decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)%"
    }
    
    /// 格式化数字（带小数位）
    public func formatted(decimalPlaces: Int = 2) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = decimalPlaces
        formatter.maximumFractionDigits = decimalPlaces
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// 四舍五入到指定小数位
    public func rounded(to places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
    
    /// 转换为 Int
    public var int: Int {
        return Int(self)
    }
    
    /// 转换为 CGFloat
    public var cgFloat: CGFloat {
        return CGFloat(self)
    }
    
    /// 转换为时间间隔字符串
    public var timeInterval: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
}

