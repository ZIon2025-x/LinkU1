import Foundation
import UIKit
import UserNotifications

/// 应用图标 Badge 管理器
/// 用于在应用图标上显示未读消息和通知数量
public class BadgeManager {
    public static let shared = BadgeManager()
    
    private init() {}
    
    /// 更新应用图标 Badge 数量
    /// - Parameter count: 未读消息和通知的总数
    public func updateBadge(count: Int) {
        DispatchQueue.main.async {
            // 检查通知权限是否包含 badge
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                DispatchQueue.main.async {
                    // 只有在授权且包含 badge 权限时才更新
                    if settings.authorizationStatus == .authorized {
                        // 设置应用图标 Badge 数量
                        // iOS 会自动处理超过 99 的情况（显示 "99+"）
                        UIApplication.shared.applicationIconBadgeNumber = count
                        print("📱 [BadgeManager] 应用图标 Badge 已更新: \(count)")
                    } else {
                        // 如果没有权限，清除 Badge
                        UIApplication.shared.applicationIconBadgeNumber = 0
                        print("📱 [BadgeManager] 通知权限未授权，清除应用图标 Badge")
                    }
                }
            }
        }
    }
    
    /// 清除应用图标 Badge
    public func clearBadge() {
        DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            print("📱 [BadgeManager] 应用图标 Badge 已清除")
        }
    }
    
    /// 获取当前 Badge 数量
    public var currentBadgeCount: Int {
        return UIApplication.shared.applicationIconBadgeNumber
    }
}
