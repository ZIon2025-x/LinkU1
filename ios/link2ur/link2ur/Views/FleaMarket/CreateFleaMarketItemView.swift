import SwiftUI
import PhotosUI
import UIKit
import MapKit

@available(iOS 16.0, *)
struct CreateFleaMarketItemView: View {
    @StateObject private var viewModel = CreateFleaMarketItemViewModel()
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
            KeyboardAvoidingScrollView(extraPadding: 20) {
                VStack(spacing: AppSpacing.xl) {
                    // 1. 基本信息
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "商品信息", icon: "bag.fill")
                        
                        VStack(spacing: AppSpacing.lg) {
                            // 标题
                            EnhancedTextField(
                                title: "商品标题",
                                placeholder: "品牌、型号、成色等 (例: iPhone 15 Pro)",
                                text: $viewModel.title,
                                icon: "tag.fill",
                                isRequired: true
                            )
                            
                            // 分类
                            CustomPickerField(
                                title: "商品分类",
                                selection: $viewModel.category,
                                options: viewModel.categories.map { ($0, $0) },
                                icon: "list.bullet.indent"
                            )
                            
                            // 描述
                            EnhancedTextEditor(
                                title: "详情描述",
                                placeholder: "请详细描述商品信息、成色、使用情况、转手原因等...",
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
                    
                    // 2. 价格与交易
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        SectionHeader(title: "价格与交易", icon: "dollarsign.circle.fill")
                        
                        VStack(spacing: AppSpacing.lg) {
                            // 价格
                            EnhancedNumberField(
                                title: "出售价格",
                                placeholder: "0.00",
                                value: $viewModel.price,
                                prefix: "£",
                                suffix: "GBP",
                                isRequired: true
                            )
                            
                            // 位置选择 - 带搜索建议
                            locationInputSection
                            
                            // 联系方式
                            EnhancedTextField(
                                title: "联系方式",
                                placeholder: "微信、电话或 WhatsApp",
                                text: $viewModel.contact,
                                icon: "phone.fill"
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
                            SectionHeader(title: "商品图片", icon: "photo.on.rectangle.angled")
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
                                            Text("添加图片")
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
                            viewModel.createItem { success in
                                if success {
                                    dismiss()
                                }
                            }
                        } else {
                            showLogin = true
                        }
                    }) {
                        HStack(spacing: 8) {
                            if viewModel.isLoading || viewModel.isUploading {
                                ProgressView().tint(.white)
                            } else {
                                IconStyle.icon("cart.fill.badge.plus", size: 18)
                            }
                            Text(viewModel.isLoading || viewModel.isUploading ? "正在发布..." : "立即发布商品")
                                .font(AppTypography.bodyBold)
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(viewModel.isLoading || viewModel.isUploading || viewModel.title.isEmpty || viewModel.price == nil)
                    .padding(.top, AppSpacing.lg)
                    .padding(.bottom, AppSpacing.xxl)
                }
                .padding(AppSpacing.md)
                .padding(.bottom, 20)
            }
            .background(AppColors.background)
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("发布商品")
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
                        selectedLocation: $viewModel.location,
                        selectedLatitude: $viewModel.latitude,
                        selectedLongitude: $viewModel.longitude
                    )
                }
            }
            .onDisappear {
                // 用户体验优化：视图消失时自动收起键盘
                isLocationFocused = false
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
            Text("交易地点")
                .font(AppTypography.subheadline)
                .foregroundColor(AppColors.textSecondary)
            
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // 输入框和地图按钮
                    HStack(spacing: 8) {
                        // 位置输入框
                        HStack(spacing: 10) {
                            // 点击切换为 Online 模式
                            Button(action: {
                                isProgrammaticLocationUpdate = true
                                viewModel.location = "Online"
                                viewModel.latitude = nil
                                viewModel.longitude = nil
                                showLocationSuggestions = false
                                locationSearchCompleter.searchResults = []
                                isLocationFocused = false
                                HapticFeedback.medium()
                            }) {
                                let isOnline = viewModel.location.lowercased() == "online"
                                HStack(spacing: 4) {
                                    Image(systemName: isOnline ? "globe.americas.fill" : "mappin.and.ellipse")
                                        .font(.system(size: 14, weight: .bold))
                                    
                                    if isOnline {
                                        Text("Online")
                                            .font(.system(size: 11, weight: .heavy))
                                            .textCase(.uppercase)
                                    } else {
                                        Text("线上")
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
                            
                            TextField("搜索地点或输入 Online", text: $viewModel.location)
                                .font(AppTypography.body)
                                .autocorrectionDisabled()
                                .focused($isLocationFocused)
                                .onChange(of: viewModel.location) { newValue in
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
                            if !viewModel.location.isEmpty {
                                Button(action: {
                                    viewModel.location = ""
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
                        viewModel.location = "\(result.title), \(result.subtitle)"
                    } else {
                        viewModel.location = result.title
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
        // 如果已经有经纬度或者地址为空/Online，则不需要地理编码
        guard !viewModel.location.isEmpty,
              viewModel.location.lowercased() != "online",
              viewModel.latitude == nil || viewModel.longitude == nil else {
            return
        }
        
        isSearchingLocation = true
        
        let geocoder = CLGeocoder()
        geocoder.geocodeAddressString(viewModel.location) { placemarks, error in
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
