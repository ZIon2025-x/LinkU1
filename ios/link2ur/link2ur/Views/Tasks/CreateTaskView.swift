import SwiftUI
import PhotosUI
import UIKit
import MapKit

@available(iOS 16.0, *)
struct CreateTaskView: View {
    @StateObject private var viewModel = CreateTaskViewModel()
    @StateObject private var locationSearchCompleter = LocationSearchCompleter()
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var appState: AppState
    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var showLogin = false
    @State private var showLocationPicker = false
    @State private var showLocationSuggestions = false
    @State private var isSearchingLocation = false
    @State private var searchDebounceTask: DispatchWorkItem?
    @State private var isProgrammaticLocationUpdate = false  // 标记是否是程序设置（非用户手动输入）
    @FocusState private var isLocationFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                KeyboardAvoidingScrollView(extraPadding: 20) {
                    VStack(spacing: AppSpacing.xl) {
                        // 1. 基本信息
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: LocalizationKey.createTaskBasicInfo.localized, icon: "doc.text.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                // 标题
                                EnhancedTextField(
                                    title: "任务标题",
                                    placeholder: "简要说明您的需求 (例: 代取包裹)",
                                    text: $viewModel.title,
                                    icon: "pencil.line",
                                    isRequired: true
                                )
                                
                                // 描述
                                EnhancedTextEditor(
                                    title: "任务详情",
                                    placeholder: "请详细描述您的需求、时间、特殊要求等，越详细越容易被接单哦...",
                                    text: $viewModel.description,
                                    height: 150,
                                    isRequired: true,
                                    characterLimit: 1000
                                )
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 2. 报酬与地点
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            SectionHeader(title: LocalizationKey.createTaskRewardLocation.localized, icon: "dollarsign.circle.fill")
                            
                            VStack(spacing: AppSpacing.lg) {
                                // 价格（固定英镑）
                                EnhancedNumberField(
                                    title: "任务酬金",
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
                            }
                        }
                        .padding(AppSpacing.md)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.large)
                        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
                        
                        // 3. 图片展示
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
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
                        .padding(AppSpacing.md)
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
                                Text(viewModel.isLoading ? "正在发布..." : "立即发布任务")
                                    .font(AppTypography.bodyBold)
                            }
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(viewModel.isLoading || viewModel.isUploading)
                        .padding(.top, AppSpacing.lg)
                        .padding(.bottom, AppSpacing.xxl)
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("发布任务")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
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
            .onAppear {
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
                Text("所在城市")
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
                                HapticFeedback.light()
                            }) {
                                Image(systemName: viewModel.city.lowercased() == "online" ? "globe" : "mappin.and.ellipse")
                                    .foregroundColor(viewModel.city.lowercased() == "online" ? AppColors.success : AppColors.primary)
                                    .frame(width: 20)
                            }
                            
                            TextField("搜索或输入城市名称", text: $viewModel.city)
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
                            
                            // 清除按钮
                            if !viewModel.city.isEmpty {
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
                            if viewModel.latitude != nil && viewModel.longitude != nil {
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
                    
                    // 搜索建议列表
                    if showLocationSuggestions && !locationSearchCompleter.searchResults.isEmpty {
                        locationSuggestionsList
                    }
                }
            }
            
            // 坐标提示（如果已选择）
            if let lat = viewModel.latitude, let lon = viewModel.longitude {
                HStack(spacing: 4) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 10))
                    Text(String(format: "%.4f, %.4f", lat, lon))
                        .font(.system(size: 11))
                }
                .foregroundColor(AppColors.textSecondary)
                .padding(.top, 4)
            }
        }
    }
    
    // MARK: - 位置搜索建议列表
    
    private var locationSuggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(locationSearchCompleter.searchResults.prefix(5).enumerated()), id: \.element) { index, result in
                Button(action: {
                    selectLocationSuggestion(result)
                }) {
                    HStack(spacing: 12) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundColor(AppColors.primary)
                            .font(.system(size: 18))
                        
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
                        
                        Image(systemName: "arrow.up.left")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(AppColors.cardBackground)
                }
                
                if index < min(locationSearchCompleter.searchResults.count, 5) - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
        .background(AppColors.cardBackground)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                .stroke(AppColors.separator, lineWidth: 1)
        )
        .padding(.top, 4)
    }
    
    // MARK: - Helper Methods
    
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
