import Foundation

/// 时间格式化工具 - 企业级时间显示
public struct TimeFormatter {
    
    /// 格式化相对时间（如"2小时前"）
    public static func relativeTime(from date: Date, to referenceDate: Date = Date()) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date,
            to: referenceDate
        )
        
        if let year = components.year, year > 0 {
            return "\(year)年前"
        }
        if let month = components.month, month > 0 {
            return "\(month)个月前"
        }
        if let day = components.day, day > 0 {
            return "\(day)天前"
        }
        if let hour = components.hour, hour > 0 {
            return "\(hour)小时前"
        }
        if let minute = components.minute, minute > 0 {
            return "\(minute)分钟前"
        }
        if let second = components.second, second > 0 {
            return "\(second)秒前"
        }
        return "刚刚"
    }
    
    /// 格式化持续时间（如"2小时30分钟"）
    public static func duration(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return "\(hours)小时\(minutes)分钟"
        } else if minutes > 0 {
            return "\(minutes)分钟\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    /// 格式化日期时间
    public static func format(
        _ date: Date,
        format: String,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = locale
        formatter.timeZone = timeZone
        return formatter.string(from: date)
    }
    
    /// 格式化日期（短格式）
    public static func shortDate(_ date: Date) -> String {
        return format(date, format: "yyyy-MM-dd")
    }
    
    /// 格式化时间（短格式）
    public static func shortTime(_ date: Date) -> String {
        return format(date, format: "HH:mm")
    }
    
    /// 格式化日期时间（短格式）
    public static func shortDateTime(_ date: Date) -> String {
        return format(date, format: "yyyy-MM-dd HH:mm")
    }
    
    /// 格式化日期时间（长格式）
    public static func longDateTime(_ date: Date) -> String {
        return format(date, format: "yyyy年MM月dd日 HH:mm:ss")
    }
    
    /// 格式化周几
    public static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: date)
    }
}

