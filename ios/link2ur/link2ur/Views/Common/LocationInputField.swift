import SwiftUI
import MapKit
import CoreLocation

/// 位置输入字段组件 - 支持搜索建议、地图选点和在线位置
/// 用于任务创建和二手商品发布等场景
struct LocationInputField: View {
    // MARK: - Bindings
    @Binding var location: String
    @Binding var latitude: Double?
    @Binding var longitude: Double?
    
    // MARK: - Configuration
    var title: String = "位置"
    var placeholder: String = "搜索地点或输入 Online"
    var isRequired: Bool = false
    var showOnlineOption: Bool = true
    
    // MARK: - State
    @StateObject private var searchCompleter = LocationSearchCompleter()
    @State private var showLocationPicker = false
    @State private var showSuggestions = false
    @State private var searchDebounceTask: DispatchWorkItem?
    @State private var isProgrammaticUpdate = false
    @State private var isGeocoding = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 标题
            HStack(spacing: 4) {
                Text(title)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                if isRequired {
                    Text("*")
                        .foregroundColor(AppColors.error)
                }
            }
            
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // 输入框和地图按钮
                    inputRow
                    
                    // 常用位置快捷选择
                    if isFocused && location.isEmpty {
                        quickLocationButtons
                    }
                }
                
                // 搜索建议列表
                if showSuggestions && !searchCompleter.searchResults.isEmpty {
                    suggestionsList
                        .offset(y: 52)
                }
            }
        }
        .sheet(isPresented: $showLocationPicker) {
            NavigationView {
                LocationPickerView(
                    selectedLocation: $location,
                    selectedLatitude: $latitude,
                    selectedLongitude: $longitude
                )
            }
        }
    }
    
    // MARK: - 输入框行
    
    private var inputRow: some View {
        HStack(spacing: 8) {
            // 位置输入框
            HStack(spacing: 10) {
                // Online 切换按钮（只显示图标）
                if showOnlineOption {
                    Button(action: {
                        toggleOnline()
                        HapticFeedback.medium()
                    }) {
                        Image(systemName: isOnline ? "globe.americas.fill" : "mappin.and.ellipse")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(isOnline ? AppColors.success.opacity(0.12) : AppColors.primary.opacity(0.08))
                            )
                            .foregroundColor(isOnline ? AppColors.success : AppColors.primary)
                            .overlay(
                                Circle()
                                    .stroke(isOnline ? AppColors.success.opacity(0.3) : AppColors.primary.opacity(0.15), lineWidth: 1)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                // 文本输入
                TextField(placeholder, text: $location)
                    .font(AppTypography.body)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .onChange(of: location) { newValue in
                        handleLocationChange(newValue)
                    }
                    .onChange(of: isFocused) { focused in
                        if !focused {
                            showSuggestions = false
                            geocodeIfNeeded()
                        }
                    }
                
                // 状态指示器
                statusIndicators
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(AppColors.background)
            .cornerRadius(AppCornerRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(isFocused ? AppColors.primary : AppColors.separator, lineWidth: isFocused ? 2 : 1)
            )
            
            // 地图选点按钮
            mapPickerButton
        }
    }
    
    // MARK: - 状态指示器
    
    private var statusIndicators: some View {
        HStack(spacing: 8) {
            // 地理编码中
            if isGeocoding {
                ProgressView()
                    .scaleEffect(0.7)
            }
            
            // 清除按钮
            if !location.isEmpty {
                Button(action: clearLocation) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.system(size: 16))
                }
            }
            
            // 已验证位置指示器
            if hasValidCoordinates {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.success)
                    .font(.system(size: 16))
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: hasValidCoordinates)
    }
    
    // MARK: - 地图选点按钮
    
    private var mapPickerButton: some View {
        Button(action: {
            showSuggestions = false
            isFocused = false
            showLocationPicker = true
            HapticFeedback.light()
        }) {
            Image(systemName: "map")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(AppColors.primary)
                .cornerRadius(AppCornerRadius.medium)
        }
    }
    
    // MARK: - 快捷位置按钮
    
    private var quickLocationButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Online 按钮
                QuickLocationButton(title: "🌐 Online", isSelected: isOnline) {
                    selectQuickLocation("Online", lat: nil, lon: nil)
                }
                
                // 常用UK城市
                ForEach(popularUKCities, id: \.name) { city in
                    QuickLocationButton(title: "📍 \(city.name)", isSelected: location.contains(city.name)) {
                        selectQuickLocation("\(city.name), UK", lat: city.lat, lon: city.lon)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - 搜索建议列表
    
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            // 关闭按钮
            HStack {
                Spacer()
                Button(action: {
                    showSuggestions = false
                    isFocused = false
                    HapticFeedback.light()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(AppColors.textSecondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(AppColors.cardBackground)
            
            Divider()
            
            // 性能优化：使用缓存的前5个结果，避免重复计算 prefix
            ForEach(topSearchResults, id: \.hashValue) { result in
                Button(action: {
                    selectSuggestion(result)
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
                
                // 性能优化：使用缓存的结果判断是否是最后一个
                if result != topSearchResults.last {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
    
    // MARK: - Computed Properties
    
    private var isOnline: Bool {
        location.lowercased() == "online"
    }
    
    private var hasValidCoordinates: Bool {
        latitude != nil && longitude != nil
    }
    
    /// 排序后的搜索结果 - UK 优先
    private var sortedSearchResults: [MKLocalSearchCompletion] {
        searchCompleter.searchResults.sorted { a, b in
            let aIsUK = isUKLocation(a)
            let bIsUK = isUKLocation(b)
            if aIsUK && !bIsUK { return true }
            if !aIsUK && bIsUK { return false }
            return false
        }
    }
    
    // 性能优化：缓存前5个搜索结果，避免重复计算
    private var topSearchResults: [MKLocalSearchCompletion] {
        Array(sortedSearchResults.prefix(5))
    }
    
    /// 常用UK城市
    private var popularUKCities: [(name: String, lat: Double, lon: Double)] {
        [
            ("London", 51.5074, -0.1278),
            ("Birmingham", 52.4862, -1.8904),
            ("Manchester", 53.4808, -2.2426),
            ("Edinburgh", 55.9533, -3.1883),
            ("Glasgow", 55.8642, -4.2518),
            ("Liverpool", 53.4084, -2.9916),
            ("Bristol", 51.4545, -2.5879),
            ("Leeds", 53.8008, -1.5491)
        ]
    }
    
    // MARK: - Helper Methods
    
    private func isUKLocation(_ result: MKLocalSearchCompletion) -> Bool {
        let text = (result.title + " " + result.subtitle).lowercased()
        return text.contains("uk") || text.contains("united kingdom") || 
               text.contains("england") || text.contains("scotland") ||
               text.contains("wales") || text.contains("northern ireland")
    }
    
    private func handleLocationChange(_ newValue: String) {
        // 程序设置的值，不触发搜索
        if isProgrammaticUpdate {
            isProgrammaticUpdate = false
            return
        }
        
        // 防抖处理
        searchDebounceTask?.cancel()
        
        // Online 或空值不触发搜索
        if newValue.lowercased() == "online" || newValue.isEmpty {
            showSuggestions = false
            searchCompleter.searchResults = []
            return
        }
        
        // 手动输入时清除坐标
        latitude = nil
        longitude = nil
        
        let task = DispatchWorkItem {
            searchCompleter.search(query: newValue)
            showSuggestions = true
        }
        searchDebounceTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
    }
    
    private func toggleOnline() {
        isProgrammaticUpdate = true
        location = "Online"
        latitude = nil
        longitude = nil
        showSuggestions = false
        searchCompleter.searchResults = []
        isFocused = false
        HapticFeedback.light()
    }
    
    private func clearLocation() {
        location = ""
        latitude = nil
        longitude = nil
        showSuggestions = false
        searchCompleter.searchResults = []
    }
    
    private func selectQuickLocation(_ loc: String, lat: Double?, lon: Double?) {
        isProgrammaticUpdate = true
        location = loc
        latitude = lat
        longitude = lon
        showSuggestions = false
        isFocused = false
        HapticFeedback.success()
    }
    
    private func selectSuggestion(_ result: MKLocalSearchCompletion) {
        isProgrammaticUpdate = true
        showSuggestions = false
        isFocused = false
        HapticFeedback.light()
        
        // 执行搜索获取精确坐标
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                if let mapItem = response?.mapItems.first {
                    let coordinate = mapItem.placemark.coordinate
                    
                    // 保存完整地址
                    if !result.subtitle.isEmpty {
                        location = "\(result.title), \(result.subtitle)"
                    } else {
                        location = result.title
                    }
                    
                    latitude = coordinate.latitude
                    longitude = coordinate.longitude
                    
                    HapticFeedback.success()
                }
            }
        }
    }
    
    private func geocodeIfNeeded() {
        // 如果已有坐标或地址为空/Online，不需要地理编码
        guard !location.isEmpty,
              !location.lowercased().contains("online"),
              latitude == nil || longitude == nil else {
            return
        }
        
        isGeocoding = true
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(location) { placemarks, error in
            DispatchQueue.main.async {
                isGeocoding = false
                
                if let placemark = placemarks?.first,
                   let loc = placemark.location {
                    latitude = loc.coordinate.latitude
                    longitude = loc.coordinate.longitude
                    HapticFeedback.success()
                }
            }
        }
    }
}

// MARK: - 快捷位置按钮

private struct QuickLocationButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : AppColors.textPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? AppColors.primary : AppColors.background)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.clear : AppColors.separator, lineWidth: 1)
                )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        LocationInputField(
            location: .constant(""),
            latitude: .constant(nil),
            longitude: .constant(nil),
            title: "任务位置",
            isRequired: true
        )
        
        LocationInputField(
            location: .constant("Birmingham, UK"),
            latitude: .constant(52.4862),
            longitude: .constant(-1.8904),
            title: "交易地点"
        )
        
        LocationInputField(
            location: .constant("Online"),
            latitude: .constant(nil),
            longitude: .constant(nil),
            title: "位置"
        )
    }
    .padding()
}

