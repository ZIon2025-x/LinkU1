import SwiftUI

struct NotificationListView: View {
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
                    title: "暂无通知",
                    message: "还没有收到任何通知消息"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.notifications) { notification in
                            // 判断是否是任务相关的通知，并提取任务ID
                            if isTaskRelated(notification: notification), let taskId = extractTaskId(from: notification) {
                                NavigationLink(destination: TaskDetailView(taskId: taskId)) {
                                    NotificationRow(notification: notification)
                                }
                                .buttonStyle(PlainButtonStyle())
                                .simultaneousGesture(
                                    TapGesture().onEnded {
                                        // 点击时立即标记为已读
                                        print("🔔 [NotificationListView] 点击任务通知，ID: \(notification.id), isRead: \(notification.isRead ?? -1)")
                                        if notification.isRead == 0 {
                                            print("🔔 [NotificationListView] 标记为已读，ID: \(notification.id)")
                                            viewModel.markAsRead(notificationId: notification.id)
                                        }
                                    }
                                )
                            } else {
                                NotificationRow(notification: notification)
                                    .onTapGesture {
                                        // 标记为已读
                                        print("🔔 [NotificationListView] 点击普通通知，ID: \(notification.id), isRead: \(notification.isRead ?? -1)")
                                        if notification.isRead == 0 {
                                            print("🔔 [NotificationListView] 标记为已读，ID: \(notification.id)")
                                            viewModel.markAsRead(notificationId: notification.id)
                                        }
                                        // 如果有链接，可以跳转
                                        if let link = notification.link, !link.isEmpty {
                                            // 处理链接跳转
                                        }
                                    }
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
            }
        }
        .refreshable {
            viewModel.loadNotifications()
        }
        .onAppear {
            if viewModel.notifications.isEmpty {
                viewModel.loadNotifications()
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
        
        guard let type = notification.type else { return notification.relatedId }
        
        let lowercasedType = type.lowercased()
        
        // 对于 negotiation_offer 和 application_message 类型，related_id 是 application_id，不是 task_id
        // 这些通知应该使用 taskId 字段（后端已添加）
        if lowercasedType == "negotiation_offer" || lowercasedType == "application_message" {
            return nil  // 如果没有 taskId，不跳转
        }
        
        // 对于 task_application 类型，related_id 是 task_id（后端已修复）
        if lowercasedType == "task_application" {
            return notification.relatedId
        } else if lowercasedType.contains("task") {
            // 其他任务相关通知，related_id 就是 task_id
            return notification.relatedId
        }
        
        return nil
    }
}

struct NotificationRow: View {
    let notification: SystemNotification
    @State private var isLoadingTokens = false
    @State private var isResponding = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var tokenAccept: String?
    @State private var tokenReject: String?
    @State private var taskId: Int?
    @State private var applicationId: Int?
    
    var isNegotiationOffer: Bool {
        notification.type?.lowercased() == "negotiation_offer"
    }
    
    var isApplicationMessage: Bool {
        notification.type?.lowercased() == "application_message"
    }
    
    var body: some View {
        Group {
            // 如果是议价通知或留言通知，且有 task_id，可以跳转
            if (isNegotiationOffer || isApplicationMessage), let taskId = taskId {
                NavigationLink(destination: TaskDetailView(taskId: taskId)) {
                    notificationContent
                }
                .buttonStyle(PlainButtonStyle())
            } else {
                notificationContent
            }
        }
    }
    
    @ViewBuilder
    private var notificationContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                // 头像/图标
                ZStack {
                    Circle()
                        .fill(AppColors.primaryLight)
                        .frame(width: 50, height: 50)
                    Image(systemName: "bell.fill")
                        .foregroundColor(AppColors.primary)
                        .font(.system(size: 20))
                }
                
                // 内容区域
                VStack(alignment: .leading, spacing: 6) {
                    // 标题和时间
                    HStack(alignment: .top) {
                        Text(notification.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(AppColors.textPrimary)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(formatTime(notification.createdAt))
                                .font(.system(size: 12))
                                .foregroundColor(AppColors.textSecondary)
                            
                            if notification.isRead == 0 {
                                Circle()
                                    .fill(AppColors.error)
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                    
                    // 内容预览
                    Text(notification.content)
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(isNegotiationOffer ? nil : 2)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
            }
            
            // 议价通知的操作按钮
            if isNegotiationOffer {
                HStack(spacing: AppSpacing.sm) {
                    Button(action: {
                        respondToNegotiation(accept: true)
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                            Text("同意")
                                .font(AppTypography.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.success)
                        .cornerRadius(AppCornerRadius.small)
                    }
                    .disabled(isResponding || isLoadingTokens)
                    
                    Button(action: {
                        respondToNegotiation(accept: false)
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                            Text("拒绝")
                                .font(AppTypography.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(AppColors.error)
                        .cornerRadius(AppCornerRadius.small)
                    }
                    .disabled(isResponding || isLoadingTokens)
                }
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle(cornerRadius: AppCornerRadius.medium)
        .opacity(notification.isRead == 1 ? 0.7 : 1.0)
        .onAppear {
            if (isNegotiationOffer || isApplicationMessage) && tokenAccept == nil {
                loadNegotiationTokens()
            }
        }
        .alert("操作失败", isPresented: $showError) {
            Button("确定", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func formatTime(_ timeString: String) -> String {
        return DateFormatterHelper.shared.formatTime(timeString)
    }
    
    private func loadNegotiationTokens() {
        guard !isLoadingTokens else { return }
        
        isLoadingTokens = true
        
        // 优先使用通知中的 taskId 字段（后端已添加）
        if let notificationTaskId = notification.taskId {
            taskId = notificationTaskId
            applicationId = notification.relatedId
            isLoadingTokens = false
            return
        }
        
        // 对于 application_message 类型，没有 token，但应该已经有 taskId 字段
        if isApplicationMessage {
            isLoadingTokens = false
            return
        }
        
        APIService.shared.getNegotiationTokens(notificationId: notification.id)
            .sink(
                receiveCompletion: { result in
                    isLoadingTokens = false
                    if case .failure(let error) = result {
                        errorMessage = error.userFriendlyMessage
                        showError = true
                    }
                },
                receiveValue: { response in
                    tokenAccept = response.tokenAccept
                    tokenReject = response.tokenReject
                    taskId = response.taskId ?? notification.taskId
                    applicationId = response.applicationId ?? notification.relatedId
                }
            )
            .store(in: &cancellables)
    }
    
    @State private var cancellables = Set<AnyCancellable>()
    
    private func respondToNegotiation(accept: Bool) {
        guard let applicationId = applicationId,
              let taskId = taskId,
              let token = accept ? tokenAccept : tokenReject else {
            errorMessage = "无法获取议价信息，请刷新后重试"
            showError = true
            return
        }
        
        isResponding = true
        
        APIService.shared.respondNegotiation(
            taskId: taskId,
            applicationId: applicationId,
            action: accept ? "accept" : "reject",
            token: token
        )
        .sink(
            receiveCompletion: { result in
                isResponding = false
                if case .failure(let error) = result {
                    errorMessage = error.userFriendlyMessage
                    showError = true
                } else {
                    // 成功，可以刷新通知列表
                    NotificationCenter.default.post(name: NSNotification.Name("NotificationUpdated"), object: nil)
                }
            },
            receiveValue: { _ in }
        )
        .store(in: &cancellables)
    }
}

