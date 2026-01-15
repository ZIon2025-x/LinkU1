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
    @State private var isSelectingResult = false  // 正在获取搜索结果的详细信息
    @State private var isDragging = false
    @State private var lastUpdateTime = Date()
    @State private var searchDebounceTask: DispatchWorkItem?
    @State private var waitingForInitialLocation = false
    @State private var isInitializing = false  // 标记是否正在初始化，避免触发地址更新
    @State private var mapRefreshId = UUID()  // 用于强制刷新地图
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
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
        .enableSwipeBack()
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
                // 延迟一帧确保绑定值已同步
                DispatchQueue.main.async {
                    initializeLocation()
                }
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
                    // 延迟清除初始化标志并更新地址
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInitializing = false
                        updateAddressForCurrentCenter()
                    }
                }
            }
            .onTapGesture {
                // 用户体验优化：点击空白区域隐藏键盘和搜索结果
                isSearchFocused = false
                showSearchResults = false
            }
            .onDisappear {
                // 用户体验优化：视图消失时自动收起键盘
                isSearchFocused = false
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
                
                if searchCompleter.isSearching || isSelectingResult {
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
            .id(mapRefreshId) // 使用 id 强制刷新地图
            .id(mapRefreshId)  // 用于强制刷新地图位置
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
        // 如果正在初始化，不触发地址更新（避免覆盖已有地址）
        guard !isInitializing else { return }
        
        isDragging = true
        lastUpdateTime = Date()
        
        // 延迟更新地址（等待用户停止拖动）
        let capturedTime = lastUpdateTime
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            // 只有当这是最后一次更新时才执行，且不在初始化中
            if capturedTime == lastUpdateTime && !isInitializing {
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
                                
                                // UK 标识
                                if isUKLocation(result) {
                                    Text("UK")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.primary)
                                        .cornerRadius(4)
                                }
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
                        Text(LocalizationKey.locationGettingAddress.localized)
                            .font(AppTypography.body)
                            .foregroundColor(AppColors.textSecondary)
                    } else if currentAddress.isEmpty {
                        Text(LocalizationKey.locationDragToSelect.localized)
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
                        Text(LocalizationKey.locationCurrentLocation.localized)
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
                        Text(LocalizationKey.locationOnlineRemote.localized)
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
    
    /// 判断搜索结果是否为 UK 地址
    private func isUKLocation(_ result: MKLocalSearchCompletion) -> Bool {
        let text = (result.title + " " + result.subtitle).lowercased()
        return text.contains("uk") || text.contains("united kingdom") ||
               text.contains("england") || text.contains("scotland") ||
               text.contains("wales") || text.contains("northern ireland")
    }
    
    private func initializeLocation() {
        // 标记正在初始化，防止 handleRegionChange 触发地址更新
        isInitializing = true
        
        #if DEBUG
        print("📍 LocationPicker initializeLocation:")
        print("   - selectedLatitude: \(String(describing: selectedLatitude))")
        print("   - selectedLongitude: \(String(describing: selectedLongitude))")
        print("   - selectedLocation: \(selectedLocation)")
        #endif
        
        // 优先使用已保存的坐标
        if let lat = selectedLatitude, let lon = selectedLongitude {
            let coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            
            #if DEBUG
            print("📍 Setting region to: \(lat), \(lon)")
            #endif
            
            // 使用更精确的 span（减少偏移）
            let newRegion = MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01) // 更小的 span 提高精度
            )
            
            // 先设置 region
            region = newRegion
            
            // 刷新地图 ID 强制重新渲染地图到正确位置（增加延迟确保地图完全加载）
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                mapRefreshId = UUID()
                // 再次确保 region 设置正确
                region = MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                )
            }
            
            currentAddress = selectedLocation
            
            // 如果没有地址文本，进行反向地理编码
            if selectedLocation.isEmpty || selectedLocation.lowercased() == "online" {
                // 延迟调用，确保初始化标志已清除
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInitializing = false
                    updateAddressForCurrentCenter()
                }
            } else {
                // 延迟清除初始化标志，确保 onChange 不会触发
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    isInitializing = false
                }
            }
        }
        // 其次使用已保存的地址进行地理编码
        else if !selectedLocation.isEmpty && selectedLocation.lowercased() != "online" {
            currentAddress = selectedLocation
            geocodeAddressAndFinishInit(selectedLocation)
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
                // 延迟更新地址并清除初始化标志
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInitializing = false
                    updateAddressForCurrentCenter()
                }
            } else {
                // 标记正在等待位置更新，onChange 会处理更新
                waitingForInitialLocation = true
                isLoadingLocation = true
                
                // 设置超时，3秒后如果仍然没有位置，使用默认位置
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if waitingForInitialLocation {
                        waitingForInitialLocation = false
                        isLoadingLocation = false
                        isInitializing = false
                        // 超时后使用默认位置并更新地址
                        updateAddressForCurrentCenter()
                    }
                }
            }
        }
    }
    
    /// 地理编码地址并完成初始化
    private func geocodeAddressAndFinishInit(_ address: String) {
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(address) { placemarks, error in
            DispatchQueue.main.async {
                if let placemark = placemarks?.first, let location = placemark.location {
                    let coordinate = location.coordinate
                    region = MKCoordinateRegion(
                        center: coordinate,
                        span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
                    )
                }
                // 延迟清除初始化标志
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isInitializing = false
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
                    // 构建完整地址（包含邮编）
                    var addressParts: [String] = []
                    
                    // 地点名称
                    if let name = placemark.name,
                       name != placemark.locality,
                       name != placemark.subLocality {
                        addressParts.append(name)
                    }
                    
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
                    
                    // 邮编（重要：添加到地址中）
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
                    
                    currentAddress = addressParts.isEmpty ? "未知位置" : addressParts.joined(separator: ", ")
                } else {
                    // 如果反向地理编码失败，显示坐标
                    currentAddress = formatCoordinate(region.center)
                }
            }
        }
    }
    
    private func selectSearchResult(_ result: MKLocalSearchCompletion) {
        isSelectingResult = true
        showSearchResults = false
        isSearchFocused = false
        searchText = result.title
        HapticFeedback.light()
        
        // 标记正在初始化，防止 handleRegionChange 覆盖地址
        isInitializing = true
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                isSelectingResult = false
                
                if let mapItem = response?.mapItems.first {
                    let coordinate = mapItem.placemark.coordinate
                    let placemark = mapItem.placemark
                    
                    // 更新地图区域（使用更精确的 span）
                    withAnimation {
                        region = MKCoordinateRegion(
                            center: coordinate,
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )
                    }
                    
                    // 构建完整地址（包含邮编）
                    var addressParts: [String] = []
                    
                    // 优先使用搜索结果的原始标题
                    addressParts.append(result.title)
                    
                    // 如果有副标题，添加
                    if !result.subtitle.isEmpty {
                        addressParts.append(result.subtitle)
                    }
                    
                    // 从 placemark 获取邮编（如果搜索结果中没有）
                    if let postalCode = placemark.postalCode, !addressParts.contains(postalCode) {
                        addressParts.append(postalCode)
                    }
                    
                    currentAddress = addressParts.joined(separator: ", ")
                    
                    // 刷新地图 ID 确保位置准确
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        mapRefreshId = UUID()
                    }
                    
                    HapticFeedback.success()
                }
                
                // 延迟清除初始化标志，确保 handleRegionChange 不会覆盖地址
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isInitializing = false
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
            // 确保坐标精确保存（使用当前 region 的中心点）
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
    @Published var isSearching = false
    
    private let completer = MKLocalSearchCompleter()
    
    /// UK 区域边界（用于优先显示 UK 结果）
    private static let ukRegion = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 54.0, longitude: -2.0),
        span: MKCoordinateSpan(latitudeDelta: 12.0, longitudeDelta: 10.0)
    )
    
    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest]
        // 设置搜索区域为 UK，提高 UK 地址的搜索优先级
        completer.region = Self.ukRegion
    }
    
    func search(query: String) {
        guard !query.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }
    
    func cancel() {
        completer.cancel()
        isSearching = false
    }
    
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = false
            // 排序：UK 结果优先
            self?.searchResults = completer.results.sorted { a, b in
                let aIsUK = self?.isUKLocation(a) ?? false
                let bIsUK = self?.isUKLocation(b) ?? false
                if aIsUK && !bIsUK { return true }
                if !aIsUK && bIsUK { return false }
                return false
            }
        }
    }
    
    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            self?.isSearching = false
        }
        print("Search completer error: \(error.localizedDescription)")
    }
    
    /// 判断搜索结果是否为 UK 地址
    private func isUKLocation(_ result: MKLocalSearchCompletion) -> Bool {
        let text = (result.title + " " + result.subtitle).lowercased()
        return text.contains("uk") || text.contains("united kingdom") ||
               text.contains("england") || text.contains("scotland") ||
               text.contains("wales") || text.contains("northern ireland")
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
