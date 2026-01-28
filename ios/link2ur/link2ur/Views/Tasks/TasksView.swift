import SwiftUI
import Combine
import UIKit

struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @StateObject private var recommendedViewModel = TasksViewModel()  // 推荐任务 ViewModel
    @EnvironmentObject var appState: AppState  // 增强：用于检查登录状态
    @Environment(\.horizontalSizeClass) var horizontalSizeClass  // 修复：使用Environment获取SizeClass，避免GeometryReader导致滚动问题
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
                // 优化：确保VStack不会裁剪子视图
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
                        // 使用网格骨架屏，提供更好的加载体验（iPad适配）
                        ScrollView {
                            GeometryReader { geometry in
                                let horizontalSizeClass = geometry.size.width > 600 ? UserInterfaceSizeClass.regular : UserInterfaceSizeClass.compact
                                let columnCount = AdaptiveLayout.gridColumnCount(
                                    horizontalSizeClass: horizontalSizeClass,
                                    itemType: .task
                                )
                                GridSkeleton(columns: columnCount, rows: 4)
                                    .padding(.horizontal, AppSpacing.md)
                                    .padding(.vertical, AppSpacing.sm)
                            }
                        }
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
                            // 修复：移除GeometryReader，使用Environment获取SizeClass，避免滚动问题
                            // iPad适配 - 根据设备类型和SizeClass动态调整列数
                            let columns = AdaptiveLayout.adaptiveGridColumns(
                                horizontalSizeClass: horizontalSizeClass,
                                itemType: .task,
                                spacing: AppSpacing.md
                            )
                            
                            LazyVGrid(columns: columns, spacing: AppSpacing.md) {
                                // 优化：添加padding，给卡片留出空间，避免长按时被裁剪
                                ForEach(allTasks, id: \.id) { task in
                                    let cardShape = RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                                    
                                    NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                        TaskCard(
                                            task: task,
                                            isRecommended: task.isRecommended == true,
                                            onNotInterested: nil, // contextMenu 移到外层
                                            enableLongPress: false // contextMenu 移到外层
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle()) // 使用PlainButtonStyle，避免长按时的缩放效果
                                    // 关键：把 clipShape/contentShape/contextMenu 都放在 NavigationLink 这层，确保长按高亮按圆角显示
                                    .clipShape(cardShape)
                                    .contentShape(cardShape)
                                    // 关键：使用 .interaction 精确控制交互区域（iOS 16+），避免长按高亮在矩形容器上显示
                                    // 这解决了iPad和iPhone上长按手势"容器感"差异的问题
                                    // InteractionContentShapeModifier 已添加iOS版本检查，确保向后兼容
                                    // 虽然项目最低版本是iOS 16，但不同设备/系统版本可能有行为差异
                                    .modifier(InteractionContentShapeModifier(shape: cardShape))
                                    // 修复真机长按显示灰色容器的问题：确保背景完全覆盖，防止系统高亮透出
                                    .background(AppColors.cardBackground.clipShape(cardShape))
                                    // 移除 drawingGroup：在 ScrollView+LazyVGrid 中会导致长按取消后立即滑动时，
                                    // 被长按的卡片在长按位置短暂停留，体验不佳。
                                    .compositingGroup() // 合成为一层再应用阴影，保证圆角与边界正确，且不栅格化
                                    // 使用非常柔和的阴影，减少容器边界感（借鉴钱包余额视图的做法）
                                    .shadow(color: AppColors.primary.opacity(0.08), radius: 12, x: 0, y: 4)
                                    .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            // 增强：记录跳过任务（用于推荐系统负反馈）
                                            recordTaskSkip(taskId: task.id)
                                        } label: {
                                            Label(LocalizationKey.tasksNotInterested.localized, systemImage: "hand.thumbsdown.fill")
                                        }
                                    }
                                    // iOS 17+ 优化：指定 context menu 预览形状，避免预览边缘漏底色
                                    .modifier(TaskCardContextMenuPreviewModifier(shape: cardShape))
                                    // 移除 zIndex(100)：与 drawingGroup 叠加时，长按取消后立即滑动会导致卡片在旧位置
                                    // 短暂停留。不设 zIndex 可避免该粘连感，context menu 预览仍正常。
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
                                
                                // 加载更多指示器（使用动态列数）
                                if viewModel.isLoadingMore || recommendedViewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        CompactLoadingView()
                                            .padding()
                                        Spacer()
                                    }
                                    .gridCellColumns(AdaptiveLayout.gridColumnCount(
                                        horizontalSizeClass: horizontalSizeClass,
                                        itemType: .task
                                    ))
                                }
                            }
                            .padding(.horizontal, AppSpacing.md)
                            .padding(.vertical, AppSpacing.md)
                            // 优化：在Grid底部添加额外padding，确保最后一个卡片长按时不被裁剪
                            .padding(.bottom, AppSpacing.lg)
                        }
                        // 优化：禁用ScrollView的裁剪，允许contextMenu超出边界显示
                        .scrollContentBackground(.hidden)
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
                // 并行加载推荐任务和普通任务
                await withTaskGroup(of: Void.self) { group in
                    group.addTask {
                        await MainActor.run {
                            recommendedViewModel.loadRecommendedTasks(
                                limit: 20,
                                algorithm: "hybrid",
                                taskType: selectedCategory,
                                location: selectedCity,
                                keyword: searchText.isEmpty ? nil : searchText,
                                forceRefresh: true
                            )
                        }
                    }
                    group.addTask {
                        await MainActor.run {
                            viewModel.loadTasks(
                                category: selectedCategory,
                                city: selectedCity,
                                status: "open",
                                keyword: searchText.isEmpty ? nil : searchText,
                                forceRefresh: true
                            )
                        }
                    }
                }
                // 等待两个任务都完成后再更新合并列表
                await MainActor.run {
                    updateMergedTasks()
                }
            }
            .task {
                // 延迟执行所有初始化操作，让导航动画先完成，提升流畅度
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    // 首次加载时，应用引导教程保存的个性化设置
                    applyOnboardingPreferences()
                    
                    // 修复：先从缓存加载普通任务，确保一开始就显示普通任务
                    viewModel.loadTasksFromCache(category: selectedCategory, city: selectedCity, status: "open")
                    
                    // 再从缓存加载推荐任务（如果已登录）
                    if appState.isAuthenticated {
                        if let cachedRecommendedTasks = CacheManager.shared.loadTasks(category: selectedCategory, city: selectedCity, isRecommended: true) {
                            if !cachedRecommendedTasks.isEmpty {
                                recommendedViewModel.tasks = cachedRecommendedTasks
                                Logger.success("从推荐任务缓存加载了 \(cachedRecommendedTasks.count) 个任务", category: .cache)
                            }
                        }
                    }
                    
                    // 立即更新合并列表（基于缓存数据）
                    updateMergedTasks()
                    
                    // 使用 task 替代 onAppear，避免重复加载
                    if !viewModel.isLoading && !recommendedViewModel.isLoading {
                        // 加载推荐任务和普通任务（网络请求）
                        loadTasksWithRecommendations()
                    }
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
        // 修复：确保普通任务也立即加载（即使推荐任务先加载完成）
        // 并行加载推荐任务和普通任务，提高加载速度
        
        // 先加载推荐任务（如果已登录）
        if appState.isAuthenticated {
            recommendedViewModel.loadRecommendedTasks(
                limit: 20,
                algorithm: "hybrid",
                taskType: selectedCategory,
                location: selectedCity,
                keyword: searchText.isEmpty ? nil : searchText,
                forceRefresh: false
            )
        }
        
        // 同时加载普通任务（无论是否登录都需要）
        // 注意：loadTasks 内部会先从缓存加载，然后进行网络请求
        viewModel.loadTasks(
            category: selectedCategory,
            city: selectedCity,
            status: "open",
            keyword: searchText.isEmpty ? nil : searchText,
            forceRefresh: false
        )
        
        // 立即更新合并列表（基于当前已有数据，包括缓存数据）
        // 这样即使推荐任务先加载完成，普通任务也能显示（如果有缓存数据）
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
    /// 优化：使用字典提高去重效率，减少时间复杂度
    /// 优化：只在数据真正变化时更新，避免不必要的视图重绘
    /// 修复：确保推荐任务和普通任务都显示，推荐任务优先排序，并去重
    private func updateMergedTasks() {
        // 使用字典快速去重，推荐任务优先（保留推荐原因和 isRecommended 标记）
        var taskMap: [Int: Task] = [:]
        
        // 先添加普通任务（作为基础）
        for task in viewModel.tasks {
            taskMap[task.id] = task
        }
        
        // 再添加推荐任务（覆盖普通任务，保留推荐原因）
        // 修复：确保所有推荐任务都被添加到 taskMap 中
        // 如果任务在 recommendedViewModel.tasks 中，无论 isRecommended 标记如何，都应该被视为推荐任务
        for task in recommendedViewModel.tasks {
            // 推荐任务优先，保留推荐原因和 isRecommended 标记
            // 如果 isRecommended 标记不正确，仍然将其添加到 taskMap（确保推荐任务不被遗漏）
            taskMap[task.id] = task
        }
        
        // 转换为数组，推荐任务在前（保留推荐原因），按匹配分数排序
        var mergedTasks: [Task] = []
        
        // 先添加推荐任务（保留推荐原因），按匹配分数降序排序
        // 修复：确保所有在推荐任务 ViewModel 中的任务都被识别为推荐任务
        // 如果任务在 recommendedViewModel.tasks 中，即使 isRecommended 标记不正确，也应该被视为推荐任务
        let recommendedTasks = recommendedViewModel.tasks
            .sorted { (task1, task2) -> Bool in
                let score1 = task1.matchScore ?? 0.0
                let score2 = task2.matchScore ?? 0.0
                return score1 > score2
            }
        
        // 获取推荐任务 ID 集合，用于去重
        let recommendedTaskIds = Set(recommendedTasks.map { $0.id })
        
        // 修复：确保所有推荐任务都被添加到合并列表中
        // 如果推荐任务在 taskMap 中，使用 taskMap 中的版本（可能包含更多信息）
        // 如果不在，直接使用推荐任务本身（确保推荐任务不被遗漏）
        for task in recommendedTasks {
            if let mergedTask = taskMap[task.id] {
                mergedTasks.append(mergedTask)
            } else {
                // 如果推荐任务不在 taskMap 中，直接添加（确保推荐任务不被遗漏）
                mergedTasks.append(task)
                Logger.warning("推荐任务 \(task.id) 不在 taskMap 中，直接添加", category: .ui)
            }
        }
        
        // 再添加普通任务（如果不在推荐列表中）
        for task in viewModel.tasks {
            if !recommendedTaskIds.contains(task.id) {
                mergedTasks.append(task)
            }
        }
        
        // 调试日志：记录任务数量和详细信息
        let recommendedTaskIdsList = recommendedTasks.map { "\($0.id)" }.joined(separator: ", ")
        let allTaskIdsList = mergedTasks.map { "\($0.id)" }.joined(separator: ", ")
        Logger.debug("任务合并完成 - 普通任务: \(viewModel.tasks.count), 推荐任务ViewModel: \(recommendedViewModel.tasks.count), 筛选后推荐任务: \(recommendedTasks.count), 合并后总数: \(mergedTasks.count)", category: .ui)
        Logger.debug("推荐任务IDs: [\(recommendedTaskIdsList)]", category: .ui)
        Logger.debug("合并后任务IDs: [\(allTaskIdsList)]", category: .ui)
        
        // 优化：只在数据真正变化时更新
        if mergedTasks.count != allTasks.count || 
           mergedTasks.map({ $0.id }) != allTasks.map({ $0.id }) {
            allTasks = mergedTasks
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

// 任务卡片组件 - Web风格（垂直布局）
struct TaskCard: View {
    let task: Task
    var isRecommended: Bool = false  // 是否为推荐任务
    var onNotInterested: (() -> Void)? = nil  // 增强：不感兴趣回调
    var enableLongPress: Bool = true  // 是否启用长按功能（首页暂时禁用）
    @State private var showNotInterestedAlert = false  // 优化：使用alert替代contextMenu，避免被容器裁剪
    
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
    
    // 增强：本地化推荐理由
    private func localizeRecommendationReason(_ reason: String?) -> String {
        guard let reason = reason, !reason.isEmpty else {
            return LocalizationKey.homeRecommendedTasks.localized
        }
        
        let language = LocalizationHelper.currentLanguage
        let isEnglish = !language.hasPrefix("zh")
        
        // 如果已经是英文，直接返回
        if isEnglish && !reason.contains("您") && !reason.contains("常") && !reason.contains("位于") {
            return reason
        }
        
        // 中文到英文的映射
        var localizedReason = reason
        
        // 任务类型匹配
        if reason.contains("您常接受") || reason.contains("常接受") {
            if let taskType = extractTaskType(from: reason) {
                localizedReason = isEnglish ? 
                    "You often accept \(taskType) tasks" : 
                    reason
            }
        }
        
        // 位置匹配
        if reason.contains("位于您常去的") || reason.contains("位于") {
            if let location = extractLocation(from: reason) {
                localizedReason = isEnglish ? 
                    "Located in \(location) where you often work" : 
                    reason
            } else if reason.contains("支持在线完成") || reason.contains("在线完成") {
                localizedReason = isEnglish ? 
                    "Can be completed online" : 
                    reason
            }
        }
        
        // 价格匹配
        if reason.contains("价格在您的接受范围内") {
            localizedReason = isEnglish ? 
                "Price within your range" : 
                reason
        } else if reason.contains("高价值任务") {
            localizedReason = isEnglish ? 
                "High-value task" : 
                reason
        }
        
        // 时间匹配
        if reason.contains("即将截止") {
            localizedReason = isEnglish ? 
                "Deadline approaching" : 
                reason
        } else if reason.contains("近期任务") || reason.contains("新发布任务") {
            localizedReason = isEnglish ? 
                "Recent task" : 
                reason
        }
        
        // 任务等级
        if reason.contains("VIP任务") {
            localizedReason = isEnglish ? 
                "VIP task" : 
                reason
        } else if reason.contains("超级任务") {
            localizedReason = isEnglish ? 
                "Super task" : 
                reason
        }
        
        // 通用推荐
        if reason.contains("根据您的偏好推荐") {
            localizedReason = isEnglish ? 
                "Recommended based on your preferences" : 
                reason
        } else if reason.contains("可能适合您") {
            localizedReason = isEnglish ? 
                "May be suitable for you" : 
                reason
        }
        
        return localizedReason
    }
    
    // 从推荐理由中提取任务类型
    private func extractTaskType(from reason: String) -> String? {
        // 尝试提取任务类型（简化版）
        let taskTypes = ["Social Help", "Transportation", "Pet Care", "Life Convenience", 
                        "Housekeeping", "Campus Life", "Errand Running", "Skill Service"]
        for type in taskTypes {
            if reason.contains(type) {
                return type
            }
        }
        return nil
    }
    
    // 从推荐理由中提取位置
    private func extractLocation(from reason: String) -> String? {
        // 尝试提取位置（简化版）
        let locations = ["Birmingham", "London", "Manchester", "Liverpool", "Leeds"]
        for location in locations {
            if reason.contains(location) {
                return location
            }
        }
        return nil
    }
    
    // 增强：解析推荐理由，返回对应的图标和颜色
    private func getRecommendationReasonInfo(_ reason: String?) -> (icon: String, color: Color) {
        guard let reason = reason else {
            return ("star.fill", AppColors.primary)
        }
        
        // 根据推荐理由内容返回不同的图标和颜色（支持中英文）
        if reason.contains("同校") || reason.contains("学校") || reason.contains("school") || reason.contains("university") {
            return ("graduationcap.fill", Color.blue)
        } else if reason.contains("距离") || reason.contains("km") || reason.contains("distance") || reason.contains("Located") {
            return ("mappin.circle.fill", Color.green)
        } else if reason.contains("活跃时间") || reason.contains("时间段") || reason.contains("当前活跃") || reason.contains("active") || reason.contains("time") {
            return ("clock.fill", Color.orange)
        } else if reason.contains("高评分") || reason.contains("评分") || reason.contains("rating") || reason.contains("score") {
            return ("star.fill", Color.yellow)
        } else if reason.contains("新发布") || reason.contains("新任务") || reason.contains("Recent") || reason.contains("New") {
            return ("sparkles", Color.purple)
        } else if reason.contains("即将截止") || reason.contains("截止") || reason.contains("Deadline") || reason.contains("approaching") {
            return ("timer", Color.red)
        } else if reason.contains("高价值") || reason.contains("High-value") {
            return ("dollarsign.circle.fill", Color.green)
        } else {
            return ("star.fill", AppColors.primary)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 图片区域（符合 HIG，使用系统圆角）
            ZStack(alignment: .top) {
                // 图片背景 - 使用 AsyncImageView 优化图片加载和缓存
                // 修复：使用 Color.clear + overlay 模式，确保图片不会撑开布局
                // 先用 Color.clear 建立固定尺寸的框架，然后在 overlay 中显示图片
                if let images = task.images, let firstImage = images.first, !firstImage.isEmpty {
                    Color.clear
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .overlay(
                            AsyncImageView(
                                urlString: firstImage,
                                placeholder: Image(systemName: "photo"),
                                contentMode: .fill
                            )
                        )
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
                Text(task.displayTitle)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(2)
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
            .background(AppColors.cardBackground) // 内容区域背景
        }
        .background(AppColors.cardBackground) // 内容区域背景
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)) // 优化：确保圆角边缘干净，不露出底层
        .compositingGroup() // 组合渲染，确保圆角边缘干净
        // 使用非常柔和的阴影，减少容器边界感（借鉴钱包余额视图的做法）
        .shadow(color: AppColors.primary.opacity(0.08), radius: 12, x: 0, y: 4)
        .shadow(color: .black.opacity(0.02), radius: 2, x: 0, y: 1)
        .contentShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)) // 优化：使用相同的圆角形状作为点击区域，避免长按时露出尖角
        .alert(LocalizationKey.tasksNotInterested.localized, isPresented: $showNotInterestedAlert) {
            Button(role: .destructive) {
                onNotInterested?()
            } label: {
                Text(LocalizationKey.tasksNotInterested.localized)
            }
            Button(role: .cancel) {
                // 取消，不做任何操作
            } label: {
                Text(LocalizationKey.commonCancel.localized)
            }
        } message: {
            Text("确定要将此任务标记为不感兴趣吗？")
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
                    // 有推荐理由，显示本地化的推荐理由
                    let localizedReason = localizeRecommendationReason(reason)
                    let reasonInfo = getRecommendationReasonInfo(reason)
                    HStack(spacing: 4) {
                        Image(systemName: reasonInfo.icon)
                            .font(.system(size: 10, weight: .semibold))
                        Text(localizedReason)
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

// iOS 17+ 优化：指定 context menu 预览形状，避免预览边缘漏底色
struct TaskCardContextMenuPreviewModifier: ViewModifier {
    let shape: RoundedRectangle
    
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentShape(.contextMenuPreview, shape)
        } else {
            content
        }
    }
}

// 空状态视图（已在 Components/EmptyStateView.swift 中定义，这里保留兼容性）
