import SwiftUI

struct TasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var searchText = ""
    @State private var showFilter = false
    @State private var selectedCategory: String?
    @State private var selectedCity: String? // 新增城市筛选状态
    
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
                            
                            TextField("搜索任务", text: $searchText)
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
                            Button("搜索") {
                                // 执行搜索，只搜索开放中的任务
                                viewModel.loadTasks(status: "open", keyword: searchText)
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
                    if viewModel.isLoading && viewModel.tasks.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage, viewModel.tasks.isEmpty {
                        // 使用统一的错误状态组件
                        ErrorStateView(
                            message: error,
                            retryAction: {
                                // 重试时也只加载开放中的任务
                                viewModel.loadTasks(status: "open")
                            }
                        )
                    } else if viewModel.tasks.isEmpty {
                        EmptyStateView(
                            icon: "doc.text.magnifyingglass",
                            title: "暂无任务",
                            message: "还没有任务发布，快来发布第一个任务吧！"
                        )
                    } else {
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: AppSpacing.md),
                                GridItem(.flexible(), spacing: AppSpacing.md)
                            ], spacing: AppSpacing.md) {
                                ForEach(viewModel.tasks, id: \.id) { task in
                                    NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                                        TaskCard(task: task)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .id(task.id) // 确保稳定的id，优化视图复用
                                    .onAppear {
                                        // 性能优化：只在接近最后一个任务时加载更多（提前3个）
                                        let threshold = max(0, viewModel.tasks.count - 3)
                                        if let index = viewModel.tasks.firstIndex(where: { $0.id == task.id }),
                                           index >= threshold {
                                            viewModel.loadMoreTasks()
                                        }
                                    }
                                }
                                
                                // 加载更多指示器
                                if viewModel.isLoadingMore {
                                    HStack {
                                        Spacer()
                                        ProgressView()
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
            // 性能优化：合并 onChange，使用防抖避免频繁调用
            .onChange(of: selectedCategory) { _ in
                applyFiltersWithDebounce()
            }
            .onChange(of: selectedCity) { _ in
                applyFiltersWithDebounce()
            }
            .refreshable {
                // 强制刷新，清除缓存并重新加载
                viewModel.loadTasks(status: "open", forceRefresh: true)
            }
            .task {
                // 使用 task 替代 onAppear，避免重复加载
                if viewModel.tasks.isEmpty && !viewModel.isLoading {
                    // 默认只加载开放中的任务
                    viewModel.loadTasks(status: "open")
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
        
        // 延迟300ms执行，避免频繁调用
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: workItem)
    }
    
    private func applyFilters() {
        // 重新加载任务，应用筛选条件（只显示开放中的任务）
        viewModel.loadTasks(category: selectedCategory, city: selectedCity, status: "open")
    }
}

// 任务卡片组件 - Web风格（垂直布局）
struct TaskCard: View {
    let task: Task
    
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
    
    // 任务类型显示名称映射
    private let taskTypeLabels: [String: String] = [
        "Housekeeping": "家政服务",
        "Campus Life": "校园生活",
        "Second-hand & Rental": "二手租赁",
        "Errand Running": "跑腿代购",
        "Skill Service": "技能服务",
        "Social Help": "社交互助",
        "Transportation": "交通用车",
        "Pet Care": "宠物寄养",
        "Life Convenience": "生活便利",
        "Other": "其他"
    ]
    
    private func getTaskTypeIcon(_ type: String) -> String {
        return taskTypeIcons[type] ?? "square.fill"
    }
    
    private func getTaskTypeLabel(_ type: String) -> String {
        return taskTypeLabels[type] ?? type
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
            return "超级任务"
        case "vip":
            return "VIP任务"
        default:
            return ""
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
                    .id(firstImage) // 使用图片URL作为id，优化缓存
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
                // 标题（使用系统字体）
                Text(task.title)
                    .font(AppTypography.body)
                    .fontWeight(.semibold)
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
        }
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.medium, style: .continuous)
                .fill(AppColors.cardBackground)
        )
        .compositingGroup() // 组合渲染，确保圆角边缘干净
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: AppShadow.small.x, y: AppShadow.small.y)
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

// 空状态视图（已在 Components/EmptyStateView.swift 中定义，这里保留兼容性）
