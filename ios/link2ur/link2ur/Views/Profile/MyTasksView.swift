import SwiftUI

struct MyTasksView: View {
    @StateObject private var viewModel = MyTasksViewModel()
    @State private var selectedTab: TaskTab = .all
    @EnvironmentObject var appState: AppState
    
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
                    ) {
                        let previousTab = selectedTab
                        selectedTab = tab
                        viewModel.currentTab = tab
                        // 切换标签页时，如果是"已完成"标签页，立即加载已完成的任务
                        if tab == .completed && previousTab != .completed {
                            viewModel.loadCompletedTasks()
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
                ProgressView()
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
            ProgressView()
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
                    ForEach(viewModel.getPendingApplications()) { application in
                        MyTasksApplicationCard(application: application)
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
                ForEach(viewModel.getFilteredTasks()) { task in
                    NavigationLink(destination: TaskDetailView(taskId: task.id)) {
                        EnhancedTaskCard(task: task, currentUserId: viewModel.currentUserId)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onAppear {
                        print("🔍 [MyTasksView] 任务卡片出现: \(task.id), 标题: \(task.title)")
                    }
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
            return "您还没有发布或接受任何任务"
        case .posted:
            return "您还没有发布任何任务"
        case .taken:
            return "您还没有接受任何任务"
        case .pending:
            return "您还没有待处理的申请记录"
        case .completed:
            return "您还没有已完成的任务"
        case .cancelled:
            return "您还没有已取消的任务"
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
                
                Text(tab.rawValue)
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
                    Text(application.taskTitle)
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
            NavigationLink(destination: TaskDetailView(taskId: application.taskId)) {
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
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .stroke(AppColors.separator.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: 0, y: AppShadow.small.y)
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
    
    private var userRole: String {
        if isPoster {
            return "发布者"
        } else if isTaker {
            return "接受者"
        }
        return "未知"
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
                        Text(task.title)
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
                    
                    // 用户角色标签
                    HStack(spacing: 4) {
                        Image(systemName: isPoster ? "square.and.pencil" : "hand.raised.fill")
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
                    InfoItemCompact(icon: "tag.fill", text: task.taskType, color: AppColors.warning)
                    Spacer()
                    if let deadline = task.deadline {
                        InfoItemCompact(icon: "clock.fill", text: DateFormatterHelper.shared.formatDeadline(deadline), color: AppColors.textSecondary)
                    }
                }
            }
            
            // 任务描述
            if !task.description.isEmpty {
                Text(task.description)
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .padding(.top, AppSpacing.xs)
            }
        }
        .padding(AppSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .fill(AppColors.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppCornerRadius.large)
                .stroke(AppColors.separator.opacity(0.3), lineWidth: 0.5)
        )
        .shadow(color: AppShadow.small.color, radius: AppShadow.small.radius, x: 0, y: AppShadow.small.y)
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
            return "🔥 超级任务"
        case "vip":
            return "⭐ VIP任务"
        default:
            return ""
        }
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

