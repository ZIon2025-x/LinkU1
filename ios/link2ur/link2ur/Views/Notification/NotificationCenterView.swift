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
            HStack(alignment: .center, spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                // 左侧图标
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.25))
                        .frame(width: DeviceInfo.isPad ? 56 : 42, height: DeviceInfo.isPad ? 56 : 42)
                    
                    Image(systemName: "bell.fill")
                        .font(.system(size: DeviceInfo.isPad ? 26 : 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // 中间文字
                VStack(alignment: .leading, spacing: DeviceInfo.isPad ? 4 : 2) {
                    Text(LocalizationKey.notificationSystemMessages.localized)
                        .font(.system(size: DeviceInfo.isPad ? 18 : 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(LocalizationKey.notificationViewAllNotifications.localized)
                        .font(.system(size: DeviceInfo.isPad ? 14 : 12))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // 右侧未读数量或箭头
                if unreadCount > 0 {
                    HStack(spacing: 4) {
                        Text("\(unreadCount)")
                            .font(.system(size: DeviceInfo.isPad ? 18 : 16, weight: .bold))
                            .foregroundColor(.white)
                        
                        if unreadCount < 10 {
                            Circle()
                                .fill(Color.white.opacity(0.3))
                                .frame(width: DeviceInfo.isPad ? 8 : 6, height: DeviceInfo.isPad ? 8 : 6)
                        }
                    }
                    .padding(.horizontal, DeviceInfo.isPad ? 12 : 10)
                    .padding(.vertical, DeviceInfo.isPad ? 8 : 6)
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(AppCornerRadius.small)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: DeviceInfo.isPad ? 16 : 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(DeviceInfo.isPad ? 10 : 8)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
            .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
        }
        .frame(height: DeviceInfo.isPad ? 100 : 80)
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
                            // 优先判断是否是跳蚤市场相关的通知
                            if NotificationHelper.isFleaMarketRelated(notification) {
                                let onTapCallback: () -> Void = {
                                    // 点击时立即标记为已读
                                    if notification.isRead == 0 {
                                        viewModel.markAsRead(notificationId: notification.id)
                                    }
                                }
                                
                                // 优先检查是否有 task_id（部分跳蚤市场通知需要跳转到任务/支付页面）
                                if let taskId = NotificationHelper.extractFleaMarketTaskId(from: notification) {
                                    NavigationLink(destination: TaskDetailView(taskId: taskId)) {
                                        NotificationRow(notification: notification, isTaskRelated: false, isFleaMarketRelated: true, onTap: onTapCallback)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            onTapCallback()
                                        }
                                    )
                                } else if let itemId = NotificationHelper.extractFleaMarketItemId(from: notification) {
                                    // 有商品ID，跳转到商品详情页
                                    NavigationLink(destination: FleaMarketDetailView(itemId: itemId)) {
                                        NotificationRow(notification: notification, isTaskRelated: false, isFleaMarketRelated: true, onTap: onTapCallback)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .simultaneousGesture(
                                        TapGesture().onEnded {
                                            onTapCallback()
                                        }
                                    )
                                } else {
                                    // 没有可跳转的ID，显示通知详情
                                    NotificationRow(notification: notification, isTaskRelated: false, isFleaMarketRelated: true, onTap: onTapCallback)
                                }
                            }
                            // 判断是否是任务相关的通知，并提取任务ID
                            else if NotificationHelper.isTaskRelated(notification) {
                                let extractedTaskId = NotificationHelper.extractTaskId(from: notification)
                                
                                let onTapCallback: () -> Void = {
                                    // 点击时立即标记为已读
                                    if notification.isRead == 0 {
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
                                    NotificationRow(notification: notification, isTaskRelated: false, onTap: onTapCallback)
                                }
                            }
                            // 达人活动相关通知（活动奖励等）→ 跳转活动详情
                            else if NotificationHelper.isActivityRelated(notification),
                                    let activityId = NotificationHelper.extractActivityId(from: notification) {
                                let onTapCallback: () -> Void = {
                                    if notification.isRead == 0 {
                                        viewModel.markAsRead(notificationId: notification.id)
                                    }
                                }
                                NavigationLink(destination: ActivityDetailView(activityId: activityId)) {
                                    NotificationRow(notification: notification, isTaskRelated: false, onTap: onTapCallback)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .simultaneousGesture(TapGesture().onEnded { onTapCallback() })
                            } else {
                                NotificationRow(notification: notification, isTaskRelated: false, onTap: {
                                    // 标记为已读
                                    if notification.isRead == 0 {
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

