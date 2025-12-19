import Foundation

/// Date 扩展 - 提供企业级日期处理工具

extension Date {
    
    // MARK: - 格式化
    
    /// 格式化为字符串
    func formatted(
        format: String,
        locale: Locale = .current,
        timeZone: TimeZone = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = locale
        formatter.timeZone = timeZone
        return formatter.string(from: self)
    }
    
    /// 相对时间描述（如"2小时前"）
    var relativeDescription: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: self,
            to: now
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
    
    /// 是否是今天
    var isToday: Bool {
        return Calendar.current.isDateInToday(self)
    }
    
    /// 是否是昨天
    var isYesterday: Bool {
        return Calendar.current.isDateInYesterday(self)
    }
    
    /// 是否是明天
    var isTomorrow: Bool {
        return Calendar.current.isDateInTomorrow(self)
    }
    
    /// 是否是本周
    var isThisWeek: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// 是否是本月
    var isThisMonth: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    /// 是否是今年
    var isThisYear: Bool {
        return Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    // MARK: - 计算
    
    /// 添加时间间隔
    func adding(_ component: Calendar.Component, value: Int) -> Date? {
        return Calendar.current.date(byAdding: component, value: value, to: self)
    }
    
    /// 开始时间（当天 00:00:00）
    var startOfDay: Date {
        return Calendar.current.startOfDay(for: self)
    }
    
    /// 结束时间（当天 23:59:59）
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    /// 开始时间（本周）
    var startOfWeek: Date? {
        return Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self))
    }
    
    /// 开始时间（本月）
    var startOfMonth: Date? {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components)
    }
    
    /// 开始时间（今年）
    var startOfYear: Date? {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components)
    }
    
    // MARK: - 比较
    
    /// 距离现在的时间间隔（秒）
    var timeIntervalSinceNow: TimeInterval {
        return self.timeIntervalSince(Date())
    }
    
    /// 是否是过去
    var isPast: Bool {
        return self < Date()
    }
    
    /// 是否是未来
    var isFuture: Bool {
        return self > Date()
    }
    
    /// 年龄（年）
    var age: Int? {
        return Calendar.current.dateComponents([.year], from: self, to: Date()).year
    }
    
    // MARK: - 时间戳
    
    /// Unix 时间戳（秒）
    var unixTimestamp: TimeInterval {
        return self.timeIntervalSince1970
    }
    
    /// Unix 时间戳（毫秒）
    var unixTimestampMilliseconds: Int64 {
        return Int64(self.timeIntervalSince1970 * 1000)
    }
    
    /// 从 Unix 时间戳创建
    static func fromUnixTimestamp(_ timestamp: TimeInterval) -> Date {
        return Date(timeIntervalSince1970: timestamp)
    }
    
    /// 从 Unix 时间戳（毫秒）创建
    static func fromUnixTimestampMilliseconds(_ timestamp: Int64) -> Date {
        return Date(timeIntervalSince1970: TimeInterval(timestamp) / 1000.0)
    }
}

// MARK: - 日期范围

extension Date {
    /// 创建日期范围
    static func range(from startDate: Date, to endDate: Date) -> ClosedRange<Date> {
        return startDate...endDate
    }
    
    /// 是否在日期范围内
    func isBetween(_ startDate: Date, and endDate: Date) -> Bool {
        return self >= startDate && self <= endDate
    }
}

