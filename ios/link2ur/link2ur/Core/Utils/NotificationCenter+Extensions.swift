import Foundation
import Combine

/// NotificationCenter 扩展 - 企业级通知管理
extension NotificationCenter {
    
    /// 发布通知（便捷方法）
    public func post(name: Notification.Name, object: Any? = nil, userInfo: [AnyHashable: Any]? = nil) {
        post(Notification(name: name, object: object, userInfo: userInfo))
    }
    
}

/// 通知名称扩展 - 统一管理通知名称
extension Notification.Name {
    // 用户相关（避免与 Utils/Notifications.swift 重复）
    public static let userDidUpdate = Notification.Name("userDidUpdate")
    
    // 网络相关
    public static let networkDidConnect = Notification.Name("networkDidConnect")
    public static let networkDidDisconnect = Notification.Name("networkDidDisconnect")
    
    // 应用生命周期
    public static let appDidBecomeActive = Notification.Name("appDidBecomeActive")
    public static let appWillResignActive = Notification.Name("appWillResignActive")
    public static let appDidEnterBackground = Notification.Name("appDidEnterBackground")
    public static let appWillEnterForeground = Notification.Name("appWillEnterForeground")
    
    // 数据更新
    public static let dataDidUpdate = Notification.Name("dataDidUpdate")
    public static let cacheDidUpdate = Notification.Name("cacheDidUpdate")
    
    // 论坛相关
    public static let forumPostUpdated = Notification.Name("forumPostUpdated")
    public static let forumPostLiked = Notification.Name("forumPostLiked")
    public static let forumPostFavorited = Notification.Name("forumPostFavorited")
    
    // 错误处理（避免与 ErrorHandler.swift 重复）
    public static let errorDidOccur = Notification.Name("errorDidOccur")
}

