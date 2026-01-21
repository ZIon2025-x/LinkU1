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
            return LocalizationKey.timeYearsAgo.localized(argument: year)
        }
        if let month = components.month, month > 0 {
            return LocalizationKey.timeMonthsAgo.localized(argument: month)
        }
        if let day = components.day, day > 0 {
            return LocalizationKey.timeDaysAgo.localized(argument: day)
        }
        if let hour = components.hour, hour > 0 {
            return LocalizationKey.timeHoursAgo.localized(argument: hour)
        }
        if let minute = components.minute, minute > 0 {
            return LocalizationKey.timeMinutesAgo.localized(argument: minute)
        }
        if let second = components.second, second > 0 {
            return LocalizationKey.timeSecondsAgo.localized(argument: second)
        }
        return LocalizationKey.timeJustNow.localized
    }
    
    /// 格式化持续时间（如"2小时30分钟"）
    public static func duration(_ timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        let seconds = Int(timeInterval) % 60
        
        if hours > 0 {
            return String(format: LocalizationKey.timeDurationHoursMinutes.localized, hours, minutes)
        } else if minutes > 0 {
            return String(format: LocalizationKey.timeDurationMinutesSeconds.localized, minutes, seconds)
        } else {
            return String(format: LocalizationKey.timeDurationSeconds.localized, seconds)
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
        // 使用系统 locale 的日期格式
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeZone = TimeZone.current
        formatter.dateStyle = .long
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    /// 格式化周几
    public static func weekday(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        formatter.locale = Locale.current // 使用用户系统 locale
        formatter.timeZone = TimeZone.current // 使用用户本地时区
        return formatter.string(from: date)
    }
}

