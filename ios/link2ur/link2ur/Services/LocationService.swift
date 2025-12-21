//
//  LocationService.swift
//  link2ur
//
//  Created for location management
//

import Foundation
import CoreLocation
import Combine

/// 位置信息模型
public struct LocationInfo: Codable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public let timestamp: Date
    public var cityName: String?  // 城市名称（通过反向地理编码获取）
    
    public init(latitude: Double, longitude: Double, timestamp: Date = Date(), cityName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.cityName = cityName
    }
}

/// 位置服务管理器
public class LocationService: NSObject, ObservableObject {
    public static let shared = LocationService()
    
    @Published public var currentLocation: LocationInfo?
    @Published public var currentCityName: String?  // 当前城市名称
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var locationError: Error?
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()  // 用于反向地理编码
    private var cancellables = Set<AnyCancellable>()
    
    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 100 // 位置变化超过100米才更新
        
        // 监听授权状态变化
        authorizationStatus = locationManager.authorizationStatus
    }
    
    /// 请求位置权限（协议方法）
    public func requestLocationAuthorization() {
        requestAuthorization()
    }
    
    /// 请求位置权限
    public func requestAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            // 权限被拒绝，静默处理（用户已知）
            // 不打印错误，避免不必要的日志
            break
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        @unknown default:
            break
        }
    }
    
    /// 开始更新位置
    public func startUpdatingLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        
        locationError = nil
        locationManager.startUpdatingLocation()
    }
    
    /// 停止更新位置
    public func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }
    
    /// 获取一次位置（不持续更新）
    public func requestLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        
        locationError = nil
        locationManager.requestLocation()
    }
    
    /// 检查位置权限是否已授权
    public var isAuthorized: Bool {
        return locationManager.authorizationStatus == .authorizedWhenInUse || 
               locationManager.authorizationStatus == .authorizedAlways
    }
    
    /// 应用支持的城市列表（与TaskFilterView保持一致）
    private let supportedCities = ["Online", "London", "Edinburgh", "Manchester", "Birmingham", "Glasgow", "Bristol", "Sheffield", "Leeds", "Nottingham", "Newcastle", "Southampton", "Liverpool", "Cardiff", "Coventry", "Exeter", "Leicester", "York", "Aberdeen", "Bath", "Dundee", "Reading", "St Andrews", "Belfast", "Brighton", "Durham", "Norwich", "Swansea", "Loughborough", "Lancaster", "Warwick", "Cambridge", "Oxford", "Other"]
    
    /// 将获取到的城市名称匹配到应用支持的城市列表
    private func matchCityName(_ cityName: String) -> String? {
        // 精确匹配
        if supportedCities.contains(cityName) {
            return cityName
        }
        
        // 不区分大小写匹配
        let lowerCityName = cityName.lowercased()
        for supportedCity in supportedCities {
            if supportedCity.lowercased() == lowerCityName {
                return supportedCity
            }
        }
        
        // 部分匹配（例如 "Greater London" 匹配 "London"）
        for supportedCity in supportedCities {
            if lowerCityName.contains(supportedCity.lowercased()) || supportedCity.lowercased().contains(lowerCityName) {
                return supportedCity
            }
        }
        
        // 如果都不匹配，返回 "Other"
        return "Other"
    }
    
    /// 反向地理编码：将GPS坐标转换为城市名称
    private func reverseGeocode(location: CLLocation, completion: @escaping (String?) -> Void) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let error = error {
                // 反向地理编码失败，静默处理
                completion(nil)
                return
            }
            
            guard let placemark = placemarks?.first else {
                completion(nil)
                return
            }
            
            // 优先使用 locality（城市），如果没有则使用 administrativeArea（省/州）
            let rawCityName = placemark.locality ?? placemark.administrativeArea
            
            if let rawCityName = rawCityName {
                // 匹配到应用支持的城市名称
                if let matchedCity = self.matchCityName(rawCityName) {
                    completion(matchedCity)
                } else {
                    completion("Other")
                }
            } else {
                completion("Other")  // 如果无法获取，返回 "Other"
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 先创建位置信息（不包含城市名称）
        var locationInfo = LocationInfo(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentLocation = locationInfo
            self.locationError = nil
        }
        
        // 进行反向地理编码，获取城市名称
        reverseGeocode(location: location) { [weak self] cityName in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                // 更新位置信息，添加城市名称
                locationInfo.cityName = cityName
                self.currentLocation = locationInfo
                self.currentCityName = cityName
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // 检查错误类型
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    // 权限被拒绝 - 这是用户选择，不需要打印错误
                    self.locationError = error
                    print("⚠️ [LocationService] 位置权限被拒绝")
                case .locationUnknown:
                    // 位置未知 - 可能是暂时性问题，静默处理
                    self.locationError = error
                    print("⚠️ [LocationService] 无法确定位置")
                case .network:
                    // 网络错误 - 可能是网络问题
                    self.locationError = error
                    print("⚠️ [LocationService] 网络错误，无法获取位置")
                case .headingFailure:
                    // 方向获取失败 - 不影响位置获取，可以忽略
                    return
                case .regionMonitoringDenied, .regionMonitoringFailure, .regionMonitoringSetupDelayed, .regionMonitoringResponseDelayed:
                    // 区域监控相关错误 - 我们不需要区域监控，可以忽略
                    return
                default:
                    // 其他错误
                    self.locationError = error
                    print("⚠️ [LocationService] 位置获取失败: \(error.localizedDescription)")
                }
            } else {
                // 非 CLError 类型的错误
                self.locationError = error
                print("⚠️ [LocationService] 位置服务错误: \(error.localizedDescription)")
            }
        }
    }
    
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            let oldStatus = self.authorizationStatus
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                // 权限已授予，开始更新位置
                if oldStatus != manager.authorizationStatus {
                    print("✅ [LocationService] 位置权限已授予")
                }
                self.startUpdatingLocation()
            case .denied, .restricted:
                // 权限被拒绝或受限 - 静默处理，不打印错误
                self.locationError = nil // 清除之前的错误
            case .notDetermined:
                break
            @unknown default:
                break
            }
        }
    }
}

