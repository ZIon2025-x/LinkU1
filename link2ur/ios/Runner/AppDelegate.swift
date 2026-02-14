import Flutter
import UIKit
import UserNotifications
import SwiftUI

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

  /// MethodChannel 用于与 Dart 层通信推送事件
  private var pushChannel: FlutterMethodChannel?

  /// MethodChannel 用于 App 角标管理
  private var badgeChannel: FlutterMethodChannel?

  /// MethodChannel 用于原生地图选点
  private var locationPickerChannel: FlutterMethodChannel?

  /// MethodChannel 用于 Stripe Connect Onboarding
  private var stripeConnectChannel: FlutterMethodChannel?
  private var stripeConnectHandler = StripeConnectOnboardingHandler()

  /// 缓存的 APNs device token（hex 格式）
  private var cachedDeviceToken: String?

  // MARK: - FlutterImplicitEngineDelegate（UIScene 生命周期下在此创建 channel，避免在 didFinishLaunching 访问 window 导致崩溃）

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    let messenger = engineBridge.applicationRegistrar.messenger()

    // 推送通知 channel
    pushChannel = FlutterMethodChannel(name: "com.link2ur/push", binaryMessenger: messenger)
    pushChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "getDeviceToken":
        result(self?.cachedDeviceToken)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    // 角标管理 channel
    badgeChannel = FlutterMethodChannel(name: "com.link2ur/badge", binaryMessenger: messenger)
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
    locationPickerChannel = FlutterMethodChannel(name: "com.link2ur/location_picker", binaryMessenger: messenger)
    locationPickerChannel?.setMethodCallHandler { [weak self] call, channelResult in
      switch call.method {
      case "openLocationPicker":
        self?.openLocationPicker(arguments: call.arguments as? [String: Any], result: channelResult)
      default:
        channelResult(FlutterMethodNotImplemented)
      }
    }

    // Stripe Connect channel（present 时通过 currentFlutterViewController() 获取 VC）
    stripeConnectChannel = FlutterMethodChannel(name: "com.link2ur/stripe_connect", binaryMessenger: messenger)
    stripeConnectChannel?.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "openOnboarding":
        guard let self = self,
              let args = call.arguments as? [String: Any],
              let publishableKey = args["publishableKey"] as? String,
              let clientSecret = args["clientSecret"] as? String else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing publishableKey or clientSecret", details: nil))
          return
        }
        guard let controller = self.currentFlutterViewController() else {
          result(FlutterError(code: "NO_VC", message: "No Flutter view controller", details: nil))
          return
        }
        self.stripeConnectHandler.openOnboarding(
          publishableKey: publishableKey,
          clientSecret: clientSecret,
          from: controller,
          result: result
        )
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 插件注册已移至 didInitializeImplicitFlutterEngine；此处仅保留进程级与推送配置
    UNUserNotificationCenter.current().delegate = self
    application.registerForRemoteNotifications()

    if let notification = launchOptions?[.remoteNotification] as? [String: Any] {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
        self?.pushChannel?.invokeMethod("onNotificationTapped", arguments: notification)
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// 当前用于 present 的 Flutter VC（兼容 UIScene：优先 delegate.window，否则取 keyWindow）
  private func currentFlutterViewController() -> FlutterViewController? {
    if let vc = window?.rootViewController as? FlutterViewController { return vc }
    if #available(iOS 15.0, *) {
      return UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first { $0.isKeyWindow }?
        .rootViewController as? FlutterViewController
    }
    return UIApplication.shared.windows.first { $0.isKeyWindow }?.rootViewController as? FlutterViewController
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
    guard let controller = currentFlutterViewController() else {
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
