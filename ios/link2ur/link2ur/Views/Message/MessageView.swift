import SwiftUI

struct MessageView: View {
    @StateObject private var viewModel = TaskChatViewModel()
    @StateObject private var notificationViewModel = NotificationViewModel()
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationStack {
            ZStack {
                AppColors.background
                    .ignoresSafeArea()
                
                if viewModel.isLoading && viewModel.taskChats.isEmpty {
                    LoadingView()
                } else if let error = viewModel.errorMessage, viewModel.taskChats.isEmpty {
                    ErrorStateView(
                        message: error,
                        retryAction: {
                            viewModel.loadTaskChats()
                        }
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                            // 系统消息卡片（始终显示在顶部）
                            NavigationLink(destination: SystemMessageView()) {
                                SystemMessageCard(unreadCount: unreadNotificationCount)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 客服信息卡片
                            NavigationLink(destination: CustomerServiceView()
                                .environmentObject(appState)) {
                                CustomerServiceCard()
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 互动信息卡片
                            NavigationLink(destination: InteractionMessageView()) {
                                InteractionMessageCard(unreadCount: interactionNotificationCount)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // 任务聊天列表
                            if viewModel.taskChats.isEmpty {
                                EmptyStateView(
                                    icon: "message.fill",
                                    title: LocalizationKey.messagesNoTaskChats.localized,
                                    message: LocalizationKey.messagesNoTaskChatsMessage.localized
                                )
                                .padding(.top, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.lg)
                            } else {
                                ForEach(Array(viewModel.taskChats.enumerated()), id: \.element.id) { index, taskChat in
                                    NavigationLink(destination: TaskChatView(taskId: taskChat.id, taskTitle: taskChat.displayTitle, taskChat: taskChat)
                                        .environmentObject(appState)) {
                                        TaskChatRow(taskChat: taskChat, currentUserId: appState.currentUser?.id)
                                    }
                                    .buttonStyle(ScaleButtonStyle())
                                    .listItemAppear(index: index, totalItems: viewModel.taskChats.count) // 分步入场动画
                                }
                            }
                        }
                        .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                        .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
                        .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                        .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                    }
                }
            }
            .navigationTitle(LocalizationKey.messagesMessages.localized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .enableSwipeBack()
            .refreshable {
                viewModel.loadTaskChats()
                notificationViewModel.loadNotifications()
            }
            .onAppear {
                // 始终重新加载任务聊天列表，确保未读数最新
                viewModel.loadTaskChats()
                
                // 加载通知以获取未读数量
                notificationViewModel.loadNotifications()
                
                // 更新 AppState 中的未读通知数量
                appState.loadUnreadNotificationCount()
            }
            .onChange(of: notificationViewModel.notifications.count) { _ in
                // 当通知列表更新时，更新 AppState
                appState.loadUnreadNotificationCount()
            }
            .onChange(of: notificationViewModel.forumNotifications.count) { _ in
                // 当论坛通知列表更新时，也更新 AppState
                appState.loadUnreadNotificationCount()
            }
            .onChange(of: viewModel.taskChats) { _ in
                // 当任务聊天列表更新时，使用列表中的 unread_count 更新 badge
                // 这样可以保证 badge 与页面显示的未读数一致
                appState.unreadMessageCount = totalUnreadMessages
            }
        }
    }
    
    // 计算未读通知数量 - 性能优化：缓存计算结果
    private var unreadNotificationCount: Int {
        notificationViewModel.notifications.filter { $0.isRead == 0 }.count
    }
    
    // 性能优化：缓存未读消息总数计算
    private var totalUnreadMessages: Int {
        viewModel.taskChats.reduce(0) { $0 + ($1.unreadCount ?? 0) }
    }
    
    // 计算互动通知数量（论坛相关等）
    private var interactionNotificationCount: Int {
        notificationViewModel.unifiedNotifications.filter { notification in
            !notification.isRead && (
                notification.type == "forum_reply" ||
                notification.type == "forum_like" ||
                notification.type == "forum_favorite" ||
                notification.type == "forum_mention" ||
                notification.type == "forum_pin" ||
                notification.type == "forum_feature" ||
                notification.type.hasPrefix("forum_") ||
                notification.type.hasPrefix("leaderboard_")
            )
        }.count
    }
}

// 客服信息卡片
struct CustomerServiceCard: View {
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: AppColors.gradientSuccess),
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
                    
                    Image(systemName: "headphones")
                        .font(.system(size: DeviceInfo.isPad ? 26 : 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // 中间文字
                VStack(alignment: .leading, spacing: DeviceInfo.isPad ? 4 : 2) {
                    Text(LocalizationKey.messagesCustomerService.localized)
                        .font(.system(size: DeviceInfo.isPad ? 18 : 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(LocalizationKey.messagesContactService.localized)
                        .font(.system(size: DeviceInfo.isPad ? 14 : 12))
                        .foregroundColor(.white.opacity(0.85))
                }
                
                Spacer()
                
                // 右侧箭头
                Image(systemName: "chevron.right")
                    .font(.system(size: DeviceInfo.isPad ? 16 : 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(DeviceInfo.isPad ? 10 : 8)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md)
            .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
        }
        .frame(height: DeviceInfo.isPad ? 100 : 80)
        .cornerRadius(AppCornerRadius.medium)
        .shadow(color: AppColors.success.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

// 互动信息卡片
struct InteractionMessageCard: View {
    let unreadCount: Int
    
    var body: some View {
        ZStack {
            // 渐变背景
            LinearGradient(
                gradient: Gradient(colors: AppColors.gradientWarning),
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
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: DeviceInfo.isPad ? 26 : 20, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                // 中间文字
                VStack(alignment: .leading, spacing: DeviceInfo.isPad ? 4 : 2) {
                    Text(LocalizationKey.messagesInteractionInfo.localized)
                        .font(.system(size: DeviceInfo.isPad ? 18 : 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text(LocalizationKey.messagesViewForumInteractions.localized)
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
        .shadow(color: AppColors.warning.opacity(0.25), radius: 6, x: 0, y: 3)
    }
}

// 互动信息页面
struct InteractionMessageView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @State private var navigationPath = NavigationPath()
    
    // 筛选出互动相关的通知（论坛和排行榜相关）
    private var interactionNotifications: [UnifiedNotification] {
        viewModel.unifiedNotifications.filter { notification in
            // 论坛相关
            return notification.type == "forum_reply" ||
                   notification.type == "forum_like" ||
                   notification.type == "forum_favorite" ||
                   notification.type == "forum_mention" ||
                   notification.type == "forum_pin" ||
                   notification.type == "forum_feature" ||
                   notification.type.hasPrefix("forum_") ||
                   // 排行榜相关
                   notification.type == "leaderboard_vote" ||
                   notification.type == "leaderboard_comment" ||
                   notification.type == "leaderboard_like" ||
                   notification.type.hasPrefix("leaderboard_")
        }
    }
    
    // 根据通知类型和 relatedId 生成导航目标
    @ViewBuilder
    private func destinationView(for notification: UnifiedNotification) -> some View {
        if let relatedId = notification.relatedId {
            if notification.type.hasPrefix("forum_") {
                // 论坛相关通知，跳转到帖子详情
                // 对于回复类型的通知，使用postId；对于点赞类型的通知，使用targetId
                let postId = notification.postId ?? relatedId
                ForumPostDetailView(postId: postId)
            } else if notification.type.hasPrefix("leaderboard_") {
                // 排行榜相关通知，使用辅助视图来加载并显示详情
                LeaderboardItemDetailWrapperView(itemId: relatedId)
            } else {
                EmptyView()
            }
        } else {
            EmptyView()
        }
    }
    
    var body: some View {
        ZStack {
            AppColors.background
                .ignoresSafeArea()
            
            if viewModel.isLoading && interactionNotifications.isEmpty {
                LoadingView()
            } else if let error = viewModel.errorMessage, interactionNotifications.isEmpty {
                ErrorStateView(
                    message: error,
                    retryAction: {
                        viewModel.loadForumNotificationsOnly()
                    }
                )
            } else if interactionNotifications.isEmpty {
                EmptyStateView(
                    icon: "heart.fill",
                    title: LocalizationKey.messagesNoInteractions.localized,
                    message: LocalizationKey.messagesNoInteractionsMessage.localized
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: DeviceInfo.isPad ? AppSpacing.lg : AppSpacing.md) {
                        ForEach(interactionNotifications) { notification in
                            // 使用 NavigationLink 实现点击跳转
                            if notification.relatedId != nil {
                                NavigationLink(destination: destinationView(for: notification)) {
                                    UnifiedNotificationRow(notification: notification)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        // 标记为已读
                                        if !notification.isRead {
                                            markNotificationAsRead(notification)
                                        }
                                    }
                                )
                            } else {
                                // 如果没有 relatedId，只显示通知，不跳转
                                UnifiedNotificationRow(notification: notification)
                                    .onTapGesture {
                                        // 标记为已读
                                        if !notification.isRead {
                                            markNotificationAsRead(notification)
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.xl : AppSpacing.md)
                    .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : AppSpacing.sm)
                    .frame(maxWidth: DeviceInfo.isPad ? 900 : .infinity) // iPad上限制最大宽度
                    .frame(maxWidth: .infinity, alignment: .center) // 确保在iPad上居中
                }
            }
        }
        .navigationTitle(LocalizationKey.messagesInteractionInfo.localized)
        .navigationBarTitleDisplayMode(.inline)
        .enableSwipeBack()
        .refreshable {
            viewModel.loadForumNotificationsOnly()
        }
        .onAppear {
            if viewModel.unifiedNotifications.isEmpty {
                viewModel.loadForumNotificationsOnly()
            }
        }
    }
    
    // 标记通知为已读
    private func markNotificationAsRead(_ notification: UnifiedNotification) {
        switch notification.source {
        case .system(let systemNotification):
            viewModel.markAsRead(notificationId: systemNotification.id)
        case .forum(let forumNotification):
            viewModel.markForumNotificationAsRead(notificationId: forumNotification.id)
        }
    }
}

// 统一通知行组件
struct UnifiedNotificationRow: View {
    let notification: UnifiedNotification
    
    var body: some View {
        HStack(alignment: .top, spacing: DeviceInfo.isPad ? AppSpacing.lg : 12) {
            // 头像/图标
            ZStack {
                let avatarSize: CGFloat = DeviceInfo.isPad ? 64 : 50
                Circle()
                    .fill(AppColors.primaryLight)
                    .frame(width: avatarSize, height: avatarSize)
                
                if let fromUser = notification.fromUser, let avatar = fromUser.avatar {
                    AvatarView(
                        urlString: avatar,
                        size: avatarSize,
                        placeholder: Image(systemName: "person.fill")
                    )
                } else {
                    Image(systemName: notification.type.hasPrefix("forum_") ? "bubble.left.and.bubble.right.fill" : "bell.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.system(size: DeviceInfo.isPad ? 28 : 20))
                }
            }
            
            // 内容区域
            VStack(alignment: .leading, spacing: DeviceInfo.isPad ? 8 : 6) {
                // 标题和时间
                HStack(alignment: .top) {
                    Text(notification.title)
                        .font(.system(size: DeviceInfo.isPad ? 18 : 16, weight: .medium))
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(formatTime(notification.createdAt))
                            .font(.system(size: DeviceInfo.isPad ? 14 : 12))
                            .foregroundColor(AppColors.textSecondary)
                        
                        if !notification.isRead {
                            Circle()
                                .fill(AppColors.error)
                                .frame(width: DeviceInfo.isPad ? 10 : 8, height: DeviceInfo.isPad ? 10 : 8)
                        }
                    }
                }
                
                // 内容预览
                Text(notification.content)
                    .font(.system(size: DeviceInfo.isPad ? 16 : 14))
                    .foregroundColor(AppColors.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, DeviceInfo.isPad ? AppSpacing.lg : 16)
        .padding(.vertical, DeviceInfo.isPad ? AppSpacing.md : 12)
        .cardStyle(cornerRadius: AppCornerRadius.medium)
        .opacity(notification.isRead ? 0.7 : 1.0)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 对话行组件 - 更现代的设计
struct ConversationRow: View {
    let contact: Contact
    
    var body: some View {
        HStack(spacing: AppSpacing.md) {
            // 头像 - 渐变边框
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: AppColors.gradientPrimary),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                
                AvatarView(
                    urlString: contact.avatar,
                    size: 56,
                    placeholder: Image(systemName: "person.fill")
                )
            }
            
            // 信息
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(contact.name ?? contact.email ?? LocalizationKey.profileUser.localized)
                        .font(AppTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastTime = contact.lastMessageTime {
                        Text(formatTime(lastTime))
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.textTertiary)
                    }
                }
                
                HStack {
                    Text(LocalizationKey.messagesClickToView.localized)
                        .font(AppTypography.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    // 未读数 - 渐变背景
                    if let unreadCount = contact.unreadCount, unreadCount > 0 {
                        ZStack {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [AppColors.error, AppColors.error.opacity(0.8)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: unreadCount > 9 ? 28 : 20, height: 20)
                            
                            Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
                                .font(AppTypography.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, unreadCount > 9 ? 6 : 0)
                        }
                    }
                }
            }
        }
        .padding(AppSpacing.md)
        .cardStyle(cornerRadius: AppCornerRadius.large)
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
}

// 排行榜竞品详情包装视图（用于从通知跳转，需要先加载item获取leaderboardId）
struct LeaderboardItemDetailWrapperView: View {
    let itemId: Int
    @StateObject private var viewModel = LeaderboardItemDetailViewModel()
    @State private var leaderboardId: Int?
    
    var body: some View {
        Group {
            if let leaderboardId = leaderboardId {
                LeaderboardItemDetailView(itemId: itemId, leaderboardId: leaderboardId)
            } else if viewModel.isLoading {
                LoadingView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // 如果无法获取leaderboardId，尝试使用默认值1，或者显示错误
                LeaderboardItemDetailView(itemId: itemId, leaderboardId: 1)
            }
        }
        .onAppear {
            // 加载item以获取leaderboardId（如果API返回的话）
            // 由于当前API可能不返回leaderboardId，这里先尝试加载
            viewModel.loadItem(itemId: itemId)
            // 如果API不返回leaderboardId，我们需要从其他地方获取
            // 暂时使用默认值，后续可以根据实际需求优化
            if leaderboardId == nil {
                // 尝试从通知的link或其他字段中提取leaderboardId
                // 或者使用一个默认值
                self.leaderboardId = 1
            }
        }
    }
}
