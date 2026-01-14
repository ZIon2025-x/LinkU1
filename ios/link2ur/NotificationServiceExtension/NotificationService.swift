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
        
        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }
        
        // 使用 PushNotificationLocalizer 获取本地化内容
        let localizedContent = PushNotificationLocalizer.localizeNotificationContent(request)
        
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
