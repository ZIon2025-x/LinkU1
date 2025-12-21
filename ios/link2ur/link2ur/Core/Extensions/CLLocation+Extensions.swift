import Foundation
import CoreLocation

/// CLLocation 扩展 - 距离计算和格式化
extension CLLocation {
    
    /// 计算到另一个坐标的距离（公里）
    func distanceInKilometers(to coordinate: CLLocationCoordinate2D) -> Double {
        let destination = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return self.distance(from: destination) / 1000.0
    }
    
    /// 计算到另一个坐标的距离并格式化显示
    func formattedDistance(to coordinate: CLLocationCoordinate2D) -> String {
        let distanceKm = distanceInKilometers(to: coordinate)
        return distanceKm.formattedAsDistance
    }
}

/// CLLocationCoordinate2D 扩展
extension CLLocationCoordinate2D {
    
    /// 检查坐标是否有效
    var isValid: Bool {
        return latitude >= -90 && latitude <= 90 && longitude >= -180 && longitude <= 180
    }
    
    /// 计算到另一个坐标的距离（公里）
    func distance(to other: CLLocationCoordinate2D) -> Double {
        let from = CLLocation(latitude: latitude, longitude: longitude)
        let to = CLLocation(latitude: other.latitude, longitude: other.longitude)
        return from.distance(from: to) / 1000.0
    }
    
    /// 计算到另一个坐标的距离并格式化显示
    func formattedDistance(to other: CLLocationCoordinate2D) -> String {
        return distance(to: other).formattedAsDistance
    }
}

/// Double 扩展 - 距离格式化
extension Double {
    
    /// 将公里数格式化为可读的距离字符串
    /// - 小于 1km：显示米
    /// - 1-10km：保留一位小数
    /// - 10km 以上：整数
    var formattedAsDistance: String {
        if self < 1 {
            return "\(Int(self * 1000))m"
        } else if self < 10 {
            return String(format: "%.1fkm", self)
        } else {
            return "\(Int(self))km"
        }
    }
}

