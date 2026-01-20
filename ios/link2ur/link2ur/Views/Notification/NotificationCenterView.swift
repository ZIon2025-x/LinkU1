import SwiftUI

struct NotificationCenterView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectedTab = 0
    @State private var searchText = ""
    @StateObject private var notificationViewModel = NotificationViewModel()
    
    private var tabs: [String] {
        [
            LocalizationKey.notificationSystemNotification.localized,
            LocalizationKey.notificationCustomerService.localized,
            LocalizationKey.notificationTaskChat.localized
        ]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // 系统消息卡片
                    NavigationLink(destination: SystemMessageView()) {
                        SystemMessageCard(unreadCount: unreadNotificationCount)
                    }
                    .buttonStyle(PlainButtonStyle())
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.sm)
                    
                    // 搜索栏
                    HStack(spacing: 12) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(AppColors.textSecondary)
                                .font(.system(size: 16))
                            
                            TextField(LocalizationKey.commonSearch.localized, text: $searchText)
                                .font(.system(size: 15))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(AppColors.cardBackground)
                        .cornerRadius(20)
                        
                        if !searchText.isEmpty {
                            Button(LocalizationKey.commonSearch.localized) {
                                // 执行搜索
                            }
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(AppColors.primary)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColors.background)
                    
                    // 分类标签栏（横向滚动）
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(0..<tabs.count, id: \.self) { index in
                                CategoryTabButton(
                                    title: tabs[index],
                                    isSelected: selectedTab == index
                                ) {
                                    selectedTab = index
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .background(AppColors.background)
                    
                    // 内容区域
                    TabView(selection: $selectedTab) {
                        NotificationListView()
                            .tag(0)
                        
                        CustomerServiceView()
                            .tag(1)
                        
                        TaskChatListView()
                            .tag(2)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // 加载通知以获取未读数量
            notificationViewModel.loadNotifications()
        }
    }
    
    // 计算未读通知数量
    private var unreadNotificationCount: Int {
        notificationViewModel.notifications.filter { $0.isRead == 0 }.count
    }
}

// 系统消息卡片 - 参考TaskCard设计
struct SystemMessageCard: View {
    let unreadCount: Int
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: AppColors.gradientPrimary),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // 内容层
            HStack(alignment: .center, spacing: AppSpacing.md) {
                // 左侧图标
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: 42, height: 42)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // 中间文字
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizationKey.notificationSystemMessages.localized)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(LocalizationKey.notificationViewAllNotifications.localized)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // 右侧未读数量或箭头
                if unreadCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(unreadCount)")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        if unreadCount < 10 {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: 6, height: 6)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(AppCornerRadius.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .frame(height: 80)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppColors.primary.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

// 系统消息页面
struct SystemMessageView: View {
    @StateObject private var viewModel = NotificationViewModel()
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && viewModel.notifications.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, viewModel.notifications.isEmpty {
                ErrorStateView(
                    message: error,
                    retryAction: {
                        viewModel.loadNotifications()
                    }
                )
            } else if viewModel.notifications.isEmpty {
                EmptyStateView(
                    icon: "bell.fill",
                    title: LocalizationKey.emptyNoNotifications.localized,
                    message: LocalizationKey.emptyNoNotificationsMessage.localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: AppSpacing.md) {
                        ForEach(viewModel.notifications) { notification in
                            // 判断是否是任务相关的通知，并提取任务ID
                            if isTaskRelated(notification: notification) {
                                let extractedTaskId = extractTaskId(from: notification)
                                
                                // 调试日志
                                print("🔔 [NotificationCenterView] 任务通知 - ID: \(notification.id), type: \(notification.type ?? "nil"), taskId: \(notification.taskId?.description ?? "nil"), relatedId: \(notification.relatedId?.description ?? "nil"), extractedTaskId: \(extractedTaskId?.description ?? "nil")")
                                
                                let onTapCallback: () -> Void = {
                                    // 点击时立即标记为已读
                                    print("🔔 [SystemMessageView] 点击任务通知，ID: \(notification.id), isRead: \(notification.isRead ?? -1)")
                                    if notification.isRead == 0 {
                                        print("🔔 [SystemMessageView] 标记为已读，ID: \(notification.id)")
                                        viewModel.markAsRead(notificationId: notification.id)
                                    }
                                }
                                
                                // 如果有 taskId，创建 NavigationLink；否则让 NotificationRow 内部处理
                                if let taskId = extractedTaskId {
                                    NavigationLink(destination: TaskDetailView(taskId: taskId)) {
                                        NotificationRow(notification: notification, isTaskRelated: true, onTap: onTapCallback)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            onTapCallback()
                                        }
                                    )
                                } else {
                                    // 对于 negotiation_offer 和 application_message，即使 taskId 为 null，也创建 NotificationRow
                                    // NotificationRow 内部会等待异步加载完成
                                    print("🔔 [NotificationCenterView] 警告：任务通知但没有 taskId，ID: \(notification.id), type: \(notification.type ?? "nil")")
                                    NotificationRow(notification: notification, isTaskRelated: false, onTap: onTapCallback)
                                }
                            } else {
                                NotificationRow(notification: notification, isTaskRelated: false, onTap: {
                                    // 标记为已读
                                    print("🔔 [SystemMessageView] 点击普通通知，ID: \(notification.id), isRead: \(notification.isRead ?? -1)")
                                    if notification.isRead == 0 {
                                        print("🔔 [SystemMessageView] 标记为已读，ID: \(notification.id)")
                                        viewModel.markAsRead(notificationId: notification.id)
                                    }
                                })
                            }
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                }
            }
        }
        .navigationTitle(LocalizationKey.notificationSystemMessages.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .refreshable {
            // 加载所有未读通知和最近已读通知，确保用户可以查看所有未读通知
            viewModel.loadNotificationsWithRecentRead(recentReadLimit: 20)
        }
        .onAppear {
            // 加载所有未读通知和最近已读通知，确保用户可以查看所有未读通知
            if viewModel.notifications.isEmpty {
                viewModel.loadNotificationsWithRecentRead(recentReadLimit: 20)
            }
        }
    }
    
    /// 判断通知是否是任务相关的
    private func isTaskRelated(notification: SystemNotification) -> Bool {
        guard let type = notification.type else { return false }
        
        let lowercasedType = type.lowercased()
        
        // 检查是否是任务相关的通知类型
        // 后端任务通知类型包括：task_application, task_approved, task_completed, task_confirmation, task_cancelled 等
        if lowercasedType.contains("task") {
            return true
        }
        
        return false
    }
    
    /// 从通知中提取任务ID
    private func extractTaskId(from notification: SystemNotification) -> Int? {
        // 优先使用 taskId 字段（后端已添加）
        if let taskId = notification.taskId {
            return taskId
        }
        
        guard let type = notification.type else { return nil }
        
        let lowercasedType = type.lowercased()
        
        // 对于 negotiation_offer 和 application_message 类型，related_id 是 application_id，不是 task_id
        // 这些通知必须使用 taskId 字段（后端已添加）
        if lowercasedType == "negotiation_offer" || lowercasedType == "application_message" {
            return nil  // 如果没有 taskId，不跳转
        }
        
        // 对于 task_application 类型，优先使用 taskId，如果没有则使用 relatedId（应该是 task_id）
        if lowercasedType == "task_application" {
            return notification.relatedId
        }
        
        // task_approved, task_completed, task_confirmed, task_cancelled, task_reward_paid 等类型
        // related_id 就是 task_id（后端已统一）
        if lowercasedType == "task_approved" || 
           lowercasedType == "task_completed" || 
           lowercasedType == "task_confirmed" || 
           lowercasedType == "task_cancelled" ||
           lowercasedType == "task_reward_paid" {
            return notification.relatedId
        }
        
        // 其他包含 "task" 的通知类型，尝试使用 relatedId
        if lowercasedType.contains("task") {
            return notification.relatedId
        }
        
        return nil
    }
}

// 分类标签按钮 - 现代简洁设计
struct CategoryTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.7)) {
                action()
            }
        }) {
            Text(title)
                .font(AppTypography.subheadline)
                .fontWeight(isSelected ? .semibold : .medium)
                .foregroundColor(isSelected ? .white : AppColors.textSecondary)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, 7)
                .background(
                    Group {
                        if isSelected {
                            LinearGradient(
                                gradient: Gradient(colors: AppColors.gradientPrimary),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            AppColors.cardBackground
                        }
                    }
                )
                .cornerRadius(AppCornerRadius.pill)
                .overlay(
                    RoundedRectangle(cornerRadius: AppCornerRadius.pill)
                        .stroke(isSelected ? Color.clear : AppColors.divider, lineWidth: 1)
                )
                .shadow(color: isSelected ? AppColors.primary.opacity(0.15) : Color.clear, radius: 4, x: 0, y: 2)
        }
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isSelected)
    }
}

