import Flutter
import UIKit
import UserNotifications
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate {

  /// MethodChannel 用于与 Dart 层通信推送事件
  private var pushChannel: FlutterMethodChannel?

  /// MethodChannel 用于 App 角标管理
  private var badgeChannel: FlutterMethodChannel?

  /// MethodChannel 用于原生地图选点
  private var locationPickerChannel: FlutterMethodChannel?

  /// 缓存的 APNs device token（hex 格式）
  private var cachedDeviceToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // 设置 MethodChannels
    if let controller = window?.rootViewController as? FlutterViewController {
      // 推送通知 channel
      pushChannel = FlutterMethodChannel(
        name: "com.link2ur/push",
        binaryMessenger: controller.binaryMessenger
      )
      pushChannel?.setMethodCallHandler { [weak self] call, result in
        switch call.method {
        case "getDeviceToken":
          result(self?.cachedDeviceToken)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // 角标管理 channel
      badgeChannel = FlutterMethodChannel(
        name: "com.link2ur/badge",
        binaryMessenger: controller.binaryMessenger
      )
      badgeChannel?.setMethodCallHandler { call, result in
        switch call.method {
        case "updateBadge":
          let count = call.arguments as? Int ?? 0
          UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
              if settings.authorizationStatus == .authorized {
                UIApplication.shared.applicationIconBadgeNumber = count
              }
              result(nil)
            }
          }
        case "clearBadge":
          DispatchQueue.main.async {
            UIApplication.shared.applicationIconBadgeNumber = 0
            result(nil)
          }
        case "getBadgeCount":
          result(UIApplication.shared.applicationIconBadgeNumber)
        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // 地图选点 channel
      locationPickerChannel = FlutterMethodChannel(
        name: "com.link2ur/location_picker",
        binaryMessenger: controller.binaryMessenger
      )
      locationPickerChannel?.setMethodCallHandler { [weak self] call, channelResult in
        switch call.method {
        case "openLocationPicker":
          self?.openLocationPicker(arguments: call.arguments as? [String: Any], result: channelResult)
        default:
          channelResult(FlutterMethodNotImplemented)
        }
      }
    }

    // 注册远程推送
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    // 检查 app 是否从通知冷启动
    if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
      // 延迟处理，等待 Flutter engine 就绪
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.pushChannel?.invokeMethod("onNotificationTapped", arguments: notification)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // MARK: - APNs Token

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // 转换 token 为 hex 字符串（与原生项目一致）
    let tokenString = deviceToken.map { String(format: "%02x", $0) }.joined()
    cachedDeviceToken = tokenString

    // 保存到 UserDefaults（与原生项目共享）
    UserDefaults.standard.set(tokenString, forKey: "device_token")

    // 发送给 Dart 层
    pushChannel?.invokeMethod("onTokenRefresh", arguments: tokenString)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    print("APNs registration failed: \(error.localizedDescription)")
  }

  // MARK: - UNUserNotificationCenterDelegate

  /// 前台收到通知 —— 显示 banner + sound + badge
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification,
    withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
  ) {
    let userInfo = notification.request.content.userInfo

    // 通知 Dart 层收到前台消息
    var messageData: [String: Any] = [:]
    messageData["title"] = notification.request.content.title
    messageData["body"] = notification.request.content.body

    // 合并 userInfo 中的自定义数据
    for (key, value) in userInfo {
      if let key = key as? String {
        messageData[key] = value
      }
    }

    pushChannel?.invokeMethod("onRemoteMessage", arguments: messageData)

    // 显示系统通知（banner、声音、角标）
    if #available(iOS 14.0, *) {
      completionHandler([.banner, .sound, .badge])
    } else {
      completionHandler([.alert, .sound, .badge])
    }
  }

  /// 用户点击通知
  override func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completionHandler: @escaping () -> Void
  ) {
    let userInfo = response.notification.request.content.userInfo

    var data: [String: Any] = [:]
    for (key, value) in userInfo {
      if let key = key as? String {
        data[key] = value
      }
    }

    pushChannel?.invokeMethod("onNotificationTapped", arguments: data)

    completionHandler()
  }

  // MARK: - Location Picker

  /// 打开原生 MapKit 地图选点页面
  private func openLocationPicker(arguments: [String: Any]?, result: @escaping FlutterResult) {
    guard let controller = window?.rootViewController else {
      result(nil)
      return
    }

    let initialLat = arguments?["initialLatitude"] as? Double
    let initialLng = arguments?["initialLongitude"] as? Double
    let initialAddr = arguments?["initialAddress"] as? String

    let pickerView = LocationPickerView(
      onComplete: { address, latitude, longitude in
        // 关闭选点页面
        controller.dismiss(animated: true) {
          // 返回结果给 Flutter
          result([
            "address": address,
            "latitude": latitude,
            "longitude": longitude
          ])
        }
      },
      onCancel: {
        controller.dismiss(animated: true) {
          result(nil)
        }
      },
      initialAddress: initialAddr,
      initialLatitude: initialLat,
      initialLongitude: initialLng
    )

    let hostingController = UIHostingController(rootView: pickerView)
    hostingController.modalPresentationStyle = .fullScreen
    controller.present(hostingController, animated: true)
  }
}
