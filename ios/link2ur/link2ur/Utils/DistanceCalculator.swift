import Foundation
import CoreLocation

/// 距离计算工具
struct DistanceCalculator {
    /// 计算两个坐标之间的距离（单位：公里）
    static func distance(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let fromLocation = CLLocation(latitude: from.latitude, longitude: from.longitude)
        let toLocation = CLLocation(latitude: to.latitude, longitude: to.longitude)
        return fromLocation.distance(from: toLocation) / 1000.0 // 转换为公里
    }
    
    /// 根据城市名称获取粗略坐标（用于城市级别的距离计算）
    static func coordinateForCity(_ cityName: String?) -> CLLocationCoordinate2D? {
        guard let cityName = cityName else { return nil }
        
        // 英国主要城市的坐标（粗略）
        let cityCoordinates: [String: CLLocationCoordinate2D] = [
            "London": CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
            "Edinburgh": CLLocationCoordinate2D(latitude: 55.9533, longitude: -3.1883),
            "Manchester": CLLocationCoordinate2D(latitude: 53.4808, longitude: -2.2426),
            "Birmingham": CLLocationCoordinate2D(latitude: 52.4862, longitude: -1.8904),
            "Glasgow": CLLocationCoordinate2D(latitude: 55.8642, longitude: -4.2518),
            "Bristol": CLLocationCoordinate2D(latitude: 51.4545, longitude: -2.5879),
            "Sheffield": CLLocationCoordinate2D(latitude: 53.3811, longitude: -1.4701),
            "Leeds": CLLocationCoordinate2D(latitude: 53.8008, longitude: -1.5491),
            "Nottingham": CLLocationCoordinate2D(latitude: 52.9548, longitude: -1.1581),
            "Newcastle": CLLocationCoordinate2D(latitude: 54.9783, longitude: -1.6178),
            "Southampton": CLLocationCoordinate2D(latitude: 50.9097, longitude: -1.4044),
            "Liverpool": CLLocationCoordinate2D(latitude: 53.4084, longitude: -2.9916),
            "Cardiff": CLLocationCoordinate2D(latitude: 51.4816, longitude: -3.1791),
            "Coventry": CLLocationCoordinate2D(latitude: 52.4068, longitude: -1.5197),
            "Exeter": CLLocationCoordinate2D(latitude: 50.7184, longitude: -3.5339),
            "Leicester": CLLocationCoordinate2D(latitude: 52.6369, longitude: -1.1398),
            "York": CLLocationCoordinate2D(latitude: 53.9600, longitude: -1.0873),
            "Aberdeen": CLLocationCoordinate2D(latitude: 57.1497, longitude: -2.0943),
            "Bath": CLLocationCoordinate2D(latitude: 51.3758, longitude: -2.3599),
            "Dundee": CLLocationCoordinate2D(latitude: 56.4620, longitude: -2.9707),
            "Reading": CLLocationCoordinate2D(latitude: 51.4543, longitude: -0.9781),
            "St Andrews": CLLocationCoordinate2D(latitude: 56.3398, longitude: -2.7967),
            "Belfast": CLLocationCoordinate2D(latitude: 54.5973, longitude: -5.9301),
            "Brighton": CLLocationCoordinate2D(latitude: 50.8225, longitude: -0.1372),
            "Durham": CLLocationCoordinate2D(latitude: 54.7752, longitude: -1.5849),
            "Norwich": CLLocationCoordinate2D(latitude: 52.6309, longitude: 1.2974),
            "Swansea": CLLocationCoordinate2D(latitude: 51.6214, longitude: -3.9436),
            "Loughborough": CLLocationCoordinate2D(latitude: 52.7719, longitude: -1.2048),
            "Lancaster": CLLocationCoordinate2D(latitude: 54.0466, longitude: -2.8001),
            "Warwick": CLLocationCoordinate2D(latitude: 52.2819, longitude: -1.5850),
            "Cambridge": CLLocationCoordinate2D(latitude: 52.2053, longitude: 0.1218),
            "Oxford": CLLocationCoordinate2D(latitude: 51.7520, longitude: -1.2577),
            "Online": CLLocationCoordinate2D(latitude: 0, longitude: 0), // 在线服务，距离为0
            "Other": CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278) // 默认使用London
        ]
        
        // 精确匹配
        if let coordinate = cityCoordinates[cityName] {
            return coordinate
        }
        
        // 不区分大小写匹配
        let lowerCityName = cityName.lowercased()
        for (key, coordinate) in cityCoordinates {
            if key.lowercased() == lowerCityName {
                return coordinate
            }
        }
        
        // 部分匹配
        for (key, coordinate) in cityCoordinates {
            if lowerCityName.contains(key.lowercased()) || key.lowercased().contains(lowerCityName) {
                return coordinate
            }
        }
        
        // 如果都不匹配，返回默认值（London）
        return cityCoordinates["Other"]
    }
    
    /// 计算到指定城市的距离（基于城市名称）
    static func distanceToCity(from userLocation: CLLocationCoordinate2D, to cityName: String?) -> Double? {
        guard let cityCoordinate = coordinateForCity(cityName) else {
            return nil
        }
        
        // 如果是Online，返回0
        if cityName?.lowercased() == "online" {
            return 0
        }
        
        return distance(from: userLocation, to: cityCoordinate)
    }
}

/// 支持距离排序的协议
protocol DistanceSortable {
    var location: String? { get }
    var distance: Double? { get set }
}

