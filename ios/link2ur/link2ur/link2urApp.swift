//
//  link2urApp.swift
//  link2ur
//
//  Created by 千丈听松 on 2025/12/2.
//

import SwiftUI
import UIKit
import UserNotifications
import LinkU
import StripeCore
import CoreSpotlight

@main
struct link2urApp: App {
    // 使用 @StateObject 创建全局状态对象，确保生命周期跟随 App
    @StateObject private var appState = AppState()
    @StateObject private var appTheme = AppTheme.shared
    
    // 适配 AppDelegate 用于处理推送通知等
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState) // 注入全局状态
                .preferredColorScheme(appTheme.colorScheme) // 应用主题颜色方案
                .onAppear {
                    // 应用启动时的初始化操作
                    // 初始化 Stripe
                    StripeAPI.defaultPublishableKey = Constants.Stripe.publishableKey
                    
                    // 预热触觉反馈引擎，提高首次交互响应速度
                    HapticFeedback.prepareAll()
                    
                    // 索引快速操作到 Spotlight
                    SpotlightIndexer.shared.indexQuickActions()
                }
                .onOpenURL { url in
                    // 处理 Universal Links 和深度链接
                    // 必须将 URL 转给 Stripe SDK，否则支付宝/微信支付重定向返回后 PaymentSheet 无法完成流程
                    let stripeHandled = StripeAPI.handleURLCallback(with: url)
                    if stripeHandled {
                        return
                    }
                    
                    DeepLinkHandler.shared.handle(url)
                }
        }
    }
}

// AppDelegate 适配，用于处理远程推送等
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 配置推送通知
        UNUserNotificationCenter.current().delegate = self
        
        // 注意：不在这里请求通知权限，而是在视频播放完成后、进入app后再请求
        // 这样可以避免在启动视频播放时弹出权限请求对话框
        
        // 初始化微信和QQ SDK（如果已集成）
        #if canImport(WechatOpenSDK)
        // 注意：需要替换为实际的微信AppID和Universal Link
        // WXApi.registerApp("YOUR_WECHAT_APPID", universalLink: "https://yourdomain.com/wechat/")
        #endif
        
        // 强制 TabBar 使用不透明背景，避免从详情页返回或某些操作后整行背景消失、变透明
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor.systemBackground
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        return true
    }
    
    // MARK: - URL处理（Stripe 支付回调、微信、QQ）
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // 优先处理 Stripe 支付重定向（支付宝/微信支付等），否则 PaymentSheet 无法完成流程
        if StripeAPI.handleURLCallback(with: url) {
            return true
        }
        
        // 处理微信回调
        #if canImport(WechatOpenSDK)
        if WXApi.handleOpen(url, delegate: WeChatShareManager.shared) {
            return true
        }
        #endif
        
        // 处理QQ回调
        #if canImport(TencentOpenAPI)
        if TencentOAuth.handleOpen(url) {
            return true
        }
        #endif
        
        return false
    }
    
    // MARK: - Universal Link处理（微信）
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // 处理 Spotlight 搜索
        // 使用字符串常量（CSSearchableItemActionType 在某些 iOS 版本可能不可用）
        let spotlightActionType = "com.apple.corespotlightitem"
        let spotlightIdentifierKey = "kCSSearchableItemActivityIdentifier"
        
        if userActivity.activityType == spotlightActionType {
            if let identifier = userActivity.userInfo?[spotlightIdentifierKey] as? String {
                handleSpotlightSearch(identifier: identifier)
                return true
            }
        }
        
        // 处理Universal Link（微信）
        #if canImport(WechatOpenSDK)
        if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
           let url = userActivity.webpageURL,
           WXApi.handleOpenUniversalLink(userActivity, delegate: WeChatShareManager.shared) {
            return true
        }
        #endif
        
        return false
    }
    
    // 处理 Spotlight 搜索
    private func handleSpotlightSearch(identifier: String) {
        // 解析标识符并跳转
        if identifier.hasPrefix("task_") {
            let taskIdString = String(identifier.dropFirst(5))
            if let taskId = Int(taskIdString) {
                // 跳转到任务详情
                if let url = DeepLinkHandler.generateURL(for: .task(id: taskId)) {
                    DeepLinkHandler.shared.handle(url)
                }
                NotificationCenter.default.post(name: NSNotification.Name("NavigateToTask"), object: taskId)
            }
        } else if identifier.hasPrefix("expert_") {
            let userIdString = String(identifier.dropFirst(7))
            // 跳转到任务达人详情
            if let url = DeepLinkHandler.generateURL(for: .expert(id: userIdString)) {
                DeepLinkHandler.shared.handle(url)
            }
            NotificationCenter.default.post(name: NSNotification.Name("NavigateToExpert"), object: userIdString)
        } else if identifier.hasPrefix("quick_action_") {
            let actionId = String(identifier.dropFirst(14))
            // 处理快速操作
            handleQuickAction(actionId)
        }
    }
    
    // 处理快速操作（Spotlight 和 Shortcuts 共用）
    private func handleQuickAction(_ actionId: String) {
        NotificationCenter.default.post(name: NSNotification.Name("QuickAction"), object: actionId)
    }
    
    // 请求推送通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        // 使用 %02x 将每字节转为 2 位十六进制，确保生成 64 字符 (32 字节) 的标准 APNs 令牌
        let tokenParts = deviceToken.map { String(format: "%02x", $0) }
        let token = tokenParts.joined()
        // 保存到UserDefaults，以便在登录后发送
        UserDefaults.standard.set(token, forKey: "device_token")
        
        // 如果用户已登录，立即发送到后端
        if KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) != nil {
            APIService.shared.registerDeviceToken(token) { _ in }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    // 前台收到通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // 即使在前台也显示通知
        completionHandler([.banner, .sound, .badge])
    }
    
    // 用户点击通知时的处理
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        // 处理通知点击
        handleNotificationTap(userInfo: userInfo)
        
        completionHandler()
    }
    
    // 处理通知点击
    func handleNotificationTap(userInfo: [AnyHashable: Any]) {
        // 检查是否有通知类型
        guard userInfo["type"] != nil else {
            return
        }
        
        // 发送通知，让应用处理跳转
        NotificationCenter.default.post(
            name: NSNotification.Name("PushNotificationTapped"),
            object: nil,
            userInfo: userInfo
        )
    }
}
