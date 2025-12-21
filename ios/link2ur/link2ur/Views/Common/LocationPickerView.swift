import SwiftUI
import MapKit
import CoreLocation
import Combine

/// 地图选点视图 - 支持搜索和拖动选点（兼容 iOS 16）
struct LocationPickerView: View {
    @Binding var selectedLocation: String
    @Binding var selectedLatitude: Double?
    @Binding var selectedLongitude: Double?
    @Environment(\.dismiss) var dismiss
    
    @ObservedObject private var locationService = LocationService.shared
    @StateObject private var searchCompleter = LocationSearchCompleter()
    
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 51.5074, longitude: -0.1278),
        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
    )
    @State private var currentAddress = ""
    @State private var isLoadingAddress = false
    @State private var isLoadingLocation = false
    @State private var locationError: String?
    @State private var searchText = ""
    @State private var showSearchResults = false
    @State private var isSearching = false
    @State private var isDragging = false
    @State private var lastUpdateTime = Date()
    @State private var searchDebounceTask: DispatchWorkItem?
    @State private var waitingForInitialLocation = false
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 搜索栏
                    searchBar
                    
                    // 地图视图（带中心指针和控制按钮）
                    ZStack {
                        mapView
                        
                        // 中心指针
                        centerPinView
                        
                        // 地图控制按钮
                        mapControlButtons
                        
                        // 搜索结果列表
                        if showSearchResults && !searchCompleter.searchResults.isEmpty {
                            searchResultsList
                        }
                    }
                    
                    // 底部控制面板
                    bottomPanel
                }
            }
            .navigationTitle("选择位置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        confirmSelection()
                    }
                    .fontWeight(.semibold)
                    .disabled(currentAddress.isEmpty)
                }
            }
            .onAppear {
                initializeLocation()
            }
            .onChange(of: locationService.currentLocation) { newLocation in
                // 如果正在等待初始位置更新
                if waitingForInitialLocation, let location = newLocation {
                    waitingForInitialLocation = false
                    isLoadingLocation = false
                    let coordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                    updateAddressForCurrentCenter()
                }
            }
            .onTapGesture {
                // 点击空白区域隐藏键盘
                isSearchFocused = false
                showSearchResults = false
            }
        }
    }
    
    // MARK: - 搜索栏
    
    private var searchBar: some View {
        HStack(spacing: 12) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(AppColors.textSecondary)
                
                TextField("搜索地点、地址...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .focused($isSearchFocused)
                    .onChange(of: searchText) { newValue in
                        // 防抖处理
                        searchDebounceTask?.cancel()
                        
                        if !newValue.isEmpty {
                            let task = DispatchWorkItem {
                                searchCompleter.search(query: newValue)
                                showSearchResults = true
                            }
                            searchDebounceTask = task
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                        } else {
                            showSearchResults = false
                            searchCompleter.searchResults = []
                        }
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        showSearchResults = false
                        searchCompleter.searchResults = []
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
                
                if isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.background)
    }
    
    // MARK: - 地图视图（iOS 16 兼容版本）
    
    private var mapView: some View {
        Map(coordinateRegion: $region, interactionModes: .all)
            .onChange(of: region.center.latitude) { _ in
                handleRegionChange()
            }
            .onChange(of: region.center.longitude) { _ in
                handleRegionChange()
            }
            .gesture(
                TapGesture()
                    .onEnded { _ in
                        showSearchResults = false
                        isSearchFocused = false
                    }
            )
    }
    
    // MARK: - 地图控制按钮（右下角小按钮）
    
    private var mapControlButtons: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                HStack(spacing: 0) {
                    // 缩小按钮
                    Button(action: {
                        zoomOut()
                    }) {
                        Image(systemName: "minus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                    
                    Divider()
                        .frame(height: 20)
                    
                    // 放大按钮
                    Button(action: {
                        zoomIn()
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .frame(width: 32, height: 32)
                    }
                }
                .background(AppColors.cardBackground.opacity(0.9))
                .cornerRadius(AppCornerRadius.small)
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0, y: 1)
            }
            .padding(.trailing, AppSpacing.sm)
            .padding(.bottom, AppSpacing.sm)
        }
    }
    
    private func handleRegionChange() {
        isDragging = true
        lastUpdateTime = Date()
        
        // 延迟更新地址（等待用户停止拖动）
        let capturedTime = lastUpdateTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // 只有当这是最后一次更新时才执行
            if capturedTime == lastUpdateTime {
                isDragging = false
                updateAddressForCurrentCenter()
            }
        }
    }
    
    private func zoomIn() {
        HapticFeedback.light()
        withAnimation {
            region.span = MKCoordinateSpan(
                latitudeDelta: max(region.span.latitudeDelta / 2, 0.001),
                longitudeDelta: max(region.span.longitudeDelta / 2, 0.001)
            )
        }
    }
    
    private func zoomOut() {
        HapticFeedback.light()
        withAnimation {
            region.span = MKCoordinateSpan(
                latitudeDelta: min(region.span.latitudeDelta * 2, 180),
                longitudeDelta: min(region.span.longitudeDelta * 2, 180)
            )
        }
    }
    
    // MARK: - 中心指针
    
    private var centerPinView: some View {
        VStack(spacing: 0) {
            // 指针图标
            ZStack {
                // 外圈光晕
                Circle()
                    .fill(AppColors.primary.opacity(0.2))
                    .frame(width: 60, height: 60)
                    .scaleEffect(isDragging ? 1.3 : 1.0)
                
                // 指针主体
                VStack(spacing: 0) {
                    // 圆形头部
                    ZStack {
                        Circle()
                            .fill(AppColors.primary)
                            .frame(width: 32, height: 32)
                        
                        Circle()
                            .fill(.white)
                            .frame(width: 12, height: 12)
                    }
                    
                    // 三角形尾部
                    Triangle()
                        .fill(AppColors.primary)
                        .frame(width: 16, height: 20)
                        .offset(y: -4)
                }
                .shadow(color: .black.opacity(0.4), radius: 4, x: 0, y: 4)
            }
            .offset(y: isDragging ? -15 : -8)
            
            // 地面阴影
            Ellipse()
                .fill(Color.black.opacity(isDragging ? 0.15 : 0.25))
                .frame(width: isDragging ? 16 : 24, height: isDragging ? 4 : 8)
                .offset(y: isDragging ? 5 : 0)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isDragging)
    }
    
    // MARK: - 搜索结果列表
    
    private var searchResultsList: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(searchCompleter.searchResults.prefix(8), id: \.self) { result in
                        Button(action: {
                            selectSearchResult(result)
                        }) {
                            HStack(spacing: 12) {
                                Image(systemName: "mappin.and.ellipse")
                                    .foregroundColor(AppColors.primary)
                                    .frame(width: 24)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(AppTypography.body)
                                        .foregroundColor(AppColors.textPrimary)
                                        .lineLimit(1)
                                    
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                        }
                        
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
            .frame(maxHeight: 280)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.top, 4)
        .frame(maxHeight: .infinity, alignment: .top)
    }
    
    // MARK: - 底部控制面板
    
    private var bottomPanel: some View {
        VStack(spacing: AppSpacing.md) {
            // 当前选择的位置信息
            HStack(spacing: 12) {
                if isLoadingAddress {
                    ProgressView()
                        .frame(width: 24, height: 24)
                } else {
                    Image(systemName: currentAddress.isEmpty ? "mappin.slash" : "mappin.circle.fill")
                        .foregroundColor(currentAddress.isEmpty ? AppColors.textSecondary : AppColors.primary)
                        .font(.system(size: 24))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    if isLoadingAddress {
                        Text("正在获取地址...")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    } else if currentAddress.isEmpty {
                        Text("拖动地图选择位置")
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    } else {
                        Text(currentAddress)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                    }
                    
                    Text(formatCoordinate(region.center))
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                
                Spacer()
            }
            .padding(12)
            .background(AppColors.cardBackground)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(currentAddress.isEmpty ? Color.clear : AppColors.primary.opacity(0.3), lineWidth: 1)
            )
            
            // 快捷按钮行
            HStack(spacing: 8) {
                // 使用当前位置按钮
                Button(action: {
                    useCurrentLocation()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill")
                            .font(.system(size: 14))
                        Text("当前位置")
                            .font(AppTypography.caption)
                        if isLoadingLocation {
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.primary)
                    .cornerRadius(AppCornerRadius.medium)
                }
                .disabled(isLoadingLocation)
                
                // Online 按钮
                Button(action: {
                    selectOnlineLocation()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 14))
                        Text("线上/远程")
                            .font(AppTypography.caption)
                    }
                    .foregroundColor(AppColors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(AppColors.primaryLight)
                    .cornerRadius(AppCornerRadius.medium)
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
                    Spacer()
                    Button("关闭") {
                        locationError = nil
                    }
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.error)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.error.opacity(0.1))
                .cornerRadius(AppCornerRadius.small)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground)
    }
    
    // MARK: - Helper Methods
    
    private func formatCoordinate(_ coordinate: CLLocationCoordinate2D) -> String {
        return String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude)
    }
    
    private func initializeLocation() {
        // 优先使用已保存的坐标
        if let lat = selectedLatitude, let lon = selectedLongitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            // 强制更新整个 region
            region = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
            currentAddress = selectedLocation
            
            // 如果没有地址文本，进行反向地理编码
            if selectedLocation.isEmpty || selectedLocation.lowercased() == "online" {
                updateAddressForCurrentCenter()
            }
        }
        // 其次使用已保存的地址进行地理编码
        else if !selectedLocation.isEmpty && selectedLocation.lowercased() != "online" {
            currentAddress = selectedLocation
            geocodeAddress(selectedLocation)
        }
        // 默认使用当前位置
        else {
            // 请求位置权限和位置
            if !locationService.isAuthorized {
                locationService.requestAuthorization()
            }
            locationService.requestLocation()
            
            // 如果已有位置，立即使用
            if let location = locationService.currentLocation {
                let coordinate = CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                )
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
                updateAddressForCurrentCenter()
            } else {
                // 标记正在等待位置更新，onChange 会处理更新
                waitingForInitialLocation = true
                isLoadingLocation = true
                
                // 设置超时，3秒后如果仍然没有位置，使用默认位置
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if waitingForInitialLocation {
                        waitingForInitialLocation = false
                        isLoadingLocation = false
                        // 超时后使用默认位置并更新地址
                        updateAddressForCurrentCenter()
                    }
                }
            }
        }
    }
    
    private func updateAddressForCurrentCenter() {
        isLoadingAddress = true
        
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: region.center.latitude, longitude: region.center.longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isLoadingAddress = false
                
                if let placemark = placemarks?.first {
                    // 构建完整地址
                    var addressParts: [String] = []
                    
                    // 地点名称
                    if let name = placemark.name,
                       name != placemark.locality,
                       name != placemark.subLocality {
                        addressParts.append(name)
                    }
                    
                    // 区/街道
                    if let subLocality = placemark.subLocality {
                        addressParts.append(subLocality)
                    }
                    
                    // 城市
                    if let locality = placemark.locality {
                        addressParts.append(locality)
                    }
                    
                    // 如果没有城市，使用行政区
                    if addressParts.isEmpty, let adminArea = placemark.administrativeArea {
                        addressParts.append(adminArea)
                    }
                    
                    // 国家（作为后备）
                    if addressParts.isEmpty, let country = placemark.country {
                        addressParts.append(country)
                    }
                    
                    currentAddress = addressParts.isEmpty ? "未知位置" : addressParts.joined(separator: ", ")
                } else {
                    // 如果反向地理编码失败，显示坐标
                    currentAddress = formatCoordinate(region.center)
                }
            }
        }
    }
    
    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        isSearching = true
        showSearchResults = false
        isSearchFocused = false
        searchText = result.title
        HapticFeedback.light()
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                isSearching = false
                
                if let mapItem = response?.mapItems.first {
                    let coordinate = mapItem.placemark.coordinate
                    
                    // 更新地图区域
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                    
                    // 优先使用搜索结果的原始标题（保留邮编等详细信息）
                    if !result.subtitle.isEmpty {
                        currentAddress = "\(result.title), \(result.subtitle)"
                    } else {
                        currentAddress = result.title
                    }
                    
                    HapticFeedback.success()
                }
            }
        }
    }
    
    private func geocodeAddress(_ address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first, let location = placemark.location {
                    let coordinate = location.coordinate
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    }
                }
            }
        }
    }
    
    private func useCurrentLocation() {
        if !locationService.isAuthorized {
            locationService.requestAuthorization()
            locationError = "需要位置权限才能使用当前位置"
            return
        }
        
        isLoadingLocation = true
        locationError = nil
        HapticFeedback.light()
        
        locationService.requestLocation()
        
        // 如果已有位置，直接使用
        if let location = locationService.currentLocation {
            let coordinate = CLLocationCoordinate2D(
                latitude: location.latitude,
                longitude: location.longitude
            )
            withAnimation {
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                )
            }
            updateAddressForCurrentCenter()
            isLoadingLocation = false
            HapticFeedback.success()
        } else {
            // 等待位置更新
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if let location = locationService.currentLocation {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                        )
                    }
                    updateAddressForCurrentCenter()
                    HapticFeedback.success()
                }
                isLoadingLocation = false
            }
        }
        
        // 设置超时
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            if isLoadingLocation {
                isLoadingLocation = false
                locationError = "获取位置超时，请重试"
            }
        }
    }
    
    private func selectOnlineLocation() {
        HapticFeedback.light()
        currentAddress = "Online"
        // 清除坐标，表示线上位置
        confirmSelection()
    }
    
    private func confirmSelection() {
        HapticFeedback.success()
        
        if currentAddress == "Online" {
            selectedLatitude = nil
            selectedLongitude = nil
            selectedLocation = "Online"
        } else {
            selectedLatitude = region.center.latitude
            selectedLongitude = region.center.longitude
            selectedLocation = currentAddress
        }
        dismiss()
    }
}

// MARK: - 三角形形状

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.closeSubpath()
        return path
    }
}

// MARK: - 地点搜索自动完成

class LocationSearchCompleter: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var searchResults: [MKLocalSearchCompletion] = []
    
    private let completer = MKLocalSearchCompleter()
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
    }
    
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            return
        }
        completer.queryFragment = query
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async {
            self.searchResults = completer.results
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("Search completer error: \(error.localizedDescription)")
    }
}

// MARK: - Preview

#Preview {
    LocationPickerView(
        selectedLocation: .constant(""),
        selectedLatitude: .constant(nil),
        selectedLongitude: .constant(nil)
    )
}
