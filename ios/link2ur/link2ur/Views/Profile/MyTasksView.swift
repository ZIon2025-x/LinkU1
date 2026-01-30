import SwiftUI

struct MyTasksView: View {
    @StateObject private var viewModel = MyTasksViewModel()
    @State private var selectedTab: TaskTab = .all
    @EnvironmentObject var appState: AppState
    var initialTab: TaskTab? = nil
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 标签页
                tabBarView
                
                Divider()
                
                // 任务列表内容
                tasksContentView
            }
        }
        .navigationTitle(LocalizationKey.tasksMyTasks.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .toolbarBackground(AppColors.background, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            // 使用 task 替代 onAppear，避免重复加载
            // 设置当前用户ID
            if let userId = appState.currentUser?.id {
                viewModel.currentUserId = userId
            }
            
            // 如果指定了初始标签页，设置它
            if let initialTab = initialTab {
                selectedTab = initialTab
                viewModel.currentTab = initialTab
            }
            
            // 先尝试从缓存加载（立即显示）
            if viewModel.tasks.isEmpty {
                viewModel.loadTasksFromCache()
            }
            
            // 延迟加载数据，避免在页面出现时立即加载导致卡顿
            if !viewModel.isLoading {
                // 延迟100ms加载，让页面先渲染完成
                try? await _Concurrency.Task.sleep(nanoseconds: 100_000_000)
                // 后台刷新数据（不强制刷新，使用缓存优先策略）
                viewModel.loadTasks(forceRefresh: false)
                // 预加载已完成的任务，这样用户点击"已完成"标签页时就能立即看到
                viewModel.loadCompletedTasks()
            }
        }
        .onChange(of: appState.currentUser?.id) { newUserId in
            // 当用户ID变化时更新
            viewModel.currentUserId = newUserId
        }
    }
    
    // MARK: - 子视图
    
    // 标签页视图
    private var tabBarView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(TaskTab.allCases, id: \.self) { tab in
                    MyTasksTabButton(
                        tab: tab,
                        count: getTabCount(for: tab),
                        isSelected: selectedTab == tab
                    )                     {
                        let previousTab = selectedTab
                        selectedTab = tab
                        viewModel.currentTab = tab
                        // 切换标签页时，如果是"已完成"标签页，立即加载已完成的任务
                        if tab == .completed && previousTab != .completed {
                            viewModel.loadCompletedTasks()
                        }
                        // 切换标签页时，如果是"进行中"标签页，刷新任务列表
                        if tab == .inProgress && previousTab != .inProgress {
                            viewModel.loadTasks(forceRefresh: false)
                        }
                        // 切换标签页时，如果是"待处理申请"标签页，刷新申请记录
                        if tab == .pending && previousTab != .pending {
                            viewModel.refreshApplications()
                        }
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(AppColors.cardBackground)
    }
    
    // 任务列表内容视图
    @ViewBuilder
    private var tasksContentView: some View {
        if selectedTab == .completed && viewModel.isLoadingCompletedTasks && viewModel.getFilteredTasks().isEmpty {
            completedTasksLoadingView
        } else if viewModel.isOffline && viewModel.tasks.isEmpty {
            offlineView
        } else if viewModel.isLoading && viewModel.tasks.isEmpty && selectedTab != .pending {
            loadingView
        } else if selectedTab == .pending {
            pendingApplicationsView
        } else if viewModel.getFilteredTasks().isEmpty {
            emptyTasksView
        } else {
            tasksListView
        }
    }
    
    // 已完成任务加载视图
    private var completedTasksLoadingView: some View {
        VStack {
            Spacer()
            VStack(spacing: AppSpacing.md) {
                CompactLoadingView()
                Text(LocalizationKey.myTasksLoadingCompleted.localized)
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
    }
    
    // 离线视图
    private var offlineView: some View {
        VStack {
            Spacer()
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 48))
                    .foregroundColor(AppColors.textTertiary)
                Text(LocalizationKey.myTasksNetworkUnavailable.localized)
                    .font(AppTypography.title3)
                    .foregroundColor(AppColors.textPrimary)
                Text(LocalizationKey.myTasksCheckNetwork.localized)
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.textSecondary)
            }
            Spacer()
        }
    }
    
    // 加载视图
    private var loadingView: some View {
        VStack {
            Spacer()
            LoadingView()
            Spacer()
        }
    }
    
    // 待处理申请视图
    @ViewBuilder
    private var pendingApplicationsView: some View {
        if viewModel.getPendingApplications().isEmpty {
            Spacer()
            EmptyStateView(
                icon: "clock.fill",
                title: LocalizationKey.myTasksNoPendingApplications.localized,
                message: LocalizationKey.myTasksNoPendingApplicationsMessage.localized
            )
            Spacer()
        } else {
            ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(Array(viewModel.getPendingApplications().enumerated()), id: \.element.id) { index, application in
                    MyTasksApplicationCard(application: application)
                        .listItemAppear(index: index, totalItems: viewModel.getPendingApplications().count) // 添加错落入场动画
                }
            }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
            }
            .refreshable {
                viewModel.loadTasks(forceRefresh: true)
            }
        }
    }
    
    // 空任务视图
    private var emptyTasksView: some View {
        VStack {
            Spacer()
            EmptyStateView(
                icon: "doc.text.fill",
                title: LocalizationKey.emptyNoTasks.localized,
                message: getEmptyMessage()
            )
            Spacer()
        }
    }
    
    // 任务列表视图
    private var tasksListView: some View {
        ScrollView {
            LazyVStack(spacing: AppSpacing.md) {
                ForEach(Array(viewModel.getFilteredTasks().enumerated()), id: \.element.id) { index, task in
                    NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                        EnhancedTaskCard(task: task, currentUserId: viewModel.currentUserId)
                    }
                    .listItemAppear(index: index, totalItems: viewModel.getFilteredTasks().count) // 添加错落入场动画
                    .buttonStyle(PlainButtonStyle())
                    .onAppear { }
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .refreshable {
            viewModel.loadTasks(forceRefresh: true)
        }
    }
    
    // MARK: - 辅助方法
    
    private func getTabCount(for tab: TaskTab) -> Int {
        switch tab {
        case .all:
            return viewModel.totalTasksCount
        case .posted:
            return viewModel.postedTasksCount
        case .taken:
            return viewModel.takenTasksCount
        case .inProgress:
            return viewModel.inProgressTasksCount
        case .pending:
            return viewModel.pendingApplicationsCount
        case .completed:
            return viewModel.completedTasksCount
        case .cancelled:
            return viewModel.tasks.filter { $0.status == .cancelled }.count
        }
    }
    
    private func getEmptyMessage() -> String {
        switch selectedTab {
        case .all:
            return LocalizationKey.myTasksEmptyAll.localized
        case .posted:
            return LocalizationKey.myTasksEmptyPosted.localized
        case .taken:
            return LocalizationKey.myTasksEmptyTaken.localized
        case .inProgress:
            return LocalizationKey.myTasksEmptyInProgress.localized
        case .pending:
            return LocalizationKey.myTasksEmptyPending.localized
        case .completed:
            return LocalizationKey.myTasksEmptyCompleted.localized
        case .cancelled:
            return LocalizationKey.myTasksEmptyCancelled.localized
        }
    }
}

// 标签页按钮组件（参考 frontend）
struct MyTasksTabButton: View {
    let tab: TaskTab
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // 使用 SF Symbols 图标（如果 tab.icon 是 SF Symbol 名称）
                if tab.icon.hasPrefix("sf:") {
                    Image(systemName: String(tab.icon.dropFirst(3)))
                        .font(.system(size: 14, weight: .semibold))
                } else {
                    Text(tab.icon)
                        .font(.system(size: 14))
                }
                
                Text(tab.localizedName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(isSelected ? AppColors.primary : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white : AppColors.primary)
                        .clipShape(Capsule())
                }
            }
            .foregroundColor(isSelected ? AppColors.primary : AppColors.textPrimary)
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, 10)
            .background(
                Group {
                    if isSelected {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(Color.white)
                            .shadow(color: AppColors.primary.opacity(0.2), radius: 4, x: 0, y: 2)
                    } else {
                        RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                            .fill(AppColors.cardBackground)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppCornerRadius.medium)
                    .stroke(isSelected ? AppColors.primary.opacity(0.3) : AppColors.separator, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 申请记录卡片（参考 frontend）
struct MyTasksApplicationCard: View {
    let application: UserTaskApplication
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 标题和状态
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(application.displayTitle)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 状态标签
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 10))
                    Text(LocalizationKey.myTasksPending.localized)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(AppColors.warning)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.warningLight)
                .clipShape(Capsule())
            }
            
            Divider()
                .background(AppColors.separator.opacity(0.5))
            
            // 任务信息 - 紧凑布局
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: 0) {
                    InfoItemCompact(icon: "dollarsign.circle.fill", text: "£\(String(format: "%.2f", application.taskReward))", color: AppColors.success)
                    Spacer()
                    InfoItemCompact(icon: "mappin.circle.fill", text: application.taskLocation.obfuscatedLocation, color: AppColors.primary)
                }
                
                InfoItemCompact(icon: "calendar", text: DateFormatterHelper.shared.formatFullTime(application.createdAt), color: AppColors.textSecondary)
            }
            
            // 申请留言
            if let message = application.message, !message.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "message.fill")
                            .font(.system(size: 11))
                            .foregroundColor(AppColors.textTertiary)
                        Text(LocalizationKey.myTasksApplicationMessage.localized)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(AppColors.textTertiary)
                    }
                    
                    Text(message)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(3)
                }
                .padding(AppSpacing.sm)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.primaryLight.opacity(0.3))
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
            }
            
            // 操作按钮
            NavigationLink(destination: TaskDetailView(taskId: application.taskId, initialHasAppliedPending: true)) {
                HStack {
                    Text(LocalizationKey.myTasksViewDetails.localized)
                        .font(.system(size: 14, weight: .medium))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(AppColors.primary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 10)
                .background(AppColors.primaryLight.opacity(0.2))
                .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.medium))
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground) // 内容区域背景
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .stroke(AppColors.separator.opacity(0.3), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)) // 优化：确保圆角边缘干净
        .compositingGroup() // 组合渲染，确保圆角边缘干净
        // 移除阴影，使用更轻量的视觉分隔
    }
}

// 增强的任务卡片（显示状态、角色等信息）
struct EnhancedTaskCard: View {
    let task: Task
    let currentUserId: String?
    
    private var isPoster: Bool {
        guard let userId = currentUserId, let posterId = task.posterId else { return false }
        return String(posterId) == userId
    }
    
    private var isTaker: Bool {
        guard let userId = currentUserId, let takerId = task.takerId else { return false }
        return String(takerId) == userId
    }
    
    private var isOriginator: Bool {
        guard let userId = currentUserId, let originatingUserId = task.originatingUserId else { return false }
        return String(originatingUserId) == userId
    }
    
    private var userRole: String {
        // 对于多人任务，需要特殊处理（按 task_source 与单人语义对齐）
        if task.isMultiParticipant == true {
            let source = task.taskSource ?? "normal"
            // 多人任务中，用户可能是：taker(达人/创建者)、申请者、发布者、参与者
            if isTaker {
                // taker 按来源：expert_activity 为组织者，expert_service 为达人，flea_market 为卖家，normal 保持任务达人
                switch source {
                case "expert_activity": return LocalizationKey.myTasksRoleOrganizer.localized
                case "expert_service": return LocalizationKey.myTasksRoleExpert.localized
                case "flea_market": return LocalizationKey.taskDetailSeller.localized
                default: return LocalizationKey.myTasksRoleExpert.localized
                }
            } else if isOriginator {
                return LocalizationKey.myTasksRoleApplicant.localized
            } else if isPoster {
                return LocalizationKey.myTasksRolePoster.localized
            } else {
                // 如果都不是，说明用户是参与者（通过 TaskParticipant 表关联）
                return LocalizationKey.myTasksRoleParticipant.localized
            }
        } else {
            // 单人任务：按任务来源使用不同称谓
            let source = task.taskSource ?? "normal"
            if isPoster {
                switch source {
                case "flea_market": return LocalizationKey.taskDetailBuyer.localized
                case "expert_service": return LocalizationKey.myTasksRoleUser.localized
                case "expert_activity": return LocalizationKey.myTasksRoleParticipant.localized
                default: return LocalizationKey.myTasksRolePoster.localized
                }
            } else if isTaker {
                switch source {
                case "flea_market": return LocalizationKey.taskDetailSeller.localized
                case "expert_service": return LocalizationKey.myTasksRoleExpert.localized
                case "expert_activity": return LocalizationKey.myTasksRoleOrganizer.localized
                default: return LocalizationKey.myTasksRoleTaker.localized
                }
            }
        }
        return LocalizationKey.myTasksRoleUnknown.localized
    }
    
    private func getRoleIcon() -> String {
        // 对于多人任务，需要特殊处理（图标与 task_source 下角色语义一致）
        if task.isMultiParticipant == true {
            let source = task.taskSource ?? "normal"
            if isTaker {
                return (source == "expert_activity") ? "person.3.fill" : "star.fill"  // 组织者 / 达人
            } else if isOriginator {
                return "person.badge.plus"  // 申请者
            } else if isPoster {
                return "square.and.pencil"  // 发布者
            } else {
                return "person.2.fill"  // 参与者
            }
        } else {
            // 单人任务
            return isPoster ? "square.and.pencil" : "hand.raised.fill"
        }
    }
    
    private func getTaskSourceIcon(_ source: String) -> String {
        switch source {
        case "flea_market":
            return "bag.fill"
        case "expert_service":
            return "star.fill"
        case "expert_activity":
            return "person.3.fill"
        default:
            return "tag.fill"
        }
    }
    
    private func getTaskSourceLabel(_ source: String) -> String {
        switch source {
        case "flea_market":
            return LocalizationKey.taskSourceFleaMarket.localized
        case "expert_service":
            return LocalizationKey.taskSourceExpertService.localized
        case "expert_activity":
            return LocalizationKey.taskSourceExpertActivity.localized
        default:
            return LocalizationKey.taskSourceNormal.localized
        }
    }
    
    private func getStatusColor() -> Color {
        switch task.status {
        case .open:
            return Color(red: 0.063, green: 0.725, blue: 0.506) // #10b981
        case .inProgress:
            return AppColors.primary
        case .completed:
            return AppColors.textSecondary
        case .cancelled:
            return AppColors.error
        case .pendingConfirmation:
            return AppColors.warning
        case .pendingPayment:
            return AppColors.warning
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // 任务标题和状态
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(task.displayTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(2)
                        
                        // 任务等级标签
                        if let taskLevel = task.taskLevel, taskLevel != "normal" {
                            Image(systemName: taskLevel == "vip" ? "star.fill" : "flame.fill")
                                .font(.system(size: 12))
                                .foregroundColor(getTaskLevelColor(taskLevel))
                        }
                    }
                    
                    // 用户角色标签和任务来源标签
                    HStack(spacing: AppSpacing.xs) {
                        // 用户角色标签
                        HStack(spacing: 4) {
                            Image(systemName: getRoleIcon())
                                .font(.system(size: 10))
                                .foregroundColor(AppColors.textTertiary)
                            Text(userRole)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(AppColors.textTertiary)
                        }
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(AppColors.fill)
                        .clipShape(Capsule())
                        
                        // 任务来源标签
                        if let taskSource = task.taskSource, taskSource != "normal" {
                            HStack(spacing: 4) {
                                Image(systemName: getTaskSourceIcon(taskSource))
                                    .font(.system(size: 10))
                                    .foregroundColor(AppColors.textTertiary)
                                Text(getTaskSourceLabel(taskSource))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundColor(AppColors.textTertiary)
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppColors.fill)
                            .clipShape(Capsule())
                        }
                    }
                }
                
                Spacer()
                
                // 状态标签
                StatusBadge(status: task.status)
            }
            
            Divider()
                .background(AppColors.separator.opacity(0.5))
            
            // 任务信息网格 - 更紧凑的布局
            VStack(spacing: AppSpacing.xs) {
                HStack(spacing: 0) {
                    InfoItemCompact(icon: "dollarsign.circle.fill", text: "£\(String(format: "%.2f", task.baseReward ?? task.reward))", color: AppColors.success)
                    Spacer()
                    InfoItemCompact(icon: task.location.lowercased() == "online" ? "globe" : "mappin.circle.fill", text: task.location.obfuscatedLocation, color: AppColors.primary)
                }
                
                HStack(spacing: 0) {
                    // 跳蚤市场：显示商品分类（从描述 "Category: " 解析），否则 taskType
                    if task.isFleaMarketTask, let cat = extractFleaMarketCategoryFromDescription(task.displayDescription), !cat.isEmpty {
                        InfoItemCompact(icon: "bag.fill", text: cat, color: AppColors.warning)
                    } else {
                        InfoItemCompact(icon: "tag.fill", text: task.taskType, color: AppColors.warning)
                    }
                    Spacer()
                    if let deadline = task.deadline {
                        InfoItemCompact(icon: "clock.fill", text: DateFormatterHelper.shared.formatDeadline(deadline), color: AppColors.textSecondary)
                    }
                }
            }
            
            // 任务描述
            if !task.description.isEmpty {
                Text(task.displayDescription)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.md)
        .background(AppColors.cardBackground) // 内容区域背景
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                .fill(AppColors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)
                        .stroke(AppColors.separator.opacity(0.3), lineWidth: 0.5)
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppCornerRadius.large, style: .continuous)) // 优化：确保圆角边缘干净
        .compositingGroup() // 组合渲染，确保圆角边缘干净
        // 移除阴影，使用更轻量的视觉分隔
    }
    
    private func getTaskLevelColor(_ level: String) -> Color {
        switch level {
        case "super":
            return Color(red: 0.545, green: 0.361, blue: 0.965) // #8b5cf6
        case "vip":
            return Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
        default:
            return Color.gray
        }
    }
    
    private func getTaskLevelLabel(_ level: String) -> String {
        switch level {
        case "super":
            return LocalizationKey.taskDetailSuperTask.localized
        case "vip":
            return LocalizationKey.taskDetailVipTask.localized
        default:
            return ""
        }
    }
    
    /// 从描述中按 "Category: {分类}" 提取跳蚤市场商品分类（后端创建任务时在描述末尾追加）
    private func extractFleaMarketCategoryFromDescription(_ text: String) -> String? {
        let prefix = "Category: "
        guard let range = text.range(of: prefix, options: .backwards) else { return nil }
        let after = String(text[range.upperBound...])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return after.isEmpty ? nil : after
    }
}

struct InfoItem: View {
    let icon: String
    let text: String
    
    var body: some View {
        Label(text, systemImage: icon) // 使用 SF Symbols
            .font(AppTypography.body) // 使用 body
            .foregroundColor(AppColors.textSecondary)
    }
}

// 紧凑的信息项组件 - 用于任务卡片
struct InfoItemCompact: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

