//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  推送通知本地化服务
//  根据设备系统语言从推送 payload 中选择对应语言的文本显示
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {

    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
        
        // 调试：打印原始通知内容
        print("🔔 [NotificationService] 收到推送通知")
        print("🔔 [NotificationService] 原始标题: \(request.content.title)")
        print("🔔 [NotificationService] 原始内容: \(request.content.body)")
        print("🔔 [NotificationService] userInfo keys: \(request.content.userInfo.keys)")
        
        guard let bestAttemptContent = bestAttemptContent else {
            print("⚠️ [NotificationService] 无法创建 mutable content，使用原始内容")
            contentHandler(request.content)
            return
        }
        
        // 使用 PushNotificationLocalizer 获取本地化内容
        let localizedContent = PushNotificationLocalizer.localizeNotificationContent(request)
        
        // 调试：打印本地化后的内容
        print("🔔 [NotificationService] 本地化后标题: \(localizedContent.title)")
        print("🔔 [NotificationService] 本地化后内容: \(localizedContent.body)")
        
        // 返回修改后的内容
        contentHandler(localizedContent)
    }
    
    override func serviceExtensionTimeWillExpire() {
        // 如果处理超时，使用原始内容（系统会在 30 秒后终止 Extension）
        if let contentHandler = contentHandler, let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }

}
