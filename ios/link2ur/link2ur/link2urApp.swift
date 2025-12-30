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
        }
    }
}

// AppDelegate 适配，用于处理远程推送等
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // 配置推送通知
        UNUserNotificationCenter.current().delegate = self
        return true
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
}
