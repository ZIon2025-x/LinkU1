import Foundation
import Combine
#if canImport(UIKit)
import UIKit
#endif
import AVFoundation
import Photos
import CoreLocation
import UserNotifications

/// 权限管理器 - 企业级权限管理
public class PermissionManager: ObservableObject {
    public static let shared = PermissionManager()
    
    @Published public var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published public var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @Published public var locationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var notificationStatus: UNAuthorizationStatus = .notDetermined
    
    private init() {
        updateAllStatuses()
    }
    
    /// 更新所有权限状态
    public func updateAllStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        locationStatus = CLLocationManager().authorizationStatus
        // 通知权限需要异步获取
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.notificationStatus = settings.authorizationStatus
            }
        }
    }
    
    /// 请求相机权限
    public func requestCameraPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                self?.cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
                completion(granted)
            }
        }
    }
    
    /// 请求相册权限
    public func requestPhotoLibraryPermission(completion: @escaping (Bool) -> Void) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { [weak self] status in
            DispatchQueue.main.async {
                self?.photoLibraryStatus = status
                completion(status == .authorized || status == .limited)
            }
        }
    }
    
    /// 请求位置权限
    public func requestLocationPermission(completion: @escaping (Bool) -> Void) {
        let manager = CLLocationManager()
        manager.requestWhenInUseAuthorization()
        // 注意：实际状态需要通过 CLLocationManagerDelegate 获取
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.locationStatus = manager.authorizationStatus
            completion(manager.authorizationStatus == .authorizedWhenInUse || 
                      manager.authorizationStatus == .authorizedAlways)
        }
    }
    
    /// 请求通知权限
    public func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    DispatchQueue.main.async {
                        self?.notificationStatus = settings.authorizationStatus
                        completion(granted)
                    }
                }
            }
        }
    }
    
    /// 检查所有权限状态
    public var allPermissionsGranted: Bool {
        return cameraStatus == .authorized &&
               (photoLibraryStatus == .authorized || photoLibraryStatus == .limited) &&
               (locationStatus == .authorizedWhenInUse || locationStatus == .authorizedAlways) &&
               notificationStatus == .authorized
    }
    
    /// 打开设置页面
    public func openSettings() {
        #if canImport(UIKit)
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

