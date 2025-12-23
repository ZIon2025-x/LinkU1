import SwiftUI
import MapKit
import CoreLocation

/// 任务详细地址视图 - 显示地图和详细地址
struct TaskLocationDetailView: View {
    let location: String
    let latitude: Double?
    let longitude: Double?
    @Environment(\.dismiss) var dismiss
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
    )
    @State private var isLoadingAddress = false
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 地图视图
                Map(coordinateRegion: $region, annotationItems: annotationItems) { item in
                    MapMarker(coordinate: item.coordinate, tint: AppColors.primary)
                }
                .frame(height: 400)
                .onAppear {
                    setupMapRegion()
                }
                
                // 地址信息面板
                VStack(alignment: .leading, spacing: AppSpacing.md) {
                    HStack {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(AppColors.primary)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("详细地址")
                                .font(AppTypography.subheadline)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Text(location)
                                .font(AppTypography.body)
                                .foregroundColor(AppColors.textPrimary)
                                .lineLimit(nil)
                        }
                        
                        Spacer()
                    }
                    .padding(AppSpacing.md)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppCornerRadius.medium)
                    
                    // 坐标信息（如果有）
                    if let lat = latitude, let lon = longitude {
                        HStack {
                            Image(systemName: "location.fill")
                                .font(.system(size: 16))
                                .foregroundColor(AppColors.textTertiary)
                            
                            Text("坐标: \(String(format: "%.6f", lat)), \(String(format: "%.6f", lon))")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.textSecondary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(AppSpacing.md)
                
                Spacer()
            }
        }
        .navigationTitle("详细地址")
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("完成") {
                    dismiss()
                }
                .foregroundColor(AppColors.primary)
            }
        }
    }
    
    // 地图标注项
    private var annotationItems: [MapAnnotationItem] {
        guard let lat = latitude, let lon = longitude else {
            return []
        }
        return [MapAnnotationItem(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lon))]
    }
    
    // 设置地图区域
    private func setupMapRegion() {
        if let lat = latitude, let lon = longitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            )
        } else {
            // 如果没有坐标，尝试地理编码地址
            geocodeAddress()
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
}

// 地图标注项模型
private struct MapAnnotationItem: Identifiable {
    let id = UUID()
    let coordinate: CLLocationCoordinate2D
}

