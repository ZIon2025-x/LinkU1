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
    private var isUpdatingLocation = false  // 自定义标志，跟踪是否正在更新位置
    
    // 反向地理编码缓存（避免重复请求）
    private var geocodeCache: [String: (cityName: String, timestamp: Date)] = [:]
    private let geocodeCacheExpiration: TimeInterval = 3600 // 缓存1小时
    private let geocodeCacheQueue = DispatchQueue(label: "com.link2ur.geocode.cache")
    
    private override init() {
        super.init()
        locationManager.delegate = self
        // 优化：使用平衡的精度，减少电池消耗
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        // 优化：增加距离阈值，减少不必要的更新
        locationManager.distanceFilter = 500 // 位置变化超过500米才更新
        
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
        
        // 如果已经在更新位置，不需要重复调用
        guard !isUpdatingLocation else {
            return
        }
        
        locationError = nil
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }
    
    /// 停止更新位置
    public func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
    }
    
    /// 获取一次位置（不持续更新）
    public func requestLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse || 
              locationManager.authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        
        // 优化：如果已经有位置且时间较近（10分钟内），不需要重新请求
        if let currentLocation = currentLocation,
           Date().timeIntervalSince(currentLocation.timestamp) < 600 {
            return
        }
        
        // 如果正在更新位置，避免重复请求
        guard !isUpdatingLocation else {
            return
        }
        
        locationError = nil
        isUpdatingLocation = true
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
    
    /// 反向地理编码：将GPS坐标转换为城市名称（带缓存优化）
    private func reverseGeocode(location: CLLocation, completion: @escaping (String?) -> Void) {
        // 生成缓存键（使用坐标的近似值，避免微小变化导致缓存失效）
        let cacheKey = String(format: "%.3f,%.3f", location.coordinate.latitude, location.coordinate.longitude)
        
        // 检查缓存
        geocodeCacheQueue.async { [weak self] in
            guard let self = self else {
                completion(nil)
                return
            }
            
            // 检查缓存
            if let cached = self.geocodeCache[cacheKey],
               Date().timeIntervalSince(cached.timestamp) < self.geocodeCacheExpiration {
                DispatchQueue.main.async {
                    completion(cached.cityName)
                }
                return
            }
            
            // 缓存未命中或已过期，进行反向地理编码
            self.geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
                guard let self = self else {
                    completion(nil)
                    return
                }
                
                if error != nil {
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
                
                let matchedCity: String
                if let rawCityName = rawCityName {
                    // 匹配到应用支持的城市名称
                    matchedCity = self.matchCityName(rawCityName) ?? "Other"
                } else {
                    matchedCity = "Other"
                }
                
                // 更新缓存
                self.geocodeCacheQueue.async {
                    self.geocodeCache[cacheKey] = (cityName: matchedCity, timestamp: Date())
                    
                    // 清理过期缓存（保持缓存大小合理）
                    self.cleanExpiredCache()
                }
                
                DispatchQueue.main.async {
                    completion(matchedCity)
                }
            }
        }
    }
    
    /// 清理过期的缓存条目
    private func cleanExpiredCache() {
        let now = Date()
        let expiredKeys = geocodeCache.filter { now.timeIntervalSince($0.value.timestamp) >= geocodeCacheExpiration }
        for key in expiredKeys.keys {
            geocodeCache.removeValue(forKey: key)
        }
        
        // 如果缓存仍然太大，删除最旧的条目（保留最多50个）
        if geocodeCache.count > 50 {
            let sortedEntries = geocodeCache.sorted { $0.value.timestamp < $1.value.timestamp }
            let keysToRemove = sortedEntries.prefix(geocodeCache.count - 50).map { $0.key }
            for key in keysToRemove {
                geocodeCache.removeValue(forKey: key)
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // 优化：检查位置是否有效（水平精度）
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 1000 else {
            // 精度太差，忽略此次更新
            return
        }
        
        // 先创建位置信息（不包含城市名称）
        var locationInfo = LocationInfo(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            // 重置更新标志
            self.isUpdatingLocation = false
            self.currentLocation = locationInfo
            self.locationError = nil
        }
        
        // 进行反向地理编码，获取城市名称（带缓存优化）
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
            
            // 重置更新标志
            self.isUpdatingLocation = false
            
            // 检查错误类型
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    // 权限被拒绝 - 这是用户选择，静默处理
                    self.locationError = error
                case .locationUnknown:
                    // 位置未知 - 可能是暂时性问题，静默处理
                    // 如果已有缓存位置，不更新错误状态
                    if self.currentLocation == nil {
                        self.locationError = error
                    }
                case .network:
                    // 网络错误 - 可能是网络问题，静默处理
                    // 如果已有缓存位置，不更新错误状态
                    if self.currentLocation == nil {
                        self.locationError = error
                    }
                case .headingFailure:
                    // 方向获取失败 - 不影响位置获取，可以忽略
                    return
                case .regionMonitoringDenied, .regionMonitoringFailure, .regionMonitoringSetupDelayed, .regionMonitoringResponseDelayed:
                    // 区域监控相关错误 - 我们不需要区域监控，可以忽略
                    return
                default:
                    // 其他错误，静默处理
                    if self.currentLocation == nil {
                        self.locationError = error
                    }
                }
            } else {
                // 非 CLError 类型的错误
                if self.currentLocation == nil {
                    self.locationError = error
                }
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

