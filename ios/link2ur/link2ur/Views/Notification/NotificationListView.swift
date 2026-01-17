import SwiftUI
import Combine

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
                    title: LocalizationKey.notificationNoNotifications.localized,
                    message: LocalizationKey.notificationNoNotificationsMessage.localized
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
    @State private var isExpired: Bool = false  // 优化：标记议价是否已过期
    @State private var expiresAt: Date? = nil  // 优化：真实过期时间
    @State private var taskStatus: String? = nil  // 优化：任务状态，用于判断是否已过期
    
    var isNegotiationOffer: Bool {
        notification.type?.lowercased() == "negotiation_offer"
    }
    
    var isApplicationMessage: Bool {
        notification.type?.lowercased() == "application_message"
    }
    
    // 优化：检查议价是否已过期（使用真实过期时间和任务状态）
    private var isNegotiationExpired: Bool {
        guard isNegotiationOffer else { return false }
        
        // 如果已标记为过期
        if isExpired {
            return true
        }
        
        // 优化：如果任务已进入进行中或更后面的状态，议价应该显示为已过期
        if let taskStatus = taskStatus {
            let status = taskStatus.lowercased()
            // 如果任务状态是 in_progress, pending_payment, pending_confirmation, completed, cancelled，议价已过期
            if status == "in_progress" || 
               status == "pending_payment" || 
               status == "pending_confirmation" || 
               status == "completed" || 
               status == "cancelled" {
                return true
            }
        }
        
        // 如果有真实过期时间，使用过期时间判断
        if let expiresAt = expiresAt {
            return Date() >= expiresAt
        }
        
        // 如果token为nil且已加载完成，检查通知创建时间是否超过5分钟（降级方案）
        if !isLoadingTokens && tokenAccept == nil && tokenReject == nil {
            // 解析通知创建时间
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            isoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
            
            if let createdAt = isoFormatter.date(from: notification.createdAt) {
                let now = Date()
                let timeInterval = now.timeIntervalSince(createdAt)
                // 5分钟 = 300秒
                return timeInterval > 300
            }
        }
        
        return false
    }
    
    // 优化：格式化剩余时间显示
    private var remainingTimeText: String? {
        guard isNegotiationOffer, let expiresAt = expiresAt else { return nil }
        let now = Date()
        if now >= expiresAt {
            return nil  // 已过期
        }
        let remaining = expiresAt.timeIntervalSince(now)
        if remaining < 60 {
            return String(format: "%.0f秒后过期", remaining)
        } else if remaining < 3600 {
            let minutes = Int(remaining / 60)
            return "\(minutes)分钟后过期"
        } else {
            let hours = Int(remaining / 3600)
            return "\(hours)小时后过期"
        }
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
                if isNegotiationExpired {
                    // 优化：已过期，显示不可点击的"已过期"按钮，显示真实过期时间
                    VStack(spacing: 4) {
                        Button(action: {}) {
                            HStack {
                                Image(systemName: "clock.fill")
                                    .font(.system(size: 16))
                                Text(LocalizationKey.notificationExpired.localized)
                                    .font(AppTypography.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.textTertiary)
                            .cornerRadius(AppCornerRadius.small)
                        }
                        .disabled(true)
                        
                        // 优化：显示真实过期时间
                        if let expiresAt = expiresAt {
                            let formatter = DateFormatter()
                            formatter.dateFormat = "yyyy-MM-dd HH:mm"
                            formatter.timeZone = TimeZone.current
                            formatter.locale = Locale.current
                            Text("过期时间: \(formatter.string(from: expiresAt))")
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.textTertiary)
                        }
                    }
                    .padding(.top, 4)
                } else {
                    // 未过期，显示接受/拒绝按钮和剩余时间
                    VStack(spacing: 4) {
                        // 优化：显示剩余时间提示
                        if let remainingTime = remainingTimeText {
                            Text(remainingTime)
                                .font(AppTypography.caption2)
                                .foregroundColor(AppColors.warning)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        HStack(spacing: AppSpacing.sm) {
                        Button(action: {
                            respondToNegotiation(accept: true)
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                Text(LocalizationKey.notificationAgree.localized)
                                    .font(AppTypography.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.success)
                            .cornerRadius(AppCornerRadius.small)
                        }
                        .disabled(isResponding || isLoadingTokens || tokenAccept == nil || isNegotiationExpired)  // 优化：过期时不可点击
                        
                        Button(action: {
                            respondToNegotiation(accept: false)
                        }) {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16))
                                Text(LocalizationKey.notificationReject.localized)
                                    .font(AppTypography.caption)
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(AppColors.error)
                            .cornerRadius(AppCornerRadius.small)
                        }
                        .disabled(isResponding || isLoadingTokens || tokenReject == nil || isNegotiationExpired)  // 优化：过期时不可点击
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .cardStyle(cornerRadius: AppCornerRadius.medium)
        .opacity(notification.isRead == 1 ? 0.7 : 1.0)
        .onAppear {
            // 优化：先检查是否已过期（基于创建时间，作为初始检查）
            if isNegotiationOffer {
                if let createdAt = DateFormatterHelper.shared.parseDatePublic(notification.createdAt) {
                    let now = Date()
                    let timeInterval = now.timeIntervalSince(createdAt)
                    // 5分钟 = 300秒
                    if timeInterval > 300 {
                        // 基于创建时间判断已过期，但还需要从API获取真实过期时间确认
                        isExpired = true
                        // 计算过期时间（创建时间+5分钟）
                        expiresAt = createdAt.addingTimeInterval(300)
                    } else {
                        // 计算过期时间（创建时间+5分钟），作为初始值
                        expiresAt = createdAt.addingTimeInterval(300)
                    }
                }
            }
            
            if (isNegotiationOffer || isApplicationMessage) && tokenAccept == nil {
                loadNegotiationTokens()
            }
        }
        .alert(LocalizationKey.errorOperationFailed.localized, isPresented: $showError) {
            Button(LocalizationKey.commonOk.localized, role: .cancel) {}
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
                        // 优化：如果获取token失败，可能是已过期或不存在（404）
                        // 检查错误类型和消息，如果是404或包含过期/不存在相关关键词，静默处理
                        var shouldMarkAsExpired = false
                        
                        // 检查是否是404错误
                        if case .httpError(let code) = error, code == 404 {
                            shouldMarkAsExpired = true
                        }
                        
                        // 检查错误消息中是否包含过期/不存在相关关键词
                        let errorMsg = error.userFriendlyMessage.lowercased()
                        if errorMsg.contains("过期") || 
                           errorMsg.contains("expired") ||
                           errorMsg.contains("无效") ||
                           errorMsg.contains("invalid") ||
                           errorMsg.contains("不存在") ||
                           errorMsg.contains("not found") ||
                           errorMsg.contains("已过期") ||
                           errorMsg.contains("does not exist") ||
                           errorMsg.contains("resource") {
                            shouldMarkAsExpired = true
                        }
                        
                        // 优化：对于议价token相关的404错误，统一视为过期（静默处理）
                        // 因为这是正常的业务逻辑（token过期），不应该显示错误提示
                        if case .httpError(let code) = error, code == 404 {
                            // 404错误对于议价token来说，通常意味着已过期，静默处理
                            shouldMarkAsExpired = true
                        }
                        
                        if shouldMarkAsExpired {
                            // 静默处理：只标记为过期，不显示错误提示
                            isExpired = true
                        } else {
                            // 其他错误才显示错误提示
                            errorMessage = error.userFriendlyMessage
                            showError = true
                        }
                    }
                },
                receiveValue: { response in
                    // 优化：保存任务状态
                    taskStatus = response.taskStatus
                    
                    // 优化：如果token为nil，说明已过期
                    if response.tokenAccept == nil && response.tokenReject == nil {
                        isExpired = true
                    } else {
                        tokenAccept = response.tokenAccept
                        tokenReject = response.tokenReject
                        taskId = response.taskId ?? notification.taskId
                        applicationId = response.applicationId ?? notification.relatedId
                        
                        // 优化：解析真实过期时间
                        if let expiresAtString = response.expiresAt {
                            let isoFormatter = ISO8601DateFormatter()
                            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                            isoFormatter.timeZone = TimeZone(identifier: "UTC") ?? TimeZone(secondsFromGMT: 0)!
                            expiresAt = isoFormatter.date(from: expiresAtString)
                            
                            // 如果过期时间已过，标记为过期
                            if let expiresAt = expiresAt, Date() >= expiresAt {
                                isExpired = true
                            }
                        } else {
                            // 如果没有过期时间，基于创建时间+5分钟计算
                            if let createdAt = DateFormatterHelper.shared.parseDatePublic(notification.createdAt) {
                                expiresAt = createdAt.addingTimeInterval(300)  // 5分钟
                                if Date() >= expiresAt! {
                                    isExpired = true
                                }
                            }
                        }
                        
                        // 优化：如果任务已进入进行中或更后面的状态，标记为过期
                        if let taskStatus = taskStatus {
                            let status = taskStatus.lowercased()
                            if status == "in_progress" || 
                               status == "pending_payment" || 
                               status == "pending_confirmation" || 
                               status == "completed" || 
                               status == "cancelled" {
                                isExpired = true
                            }
                        }
                    }
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

