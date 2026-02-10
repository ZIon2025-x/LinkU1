import Foundation
import CoreLocation
import Combine

/// 位置信息模型
struct LocationInfo: Codable, Equatable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    var cityName: String?

    init(latitude: Double, longitude: Double, timestamp: Date = Date(), cityName: String? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
        self.cityName = cityName
    }
}

/// 位置服务管理器（移植自原生项目 LocationService.swift）
class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: LocationInfo?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var locationError: Error?

    private let locationManager = CLLocationManager()
    private var isUpdatingLocation = false

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 500
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestAuthorization() {
        switch locationManager.authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            break
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdatingLocation()
        @unknown default:
            break
        }
    }

    func startUpdatingLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        guard !isUpdatingLocation else { return }
        locationError = nil
        isUpdatingLocation = true
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        isUpdatingLocation = false
    }

    func requestLocation() {
        guard locationManager.authorizationStatus == .authorizedWhenInUse ||
              locationManager.authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        if let loc = currentLocation, Date().timeIntervalSince(loc.timestamp) < 600 {
            return
        }
        guard !isUpdatingLocation else { return }
        locationError = nil
        isUpdatingLocation = true
        locationManager.requestLocation()
    }

    var isAuthorized: Bool {
        locationManager.authorizationStatus == .authorizedWhenInUse ||
        locationManager.authorizationStatus == .authorizedAlways
    }
}

// MARK: - CLLocationManagerDelegate
extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        guard location.horizontalAccuracy >= 0 && location.horizontalAccuracy <= 1000 else { return }

        let info = LocationInfo(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            timestamp: location.timestamp
        )
        DispatchQueue.main.async { [weak self] in
            self?.isUpdatingLocation = false
            self?.currentLocation = info
            self?.locationError = nil
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isUpdatingLocation = false
            if self?.currentLocation == nil {
                self?.locationError = error
            }
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        DispatchQueue.main.async { [weak self] in
            self?.authorizationStatus = manager.authorizationStatus
            if manager.authorizationStatus == .authorizedWhenInUse ||
               manager.authorizationStatus == .authorizedAlways {
                self?.startUpdatingLocation()
            }
        }
    }
}
