import Foundation

class DateFormatterHelper {
    static let shared = DateFormatterHelper()
    
    private let isoFormatter: ISO8601DateFormatter
    private let displayFormatter: DateFormatter
    
    private init() {
        isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        displayFormatter = DateFormatter()
        displayFormatter.locale = Locale(identifier: "zh_CN")
    }
    
    func formatTime(_ timeString: String) -> String {
        guard let date = isoFormatter.date(from: timeString) ?? parseDate(timeString) else {
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
        displayFormatter.dateFormat = "MM月dd日"
        if Calendar.current.component(.year, from: date) != Calendar.current.component(.year, from: now) {
            displayFormatter.dateFormat = "yyyy年MM月dd日"
        }
        return displayFormatter.string(from: date)
    }
    
    func formatFullTime(_ timeString: String) -> String {
        guard let date = isoFormatter.date(from: timeString) ?? parseDate(timeString) else {
            return ""
        }
        
        displayFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        return displayFormatter.string(from: date)
    }
    
    private func parseDate(_ timeString: String) -> Date? {
        // 尝试多种日期格式
        let formats = [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss"
        ]
        
        for format in formats {
            displayFormatter.dateFormat = format
            if let date = displayFormatter.date(from: timeString) {
                return date
            }
        }
        
        return nil
    }
}

