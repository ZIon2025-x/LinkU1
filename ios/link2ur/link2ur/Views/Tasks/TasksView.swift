import SwiftUI
import Combine

struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @StateObject private var recommendedViewModel = TasksViewModel()  // 推荐任务 ViewModel
    @EnvironmentObject var appState: AppState  // 增强：用于检查登录状态
    @State private var searchText = ""
    @State private var showFilter = false
    @State private var selectedCategory: String?
    @State private var selectedCity: String? // 新增城市筛选状态
    @State private var allTasks: [Task] = []  // 合并后的任务列表（推荐任务优先）
    @State private var imagePreloadCancellables = Set<AnyCancellable>() // 图片预加载订阅
    
    // 任务分类映射 (显示名称 -> 后端值)
    let categories: [(name: String, value: String)] = [
        (LocalizationKey.taskCategoryAll.localized, ""),
        (LocalizationKey.taskCategoryHousekeeping.localized, "Housekeeping"),
        (LocalizationKey.taskCategoryCampusLife.localized, "Campus Life"),
        (LocalizationKey.taskCategorySecondhandRental.localized, "Second-hand & Rental"),
        (LocalizationKey.taskCategoryErrandRunning.localized, "Errand Running"),
        (LocalizationKey.taskCategorySkillService.localized, "Skill Service"),
        (LocalizationKey.taskCategorySocialHelp.localized, "Social Help"),
        (LocalizationKey.taskCategoryTransportation.localized, "Transportation"),
        (LocalizationKey.taskCategoryPetCare.localized, "Pet Care"),
        (LocalizationKey.taskCategoryLifeConvenience.localized, "Life Convenience"),
        (LocalizationKey.taskCategoryOther.localized, "Other")
    ]
    @State private var selectedCategoryIndex = 0
    @State private var hasAppliedOnboardingPreferences = false // 标记是否已应用引导偏好
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                    // 搜索栏 - 更现代的设计
                    HStack(spacing: 12) {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.textSecondary)
                                .font(.system(size: 16, weight: .medium))
                            
                            TextField(LocalizationKey.searchTaskPlaceholder.localized, text: $searchText)
                                .font(.system(size: 15))
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.search)
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 12)
                        .background(AppColors.cardBackground)
                        .cornerRadius(AppCornerRadius.pill)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppCornerRadius.pill)
                                .stroke(AppColors.separator.opacity(0.3), lineWidth: 1)
                        )
                        
                        if !searchText.isEmpty {
                            Button(LocalizationKey.commonSearch.localized) {
                                // 执行搜索，同时搜索推荐任务和普通任务
                                loadTasksWithRecommendations()
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.primary)
                        } else {
                            Button(action: {
                                showFilter = true
                            }) {
                                Image(systemName: "slider.horizontal.3")
                                    .foregroundColor(AppColors.primary)
                                    .font(.system(size: 18))
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.background)
                    
                    // 分类标签栏（横向滚动，固定位置，不能上下滑动）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<categories.count, id: \.self) { index in
                                CategoryTabButton(
                                    title: categories[index].name,
                                    isSelected: selectedCategoryIndex == index
                                ) {
                                    selectedCategoryIndex = index
                                    if categories[index].value.isEmpty {
                                        selectedCategory = nil
                                    } else {
                                        selectedCategory = categories[index].value
                                    }
                                    applyFilters()
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .background(AppColors.background)
                    
                    // 内容区域
                    if (viewModel.isLoading || recommendedViewModel.isLoading) && allTasks.isEmpty {
                        LoadingView()
                    } else if let error = viewModel.errorMessage, allTasks.isEmpty {
                        // 使用统一的错误状态组件
                        ErrorStateView(
                            message: error,
                            retryAction: {
                                // 重试时加载推荐任务和普通任务
                                loadTasksWithRecommendations()
                            }
                        )
                    } else if allTasks.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: LocalizationKey.emptyNoTasks.localized,
                            message: LocalizationKey.emptyNoTasksMessage.localized
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: AppSpacing.md),
                                GridItem(.flexible(), spacing: AppSpacing.md)
                            ], spacing: AppSpacing.md) {
                                ForEach(allTasks, id: \.id) { task in
                                    NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                        TaskCard(
                                            task: task,
                                            isRecommended: task.isRecommended == true,
                                            onNotInterested: {
                                                // 增强：记录跳过任务（用于推荐系统负反馈）
                                                recordTaskSkip(taskId: task.id)
                                            }
                                        )
                                        .drawingGroup() // 优化复杂卡片渲染性能
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .id(task.id) // 确保稳定的id，优化视图复用
                                    .onAppear {
                                        // 性能优化：只在接近最后一个任务时加载更多（提前3个）
                                        let threshold = max(0, allTasks.count - 3)
                                        if let index = allTasks.firstIndex(where: { $0.id == task.id }),
                                           index >= threshold {
                                            viewModel.loadMoreTasks()
                                        }
                                        
                                        // 图片预加载：预加载即将显示的任务图片（提前2个）
                                        if let index = allTasks.firstIndex(where: { $0.id == task.id }),
                                           index < allTasks.count - 2 {
                                            let nextIndex = index + 1
                                            if nextIndex < allTasks.count {
                                                let nextTask = allTasks[nextIndex]
                                                if let images = nextTask.images, let firstImage = images.first, !firstImage.isEmpty {
                                                    // 检查是否已缓存，未缓存则预加载
                                                    if ImageCache.shared.getCachedImage(from: firstImage) == nil {
                                                        ImageCache.shared.loadImage(from: firstImage)
                                                            .sink(receiveValue: { _ in })
                                                            .store(in: &imagePreloadCancellables)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                                
                                // 加载更多指示器
                                if viewModel.isLoadingMore || recommendedViewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        CompactLoadingView()
                                            .padding()
                                        Spacer()
                                    }
                                    .gridCellColumns(2)
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.md)
                        }
                        // 注意：不能在 ScrollView 上使用 drawingGroup，会阻止点击事件
                    }
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showFilter) {
                TaskFilterView(selectedCategory: $selectedCategory, selectedCity: $selectedCity)
            }
            // 点击空白区域关闭键盘
            .keyboardDismissable()
            // 性能优化：合并 onChange，使用防抖避免频繁调用
            .onChange(of: selectedCategory) { _ in
                applyFiltersWithDebounce()
            }
            .onChange(of: selectedCity) { _ in
                applyFiltersWithDebounce()
            }
            .refreshable {
                // 强制刷新，清除缓存并重新加载推荐任务和普通任务
                recommendedViewModel.loadRecommendedTasks(
                    limit: 20,
                    algorithm: "hybrid",
                    taskType: selectedCategory,
                    location: selectedCity,
                    keyword: searchText.isEmpty ? nil : searchText,
                    forceRefresh: true
                )
                viewModel.loadTasks(
                    category: selectedCategory,
                    city: selectedCity,
                    status: "open",
                    keyword: searchText.isEmpty ? nil : searchText,
                    forceRefresh: true
                )
            }
            .task {
                // 首次加载时，应用引导教程保存的个性化设置
                applyOnboardingPreferences()
                
                // 使用 task 替代 onAppear，避免重复加载
                if allTasks.isEmpty && !viewModel.isLoading && !recommendedViewModel.isLoading {
                    // 加载推荐任务和普通任务
                    loadTasksWithRecommendations()
                }
            }
            // 优化：使用防抖机制，减少频繁更新（减少延迟提升响应速度）
            .onChange(of: viewModel.tasks) { _ in
                // 立即更新，减少延迟（已使用防抖机制避免频繁调用）
                updateMergedTasks()
            }
            .onChange(of: recommendedViewModel.tasks) { _ in
                // 立即更新，减少延迟（已使用防抖机制避免频繁调用）
                updateMergedTasks()
            }
            // 监听任务更新通知，实时刷新推荐任务
            .onReceive(NotificationCenter.default.publisher(for: .taskUpdated)) { _ in
                // 用户交互后，延迟刷新推荐任务（避免频繁请求）
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                    if !recommendedViewModel.isLoading {
                        recommendedViewModel.loadRecommendedTasks(
                            limit: 20,
                            algorithm: "hybrid",
                            taskType: selectedCategory,
                            location: selectedCity,
                            keyword: searchText.isEmpty ? nil : searchText,
                            forceRefresh: false
                        )
                    }
                }
            }
        }
    
    @State private var filterWorkItem: DispatchWorkItem?
    
    private func applyFiltersWithDebounce() {
        // 取消之前的任务
        filterWorkItem?.cancel()
        
        // 创建新的防抖任务
        let workItem = DispatchWorkItem {
            applyFilters()
        }
        filterWorkItem = workItem
        
        // 延迟200ms执行，避免频繁调用（优化响应速度）
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: workItem)
    }
    
    private func applyFilters() {
        // 重新加载任务，应用筛选条件（只显示开放中的任务）
        // 同时加载推荐任务和普通任务，推荐任务优先显示
        loadTasksWithRecommendations()
    }
    
    /// 加载任务（推荐任务优先）
    private func loadTasksWithRecommendations() {
        // 先加载推荐任务
        recommendedViewModel.loadRecommendedTasks(
            limit: 20,
            algorithm: "hybrid",
            taskType: selectedCategory,
            location: selectedCity,
            keyword: searchText.isEmpty ? nil : searchText,
            forceRefresh: false
        )
        
        // 然后加载普通任务
        viewModel.loadTasks(
            category: selectedCategory,
            city: selectedCity,
            status: "open",
            keyword: searchText.isEmpty ? nil : searchText,
            forceRefresh: false
        )
        
        // 监听两个 ViewModel 的变化，合并任务列表
        updateMergedTasks()
    }
    
    /// 应用引导教程保存的个性化设置
    private func applyOnboardingPreferences() {
        // 只应用一次，避免重复应用
        guard !hasAppliedOnboardingPreferences else { return }
        hasAppliedOnboardingPreferences = true
        
        // 读取保存的偏好城市
        if let preferredCity = UserDefaults.standard.string(forKey: "preferred_city"),
           !preferredCity.isEmpty {
            selectedCity = preferredCity
            print("✅ [TasksView] 应用引导偏好城市: \(preferredCity)")
        }
        
        // 读取保存的偏好任务类型
        if let preferredTaskTypes = UserDefaults.standard.array(forKey: "preferred_task_types") as? [String],
           !preferredTaskTypes.isEmpty {
            // 将本地化的显示名称转换为后端值
            // 引导教程中保存的是本地化名称（如"跑腿代购"），需要转换为后端值（如"Errand Running"）
            let taskTypeMapping: [String: String] = [
                LocalizationKey.taskCategoryErrandRunning.localized: "Errand Running",
                LocalizationKey.taskCategorySkillService.localized: "Skill Service",
                LocalizationKey.taskCategoryHousekeeping.localized: "Housekeeping",
                LocalizationKey.taskCategoryTransportation.localized: "Transportation",
                LocalizationKey.taskCategorySocialHelp.localized: "Social Help",
                LocalizationKey.taskCategoryCampusLife.localized: "Campus Life",
                LocalizationKey.taskCategorySecondhandRental.localized: "Second-hand & Rental",
                LocalizationKey.taskCategoryPetCare.localized: "Pet Care",
                LocalizationKey.taskCategoryLifeConvenience.localized: "Life Convenience",
                LocalizationKey.taskCategoryOther.localized: "Other"
            ]
            
            // 如果用户只选择了一个任务类型，自动应用筛选
            if preferredTaskTypes.count == 1,
               let firstType = preferredTaskTypes.first,
               let backendValue = taskTypeMapping[firstType] {
                selectedCategory = backendValue
                print("✅ [TasksView] 应用引导偏好任务类型: \(firstType) -> \(backendValue)")
            }
        }
    }
    
    /// 更新合并后的任务列表（推荐任务优先）
    /// 优化：数据合并操作很快，直接在主线程处理即可
    /// 优化：只在数据真正变化时更新，避免不必要的视图重绘
    private func updateMergedTasks() {
        // 使用 Set 去重，推荐任务优先
        var taskMap: [Int: Task] = [:]
        
        // 先添加推荐任务
        for task in recommendedViewModel.tasks {
            taskMap[task.id] = task
        }
        
        // 再添加普通任务（如果不在推荐列表中）
        for task in viewModel.tasks {
            if taskMap[task.id] == nil {
                taskMap[task.id] = task
            }
        }
        
        // 转换为数组，推荐任务在前
        var mergedTasks: [Task] = []
        var addedIds = Set<Int>()
        
        // 先添加推荐任务
        for task in recommendedViewModel.tasks {
            if !addedIds.contains(task.id) {
                mergedTasks.append(task)
                addedIds.insert(task.id)
            }
        }
        
        // 再添加普通任务
        for task in viewModel.tasks {
            if !addedIds.contains(task.id) {
                mergedTasks.append(task)
                addedIds.insert(task.id)
            }
        }
        
        // 优化：只在数据真正变化时更新
        if mergedTasks.count != allTasks.count || 
           mergedTasks.map({ $0.id }) != allTasks.map({ $0.id }) {
            allTasks = mergedTasks
        }
    }
}

// 任务卡片组件 - Web风格（垂直布局）
struct TaskCard: View {
    let task: Task
    var isRecommended: Bool = false  // 是否为推荐任务
    var onNotInterested: (() -> Void)? = nil  // 增强：不感兴趣回调
    
    // 任务类型 SF Symbols 映射（符合 Apple HIG）
    private let taskTypeIcons: [String: String] = [
        "Housekeeping": "house.fill",
        "Campus Life": "graduationcap.fill",
        "Second-hand & Rental": "bag.fill",
        "Errand Running": "figure.run",
        "Skill Service": "wrench.and.screwdriver.fill",
        "Social Help": "person.2.fill",
        "Transportation": "car.fill",
        "Pet Care": "pawprint.fill",
        "Life Convenience": "cart.fill",
        "Other": "square.grid.2x2.fill"
    ]
    
    // 任务类型显示名称映射（使用本地化）
    private func getTaskTypeLabel(_ type: String) -> String {
        switch type {
        case "Housekeeping":
            return LocalizationKey.taskCategoryHousekeeping.localized
        case "Campus Life":
            return LocalizationKey.taskCategoryCampusLife.localized
        case "Second-hand & Rental":
            return LocalizationKey.taskCategorySecondhandRental.localized
        case "Errand Running":
            return LocalizationKey.taskCategoryErrandRunning.localized
        case "Skill Service":
            return LocalizationKey.taskCategorySkillService.localized
        case "Social Help":
            return LocalizationKey.taskCategorySocialHelp.localized
        case "Transportation":
            return LocalizationKey.taskCategoryTransportation.localized
        case "Pet Care":
            return LocalizationKey.taskCategoryPetCare.localized
        case "Life Convenience":
            return LocalizationKey.taskCategoryLifeConvenience.localized
        case "Other":
            return LocalizationKey.taskCategoryOther.localized
        default:
            return type
        }
    }
    
    private func getTaskTypeIcon(_ type: String) -> String {
        return taskTypeIcons[type] ?? "square.fill"
    }
    
    private func getTaskLevelColor(_ level: String?) -> Color {
        guard let level = level else { return Color.gray }
        switch level {
        case "super":
            return Color(red: 0.545, green: 0.361, blue: 0.965) // #8b5cf6
        case "vip":
            return Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
        default:
            return Color.gray
        }
    }
    
    private func getTaskLevelLabel(_ level: String?) -> String {
        guard let level = level else { return "" }
        switch level {
        case "super":
            return LocalizationKey.taskTypeSuperTask.localized
        case "vip":
            return LocalizationKey.taskTypeVipTask.localized
        default:
            return ""
        }
    }
    
    // 增强：解析推荐理由，返回对应的图标和颜色
    private func getRecommendationReasonInfo(_ reason: String?) -> (icon: String, color: Color) {
        guard let reason = reason else {
            return ("star.fill", AppColors.primary)
        }
        
        // 根据推荐理由内容返回不同的图标和颜色
        if reason.contains("同校") || reason.contains("学校") {
            return ("graduationcap.fill", Color.blue)
        } else if reason.contains("距离") || reason.contains("km") {
            return ("mappin.circle.fill", Color.green)
        } else if reason.contains("活跃时间") || reason.contains("时间段") || reason.contains("当前活跃") {
            return ("clock.fill", Color.orange)
        } else if reason.contains("高评分") || reason.contains("评分") {
            return ("star.fill", Color.yellow)
        } else if reason.contains("新发布") || reason.contains("新任务") {
            return ("sparkles", Color.purple)
        } else if reason.contains("即将截止") || reason.contains("截止") {
            return ("timer", Color.red)
        } else {
            return ("star.fill", AppColors.primary)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 图片区域（符合 HIG，使用系统圆角）
            ZStack(alignment: .top) {
                // 图片背景 - 使用 AsyncImageView 优化图片加载和缓存
                if let images = task.images, let firstImage = images.first, !firstImage.isEmpty {
                    AsyncImageView(
                        urlString: firstImage,
                        placeholder: Image(systemName: "photo"),
                        width: nil,
                        height: 180,
                        contentMode: .fill,
                        cornerRadius: 0
                    )
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .id("\(task.id)-\(firstImage)") // 使用任务ID和图片URL作为id，优化缓存
                } else {
                    placeholderBackground()
                }
                
                // 图片遮罩层（更柔和的渐变）
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.black.opacity(0.2),
                        Color.black.opacity(0.0),
                        Color.black.opacity(0.4)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // 顶部标签栏（位置标签 - 模糊显示，只显示城市）
                HStack {
                    // 位置标签（使用 SF Symbols）
                    HStack(spacing: 4) {
                        Label(task.location.obfuscatedLocation, systemImage: task.isOnline ? "globe" : "mappin.circle.fill")
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                        
                        // 距离显示（如果有的话）
                        if let distance = task.formattedDistanceFromUser, !task.isOnline {
                            Text("· \(distance)")
                                .font(AppTypography.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    
                    Spacer()
                }
                .padding(AppSpacing.sm)
                
                // 右下角任务类型标签
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        // 任务类型标签（使用 SF Symbols）
                        Label(getTaskTypeLabel(task.taskType), systemImage: getTaskTypeIcon(task.taskType))
                            .font(AppTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .clipShape(Capsule())
                    }
                    .padding(AppSpacing.sm)
                }
            }
            .frame(height: 180)
            .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous))
            
            // 内容区域（符合 HIG，使用系统背景）
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                // 标题（使用系统字体，支持翻译）
                TranslatableText(
                    task.title,
                    font: AppTypography.body,
                    foregroundColor: AppColors.textPrimary,
                    lineLimit: 2
                )
                .multilineTextAlignment(.leading)
                
                // 底部信息栏
                HStack(spacing: AppSpacing.sm) {
                    // 截止时间（使用 SF Symbols）
                    if let deadline = task.deadline {
                        Label(DateFormatterHelper.shared.formatDeadline(deadline), systemImage: "clock.fill")
                            .font(AppTypography.caption)
                            .foregroundColor(
                                DateFormatterHelper.shared.isExpired(deadline) ? AppColors.error :
                                DateFormatterHelper.shared.isExpiringSoon(deadline) ? AppColors.warning :
                                AppColors.textSecondary
                            )
                    }
                    
                    Spacer()
                    
                    // 价格/积分（使用 SF Symbols）
                    priceBadge
                }
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .compositingGroup() // 组合渲染，确保圆角边缘干净
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
        .contextMenu {
            // 增强：长按菜单 - 不感兴趣
            if let onNotInterested = onNotInterested {
                Button(role: .destructive) {
                    onNotInterested()
                } label: {
                    Label(LocalizationKey.tasksNotInterested.localized, systemImage: "hand.thumbsdown.fill")
                }
            }
        }
        .overlay(alignment: .topTrailing) {
            // 任务等级标签（VIP/Super）- 右上角
            if let taskLevel = task.taskLevel, taskLevel != "normal" {
                Text(getTaskLevelLabel(taskLevel))
                    .font(AppTypography.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(getTaskLevelColor(taskLevel))
                    .clipShape(Capsule())
                    .shadow(color: getTaskLevelColor(taskLevel).opacity(0.5), radius: 4, x: 0, y: 2)
                    .padding(.top, AppSpacing.sm)
                    .padding(.trailing, AppSpacing.sm)
            }
        }
        .overlay(alignment: .topLeading) {
            // 增强：推荐理由标签（如果有推荐理由）- 左上角
            // 优先级：推荐理由 > 任务等级标签（如果同时存在，推荐理由在左上角，任务等级在右上角）
            if isRecommended {
                if let reason = task.recommendationReason, !reason.isEmpty {
                    // 有推荐理由，显示推荐理由
                    let reasonInfo = getRecommendationReasonInfo(reason)
                    HStack(spacing: 4) {
                        Image(systemName: reasonInfo.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(reason)
                            .font(AppTypography.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(reasonInfo.color.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: reasonInfo.color.opacity(0.5), radius: 4, x: 0, y: 2)
                    .padding(.top, AppSpacing.sm)
                    .padding(.leading, AppSpacing.sm)
                } else {
                    // 没有推荐理由，显示默认推荐标签
                    HStack(spacing: 4) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10, weight: .semibold))
                        Text(LocalizationKey.homeRecommendedTasks.localized)
                            .font(AppTypography.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.primary.opacity(0.9))
                    .clipShape(Capsule())
                    .shadow(color: AppColors.primary.opacity(0.5), radius: 4, x: 0, y: 2)
                    .padding(.top, AppSpacing.sm)
                    .padding(.leading, AppSpacing.sm)
                }
            }
        }
    }
    
    // 占位背景（符合 HIG，使用系统颜色和 SF Symbols）
    private func placeholderBackground() -> some View {
        ZStack {
            Rectangle()
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            AppColors.primary.opacity(0.1),
                            AppColors.primary.opacity(0.05)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(height: 180)
                .frame(maxWidth: .infinity)
            
            IconStyle.icon(getTaskTypeIcon(task.taskType), size: IconStyle.xlarge)
                .foregroundColor(AppColors.primary.opacity(0.3))
        }
    }
    
    // 价格标签（符合 HIG，使用 SF Symbols）
    private var priceBadge: some View {
        Group {
            if let pointsReward = task.pointsReward, pointsReward > 0, task.reward <= 0 {
                // 只有积分奖励
                Label("\(pointsReward)", systemImage: "star.fill")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.warning)
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(AppColors.warningLight)
                    .clipShape(Capsule())
            } else if task.reward > 0 {
                // 金额奖励（可能还有积分）
                HStack(spacing: 2) {
                    Text("£")
                        .font(AppTypography.caption2)
                        .fontWeight(.bold)
                    Text(formatPrice(task.reward))
                        .font(AppTypography.caption)
                        .fontWeight(.bold)
                    
                    // 积分奖励文本（如果有）
                    if let pointsReward = task.pointsReward, pointsReward > 0 {
                        Label("\(pointsReward)", systemImage: "star.fill")
                            .font(AppTypography.caption2)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(AppColors.warningLight)
                            .clipShape(Capsule())
                            .padding(.leading, 2)
                    }
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, 4)
                .background(AppColors.success)
                .clipShape(Capsule())
                .foregroundColor(.white)
            }
        }
    }
    
    private func formatPrice(_ price: Double) -> String {
        if price.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", price)
        } else {
            return String(format: "%.2f", price)
        }
    }
}

// 状态标签组件
struct StatusBadge: View {
    let status: TaskStatus
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(status.displayText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.15))
        .foregroundColor(statusColor)
        .cornerRadius(AppCornerRadius.small)
    }
    
    private var statusColor: Color {
        switch status {
        case .open: return AppColors.success
        case .inProgress: return AppColors.primary
        case .completed: return AppColors.textSecondary
        case .cancelled: return AppColors.error
        case .pendingConfirmation: return AppColors.warning
        case .pendingPayment: return AppColors.warning
        }
    }
}

    // 增强：记录跳过任务（用于推荐系统负反馈）
    private func recordTaskSkip(taskId: Int) {
        guard appState.isAuthenticated else { return }
        
        // 异步非阻塞方式记录交互
        DispatchQueue.global(qos: .utility).async {
            let deviceType = DeviceInfo.isPad ? "tablet" : "mobile"
            let metadata: [String: Any] = [
                "source": "task_list",
                "action": "not_interested"
            ]
            
            var cancellable: AnyCancellable?
            cancellable = APIService.shared.recordTaskInteraction(
                taskId: taskId,
                interactionType: "skip",
                deviceType: deviceType,
                isRecommended: false,
                metadata: metadata
            )
            .sink(
                receiveCompletion: { completion in
                    if case .failure(let error) = completion {
                        Logger.warning("记录跳过任务失败: \(error.localizedDescription)", category: .api)
                    }
                    cancellable = nil
                },
                receiveValue: { _ in
                    Logger.debug("已记录跳过任务: taskId=\(taskId)", category: .api)
                }
            )
            _ = cancellable
        }
    }
}

// 空状态视图（已在 Components/EmptyStateView.swift 中定义，这里保留兼容性）
