import Foundation
import UserNotifications

/// 推送通知本地化工具
/// 从推送通知的 payload 中提取本地化内容，根据设备语言选择显示
class PushNotificationLocalizer {
    
    /// 获取设备当前语言代码（简化版：en 或 zh）
    static var deviceLanguage: String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = preferredLanguage.components(separatedBy: "-").first ?? "en"
        
        // 如果是中文相关语言，统一返回 "zh"
        if languageCode.lowercased().hasPrefix("zh") {
            return "zh"
        }
        
        // 默认返回英文
        return "en"
    }
    
    /// 从推送通知的 userInfo 中提取本地化内容
    /// - Parameter userInfo: 推送通知的 userInfo 字典
    /// - Returns: (title, body) 本地化后的标题和内容，如果无法本地化则返回 nil
    static func getLocalizedContent(from userInfo: [AnyHashable: Any]) -> (title: String, body: String)? {
        // 检查是否有本地化内容
        // APNs payload 结构：custom.localized
        guard let custom = userInfo["custom"] as? [String: Any],
              let localized = custom["localized"] as? [String: [String: String]] else {
            // 如果没有本地化内容，返回 nil，使用系统默认的 alert
            return nil
        }
        
        // 获取设备语言
        let language = deviceLanguage
        
        // 获取对应语言的本地化内容
        guard let languageContent = localized[language] else {
            // 如果当前语言不存在，尝试使用英文作为后备
            guard let fallbackContent = localized["en"] else {
                return nil
            }
            return (title: fallbackContent["title"] ?? "", body: fallbackContent["body"] ?? "")
        }
        
        return (title: languageContent["title"] ?? "", body: languageContent["body"] ?? "")
    }
    
    /// 修改通知内容以使用本地化文本
    /// 注意：这个方法需要在 Notification Service Extension 中使用
    /// - Parameter request: 通知请求
    /// - Returns: 修改后的通知内容，如果无法本地化则返回原始内容
    static func localizeNotificationContent(_ request: UNNotificationRequest) -> UNMutableNotificationContent {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        
        // 获取本地化内容
        if let localized = getLocalizedContent(from: request.content.userInfo) {
            content.title = localized.title
            content.body = localized.body
        }
        
        // 保留其他信息
        content.userInfo = request.content.userInfo
        content.badge = request.content.badge
        content.sound = request.content.sound
        
        return content
    }
}
