import SwiftUI
import MapKit
import CoreLocation

/// 任务详细地址视图 - 显示地图和详细地址
struct TaskLocationDetailView: View {
    let location: String
    let latitude: Double?
    let longitude: Double?
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject private var locationService = LocationService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isLoadingAddress = false
    @State private var userCurrentAddress: String? = nil
    @State private var isLoadingUserAddress = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 地图视图
                Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
                    MapAnnotation(coordinate: item.coordinate) {
                        VStack(spacing: 0) {
                            Image(systemName: item.isUserLocation ? "location.circle.fill" : "mappin.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(item.isUserLocation ? AppColors.success : AppColors.primary)
                                .background(
                                    Circle()
                                        .fill(Color.white)
                                        .frame(width: 20, height: 20)
                                )
                            
                            Text(item.isUserLocation ? LocalizationKey.taskLocationMyLocation.localized : LocalizationKey.taskLocationAddress.localized)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.isUserLocation ? AppColors.success : AppColors.primary)
                                .cornerRadius(4)
                                .offset(y: -4)
                        }
                    }
                }
                .frame(height: 400)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        // 任务详细地址
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            HStack {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(AppColors.primary)
                                
                                Text(LocalizationKey.taskLocationAddress.localized)
                                    .font(AppTypography.subheadline)
                                    .foregroundColor(AppColors.textSecondary)
                                
                                Spacer()
                            }
                            
                            Text(location)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(nil)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // 坐标信息（如果有）
                            if let lat = latitude, let lon = longitude {
                                HStack {
                                    Image(systemName: "location.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.textTertiary)
                                    
                                    Text("\(LocalizationKey.taskLocationCoordinates.localized): \(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))")
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    Spacer()
                                }
                            }
                            
                            // 导航按钮
                            if let lat = latitude, let lon = longitude {
                                HStack(spacing: AppSpacing.sm) {
                                    // 苹果地图导航
                                    Button(action: {
                                        openInAppleMaps(latitude: lat, longitude: lon)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "map.fill")
                                                .font(.system(size: 14))
                                            Text(LocalizationKey.taskLocationAppleMaps.localized)
                                                .font(AppTypography.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, 10)
                                        .background(AppColors.primary)
                                        .cornerRadius(AppCornerRadius.medium)
                                    }
                                    
                                    // Google 地图导航
                                    Button(action: {
                                        openInGoogleMaps(latitude: lat, longitude: lon)
                                    }) {
                                        HStack(spacing: 6) {
                                            Image(systemName: "map.circle.fill")
                                                .font(.system(size: 14))
                                            Text(LocalizationKey.locationGoogleMaps.localized)
                                                .font(AppTypography.caption)
                                                .fontWeight(.medium)
                                        }
                                        .foregroundColor(.white)
                                        .padding(.horizontal, AppSpacing.md)
                                        .padding(.vertical, 10)
                                        .background(Color(red: 0.26, green: 0.52, blue: 0.96)) // Google 蓝色
                                        .cornerRadius(AppCornerRadius.medium)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.medium)
                        
                        // 用户当前位置（如果有）
                        if let userLocation = locationService.currentLocation {
                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                HStack {
                                    Image(systemName: "location.circle.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(AppColors.success)
                                    
                                    Text(LocalizationKey.taskLocationMyLocation.localized)
                                        .font(AppTypography.subheadline)
                                        .foregroundColor(AppColors.textSecondary)
                                    
                                    Spacer()
                                    
                                    if isLoadingUserAddress {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                }
                                
                                if let userAddress = userCurrentAddress {
                                    Text(userAddress)
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(nil)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    HStack {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.textTertiary)
                                        
                                        Text("\(LocalizationKey.taskLocationCoordinates.localized): \(String(format: "%.6f", userLocation.latitude)), \(String(format: "%.6f", userLocation.longitude))")
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                        
                                        Spacer()
                                    }
                                    
                                    // 导航到用户位置（从任务地址导航到用户位置）
                                    if latitude != nil && longitude != nil {
                                        HStack(spacing: AppSpacing.sm) {
                                            // 苹果地图导航
                                            Button(action: {
                                                openInAppleMaps(latitude: userLocation.latitude, longitude: userLocation.longitude)
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "map.fill")
                                                        .font(.system(size: 14))
                                                    Text(LocalizationKey.taskLocationAppleMaps.localized)
                                                        .font(AppTypography.caption)
                                                        .fontWeight(.medium)
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, AppSpacing.md)
                                                .padding(.vertical, 10)
                                                .background(AppColors.success)
                                                .cornerRadius(AppCornerRadius.medium)
                                            }
                                            
                                            // Google 地图导航
                                            Button(action: {
                                                openInGoogleMaps(latitude: userLocation.latitude, longitude: userLocation.longitude)
                                            }) {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "map.circle.fill")
                                                        .font(.system(size: 14))
                                                    Text(LocalizationKey.locationGoogleMaps.localized)
                                                        .font(AppTypography.caption)
                                                        .fontWeight(.medium)
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, AppSpacing.md)
                                                .padding(.vertical, 10)
                                                .background(Color(red: 0.26, green: 0.52, blue: 0.96)) // Google 蓝色
                                                .cornerRadius(AppCornerRadius.medium)
                                            }
                                            
                                            Spacer()
                                        }
                                    }
                                } else {
                                    Text(LocalizationKey.taskLocationLoadingAddress.localized)
                                        .font(AppTypography.caption)
                                        .foregroundColor(AppColors.textTertiary)
                                }
                            }
                            .padding(AppSpacing.md)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                    }
                    .padding(AppSpacing.md)
                }
                
            }
        }
        .navigationTitle(LocalizationKey.taskLocationDetailAddress.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(LocalizationKey.commonDone.localized) {
                    dismiss()
                }
                .foregroundColor(AppColors.primary)
            }
        }
        .onAppear {
            setupMapRegion()
            loadUserCurrentAddress()
        }
        .onChange(of: locationService.currentLocation) { newLocation in
            // 当用户位置更新时，重新加载地址和更新地图
            if newLocation != nil {
                loadUserCurrentAddress()
                setupMapRegion()
            }
        }
    }
    
    // 地图标注项（包括任务地址和用户位置）
    private var annotationItems: [MapAnnotationItem] {
        var items: [MapAnnotationItem] = []
        
        // 添加任务地址标记
        if let lat = latitude, let lon = longitude {
            items.append(MapAnnotationItem(
                coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon),
                isUserLocation: false
            ))
        }
        
        // 添加用户当前位置标记
        if let userLocation = locationService.currentLocation {
            items.append(MapAnnotationItem(
                coordinate: CLLocationCoordinate2D(
                    latitude: userLocation.latitude,
                    longitude: userLocation.longitude
                ),
                isUserLocation: true
            ))
        }
        
        return items
    }
    
    // 设置地图区域（包含任务地址和用户位置）
    private func setupMapRegion() {
        var coordinates: [CLLocationCoordinate2D] = []
        
        // 添加任务地址坐标
        if let lat = latitude, let lon = longitude {
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        // 添加用户位置坐标
        if let userLocation = locationService.currentLocation {
            coordinates.append(CLLocationCoordinate2D(
                latitude: userLocation.latitude,
                longitude: userLocation.longitude
            ))
        }
        
        if coordinates.isEmpty {
            // 如果没有坐标，尝试地理编码地址
            geocodeAddress()
            return
        }
        
        // 计算包含所有坐标的区域
        if coordinates.count == 1 {
            // 只有一个坐标，直接设置
            region = MKCoordinateRegion(
                center: coordinates[0],
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else {
            // 多个坐标，计算包含所有坐标的区域
            let minLat = coordinates.map { $0.latitude }.min()!
            let maxLat = coordinates.map { $0.latitude }.max()!
            let minLon = coordinates.map { $0.longitude }.min()!
            let maxLon = coordinates.map { $0.longitude }.max()!
            
            let centerLat = (minLat + maxLat) / 2
            let centerLon = (minLon + maxLon) / 2
            let latDelta = max((maxLat - minLat) * 1.5, 0.01) // 至少 0.01，并增加 50% 的边距
            let lonDelta = max((maxLon - minLon) * 1.5, 0.01)
            
            region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
                span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta)
            )
        }
    }
    
    
    // 地理编码地址
    private func geocodeAddress() {
        guard !location.isEmpty, location.lowercased() != "online" else {
            return
        }
        
        isLoadingAddress = true
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoadingAddress = false
                if let placemark = placemarks?.first,
                   let coordinate = placemark.location?.coordinate {
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                    )
                }
            }
        }
    }
    
    // 加载用户当前位置的完整地址
    private func loadUserCurrentAddress() {
        guard let userLocation = locationService.currentLocation else {
            // 如果没有位置，尝试请求位置
            if locationService.isAuthorized {
                locationService.requestLocation()
            } else {
                locationService.requestAuthorization()
            }
            return
        }
        
        isLoadingUserAddress = true
        let geocoder = CLGeocoder()
        let location = CLLocation(
            latitude: userLocation.latitude,
            longitude: userLocation.longitude
        )
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoadingUserAddress = false
                
                if let placemark = placemarks?.first {
                    // 构建完整地址
                    var addressParts: [String] = []
                    
                    // 街道地址
                    if let thoroughfare = placemark.thoroughfare {
                        addressParts.append(thoroughfare)
                    }
                    
                    // 区/街道
                    if let subLocality = placemark.subLocality {
                        addressParts.append(subLocality)
                    }
                    
                    // 城市
                    if let locality = placemark.locality {
                        addressParts.append(locality)
                    }
                    
                    // 邮编
                    if let postalCode = placemark.postalCode {
                        addressParts.append(postalCode)
                    }
                    
                    // 如果没有城市，使用行政区
                    if addressParts.isEmpty, let adminArea = placemark.administrativeArea {
                        addressParts.append(adminArea)
                    }
                    
                    // 国家（作为后备）
                    if addressParts.isEmpty, let country = placemark.country {
                        addressParts.append(country)
                    }
                    
                    userCurrentAddress = addressParts.isEmpty ? "未知位置" : addressParts.joined(separator: ", ")
                } else {
                    userCurrentAddress = "无法获取地址"
                }
            }
        }
    }
    
    // 在苹果地图中打开导航
    private func openInAppleMaps(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        
        // 判断是任务地址还是用户位置
        let isTaskLocation = abs(latitude - (self.latitude ?? 0)) < 0.0001 && 
                            abs(longitude - (self.longitude ?? 0)) < 0.0001
        
        if isTaskLocation {
            // 任务地址导航
            mapItem.name = self.location
        } else {
            // 用户位置导航
            mapItem.name = userCurrentAddress ?? LocalizationKey.taskLocationMyLocation.localized
        }
        
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }
    
    // 在 Google 地图中打开导航
    private func openInGoogleMaps(latitude: Double, longitude: Double) {
        // Google Maps URL Scheme: comgooglemaps://
        // 如果安装了 Google Maps，使用 URL Scheme
        let urlString = "comgooglemaps://?daddr=\(latitude),\(longitude)&directionsmode=driving"
        if let url = URL(string: urlString),
           UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        } else {
            // 如果没有安装 Google Maps，使用网页版
            let webUrlString = "https://www.google.com/maps/dir/?api=1&destination=\(latitude),\(longitude)"
            if let url = URL(string: webUrlString) {
                UIApplication.shared.open(url)
            }
        }
    }
}

// 地图标注项模型
private struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
    let isUserLocation: Bool
}

