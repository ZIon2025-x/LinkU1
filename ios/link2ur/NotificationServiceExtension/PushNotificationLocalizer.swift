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
        // 调试：打印 userInfo 的所有键
        print("[推送本地化] userInfo keys: \(userInfo.keys)")
        
        // 检查是否有本地化内容
        // APNs payload 结构：custom.localized
        // 注意：apns2 库会将 custom 字段直接放入 userInfo，所以结构是 userInfo["localized"]
        var localized: [String: [String: String]]?
        
        // 首先尝试从 custom.localized 读取（标准结构）
        if let custom = userInfo["custom"] as? [String: Any],
           let customLocalized = custom["localized"] as? [String: [String: String]] {
            localized = customLocalized
            print("[推送本地化] 从 custom.localized 读取本地化内容")
        }
        // 如果 custom.localized 不存在，尝试直接从 userInfo["localized"] 读取
        else if let directLocalized = userInfo["localized"] as? [String: [String: String]] {
            localized = directLocalized
            print("[推送本地化] 从 userInfo.localized 读取本地化内容")
        }
        // 如果都不存在，返回 nil
        else {
            print("[推送本地化] 未找到本地化内容，userInfo 结构: \(userInfo)")
            return nil
        }
        
        guard let localized = localized else {
            return nil
        }
        
        // 获取设备语言
        let language = deviceLanguage
        print("[推送本地化] 设备语言: \(language), 可用语言: \(Array(localized.keys))")
        
        // 获取对应语言的本地化内容
        guard let languageContent = localized[language] else {
            // 如果当前语言不存在，尝试使用英文作为后备
            print("[推送本地化] 当前语言 \(language) 不存在，尝试使用英文作为后备")
            guard let fallbackContent = localized["en"] else {
                print("[推送本地化] 英文后备也不存在")
                return nil
            }
            return (title: fallbackContent["title"] ?? "", body: fallbackContent["body"] ?? "")
        }
        
        print("[推送本地化] 成功获取 \(language) 语言内容: title=\(languageContent["title"] ?? ""), body=\(languageContent["body"] ?? "")")
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
