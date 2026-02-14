//
//  PushNotificationLocalizer.swift
//  NotificationServiceExtension
//

import Foundation
import UserNotifications

/// 推送通知本地化工具
/// 从推送通知的 payload 中提取本地化内容，根据设备语言选择显示
class PushNotificationLocalizer {
    
    static var deviceLanguage: String {
        let preferredLanguage = Locale.preferredLanguages.first ?? "en"
        let languageCode = preferredLanguage.components(separatedBy: "-").first ?? "en"
        if languageCode.lowercased().hasPrefix("zh") {
            return "zh"
        }
        return "en"
    }
    
    static func getLocalizedContent(from userInfo: [AnyHashable: Any]) -> (title: String, body: String)? {
        var localized: [String: [String: String]]?
        
        if let custom = userInfo["custom"] as? [String: Any],
           let customLocalized = custom["localized"] as? [String: [String: String]] {
            localized = customLocalized
        } else if let directLocalized = userInfo["localized"] as? [String: [String: String]] {
            localized = directLocalized
        } else {
            return nil
        }
        
        guard let localized = localized else { return nil }
        
        let language = deviceLanguage
        guard let languageContent = localized[language] else {
            guard let fallbackContent = localized["en"] else { return nil }
            return (title: fallbackContent["title"] ?? "", body: fallbackContent["body"] ?? "")
        }
        return (title: languageContent["title"] ?? "", body: languageContent["body"] ?? "")
    }
    
    static func localizeNotificationContent(_ request: UNNotificationRequest) -> UNMutableNotificationContent {
        let content = (request.content.mutableCopy() as? UNMutableNotificationContent) ?? UNMutableNotificationContent()
        
        if let localized = getLocalizedContent(from: request.content.userInfo) {
            content.title = localized.title
            content.body = localized.body
        }
        
        content.userInfo = request.content.userInfo
        content.badge = request.content.badge
        content.sound = request.content.sound
        
        return content
    }
}
