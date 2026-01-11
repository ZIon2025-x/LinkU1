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
                    print("Link²Ur App Started")
                    
                    // 初始化 Stripe
                    StripeAPI.defaultPublishableKey = Constants.Stripe.publishableKey
                }
                .onOpenURL { url in
                    // 处理Universal Links和深度链接
                    print("🔗 [App] 收到URL: \(url.absoluteString)")
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
        
        return true
    }
    
    // 请求推送通知权限
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("推送通知权限请求失败: \(error)")
            } else if granted {
                print("推送通知权限已授予")
                // 权限授予后，注册远程推送
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("推送通知权限被拒绝")
            }
        }
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("Device Token: \(token)")
        
        // 保存到UserDefaults，以便在登录后发送
        UserDefaults.standard.set(token, forKey: "device_token")
        
        // 如果用户已登录，立即发送到后端
        if KeychainHelper.shared.read(service: Constants.Keychain.service, account: Constants.Keychain.accessTokenKey) != nil {
            APIService.shared.registerDeviceToken(token) { success in
                if success {
                    print("Device token sent to backend successfully")
                }
            }
        }
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
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
