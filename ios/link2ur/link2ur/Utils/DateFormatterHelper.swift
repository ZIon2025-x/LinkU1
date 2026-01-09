import Foundation

class DateFormatterHelper {
    static let shared = DateFormatterHelper()
    
    private let isoFormatter: ISO8601DateFormatter
    private let displayFormatter: DateFormatter
    
    private init() {
        // ISO8601 解析器：明确指定 UTC 时区，因为数据库存储的是 UTC 时间
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        isoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        
        // 显示格式化器：使用用户本地时区和系统 locale
        displayFormatter = DateFormatter()
        displayFormatter.locale = Locale.current // 使用用户系统 locale（根据 iOS 设置）
        displayFormatter.timeZone = TimeZone.current // 使用用户本地时区（根据 iOS 设置或位置信息）
    }
    
    func formatTime(_ timeString: String) -> String {
        guard let date = parseDate(timeString) else {
            return "刚刚"
        }
        
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        // 小于1分钟
        if timeInterval < 60 {
            return "刚刚"
        }
        
        // 小于1小时
        if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分钟前"
        }
        
        // 小于24小时
        if timeInterval < 86400 {
            let hours = Int(timeInterval / 3600)
            return "\(hours)小时前"
        }
        
        // 小于7天
        if timeInterval < 604800 {
            let days = Int(timeInterval / 86400)
            return "\(days)天前"
        }
        
        // 超过7天，显示具体日期
        // 使用系统 locale 的日期格式
        let calendar = Calendar.current
        let userLocale = Locale.current
        
        // 根据用户 locale 选择合适的日期格式
        if userLocale.identifier.hasPrefix("zh") {
            // 中文格式
            displayFormatter.dateFormat = "MM月dd日"
            if calendar.component(.year, from: date) != calendar.component(.year, from: now) {
                displayFormatter.dateFormat = "yyyy年MM月dd日"
            }
        } else {
            // 英文或其他语言格式 - 使用系统默认格式
            displayFormatter.dateStyle = .medium
            displayFormatter.timeStyle = .none
        }
        return displayFormatter.string(from: date)
    }
    
    func formatFullTime(_ timeString: String) -> String {
        guard let date = parseDate(timeString) else {
            return ""
        }
        
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
    
    /// 格式化日期时间（短格式，包含日期和时间）
    /// 使用用户本地时区和系统 locale
    func formatShortDateTime(_ timeString: String) -> String {
        guard let date = parseDate(timeString) else {
            return timeString
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.locale = Locale.current // 使用用户系统 locale
        formatter.timeZone = TimeZone.current // 使用用户本地时区
        return formatter.string(from: date)
    }
    
    /// 解析日期字符串（公开方法）
    /// 从 UTC 时区解析，返回 Date 对象
    func parseDatePublic(_ dateString: String) -> Date? {
        return parseDate(dateString)
    }
    
    func formatDeadline(_ deadlineString: String) -> String {
        guard let deadline = parseDate(deadlineString) else {
            return "截止时间未知"
        }
        
        let now = Date()
        let timeInterval = deadline.timeIntervalSince(now)
        
        // 已过期
        if timeInterval <= 0 {
            return "已过期"
        }
        
        let totalMinutes = Int(timeInterval / 60)
        let days = totalMinutes / (24 * 60)
        let hours = (totalMinutes % (24 * 60)) / 60
        let minutes = totalMinutes % 60
        
        // 超过30天
        if days >= 30 {
            let months = days / 30
            let remainingDays = days % 30
            if remainingDays > 0 {
                return "\(months)个月 · \(remainingDays)天"
            }
            return "\(months)个月"
        }
        // 1-30天
        else if days > 0 {
            if hours > 0 {
                return "\(days)天 · \(hours)小时"
            }
            return "\(days)天"
        }
        // 小于1天但大于1小时
        else if hours > 0 {
            if minutes > 0 {
                return "\(hours)小时 · \(minutes)分钟"
            }
            return "\(hours)小时"
        }
        // 小于1小时
        else {
            return "\(minutes)分钟"
        }
    }
    
    func isExpired(_ deadlineString: String) -> Bool {
        guard let deadline = parseDate(deadlineString) else { return false }
        return deadline <= Date()
    }
    
    func isExpiringSoon(_ deadlineString: String) -> Bool {
        guard let deadline = parseDate(deadlineString) else { return false }
        let twoHoursLater = Date().addingTimeInterval(2 * 60 * 60)
        return Date() < deadline && deadline < twoHoursLater
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        // 先尝试 ISO8601 (带小数秒) - 使用 UTC 时区解析
        if let date = isoFormatter.date(from: dateString) {
            return date
        }
        
        // 尝试 ISO8601 (不带小数秒) - 使用 UTC 时区解析
        let standardIsoFormatter = ISO8601DateFormatter()
        standardIsoFormatter.formatOptions = [.withInternetDateTime]
        standardIsoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        if let date = standardIsoFormatter.date(from: dateString) {
            return date
        }
        
        // 尝试多种日期格式 - 所有解析都使用 UTC 时区（因为数据库存储的是 UTC）
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'", // Python datetime default (带 Z 表示 UTC)
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",     // 不带 Z，但假设是 UTC
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",            // 不带 Z，但假设是 UTC
            "yyyy-MM-dd'T'HH:mm",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy-MM-dd",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "yyyy/MM/dd"
        ]
        
        // 解析时使用 UTC 时区（数据库存储的是 UTC）
        let utcTimeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
        let parserFormatter = DateFormatter()
        parserFormatter.locale = Locale(identifier: "en_US_POSIX")
        parserFormatter.timeZone = utcTimeZone
        
        for format in formats {
            parserFormatter.dateFormat = format
            if let date = parserFormatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
}

// MARK: - 数字格式化工具
extension Int {
    /// 格式化数字显示（用于浏览量、点赞数等）
    /// - 小于1000：返回纯数字，如 "38"
    /// - 1000及以上：返回 k 格式，如 "1.2k", "1k"
    /// - 10000及以上：返回万格式，如 "1.2万", "1万"
    /// - 100000及以上：返回 "10万+" 格式
    /// - 负数：返回 "0"（确保不显示负数）
    func formatCount() -> String {
        // 处理负数：如果为负数，返回 "0"
        if self < 0 {
            return "0"
        }
        
        if self < 1000 {
            return "\(self)"
        } else if self < 10000 {
            let k = Double(self) / 1000.0
            // 如果是整数，不显示小数
            if k.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(k))k"
            } else {
                // 保留一位小数
                return String(format: "%.1fk", k)
            }
        } else if self < 100000 {
            let wan = Double(self) / 10000.0
            // 如果是整数，不显示小数
            if wan.truncatingRemainder(dividingBy: 1) == 0 {
                return "\(Int(wan))万"
            } else {
                // 保留一位小数
                return String(format: "%.1f万", wan)
            }
        } else {
            // 10万及以上显示为 "10万+"
            let wan = self / 10000
            return "\(wan)万+"
        }
    }
}
