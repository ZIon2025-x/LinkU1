import SwiftUI
import PhotosUI
import UIKit
import MapKit
import CoreLocation

@available(iOS 16.0, *)
struct CreateTaskView: View {
    @StateObject private var viewModel = CreateTaskViewModel()
    @StateObject private var locationSearchCompleter = LocationSearchCompleter()
    @ObservedObject private var locationService = LocationService.shared
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showLogin = false
    @State private var showLocationPicker = false
    @State private var showLocationSuggestions = false
    @State private var isSearchingLocation = false
    @State private var isGettingCurrentLocation = false  // 正在获取当前位置
    @State private var searchDebounceTask: DispatchWorkItem?
    @State private var isProgrammaticLocationUpdate = false  // 标记是否是程序设置（非用户手动输入）
    @FocusState private var isLocationFocused: Bool
    @StateObject private var visibilityHolder = ViewVisibilityHolder() // 避免异步回调在视图销毁后更新 @State
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: DeviceInfo.isPad ? AppSpacing.xxl : AppSpacing.xl) {
                        // 1. 基本信息
                        VStack(alignment: .leading, spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                            SectionHeader(title: LocalizationKey.createTaskBasicInfo.localized, icon: "doc.text.fill")
                            
                            VStack(spacing: DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg) {
                                // 标题
                                EnhancedTextField(
                                    title: LocalizationKey.createTaskTitle.localized,
                                    placeholder: LocalizationKey.createTaskTitlePlaceholder.localized,
                                    text: $viewModel.title,
                                    icon: "pencil.line",
                                    isRequired: true
                                )
                                
                                // 描述
                                EnhancedTextEditor(
                                    title: LocalizationKey.createTaskDescription.localized,
                                    placeholder: LocalizationKey.createTaskDescriptionPlaceholder.localized,
                                    text: $viewModel.description,
                                    height: DeviceInfo.isPad ? 200 : 150,
                                    isRequired: true,
                                    characterLimit: 1000
                                )
                            }
                        }
                        .padding(DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 2. 报酬与地点
                        VStack(alignment: .leading, spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                            SectionHeader(title: LocalizationKey.createTaskRewardLocation.localized, icon: "dollarsign.circle.fill")
                            
                            VStack(spacing: DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg) {
                                // 价格（固定英镑）
                                EnhancedNumberField(
                                    title: LocalizationKey.createTaskReward.localized,
                                    placeholder: "0.00",
                                    value: $viewModel.price,
                                    prefix: "£",
                                    suffix: "GBP",
                                    isRequired: true
                                )
                                
                                // 位置选择 - 带搜索建议
                                locationInputSection
                                
                                // 任务类型
                                CustomPickerField(
                                    title: LocalizationKey.createTaskTaskType.localized,
                                    selection: $viewModel.taskType,
                                    options: viewModel.taskTypes.map { ($0.value, $0.label) },
                                    icon: "tag.fill"
                                )
                                
                                // 校园生活类型权限提示
                                if viewModel.taskType == "Campus Life" && viewModel.studentVerificationStatus?.isVerified != true {
                                    HStack(spacing: 8) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.system(size: 14))
                                            .foregroundColor(AppColors.warning)
                                        Text(LocalizationKey.createTaskCampusLifeRestriction.localized)
                                            .font(AppTypography.caption)
                                            .foregroundColor(AppColors.warning)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(AppColors.warning.opacity(0.1))
                                    .cornerRadius(AppCornerRadius.medium)
                                }
                            }
                        }
                        .padding(DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 3. 图片展示
                        VStack(alignment: .leading, spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                            HStack {
                                SectionHeader(title: LocalizationKey.createTaskImages.localized, icon: "photo.on.rectangle.angled")
                                Spacer()
                                Text("\(viewModel.selectedImages.count)/5")
                                    .font(AppTypography.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(AppColors.primary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.primaryLight)
                                    .clipShape(Capsule())
                            }
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: AppSpacing.md) {
                                    // 添加按钮
                                    if viewModel.selectedImages.count < 5 {
                                        PhotosPicker(selection: $selectedItems, maxSelectionCount: 5 - viewModel.selectedImages.count, matching: .images) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "plus.viewfinder")
                                                    .font(.system(size: 28))
                                                    .foregroundColor(AppColors.primary)
                                                Text(LocalizationKey.createTaskAddImages.localized)
                                                    .font(.system(size: 11, weight: .medium))
                                                    .foregroundColor(AppColors.textSecondary)
                                            }
                                            .frame(width: 90, height: 90)
                                            .background(AppColors.background)
                                            .cornerRadius(AppCornerRadius.medium)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                                    .stroke(AppColors.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [5, 3]))
                                            )
                                        }
                                        .onChange(of: selectedItems) { _ in
                                            handleImageSelection()
                                        }
                                    }
                                    
                                    // 图片预览
                                    ForEach(Array(viewModel.selectedImages.enumerated()), id: \.offset) { index, image in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: 90, height: 90)
                                                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
                                            
                                            Button(action: {
                                                withAnimation {
                                                    viewModel.selectedImages.remove(at: index)
                                                    selectedItems = []
                                                    HapticFeedback.light()
                                                }
                                            }) {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.black.opacity(0.5)))
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 错误提示
                        if let errorMessage = viewModel.errorMessage {
                            HStack(spacing: 8) {
                                IconStyle.icon("exclamationmark.octagon.fill", size: 16)
                                Text(errorMessage)
                                    .font(AppTypography.caption)
                                    .fontWeight(.medium)
                            }
                            .foregroundColor(AppColors.error)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppColors.error.opacity(0.08))
                            .cornerRadius(AppCornerRadius.medium)
                        }
                        
                        // 提交按钮
                        Button(action: {
                            if appState.isAuthenticated {
                                HapticFeedback.success()
                                viewModel.createTask { success in
                                    if success {
                                        dismiss()
                                    }
                                }
                            } else {
                                showLogin = true
                            }
                        }) {
                            HStack(spacing: 8) {
                                if viewModel.isLoading {
                                    ProgressView().tint(.white)
                                } else {
                                    IconStyle.icon("paperplane.fill", size: 18)
                                }
                                Text(viewModel.isLoading ? LocalizationKey.createTaskPublishing.localized : LocalizationKey.createTaskPublishNow.localized)
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isLoading || viewModel.isUploading)
                        .padding(.top, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg)
                        .padding(.bottom, DeviceInfo.isPad ? AppSpacing.xxl : AppSpacing.xxl)
                    }
                    .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                    .padding(.top, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
                    .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                    .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(LocalizationKey.createTaskPublishTask.localized)
            .navigationBarTitleDisplayMode(.inline)
            .enableSwipeBack()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(LocalizationKey.commonCancel.localized) {
                        dismiss()
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                isLocationFocused = false
                hideKeyboard()
            }
            .sheet(isPresented: $showLogin) {
                LoginView()
            }
            .sheet(isPresented: $showLocationPicker) {
                NavigationView {
                    LocationPickerView(
                        selectedLocation: $viewModel.city,
                        selectedLatitude: $viewModel.latitude,
                        selectedLongitude: $viewModel.longitude
                    )
                }
            }
            .onDisappear {
                visibilityHolder.isVisible = false
                isLocationFocused = false
            }
            .onAppear {
                visibilityHolder.isVisible = true
                if !appState.isAuthenticated {
                    showLogin = true
                }
            }
        }
    }
    
    // MARK: - 位置输入区域（带搜索建议）
    
    private var locationInputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(LocalizationKey.createTaskCity.localized)
                    .font(AppTypography.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                if viewModel.city.isEmpty {
                    Text("*")
                        .foregroundColor(AppColors.error)
                }
            }
            
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // 输入框和地图按钮
                    HStack(spacing: 8) {
                        // 位置输入框
                        HStack(spacing: 10) {
                            // 点击切换为 Online 模式
                            Button(action: {
                                isProgrammaticLocationUpdate = true
                                viewModel.city = "Online"
                                viewModel.latitude = nil
                                viewModel.longitude = nil
                                showLocationSuggestions = false
                                locationSearchCompleter.searchResults = []
                                isLocationFocused = false
                                HapticFeedback.medium()
                            }) {
                                let isOnline = viewModel.city.lowercased() == "online"
                                HStack(spacing: 4) {
                                    Image(systemName: isOnline ? "globe.americas.fill" : "mappin.and.ellipse")
                                        .font(.system(size: 14, weight: .bold))
                                    
                                    if isOnline {
                                        Text("Online")
                                            .font(.system(size: 11, weight: .heavy))
                                            .textCase(.uppercase)
                                    } else {
                                        Text(LocalizationKey.createTaskOnline.localized)
                                            .font(.system(size: 11, weight: .bold))
                                    }
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(isOnline ? AppColors.success.opacity(0.12) : AppColors.primary.opacity(0.08))
                                )
                                .foregroundColor(isOnline ? AppColors.success : AppColors.primary)
                                .overlay(
                                    Capsule()
                                        .stroke(isOnline ? AppColors.success.opacity(0.3) : AppColors.primary.opacity(0.15), lineWidth: 1)
                                )
                            }
                            
                            TextField(LocalizationKey.taskLocationSearchCity.localized, text: $viewModel.city)
                                .font(AppTypography.body)
                                .autocorrectionDisabled()
                                .focused($isLocationFocused)
                                .onChange(of: viewModel.city) { newValue in
                                    // 如果是程序设置的值，不触发搜索和清除坐标
                                    if isProgrammaticLocationUpdate {
                                        isProgrammaticLocationUpdate = false
                                        return
                                    }
                                    
                                    // 防抖处理
                                    searchDebounceTask?.cancel()
                                    
                                    // 如果是 Online 或为空，不触发搜索
                                    if newValue.lowercased() == "online" || newValue.isEmpty {
                                        showLocationSuggestions = false
                                        locationSearchCompleter.searchResults = []
                                        return
                                    }
                                    
                                    // 手动输入时清除坐标
                                    viewModel.latitude = nil
                                    viewModel.longitude = nil
                                    
                                    let task = DispatchWorkItem {
                                        locationSearchCompleter.search(query: newValue)
                                        showLocationSuggestions = true
                                    }
                                    searchDebounceTask = task
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: task)
                                }
                                .onChange(of: isLocationFocused) { focused in
                                    // 当失去焦点时，如果有地址但没有经纬度，自动进行地理编码
                                    if !focused {
                                        showLocationSuggestions = false
                                        geocodeAddressIfNeeded()
                                    }
                                }
                            
                            // 搜索加载指示器
                            if locationSearchCompleter.isSearching || isSearchingLocation || isGettingCurrentLocation {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            
                            // 清除按钮
                            if !viewModel.city.isEmpty && !locationSearchCompleter.isSearching && !isSearchingLocation && !isGettingCurrentLocation {
                                Button(action: {
                                    viewModel.city = ""
                                    viewModel.latitude = nil
                                    viewModel.longitude = nil
                                    showLocationSuggestions = false
                                    locationSearchCompleter.searchResults = []
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(AppColors.textSecondary)
                                        .font(.system(size: 16))
                                }
                            }
                            
                            // 已选择位置的指示器
                            if viewModel.latitude != nil && viewModel.longitude != nil && !isSearchingLocation && !isGettingCurrentLocation {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(AppColors.success)
                                    .font(.system(size: 16))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(AppColors.background)
                        .cornerRadius(AppCornerRadius.medium)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                                .stroke(AppColors.separator, lineWidth: 1)
                        )
                        
                        // 地图选点按钮
                        Button(action: {
                            showLocationSuggestions = false
                            showLocationPicker = true
                        }) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(AppColors.primary)
                                .cornerRadius(AppCornerRadius.medium)
                        }
                    }
                    
                    // 快捷操作按钮行
                    HStack(spacing: 8) {
                        // 使用当前位置按钮
                        Button(action: {
                            useCurrentLocation()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 12))
                                Text(LocalizationKey.locationCurrentLocation.localized)
                                    .font(.system(size: 12, weight: .medium))
                                if isGettingCurrentLocation {
                                    ProgressView()
                                        .scaleEffect(0.6)
                                }
                            }
                            .foregroundColor(AppColors.primary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(AppColors.primaryLight)
                            .cornerRadius(AppCornerRadius.small)
                        }
                        .disabled(isGettingCurrentLocation)
                        
                        Spacer()
                        
                        // 坐标提示（如果已选择）
                        if let lat = viewModel.latitude, let lon = viewModel.longitude {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 10))
                                Text(String(format: "%.4f, %.4f", lat, lon))
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(AppColors.textSecondary)
                        }
                    }
                    .padding(.top, 8)
                    
                    // 搜索建议列表
                    if showLocationSuggestions && !locationSearchCompleter.searchResults.isEmpty {
                        locationSuggestionsList
                    }
                }
            }
        }
    }
    
    /// 使用当前位置
    private func useCurrentLocation() {
        // 检查位置权限
        if !locationService.isAuthorized {
            locationService.requestAuthorization()
            return
        }
        
        isGettingCurrentLocation = true
        showLocationSuggestions = false
        isLocationFocused = false
        HapticFeedback.light()
        
        // 请求位置更新
        locationService.requestLocation()
        
        // 如果已有位置，立即使用
        if let location = locationService.currentLocation {
            handleCurrentLocation(latitude: location.latitude, longitude: location.longitude)
        } else {
            // 等待位置更新（最多3秒）；使用 visibilityHolder 避免视图销毁后仍更新 @State
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [visibilityHolder, self] in
                guard visibilityHolder.isVisible else { return }
                if let location = locationService.currentLocation {
                    handleCurrentLocation(latitude: location.latitude, longitude: location.longitude)
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [visibilityHolder, self] in
                        guard visibilityHolder.isVisible else { return }
                        if let location = locationService.currentLocation {
                            handleCurrentLocation(latitude: location.latitude, longitude: location.longitude)
                        } else {
                            isGettingCurrentLocation = false
                            HapticFeedback.error()
                        }
                    }
                }
            }
        }
    }
    
    /// 处理获取到的当前位置
    private func handleCurrentLocation(latitude: Double, longitude: Double) {
        viewModel.latitude = latitude
        viewModel.longitude = longitude
        
        // 反向地理编码获取地址
        let geocoder = CLGeocoder()
        let location = CLLocation(latitude: latitude, longitude: longitude)
        
        geocoder.reverseGeocodeLocation(location) { placemarks, error in
            DispatchQueue.main.async {
                isGettingCurrentLocation = false
                
                if let placemark = placemarks?.first {
                    var addressParts: [String] = []
                    
                    // 地点名称
                    if let name = placemark.name,
                       name != placemark.locality,
                       name != placemark.subLocality {
                        addressParts.append(name)
                    }
                    
                    // 城市
                    if let locality = placemark.locality {
                        addressParts.append(locality)
                    }
                    
                    // 邮编
                    if let postalCode = placemark.postalCode {
                        addressParts.append(postalCode)
                    }
                    
                    isProgrammaticLocationUpdate = true
                    viewModel.city = addressParts.isEmpty ? "当前位置" : addressParts.joined(separator: ", ")
                    HapticFeedback.success()
                } else {
                    // 地理编码失败，使用坐标作为地址
                    isProgrammaticLocationUpdate = true
                    viewModel.city = String(format: "%.4f, %.4f", latitude, longitude)
                    HapticFeedback.warning()
                }
            }
        }
    }
    
    // MARK: - 位置搜索建议列表
    
    private var locationSuggestionsList: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundColor(AppColors.textSecondary)
                    Text(LocalizationKey.searchResultsTitle.localized)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(AppColors.textSecondary)
                    
                    // 搜索中指示器
                    if locationSearchCompleter.isSearching {
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    showLocationSuggestions = false
                    isLocationFocused = false
                    hideKeyboard()
                    HapticFeedback.light()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(AppColors.cardBackground)
            
            Divider()
            
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(locationSearchCompleter.searchResults.prefix(6).enumerated()), id: \.element) { index, result in
                        Button(action: {
                            selectLocationSuggestion(result)
                        }) {
                            HStack(spacing: 12) {
                                // 位置图标（UK地址使用特殊样式）
                                ZStack {
                                    Circle()
                                        .fill(isUKLocation(result) ? AppColors.primary.opacity(0.15) : AppColors.background)
                                        .frame(width: 36, height: 36)
                                    
                                    Image(systemName: isUKLocation(result) ? "mappin.circle.fill" : "mappin.and.ellipse")
                                        .foregroundColor(isUKLocation(result) ? AppColors.primary : AppColors.textSecondary)
                                        .font(.system(size: 16))
                                }
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(result.title)
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(AppColors.textPrimary)
                                            .lineLimit(1)
                                        
                                        // UK 标识
                                        if isUKLocation(result) {
                                            Text("UK")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(AppColors.primary)
                                                .cornerRadius(3)
                                        }
                                    }
                                    
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.system(size: 13))
                                            .foregroundColor(AppColors.textSecondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(AppColors.textSecondary.opacity(0.5))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(AppColors.cardBackground)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        if index < min(locationSearchCompleter.searchResults.count, 6) - 1 {
                            Divider()
                                .padding(.leading, 62)
                        }
                    }
                }
            }
            .frame(maxHeight: 300)
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                .stroke(AppColors.separator.opacity(0.5), lineWidth: 1)
        )
        .padding(.top, 6)
    }
    
    /// 判断搜索结果是否为 UK 地址
    private func isUKLocation(_ result: MKLocalSearchCompletion) -> Bool {
        let text = (result.title + " " + result.subtitle).lowercased()
        return text.contains("uk") || text.contains("united kingdom") ||
               text.contains("england") || text.contains("scotland") ||
               text.contains("wales") || text.contains("northern ireland")
    }
    
    // MARK: - Helper Methods
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    private func selectLocationSuggestion(_ result: MKLocalSearchCompletion) {
        isSearchingLocation = true
        showLocationSuggestions = false
        isLocationFocused = false // 隐藏键盘
        HapticFeedback.light()
        
        let searchRequest = MKLocalSearch.Request(completion: result)
        let search = MKLocalSearch(request: searchRequest)
        
        search.start { response, error in
            DispatchQueue.main.async {
                isSearchingLocation = false
                
                if let mapItem = response?.mapItems.first {
                    let coordinate = mapItem.placemark.coordinate
                    
                    // 更新位置信息（先设置坐标）
                    viewModel.latitude = coordinate.latitude
                    viewModel.longitude = coordinate.longitude
                    
                    // 标记为程序设置，避免 onChange 清除坐标
                    isProgrammaticLocationUpdate = true
                    
                    // 优先使用搜索结果的原始标题（保留邮编等详细信息）
                    // 如果有副标题，组合显示
                    if !result.subtitle.isEmpty {
                        viewModel.city = "\(result.title), \(result.subtitle)"
                    } else {
                        viewModel.city = result.title
                    }
                    
                    // 清空搜索结果
                    locationSearchCompleter.searchResults = []
                    
                    HapticFeedback.success()
                }
            }
        }
    }
    
    /// 当用户手动输入地址但没有从建议列表选择时，自动进行地理编码获取经纬度
    private func geocodeAddressIfNeeded() {
        // 如果已经有经纬度或者地址为空，则不需要地理编码
        guard !viewModel.city.isEmpty,
              viewModel.city.lowercased() != "online",
              viewModel.latitude == nil || viewModel.longitude == nil else {
            return
        }
        
        isSearchingLocation = true
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(viewModel.city) { placemarks, error in
            DispatchQueue.main.async {
                isSearchingLocation = false
                
                if let placemark = placemarks?.first,
                   let location = placemark.location {
                    viewModel.latitude = location.coordinate.latitude
                    viewModel.longitude = location.coordinate.longitude
                    HapticFeedback.success()
                }
            }
        }
    }
    
    private func handleImageSelection() {
        _Concurrency.Task {
            for item in selectedItems {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        if viewModel.selectedImages.count < 5 {
                            viewModel.selectedImages.append(image)
                        }
                    }
                }
            }
            selectedItems = [] // 清空以备下次选择
        }
    }
}
