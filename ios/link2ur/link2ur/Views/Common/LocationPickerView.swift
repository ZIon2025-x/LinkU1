import SwiftUI
import MapKit
import CoreLocation
import Combine

/// 地图选点视图
struct LocationPickerView: View {
    @Binding var selectedLocation: String
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject private var locationService = LocationService.shared
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278), // 默认：London
        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
    )
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var isUsingCurrentLocation = false
    @State private var isLoadingLocation = false
    @State private var locationError: String?
    @State private var addressText = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 地图视图
                    Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
                        MapMarker(coordinate: item.coordinate, tint: AppColors.primary)
                    }
                    .onTapGesture { location in
                        let coordinate = region.center
                        selectLocation(coordinate: coordinate)
                    }
                    .gesture(
                        DragGesture()
                            .onEnded { _ in
                                // 地图拖动结束后，更新选中位置为中心点
                                if let coordinate = selectedCoordinate {
                                    selectLocation(coordinate: region.center)
                                }
                            }
                    )
                    .frame(height: 400)
                    
                    // 控制面板
                    VStack(spacing: AppSpacing.md) {
                        // 使用当前位置按钮
                        Button(action: {
                            useCurrentLocation()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 16))
                                Text("使用当前位置")
                                    .font(AppTypography.body)
                                if isLoadingLocation {
                                    Spacer()
                                    ProgressView()
                                        .scaleEffect(0.8)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppColors.primary)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        .disabled(isLoadingLocation || !locationService.isAuthorized)
                        
                        // 手动输入位置
                        VStack(alignment: .leading, spacing: 8) {
                            Text("或手动输入位置")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            TextField("例如: London, Online", text: $addressText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onChange(of: addressText) { newValue in
                                    selectedLocation = newValue
                                    // 手动输入时清空坐标
                                    selectedLatitude = nil
                                    selectedLongitude = nil
                                }
                        }
                        
                        // 错误提示
                        if let error = locationError {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(AppColors.error)
                                Text(error)
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.error)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.error.opacity(0.1))
                            .cornerRadius(AppCornerRadius.small)
                        }
                        
                        // 当前选择的位置信息
                        if let coordinate = selectedCoordinate {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("已选择位置")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textSecondary)
                                Text("纬度: \(coordinate.latitude, specifier: "%.6f"), 经度: \(coordinate.longitude, specifier: "%.6f")")
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.textPrimary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppCornerRadius.medium)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        if let coordinate = selectedCoordinate {
                            selectedLatitude = coordinate.latitude
                            selectedLongitude = coordinate.longitude
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCoordinate == nil && addressText.isEmpty)
                }
            }
            .onAppear {
                // 初始化：如果有已选择的位置，显示在地图上
                if let lat = selectedLatitude, let lon = selectedLongitude {
                    let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                    region.center = coordinate
                    selectedCoordinate = coordinate
                } else if !selectedLocation.isEmpty && selectedLocation.lowercased() != "online" {
                    addressText = selectedLocation
                }
                
                // 如果位置服务已授权，尝试获取当前位置
                if locationService.isAuthorized {
                    updateRegionToCurrentLocation()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var annotationItems: [MapAnnotation] {
        guard let coordinate = selectedCoordinate else { return [] }
        return [MapAnnotation(coordinate: coordinate)]
    }
    
    private func selectLocation(coordinate: CLLocationCoordinate2D) {
        selectedCoordinate = coordinate
        isUsingCurrentLocation = false
        
        // 反向地理编码获取地址文本
        reverseGeocode(coordinate: coordinate)
        
        // 更新地图区域
        withAnimation {
            region.center = coordinate
        }
    }
    
    private func useCurrentLocation() {
        guard locationService.isAuthorized else {
            locationService.requestAuthorization()
            locationError = "需要位置权限才能使用当前位置"
            return
        }
        
        isLoadingLocation = true
        locationError = nil
        
        locationService.requestLocation()
        
        // 使用 Combine 监听位置更新（最多等待 5 秒）
        let locationCancellable = locationService.$currentLocation
            .compactMap { $0 }
            .first()
            .sink(
                receiveCompletion: { [weak self] completion in
                    guard let self = self else { return }
                    self.isLoadingLocation = false
                    if case .failure = completion {
                        self.locationError = "获取位置失败，请重试"
                    }
                },
                receiveValue: { [weak self] locationInfo in
                    guard let self = self else { return }
                    self.isLoadingLocation = false
                    let coordinate = CLLocationCoordinate2D(
                        latitude: locationInfo.latitude,
                        longitude: locationInfo.longitude
                    )
                    self.selectLocation(coordinate: coordinate)
                    self.isUsingCurrentLocation = true
                }
            )
        cancellables.insert(locationCancellable)
    }
    
    private func updateRegionToCurrentLocation() {
        if let location = locationService.currentLocation {
            let coordinate = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            region.center = coordinate
            if selectedCoordinate == nil {
                selectLocation(coordinate: coordinate)
            }
        }
    }
    
    private func reverseGeocode(coordinate: CLLocationCoordinate2D) {
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first {
                    // 优先使用城市名称
                    let city = placemark.locality ?? placemark.administrativeArea ?? "未知位置"
                    addressText = city
                    selectedLocation = city
                } else {
                    // 如果反向地理编码失败，使用坐标的简化显示
                    addressText = "\(coordinate.latitude, specifier: "%.4f"), \(coordinate.longitude, specifier: "%.4f")"
                    selectedLocation = addressText
                }
            }
        }
    }
    
    @State private var cancellables = Set<AnyCancellable>()
}

// MARK: - Map Annotation Model

struct MapAnnotation: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

// MARK: - Preview

#Preview {
    LocationPickerView(
        selectedLocation: .constant(""),
        selectedLatitude: .constant(nil),
        selectedLongitude: .constant(nil)
    )
}

