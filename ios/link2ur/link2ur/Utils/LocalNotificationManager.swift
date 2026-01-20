import Foundation
import UserNotifications
import UIKit

/// 本地推送通知管理器
/// 用于在应用后台时发送本地推送通知
class LocalNotificationManager {
    static let shared = LocalNotificationManager()
    
    private init() {}
    
    /// 发送消息推送通知
    /// - Parameters:
    ///   - title: 通知标题（发送者名称）
    ///   - body: 通知内容（消息内容）
    ///   - messageId: 消息ID
    ///   - senderId: 发送者ID
    ///   - taskId: 任务ID（如果是任务聊天）
    ///   - partnerId: 对方用户ID（如果是私信）
    func sendMessageNotification(
        title: String,
        body: String,
        messageId: String,
        senderId: String? = nil,
        taskId: Int? = nil,
        partnerId: String? = nil
    ) {
        // 检查通知权限
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else {
                print("⚠️ 推送通知权限未授予，无法发送本地推送")
                return
            }
            
            // 创建通知内容
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.badge = NSNumber(value: UIApplication.shared.applicationIconBadgeNumber + 1)
            
            // 添加自定义数据，用于点击通知时跳转
            var userInfo: [AnyHashable: Any] = [
                "type": "message",
                "message_id": messageId
            ]
            
            if let taskId = taskId {
                userInfo["task_id"] = taskId
                userInfo["notification_type"] = "task_message"
            } else if let partnerId = partnerId {
                userInfo["partner_id"] = partnerId
                userInfo["notification_type"] = "private_message"
            }
            
            if let senderId = senderId {
                userInfo["sender_id"] = senderId
            }
            
            content.userInfo = userInfo
            
            // 创建通知请求
            let identifier = "message_\(messageId)_\(Date().timeIntervalSince1970)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            
            // 发送通知
            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    print("❌ 发送本地推送通知失败: \(error.localizedDescription)")
                } else {
                    print("✅ 已发送本地推送通知: \(title) - \(body)")
                }
            }
        }
    }
    
    /// 检查应用是否在后台
    func isAppInBackground() -> Bool {
        return UIApplication.shared.applicationState != .active
    }
}
