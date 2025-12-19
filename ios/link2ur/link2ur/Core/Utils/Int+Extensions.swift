import Foundation

/// Int 扩展 - 企业级整数工具
extension Int {
    
    /// 格式化文件大小
    public var fileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(self))
    }
    
    /// 格式化距离（米）
    public var distance: String {
        if self < 1000 {
            return "\(self)米"
        } else {
            return String(format: "%.2f公里", Double(self) / 1000.0)
        }
    }
    
    /// 格式化时间间隔（秒）
    public var timeInterval: String {
        let hours = self / 3600
        let minutes = (self % 3600) / 60
        let seconds = self % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    /// 格式化数字（带千位分隔符）
    public var formatted: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// 大数字缩写（1.2K, 1.5M）
    public var abbreviated: String {
        if self >= 1_000_000_000 {
            return String(format: "%.1fB", Double(self) / 1_000_000_000.0)
        } else if self >= 1_000_000 {
            return String(format: "%.1fM", Double(self) / 1_000_000.0)
        } else if self >= 1_000 {
            return String(format: "%.1fK", Double(self) / 1_000.0)
        } else {
            return "\(self)"
        }
    }
    
    /// 转换为 Double
    public var double: Double {
        return Double(self)
    }
    
    /// 转换为 CGFloat
    public var cgFloat: CGFloat {
        return CGFloat(self)
    }
}

